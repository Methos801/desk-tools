# Desk Tools 0.5.4

Desk Tools is a Copilot plugin for planning, implementation review, and
handoffs. Its agents and skills cover bounded task packets, corpus inventory,
and preserving controls when revising instruction kernels.

## Try a read-only local preview

Use a current GitHub Copilot CLI, and run the following from a clean workspace
that has no other Desk Tools installation or same-named workspace skills:

```powershell
$plugin = (Resolve-Path .\plugins\desk-tools).Path
copilot --plugin-dir $plugin plugin list --json
copilot --plugin-dir $plugin skill list --json
```

Look for external `desk-tools` version `0.5.4` and 11 skill entries whose paths
point to this bundle. This checks discovery, not model execution. Existing
workspace/profile skills can take precedence over plugins. GitHub Copilot
Desktop use has been reported by the author; it is not independently tested
against this exact bundle. Model/tool availability and behavior depend on the
host and model. Do not give example workloads access to private data.

For a simple demo, ask a compatible host to review a change to a synthetic
README using `review-work`, then capture the result with `checkpoint-handoff`.
No additional service or connector is needed for that walkthrough.

The bundle contains the Desk Tools plugin only. See [MIT License](LICENSE).
