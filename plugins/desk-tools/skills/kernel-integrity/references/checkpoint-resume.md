# Checkpoint and Resume

## Required checkpoint fields

Record: agent/skill version; kernel name/version; target platform; size limit; source basis;
protected-baseline status; logical-file status; runtime/archive status; function inventory;
compression decisions; relocation map; no-loss findings; candidate version; defects; holds;
repair prompts; readiness label; Next Prompt Block.

## Resume prompt

```text
Resume kernel compression from this checkpoint. Preserve function, source-role rules, prompt-bank
behavior, audit/no-loss controls, logical-file parse discipline, runtime/archive separation,
protected-baseline status, candidate-only treatment, and human-review gates. Treat all generated
drafts as candidate-only.

Checkpoint:
[paste checkpoint]
```

## Resume behavior

On resume: 1. do not invent missing prior state; 2. reconstruct from the checkpoint only;
3. identify missing artifacts; 4. confirm whether the last readiness label permits continuation;
5. continue only at the safe next stage; 6. end with a new Next Prompt Block.

A bare "continue" permits resume only from checkpointed or reconstructable state — never invented
state.
