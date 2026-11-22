# Logical-File Parsing

## Trigger

Use this discipline when the source kernel or a control file is supplied as: `.json.txt`;
JSON-in-TXT; wrapped with `BEGIN_JSON` and `END_JSON`; or a logical package with a manifest,
retrieval index, fixed-mapping index, source-role lock, or validation/promotion controller.

## Parse rule

Parse from the first standalone `BEGIN_JSON` to the last standalone `END_JSON` **before** any
compression or execution decision.

## Required extraction

Extract and classify: manifest; source-role lock; retrieval index; fixed-mapping index;
summary/truncation controls; source-scope controls; anti-recursion controls; human gate;
validation/promotion controls; active-stack map where present.

## Prohibitions

- Never compress from a title summary or snippet.
- Never treat snippets as full source.
- Never treat parse success as authorization to replace a source.
- Never treat generated outputs as source authority.
- Never collapse archive/source-basis files into runtime without a specific comparison need.

## Required output — Logical File Parse Status

When logical-file mode triggers, include:

```text
Logical file detected:
Parse range used:
Required blocks found:
Required blocks missing:
Source-role lock preserved?:
Summary/snippet limitation?:
Replacement authorized?: no
HOLD items:
```

If required controller blocks are unreadable, truncated, or missing, assign HOLD or return a
limitation note before continuing.
