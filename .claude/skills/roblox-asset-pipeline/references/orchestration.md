# Orchestrating the work (agents, approvals, autonomous runs)

## Who does what (pattern that worked)

| Role | Does | Never |
|---|---|---|
| main session (you) | plans, exports, uploads, places, verifies in Studio, reports | invents approvals |
| researcher | source families + licences + coverage table | downloads/imports |
| art-director | maps every sheet to a candidate, credits, atlas notes | approves |
| modeler agents (parallel, one batch each) | build/edit in headless Blender, renders, checks, files | edit docs, touch others' files |
| level-designer | placement table from the level doc | runs Studio |
| game-designer | proposals when an art choice becomes design (animal = class) | decides |
| secretary / recorder | writes the user's decision verbatim into the decisions log, opens questions | decides |

The user approves; record every approval/decision with the user's literal words before mass work.
When a choice is not made by the user, record it as an open (non-blocking) question with a recommendation -
do not silently decide.

## Modeler brief (templates/BRIEF_modeler.md)

Shared brief file referenced by every batch prompt: method (headless wrapper), conventions (units, front,
pivot, atlas, separate moving parts), quality gates (z-fight 0, budgets, first-person render, close-ups),
delivery paths, "do not edit docs". Batch prompt = sheets + specifics + known traps. Batches of 4-6 assets
per agent, 4-6 agents in parallel is fine; tell them about environment problems as soon as one finds them
(e.g. the WMI hang workaround) via message to the running agents.

## Approval loop

board → user picks/edits per category → record → build edits → Studio test batch → user "aprovar" → record →
commit. Users edit previews in Studio themselves (resizing, rotating): read the state back (sizes, rotations)
and carry their values into the source files and the sheets - previews are not the source.

## Autonomous / overnight runs

When the user hands over ("faz sozinho, de manhã eu vejo"):
- Keep everything reversible (hide, don't delete; separate folders; commits on a feature branch, no push).
- Calibrate first (scale/orientation) on one asset, then go wide.
- Verify each area with captures/probes and fix what you can; list the rest.
- End with a short morning report: done / where / how to toggle / stayed blockout / decisions pending /
  "save the place". Mention that the user must save the place (MCP cannot).
