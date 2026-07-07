# SW_MMO â€” Path Forward (strategy addendum to the 2026-07-02 review)

Ordered by leverage. Items 1, 2, 4â€“7 are directly executable by Claude Code; item 3 is an owner fork.

## 1. Name the next milestone: First Strangers Night (PT1)
The unattended loop optimizes breadth ("exhaust the backlog"); a playtest optimizes truth. Wave F made the game *playable* â€” by its own developer. The highest-information action available is 5â€“10 outside players for one evening running a scripted ~30-minute loop:

> chargen â†’ range sparring â†’ travel â†’ Dune Sea hostile fight â†’ die â†’ respawn â†’ buy insurance â†’ buy/sell â†’ lawless PvP duel â†’ org claim.

Let PT1 pull priorities instead of the backlog pushing them. Its ship list is small and knowable: the three P0s, hostile initiation (P1-1), the presentation wave already in flight, the auth bundle (G8 stops being "someday" â€” it gates strangers), and telemetry (item 5). Add one nearly-free pre-req: a **20-bot headless soak test** â€” the client affordances (`--autofire`, `--travel`, `--fire-nearest`, `--quickstart`) already exist, so a script that launches 20 bot clients for 30 minutes and watches tick time + snapshot size is an afternoon, and it finds the first scaling wall before humans do.

## 2. Adopt the opposite launch posture from SW_MUSH â€” deliberately, in writing
SW_MUSH's posture is *everything pre-launch* â€” correct for a persistent RP world where live schema churn breaks trust. The MMO is the opposite genre: live-service, where every historical lesson says launch a tight loop and grow. The persistence layer is already migration-friendly (`schema_version`, JSON records, crash-safe writes). Write the posture into `CLAUDE.md` so the loop doesn't inherit the MUSH stance by osmosis:

> *The MMO ships thin and iterates live; the MUSH ships complete.*

Corollary â€” a standing **not-before-live list**: multiplayer space (the ~4k-line solo space model stays a solo mode until the ground loop has real players; porting it to the server is a project the size of everything built so far), sieges, player cities, any runtime LLM.

## 3. Decide the two-games relationship explicitly (owner fork â€” one line in both CLAUDE.md files)
Both repos' loops currently assume they're the main character. A solo developer running two 80%-done multiplayer games is the standard failure mode; the fix is not effort, it's an explicit answer:

- **A** â€” MUSH launches first; the MMO is the successor and inherits post-launch learnings + the content pipeline. (Protects the launch investment; MMO cadence slows.)
- **B** â€” the MMO is the product; the MUSH becomes the design-lab/content-forge and launches minimally or not at all. (Honest if the MMO is where the pull is; releases the "everything pre-launch" pressure.)
- **C** â€” both live: MUSH as the RP/canon layer, MMO as the gameplay layer, shared era + data. (Most ambitious; only viable if item 6's pipeline is formalized.)

Whichever: content flows **one way** (already the rule). Formalize cadence â€” a scheduled `mush-content-porter` re-extraction (weekly) with a source-hash manifest diff, so "SW_MUSH changed a lot" becomes an automated sync report instead of a review-time surprise. The 06-24 port is already ~10 heavy MUSH content-days stale.

## 4. Institutionalize the seam audit
The gate catches syntax and assertion failures. It structurally *cannot* catch a green smoke asserting unwired semantics (P0-1), a ledger row claiming tiering the wire skips, or a stale comment describing pre-fix behavior (P2-1). Three additions:

- **Post-[HOT]-wave seam audit** â€” after any wave that touched `network_manager`/`net_world`/`combat_arena`, one mandatory read-only tick by a fresh agent hunting docâ†”modelâ†”wire disagreements only. No code. (This review was that pass; make it a rule, not a favor.)
- **Dead-symbol detector in the gate** â€” for each public func/const in `scripts/rules` + `scripts/net`, grep call sites outside its own smoke; report orphans. `is_kill`/`PVP_DEATH_SEVERITY` would have flagged the day they shipped.
- **The invariant-auditor agent** from the review (era grep + FORBIDDEN_SHIPS, no client RNG, no `_intents`/client-field trust in HOT files, divergence-row-before-mechanic).

## 5. Telemetry before tuning
The MUSH learned this the long way (T3.19). The MMO has prints, not data. Pre-PT1: one structured JSONL server log â€” death (killer, zone, severity path), buy/sell (item, price, discounts applied), loot, travel, window-resolve (per-shooter severities), awaken-phase transitions. One writer func routed from the existing print sites; an afternoon. You cannot tune insurance value, loot bands, or TTK you can't see, and PT1's entire value is this data.

## 6. LLM policy for the MMO: author-time, never runtime
Keep the deterministic Director. If AI flavor is wanted (NPC barks, event headline pools, quest text), have Claude Code generate content **batches offline** that ship as reviewed JSON â€” exactly the MUSH questline authoring pattern. Runtime stays deterministic, free, and fast; the server-owns-everything doctrine stays intact. This also resolves the parked "LLM-Director-at-launch" fork with a *shape* instead of a yes/no: the answer is "yes, at the authoring desk; no, in the tick loop."

## 7. Nearly-free wins
- **Envelope replay tool** â€” envelopes already carry exchange seeds; a dev command that re-runs `resolve_exchange` from a pasted envelope and prints the audit gives combat debugging and player-dispute resolution for free. The determinism was built; spend it.
- **Server watchdog** â€” PT1 will find the first server crash. Auto-restart script + the existing crash-safe persistence = a survivable evening instead of a dead one.
- **Gate prints the counts** â€” smoke count + RPC count in `check_project.ps1` output; docs reference the gate, never a literal (kills the 59/66/72 drift class permanently).
