<#
.SYNOPSIS
  Deterministic corpus census for the corpus-inventory workflow (PowerShell port of census.py).

.DESCRIPTION
  Enumerates every directory and artifact under -Root without following links,
  assigns stable run-local IDs (D000001 / F000001), and writes the frozen census
  plus empty record files into the inventory workspace.

  Output is byte-identical to census.py for the same tree and options, except
  PROCESS_STATE.json (timestamps and absolute paths). Works on Windows
  PowerShell 5.1 and PowerShell 7+ (Windows, macOS, Linux). Never modifies -Root.

.EXAMPLE
  ./census.ps1 -Root C:\matters\corpus -Out .inventory-manifest -Exclude .git,node_modules
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Root,
    [string]$Out = '.inventory-manifest',
    [string[]]$Exclude = @(),
    [string[]]$MetadataOnly = @(),
    [switch]$NoHash,
    [int]$MaxHashMB = 100,
    [int]$BatchTokens = 12000,
    [switch]$Force
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$SchemaVersion = 1
$CensusColumns = @('item_id', 'item_type', 'path', 'parent_id', 'name', 'ext', 'size_bytes',
    'mtime_utc', 'sha256', 'likely_binary', 'link_target', 'census_status', 'note')
$BinarySniffBytes = 8192
$BinaryTokenEstimate = 50
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Stdout([string]$text) {
    $bytes = $Utf8NoBom.GetBytes($text)
    $stdout = [Console]::OpenStandardOutput()
    $stdout.Write($bytes, 0, $bytes.Length)
    $stdout.Flush()
}

function Get-JsonString([string]$s) {
    if ($null -eq $s) { return 'null' }
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

# Serialize like Python json.dumps(ensure_ascii=False): compact (separators ',' ':') or indent=2.
function ConvertTo-PyJson($Value, [int]$Indent = -1, [int]$Level = 0) {
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
    if ($Value -is [string]) { return (Get-JsonString $Value) }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [int16] -or $Value -is [byte] -or $Value -is [uint32] -or $Value -is [uint64]) {
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
    if ($Value -is [System.Collections.IEnumerable]) {
        $parts = New-Object System.Collections.Generic.List[string]
        foreach ($item in $Value) { $parts.Add($padIn + (ConvertTo-PyJson $item $Indent ($Level + 1))) }
        if ($parts.Count -eq 0) { return '[]' }
        return '[' + $nl + ($parts -join (',' + $nl)) + $nl + $pad + ']'
    }
    return (Get-JsonString ([string]$Value))
}

function ConvertTo-CsvField([string]$s) {
    if ($null -eq $s) { return '' }
    if ($s.IndexOfAny([char[]]@(',', '"', "`r", "`n")) -ge 0) { return '"' + $s.Replace('"', '""') + '"' }
    return $s
}

function Get-SortKey([string]$name) {
    $bytes = $Utf8NoBom.GetBytes($name)
    return ([System.BitConverter]::ToString($bytes)).Replace('-', '').ToLowerInvariant()
}

function Get-Ext([string]$name) {
    $i = $name.LastIndexOf('.')
    if ($i -gt 0) { return $name.Substring($i + 1).ToLowerInvariant() }
    return ''
}

function Format-Mtime([datetime]$utc) {
    return $utc.ToString('yyyy-MM-ddTHH:mm:ssZ', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Test-Match([string[]]$patterns, [string]$relPath, [string]$name) {
    foreach ($p in $patterns) {
        if ($relPath -clike $p -or $name -clike $p) { return $p }
    }
    return $null
}

# Symlinks and junctions only. Other reparse points (OneDrive/SharePoint placeholders) are real files/dirs.
function Test-IsLink($fsi) {
    if (($fsi.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) { return $false }
    try {
        if ($fsi.PSObject.Properties['LinkTarget']) { return ($null -ne $fsi.LinkTarget) }
        $lt = (Get-Item -LiteralPath $fsi.FullName -Force).LinkType
        return ($lt -eq 'SymbolicLink' -or $lt -eq 'Junction')
    } catch { return $false }
}

# Windows files whose content is not on disk (Offline / RecallOnDataAccess); reading would download them.
function Test-IsCloudPlaceholder($fsi) {
    return ((([long]$fsi.Attributes) -band (0x1000 -bor 0x400000)) -ne 0)
}

function Get-LinkTarget($fsi) {
    try {
        if ($fsi.PSObject.Properties['LinkTarget'] -and $fsi.LinkTarget) { return ([string]$fsi.LinkTarget).Replace('\', '/') }
        $t = (Get-Item -LiteralPath $fsi.FullName -Force).Target
        if ($t) { return ([string](@($t)[0])).Replace('\', '/') }
    } catch { }
    return ''
}

function Get-SniffAndHash([string]$path, [bool]$wantHash) {
    $binary = $false
    $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $buf = New-Object byte[] $BinarySniffBytes
        $total = 0
        while ($total -lt $BinarySniffBytes) {
            $n = $fs.Read($buf, $total, $BinarySniffBytes - $total)
            if ($n -le 0) { break }
            $total += $n
        }
        for ($i = 0; $i -lt $total; $i++) { if ($buf[$i] -eq 0) { $binary = $true; break } }
        $digest = ''
        if ($wantHash) {
            [void]$fs.Seek(0, [System.IO.SeekOrigin]::Begin)
            $sha = [System.Security.Cryptography.SHA256]::Create()
            try { $digest = ([System.BitConverter]::ToString($sha.ComputeHash($fs))).Replace('-', '').ToLowerInvariant() }
            finally { $sha.Dispose() }
        }
    } finally { $fs.Dispose() }
    return @($binary, $digest)
}

function New-Row {
    $r = [ordered]@{}
    foreach ($c in $CensusColumns) { $r[$c] = '' }
    return $r
}

$rootFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
$outFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
foreach ($v in @('rootFull', 'outFull')) {
    $p = Get-Variable -Name $v -ValueOnly
    $anchor = [System.IO.Path]::GetPathRoot($p)
    if ($p.Length -gt $anchor.Length) { Set-Variable -Name $v -Value ($p.TrimEnd('\', '/')) }
}
if (-not [System.IO.Directory]::Exists($rootFull)) {
    [Console]::Error.WriteLine("ERROR: root is not a directory: $rootFull"); exit 2
}
if ([System.IO.File]::Exists([System.IO.Path]::Combine($outFull, 'CORPUS_CENSUS.csv')) -and -not $Force) {
    [Console]::Error.WriteLine("ERROR: a census already exists in $outFull. The census is frozen; use -Force only to start a new run."); exit 2
}
[void][System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine($outFull, 'batches'))

$isWin = ([System.IO.Path]::DirectorySeparatorChar -eq '\')
$cmp = [System.StringComparison]::Ordinal
if ($isWin) { $cmp = [System.StringComparison]::OrdinalIgnoreCase }
$outRel = $null
$rootPrefix = $rootFull.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if ($outFull.StartsWith($rootPrefix, $cmp)) { $outRel = $outFull.Substring($rootPrefix.Length).Replace('\', '/') }

$maxHashBytes = [long]$MaxHashMB * 1024 * 1024
$rows = New-Object System.Collections.Generic.List[object]
$dirs = New-Object System.Collections.Generic.List[object]
$dirIndex = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
$script:dCount = 0
$script:fCount = 0

$rootName = [System.IO.Path]::GetFileName($rootFull)
if (-not $rootName) { $rootName = $rootFull }
$stack = New-Object System.Collections.Generic.Stack[object]
$stack.Push(@($rootFull, '.', $rootName, '', 0, $false))

while ($stack.Count -gt 0) {
    $item = $stack.Pop()
    $absPath = $item[0]; $relPath = $item[1]; $name = $item[2]; $parentId = $item[3]; $depth = $item[4]; $metaInh = $item[5]
    $script:dCount++
    $did = 'D' + $script:dCount.ToString('D6')
    $mt = ''
    try { $mt = Format-Mtime ((New-Object System.IO.DirectoryInfo $absPath).LastWriteTimeUtc) } catch { $mt = '' }
    $entry = [ordered]@{
        directory_id = $did; path = $relPath; parent_id = $parentId; depth = $depth
        expected_direct_artifacts = 0; expected_child_directories = 0
        direct_artifact_ids = (New-Object System.Collections.Generic.List[object])
        child_directory_ids = (New-Object System.Collections.Generic.List[object])
        status = 'UNSEEN'; note = ''
    }
    $dirs.Add($entry)
    $dirIndex[$did] = $entry
    if ($parentId) {
        $parent = $dirIndex[$parentId]
        $parent.child_directory_ids.Add($did)
        $parent.expected_child_directories = $parent.expected_child_directories + 1
    }
    $row = New-Row
    $row.item_id = $did; $row.item_type = 'DIRECTORY'; $row.path = $relPath; $row.parent_id = $parentId
    $row.name = $name; $row.mtime_utc = $mt; $row.census_status = 'UNSEEN'
    $rows.Add($row)

    $excl = $null
    if ($relPath -ne '.') {
        $excl = Test-Match $Exclude $relPath $name
        if ($null -ne $outRel -and $relPath -eq $outRel -and -not $excl) { $excl = 'inventory workspace' }
    }
    if ($excl) {
        $note = "excluded by rule: $excl; not descended"
        $row.census_status = 'EXCLUDED_BY_RULE'; $row.note = $note
        $entry.status = 'EXCLUDED_BY_RULE'; $entry.note = $note
        continue
    }
    $metaHere = $metaInh -or ($relPath -ne '.' -and $null -ne (Test-Match $MetadataOnly $relPath $name))

    try {
        $infos = @((New-Object System.IO.DirectoryInfo $absPath).GetFileSystemInfos())
    } catch {
        $row.census_status = 'INACCESSIBLE'; $row.note = 'cannot list directory'
        $entry.status = 'INACCESSIBLE'; $entry.note = 'cannot list directory'
        continue
    }
    if ($infos.Count -gt 1) {
        $keyed = New-Object System.Collections.Generic.List[object]
        foreach ($x in $infos) { $keyed.Add([pscustomobject]@{ K = (Get-SortKey $x.Name); V = $x }) }
        $keyed.Sort([System.Comparison[object]] { param($a, $b) [string]::CompareOrdinal($a.K, $b.K) })
        $infos = @($keyed | ForEach-Object { $_.V })
    }

    $subdirs = New-Object System.Collections.Generic.List[object]
    foreach ($e in $infos) {
        if ($relPath -eq '.') { $childRel = $e.Name } else { $childRel = $relPath + '/' + $e.Name }
        $link = Test-IsLink $e
        $isDir = (-not $link) -and ($e -is [System.IO.DirectoryInfo])
        if ($isDir) {
            $subdirs.Add(@($e.FullName, $childRel, $e.Name, $did, ($depth + 1), $metaHere))
            continue
        }
        $script:fCount++
        $fid = 'F' + $script:fCount.ToString('D6')
        $entry.direct_artifact_ids.Add($fid)
        $entry.expected_direct_artifacts = $entry.expected_direct_artifacts + 1
        $r = New-Row
        $r.item_id = $fid; $r.path = $childRel; $r.parent_id = $did; $r.name = $e.Name
        $r.ext = Get-Ext $e.Name; $r.census_status = 'UNSEEN'
        try {
            $r.mtime_utc = Format-Mtime $e.LastWriteTimeUtc
        } catch {
            $r.item_type = 'FILE'; $r.census_status = 'INACCESSIBLE'; $r.note = 'cannot stat'
            $rows.Add($r); continue
        }
        if ($link) {
            $r.item_type = 'LINK'; $r.link_target = Get-LinkTarget $e
            $r.census_status = 'METADATA_ONLY'; $r.note = 'link not followed'
        } else {
            $size = [long]$e.Length
            $r.item_type = 'FILE'; $r.size_bytes = $size.ToString([System.Globalization.CultureInfo]::InvariantCulture)
            $exclF = Test-Match $Exclude $childRel $e.Name
            $wantHash = (-not $NoHash) -and ($size -le $maxHashBytes)
            if (Test-IsCloudPlaceholder $e) {
                $r.note = 'cloud placeholder: not downloaded, not hashed'
            } else {
                try {
                    $res = Get-SniffAndHash $e.FullName $wantHash
                    if ($res[0]) { $r.likely_binary = 'true' } else { $r.likely_binary = 'false' }
                    $r.sha256 = $res[1]
                    if ((-not $NoHash) -and (-not $wantHash)) { $r.note = 'hash skipped: size' }
                } catch {
                    $r.census_status = 'INACCESSIBLE'; $r.note = 'cannot read'
                }
            }
            if ($r.census_status -eq 'UNSEEN') {
                if ($exclF) {
                    $r.census_status = 'EXCLUDED_BY_RULE'; $r.note = "excluded by rule: $exclF"
                } elseif ($metaHere -or $null -ne (Test-Match $MetadataOnly $childRel $e.Name)) {
                    $r.census_status = 'METADATA_ONLY'; $r.note = 'metadata-only by rule'
                }
            }
        }
        $rows.Add($r)
    }
    for ($i = $subdirs.Count - 1; $i -ge 0; $i--) { $stack.Push($subdirs[$i]) }
}

# Exact-content relationships (non-empty files with identical SHA-256).
$groups = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
foreach ($r in $rows) {
    if ($r.item_type -eq 'FILE' -and $r.sha256 -and $r.size_bytes -ne '' -and $r.size_bytes -ne '0') {
        if (-not $groups.ContainsKey($r.sha256)) { $groups[$r.sha256] = New-Object System.Collections.Generic.List[object] }
        $groups[$r.sha256].Add($r.item_id)
    }
}
$digests = [string[]]@($groups.Keys)
[System.Array]::Sort($digests, [System.StringComparer]::Ordinal)
$relationships = New-Object System.Collections.Generic.List[object]
foreach ($d in $digests) {
    $ids = $groups[$d]
    for ($i = 1; $i -lt $ids.Count; $i++) {
        $relationships.Add([ordered]@{ type = 'EXACT_CONTENT_MATCH'; from = $ids[$i]; to = $ids[0]; certainty = 'CONFIRMED'; source = 'census-sha256' })
    }
}

# Hierarchy-aware queue: UNSEEN files, grouped per directory in census order.
$byId = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
foreach ($r in $rows) { $byId[$r.item_id] = $r }
$queue = New-Object System.Collections.Generic.List[object]
$script:bCount = 0
function Add-Batch($dir, $items, [long]$tokens, [bool]$oversized) {
    if ($items.Count -eq 0) { return }
    $script:bCount++
    $copy = New-Object System.Collections.Generic.List[object]
    foreach ($x in $items) { $copy.Add($x) }
    $queue.Add([ordered]@{ batch_id = ('B' + $script:bCount.ToString('D5')); directory_id = $dir.directory_id
            directory_path = $dir.path; item_ids = $copy; est_tokens = $tokens; oversized = $oversized })
}
foreach ($d in $dirs) {
    $batch = New-Object System.Collections.Generic.List[object]
    [long]$tokens = 0
    foreach ($fid in $d.direct_artifact_ids) {
        $r = $byId[$fid]
        if ($r.census_status -ne 'UNSEEN') { continue }
        if ($r.likely_binary -eq 'true') { [long]$est = $BinaryTokenEstimate }
        else {
            [long]$sz = 0
            if ($r.size_bytes) { $sz = [long]$r.size_bytes }
            [long]$est = [long][Math]::Floor(($sz + 3) / 4)
        }
        if ($est -gt $BatchTokens) {
            Add-Batch $d $batch $tokens $false
            $batch.Clear(); $tokens = 0
            $one = New-Object System.Collections.Generic.List[object]; $one.Add($fid)
            Add-Batch $d $one $est $true
            continue
        }
        if ($batch.Count -gt 0 -and ($tokens + $est) -gt $BatchTokens) {
            Add-Batch $d $batch $tokens $false
            $batch.Clear(); $tokens = 0
        }
        $batch.Add($fid); $tokens += $est
    }
    Add-Batch $d $batch $tokens $false
}

function Write-Utf8([string]$fileName, [string]$text) {
    [System.IO.File]::WriteAllText([System.IO.Path]::Combine($outFull, $fileName), $text, $Utf8NoBom)
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append(($CensusColumns -join ',') + "`n")
foreach ($r in $rows) {
    $fields = foreach ($c in $CensusColumns) { ConvertTo-CsvField $r[$c] }
    [void]$sb.Append(($fields -join ',') + "`n")
}
Write-Utf8 'CORPUS_CENSUS.csv' $sb.ToString()

function Write-Jsonl([string]$fileName, $items) {
    $b = New-Object System.Text.StringBuilder
    foreach ($it in $items) { [void]$b.Append((ConvertTo-PyJson $it) + "`n") }
    Write-Utf8 $fileName $b.ToString()
}
Write-Jsonl 'DIRECTORY_LEDGER.jsonl' $dirs
Write-Jsonl 'RELATIONSHIPS.jsonl' $relationships
Write-Jsonl 'QUEUE.jsonl' $queue
Write-Jsonl 'ARTIFACT_RECORDS.jsonl' @()

$byStatus = New-Object 'System.Collections.Generic.SortedDictionary[string,object]' ([System.StringComparer]::Ordinal)
$byType = New-Object 'System.Collections.Generic.SortedDictionary[string,object]' ([System.StringComparer]::Ordinal)
foreach ($r in $rows) {
    if ($r.item_type -eq 'DIRECTORY') { continue }
    if ($byStatus.ContainsKey($r.census_status)) { $byStatus[$r.census_status] = [int]$byStatus[$r.census_status] + 1 } else { $byStatus[$r.census_status] = 1 }
    if ($byType.ContainsKey($r.item_type)) { $byType[$r.item_type] = [int]$byType[$r.item_type] + 1 } else { $byType[$r.item_type] = 1 }
}
$counts = [ordered]@{
    directories = $script:dCount
    artifacts = $script:fCount
    artifacts_by_census_status = $byStatus
    artifacts_by_type = $byType
    exact_content_relationships = $relationships.Count
    queue_batches = $queue.Count
}
if ($queue.Count -gt 0) { $next = 'Process batch ' + $queue[0].batch_id } else { $next = 'No UNSEEN artifacts; run reconcile' }
$state = [ordered]@{
    schema_version = $SchemaVersion
    phase = 'CENSUS_FROZEN'
    root = $rootFull
    output = $outFull
    created_utc = (Format-Mtime ([datetime]::UtcNow))
    generator = 'census.ps1'
    config = [ordered]@{
        exclude = (New-Object System.Collections.Generic.List[object] (, [object[]]$Exclude))
        metadata_only = (New-Object System.Collections.Generic.List[object] (, [object[]]$MetadataOnly))
        hash = [bool](-not $NoHash); max_hash_mb = $MaxHashMB; batch_tokens = $BatchTokens
    }
    counts = $counts
    last_completed_batch = $null
    next_action = $next
}
Write-Utf8 'PROCESS_STATE.json' ((ConvertTo-PyJson $state 2) + "`n")

Write-Stdout ((ConvertTo-PyJson $counts) + "`n")
exit 0
