<#
.SYNOPSIS
  No-loss reconciliation for the corpus-inventory workflow (PowerShell port of reconcile.py).

.DESCRIPTION
  Reads the frozen census and the append-only record files in the inventory
  workspace, applies "latest line per ID wins", and reports every artifact and
  directory that is not yet in a terminal accounted state.

  Exit codes: 0 = fully reconciled (or -Batch complete); 1 = incomplete;
  2 = record errors (bad JSON, unknown IDs, path mismatch, invalid status).
  Output matches reconcile.py. Works on Windows PowerShell 5.1 and PowerShell 7+.

.EXAMPLE
  ./reconcile.ps1 -Out .inventory-manifest -Batch B00012
#>
[CmdletBinding()]
param(
    [string]$Out = '.inventory-manifest',
    [string]$Batch,
    [int]$Limit = 50,
    [switch]$Write
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function New-Set([string[]]$items) {
    $s = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    foreach ($i in $items) { [void]$s.Add($i) }
    return , $s
}
$ArtifactStatuses = New-Set @('UNSEEN', 'QUEUED', 'PARTIAL', 'REVIEWED', 'METADATA_ONLY', 'EXCLUDED_BY_RULE', 'FAILED', 'INACCESSIBLE', 'NEEDS_REVIEW')
$ArtifactTerminal = New-Set @('REVIEWED', 'METADATA_ONLY', 'EXCLUDED_BY_RULE', 'FAILED', 'INACCESSIBLE', 'NEEDS_REVIEW')
$DirectoryStatuses = New-Set @('UNSEEN', 'ACTIVE', 'PARTIAL', 'COMPLETE', 'EXCLUDED_BY_RULE', 'INACCESSIBLE')
$DirectoryTerminal = New-Set @('COMPLETE', 'EXCLUDED_BY_RULE', 'INACCESSIBLE')

function Write-Stdout([string]$text) {
    $bytes = $Utf8NoBom.GetBytes($text)
    $stdout = [Console]::OpenStandardOutput()
    $stdout.Write($bytes, 0, $bytes.Length)
    $stdout.Flush()
}

function Get-JsonString([string]$s) {
    if ($s -notmatch '[\x00-\x1f"\\]') { return '"' + $s + '"' }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    foreach ($ch in $s.ToCharArray()) {
        $code = [int]$ch
        switch ($code) {
            34 { [void]$sb.Append('\"'); continue }
            92 { [void]$sb.Append('\\'); continue }
            10 { [void]$sb.Append('\n'); continue }
            13 { [void]$sb.Append('\r'); continue }
            9 { [void]$sb.Append('\t'); continue }
            8 { [void]$sb.Append('\b'); continue }
            12 { [void]$sb.Append('\f'); continue }
            default {
                if ($code -lt 32) { [void]$sb.Append('\u' + $code.ToString('x4')) }
                else { [void]$sb.Append($ch) }
            }
        }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

# Serialize like Python json.dumps(ensure_ascii=False): compact or indent=2.
function ConvertTo-PyJson($Value, [int]$Indent = -1, [int]$Level = 0) {
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
    if ($Value -is [string]) { return (Get-JsonString $Value) }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [decimal] -or $Value -is [double]) {
        return $Value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    $nl = ''; $pad = ''; $padIn = ''; $colon = ':'
    if ($Indent -ge 0) {
        $nl = "`n"; $pad = ' ' * ($Indent * $Level); $padIn = ' ' * ($Indent * ($Level + 1)); $colon = ': '
    }
    if ($Value -is [System.Collections.IDictionary]) {
        if ($Value.Count -eq 0) { return '{}' }
        $parts = New-Object System.Collections.Generic.List[string]
        foreach ($k in $Value.Keys) {
            $parts.Add($padIn + (Get-JsonString ([string]$k)) + $colon + (ConvertTo-PyJson $Value[$k] $Indent ($Level + 1)))
        }
        return '{' + $nl + ($parts -join (',' + $nl)) + $nl + $pad + '}'
    }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $props = @($Value.PSObject.Properties)
        if ($props.Count -eq 0) { return '{}' }
        $parts = New-Object System.Collections.Generic.List[string]
        foreach ($p in $props) {
            $parts.Add($padIn + (Get-JsonString $p.Name) + $colon + (ConvertTo-PyJson $p.Value $Indent ($Level + 1)))
        }
        return '{' + $nl + ($parts -join (',' + $nl)) + $nl + $pad + '}'
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $parts = New-Object System.Collections.Generic.List[string]
        foreach ($item in $Value) { $parts.Add($padIn + (ConvertTo-PyJson $item $Indent ($Level + 1))) }
        if ($parts.Count -eq 0) { return '[]' }
        return '[' + $nl + ($parts -join (',' + $nl)) + $nl + $pad + ']'
    }
    return (Get-JsonString ([string]$Value))
}

function Get-Prop($obj, [string]$name) {
    $p = $obj.PSObject.Properties[$name]
    if ($null -eq $p) { return $null }
    return $p.Value
}
function Test-Prop($obj, [string]$name) { return ($null -ne $obj.PSObject.Properties[$name]) }

function Read-Jsonl([string]$path, $errors, [string]$label) {
    $items = New-Object System.Collections.Generic.List[object]
    if (-not [System.IO.File]::Exists($path)) { return , $items }
    $lines = [System.IO.File]::ReadAllLines($path, $Utf8NoBom)
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $n = $i + 1
        $line = $lines[$i]
        if (-not $line.Trim()) { continue }
        try { $obj = $line | ConvertFrom-Json } catch { $errors.Add("${label}:${n}: invalid JSON"); continue }
        if ($obj -isnot [System.Management.Automation.PSCustomObject]) { $errors.Add("${label}:${n}: not a JSON object"); continue }
        $items.Add(@($n, $obj))
    }
    return , $items
}

function Get-Sorted($items) {
    $a = [string[]]@($items)
    [System.Array]::Sort($a, [System.StringComparer]::Ordinal)
    $l = New-Object System.Collections.Generic.List[object]
    foreach ($x in $a) { $l.Add($x) }
    return , $l
}
function Get-First($list, [int]$n) {
    $l = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt [Math]::Min($n, $list.Count); $i++) { $l.Add($list[$i]) }
    return , $l
}
function Get-Counted($dict) {
    $sorted = [ordered]@{}
    foreach ($k in (Get-Sorted $dict.Keys)) { $sorted[$k] = $dict[$k] }
    return $sorted
}

$outFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
$censusPath = [System.IO.Path]::Combine($outFull, 'CORPUS_CENSUS.csv')
if (-not [System.IO.File]::Exists($censusPath)) { [Console]::Error.WriteLine("ERROR: no census at $censusPath"); exit 2 }

$errors = New-Object System.Collections.Generic.List[string]
$artifacts = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
foreach ($row in (Import-Csv -LiteralPath $censusPath -Encoding UTF8)) {
    if ($row.item_type -ne 'DIRECTORY') { $artifacts[$row.item_id] = @{ path = $row.path; status = $row.census_status } }
}

$directories = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
$dirOrder = New-Object System.Collections.Generic.List[string]
foreach ($pair in (Read-Jsonl ([System.IO.Path]::Combine($outFull, 'DIRECTORY_LEDGER.jsonl')) $errors 'DIRECTORY_LEDGER.jsonl')) {
    $n = $pair[0]; $obj = $pair[1]
    $did = Get-Prop $obj 'directory_id'
    if ($did -isnot [string]) { $errors.Add("DIRECTORY_LEDGER.jsonl:${n}: missing directory_id"); continue }
    $status = Get-Prop $obj 'status'
    if (-not $directories.ContainsKey($did)) {
        if (-not (Test-Prop $obj 'direct_artifact_ids')) { $errors.Add("DIRECTORY_LEDGER.jsonl:${n}: unknown directory_id $did"); continue }
        $p = Get-Prop $obj 'path'; if ($null -eq $p) { $p = '' }
        $directories[$did] = @{ path = $p; direct = @(Get-Prop $obj 'direct_artifact_ids'); children = @(Get-Prop $obj 'child_directory_ids'); status = $status }
        $dirOrder.Add($did)
    } elseif ($null -ne $status) {
        if ((Test-Prop $obj 'path') -and ((Get-Prop $obj 'path') -cne $directories[$did].path)) { $errors.Add("DIRECTORY_LEDGER.jsonl:${n}: path mismatch for $did") }
        $directories[$did].status = $status
    }
    if ($null -ne $status -and -not (($status -is [string]) -and $DirectoryStatuses.Contains($status))) {
        $errors.Add("DIRECTORY_LEDGER.jsonl:${n}: invalid status $(ConvertTo-PyJson $status) for $did")
    }
}

foreach ($pair in (Read-Jsonl ([System.IO.Path]::Combine($outFull, 'ARTIFACT_RECORDS.jsonl')) $errors 'ARTIFACT_RECORDS.jsonl')) {
    $n = $pair[0]; $obj = $pair[1]
    $iid = Get-Prop $obj 'item_id'
    if (($iid -isnot [string]) -or -not $artifacts.ContainsKey($iid)) { $errors.Add("ARTIFACT_RECORDS.jsonl:${n}: unknown item_id $(ConvertTo-PyJson $iid)"); continue }
    if ((Test-Prop $obj 'path') -and ((Get-Prop $obj 'path') -cne $artifacts[$iid].path)) { $errors.Add("ARTIFACT_RECORDS.jsonl:${n}: path mismatch for $iid") }
    $status = Get-Prop $obj 'status'
    if (-not (($status -is [string]) -and $ArtifactStatuses.Contains($status))) {
        $errors.Add("ARTIFACT_RECORDS.jsonl:${n}: invalid status $(ConvertTo-PyJson $status) for $iid"); continue
    }
    $artifacts[$iid].status = $status
}

function Test-ArtifactTerminal([string]$id) {
    if (-not $artifacts.ContainsKey($id)) { return $false }
    $s = $artifacts[$id].status
    return (($s -is [string]) -and $ArtifactTerminal.Contains($s))
}
function Test-DirTerminal([string]$id) {
    if (-not $directories.ContainsKey($id)) { return $false }
    $s = $directories[$id].status
    return (($s -is [string]) -and $DirectoryTerminal.Contains($s))
}

if ($Batch) {
    $found = $null
    foreach ($pair in (Read-Jsonl ([System.IO.Path]::Combine($outFull, 'QUEUE.jsonl')) $errors 'QUEUE.jsonl')) {
        if ((Get-Prop $pair[1] 'batch_id') -ceq $Batch) { $found = $pair[1] }
    }
    $ids = @()
    if ($null -eq $found) { $errors.Add("QUEUE.jsonl: batch $Batch not found") }
    else { $v = Get-Prop $found 'item_ids'; if ($null -ne $v) { $ids = @($v) } }
    $pending = Get-Sorted @($ids | Where-Object { -not (Test-ArtifactTerminal $_) })
    if ($errors.Count -gt 0) { $result = 'ERRORS' } elseif ($pending.Count -eq 0) { $result = 'BATCH_COMPLETE' } else { $result = 'BATCH_INCOMPLETE' }
    $report = [ordered]@{
        mode = 'batch'
        batch_id = $Batch
        expected = $ids.Count
        terminal = $ids.Count - $pending.Count
        pending_count = $pending.Count
        pending_ids = (Get-First $pending $Limit)
        errors = (Get-First $errors $Limit)
        error_count = $errors.Count
        result = $result
    }
} else {
    $aStatus = @{}; $dStatus = @{}
    foreach ($a in $artifacts.Values) { $k = [string]$a.status; if ($aStatus.ContainsKey($k)) { $aStatus[$k]++ } else { $aStatus[$k] = 1 } }
    foreach ($d in $directories.Values) { $k = [string]$d.status; if ($dStatus.ContainsKey($k)) { $dStatus[$k]++ } else { $dStatus[$k] = 1 } }
    $unA = Get-Sorted @($artifacts.Keys | Where-Object { -not (Test-ArtifactTerminal $_) })
    $unD = Get-Sorted @($directories.Keys | Where-Object { -not (Test-DirTerminal $_) })
    $premature = New-Object System.Collections.Generic.List[object]
    foreach ($did in (Get-Sorted $directories.Keys)) {
        $d = $directories[$did]
        if ($d.status -cne 'COMPLETE') { continue }
        $openA = @($d.direct | Where-Object { -not (Test-ArtifactTerminal $_) })
        $openD = @($d.children | Where-Object { -not (Test-DirTerminal $_) })
        if ($openA.Count -gt 0 -or $openD.Count -gt 0) { $premature.Add($did) }
    }
    $ok = ($errors.Count -eq 0) -and ($unA.Count -eq 0) -and ($unD.Count -eq 0) -and ($premature.Count -eq 0)
    if ($errors.Count -gt 0) { $result = 'ERRORS' } elseif ($ok) { $result = 'RECONCILED' } else { $result = 'INCOMPLETE' }
    $report = [ordered]@{
        mode = 'full'
        artifacts = $artifacts.Count
        directories = $directories.Count
        artifacts_by_status = (Get-Counted $aStatus)
        directories_by_status = (Get-Counted $dStatus)
        unaccounted_artifact_count = $unA.Count
        unaccounted_artifact_ids = (Get-First $unA $Limit)
        unaccounted_directory_count = $unD.Count
        unaccounted_directory_ids = (Get-First $unD $Limit)
        premature_complete_count = $premature.Count
        premature_complete_ids = (Get-First $premature $Limit)
        error_count = $errors.Count
        errors = (Get-First $errors $Limit)
        result = $result
    }
}

$text = ConvertTo-PyJson $report 2
if ($Write) { [System.IO.File]::WriteAllText([System.IO.Path]::Combine($outFull, 'RECONCILE_REPORT.json'), $text + "`n", $Utf8NoBom) }
Write-Stdout ($text + "`n")
if ($report.result -eq 'ERRORS') { exit 2 }
if ($report.result -eq 'RECONCILED' -or $report.result -eq 'BATCH_COMPLETE') { exit 0 }
exit 1
