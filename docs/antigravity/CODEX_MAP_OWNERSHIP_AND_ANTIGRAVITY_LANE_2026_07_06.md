# Codex Map Ownership and Antigravity Lane

Date: 2026-07-06
Owner direction: Codex handles the authored Mos Eisley map/playspace directly; Antigravity handles everything else unless explicitly asked to pair on a map task.

## Current State

Codex has taken ownership of the Mos Eisley visual/collision loop for now.

The latest Codex map pass:

- fixed the POI slug mismatch that prevented Customs, Speeders, and Transport Depot identity dressing from running;
- moved south-side POI dressing onto the street-facing side;
- rebuilt Bay 94's service/cargo dressing so it no longer shows white default-material panels or red/yellow debug cube stacks;
- raised low awnings/scanner arches that created stray player-capsule collision;
- regenerated the 13 canonical playtest captures;
- confirmed the full gate green. Trust the current gate output for smoke/RPC counts
  rather than the historical literals in review docs. The latest Codex acceptance run
  passed Python tests, import, runtime launch, all wired GDScript smokes, and the
  world capture/collision/grounding checks:

```text
All checks passed.
World Collision Route Smoke: OK - Checked 13 probes against blocking geometry
World Capture Points Smoke: OK - Found 13 capture points
World Grounding Smoke: OK
```

This does not mean the map is release-quality art. It means the worst visible regressions and stale-evidence failures are fixed, and the map is back to a controlled improvement lane.

## Ownership Split

### Codex owns for now

- `scripts/world/world_builder.gd` authored Mos Eisley geometry.
- Capture point composition and visual evidence under `captures/playtest/`.
- Stray collision created by map dressing.
- Bay 94, Spaceport Row, Customs, Speeders, Transport Depot, Control Tower, and Cantina visual acceptance.
- Any future map pass that changes collision, capture points, or large set-dressing.

Antigravity should not broaden, restyle, or replace the Mos Eisley map without an explicit owner request. If a non-map task requires a map hook, keep the hook minimal and call it out in the handoff.

### Antigravity owns

- Server-authoritative gameplay loops outside map construction.
- Economy/crafting/market/item identity closure.
- Wire-level proof of beta loops.
- Persistence, telemetry, and migration-safe data shape fixes.
- Focused tests and full-gate maintenance.
- Docs that describe actual shipped systems and remaining non-map gaps.
- Roadmap extension proposals when the project reaches the trigger below.

## Antigravity's Active Non-Map Priorities

Do not start with new visual work. Start with beta-spine proof.

Recommended next lane:

1. Prove the complete item economy loop end to end:
   `survey -> harvest -> craft -> list -> buy -> use -> telemetry/persistence`.
2. Normalize item identity across live paths:
   `instance_id` / `template_id` should work consistently through inventory, bazaar, First Aid, ammo, crafted outputs, vendors, and item use.
3. Move crafted power packs toward item-instance truth instead of legacy ammo counters.
4. Harden space travel only as a server-owned solo/character loop:
   launch, cargo, mine/salvage, land, sell/list/craft. Do not build multiplayer space.
5. Add focused wire/composition smokes beside every beta-facing loop.
6. Keep `tools/check_project.ps1` green and paste exact gate output in handoffs.

## Roadmap Expansion Trigger

Do not expand the beta roadmap merely because the map looks less bad or the gate is green.

Ask Codex/owner for roadmap expansion only when all of these are true:

- Full gate is green.
- The 13 playtest captures are fresh and visually acceptable enough that map polish is no longer blocking beta planning.
- The economy/item loop has at least one end-to-end wire/composition smoke.
- Item identity is normalized enough that crafted items survive list/buy/use without legacy-shape assumptions.
- No parked not-before-live systems were wired by accident.
- The remaining gaps are sequencing/product questions rather than obvious broken-loop repairs.

When those are true, Antigravity should request a roadmap extension with:

- exact latest commit;
- exact full-gate output;
- list of beta loops proven by tests;
- list of known remaining gaps;
- explicit confirmation that no map work is being claimed as release-quality unless Codex has accepted the captures.

## Practical Rule

Antigravity should treat map work as blocked unless explicitly assigned. Codex will handle map quality and will tell Antigravity when the visual/collision state is good enough to stop gating roadmap planning.

Until then, Antigravity's best contribution is to make the non-map MMO spine boringly reliable.
