# SW MMO Prototype — Player Guide & Systems Manual

*Clone Wars-era (20 BBY) Mos Eisley · West End Games Star Wars D6 R&E · Godot 4.6.3*

Written 2026-07-02 against HEAD `7746019` (Wave F). This is a **living prototype**, not a
finished game — so this manual does two things at once: it tells you how to *play* what
exists today, and it is honest about what is **built but not yet reachable** so you always
know where the edges are. Every mechanic below was read straight out of the current source,
not the older design docs.

A quick legend used throughout:

- **[LIVE]** — works in normal play right now.
- **[PARTIAL]** — works, but capped, half-wired, or only through a narrow path.
- **[LATENT]** — the code and rules exist and are unit-tested, but nothing in live play calls them.
- **[GATED]** — deliberately blocked behind an owner decision (faction access, siege numbers…).

---

## 0. What landed most recently (Wave F, latest)

Since the first draft of this guide, the dev loop shipped a batch that mostly closes the gap
between "the backend does it" and "you can *see* it happen":

- **A presentation pass made the MMO systems visible.** Combat targets are now **rendered as
  low-poly monster/remote meshes** in front of you (not invisible server entities); the shop is a
  **real on-screen panel with Buy/Sell buttons**; death shows a **full-screen death card**; and
  you get **muzzle flashes, hit sparks, floating damage numbers, and toast pop-ups** for loot,
  credit changes, buys/sells, and Force awakenings. The backend was ahead of what was on screen —
  this catches the visuals up.
- **Zone-based PvP is now wired on the server** (lawless zones only, no consent handshake — DIV-0019).
  The combat/death/full-loot plumbing is live, **but there is still no interactive way to target
  another player** — player-vs-player fire is currently reachable only through headless test flags,
  so for a keyboard player PvP isn't playable yet. Details in §6.
- **The space bridge got an isometric 3D tactical view** and a fix for a bug that could trap you in
  the overlay (§13).
- **A quest/mission model landed as pure logic** (starter quests like "cull three Dune Sea beasts" —
  DIV-0020), but it is **not yet wired into the server**, so there's no notice board to accept
  quests from in live play. It's groundwork (§15).

---

## 1. The single most important thing: there are two different games in this repo

When you launch the project the normal way (double-click / plain run), you get the **SOLO
scene** — `scenes/main.tscn`. That is what `project.godot` sets as the run scene. It is a
single-player **blaster training range** plus a **2.5D space "bridge" tactical drill**. It is
*not* the MMO, has no accounts, no persistence, and no economy — it's a hand-authored WEG-rules
sandbox.

The actual **server-authoritative MMO** lives in a *different* scene — `scenes/net_world.tscn`
— and is **only reachable from the command line**. There is no menu button that takes you there.
This is where chargen, progression, the lethal PvE loop, credits, chat, travel, healing, and the
Force live.

> ⚠️ **The same keys mean different things in the two scenes.** In the solo range `H` opens
> your character sheet and `F` is a full-dodge; in the MMO `H` is *First Aid* and `F` is a
> *Force Point*. Don't carry muscle memory between them. Full keymaps are in §11.

The rest of this manual is mostly about the **MMO** (net world), because that's the direction of
the project. The solo drills get their own section (§10).

---

## 2. Quickstart — your first 10 minutes in the MMO

You need **two terminals**: one for the server, one for your client. Paths are the stock Windows
install locations from the repo.

**Terminal 1 — start the authoritative server (headless):**

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --headless --path . res://scenes/net_world.tscn -- --server
```

Wait for it to print `[net] server listening on port 24555`. (The port is hard-coded — there is
no `--port` flag.)

**Terminal 2 — start your client (GUI) with a unique account name:**

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64.exe" --path . res://scenes/net_world.tscn -- --connect 127.0.0.1 --account alice --name Alice --species human
```

- `--account` is the one flag you must not omit — it's your character's identity, and it's what a
  re-login loads. Every player on a server needs a **distinct** `--account` (a single-session lock
  rejects two peers on the same character with `already_logged_in`).
- `--species` and `--quickstart` are **optional** — a bare `--account alice` already gives you a
  deterministic human quick-start character. Species choices: `human, bothan, duros, mon_calamari,
  rodian, sullustan, trandoshan, twilek, wookiee`.

Then, in the client window:

1. **You spawn first-person at Docking Bay 94** in the *secured* Mos Eisley Spaceport, mouse
   captured. `WASD` move, mouse looks, `Space` jumps, `Esc` frees the cursor (click to recapture).
   The top-right HUD shows Zone / CP wallet / Condition / **Credits: 1000**.
2. **Earn your first Character Points — safely.** You start with **0 spendable CP** (see §4), so
   walk up to the **B1 Training Silhouette** and `LMB` to fire. Shots resolve on the server every
   **5 seconds**. Tap `RMB` up to 3× first for +1D aim each. The dummy shoots back but return fire
   here is **capped at Wounded** — you cannot die in the spaceport. Every time you disable it you
   get **+3 CP** and it respawns. This is a legitimate, no-risk CP farm.
3. **Spend CP.** Press `V` to open your character sheet and watch the CP wallet. A skill raise
   costs the *number of dice* in the skill's current pool (≈3–4 CP for Blaster to start). Press `K`
   to raise Blaster one pip, or press `Enter` and type `/raise dodge` (or `/raise first_aid`,
   `/raise bargain`, …) to raise **any** WEG skill. `/help` prints every command and keybind.
4. **Insure yourself before you risk death.** Press `B` (or `/shop`) to list vendor stock, then
   `Enter` → `/insure` to buy a policy: **500 credits = 3 covered deaths**. (Buying *gear* is not
   worth it yet — see the equip caveat in §5/§12.)
5. **Go lethal.** Press `T` to cycle-travel until the zone label reads **"The Dune Sea"**, or
   `/travel tatooine.dune_sea`. The lawless Dune Sea reliably spawns a hostile creature within one
   Director tick (~30s).
6. **Fight the creature.** It appears ~10m away and becomes your `LMB` target. Here return fire is
   **real and uncapped.** Disable it for **+3 CP and loot credits** (watch the Credits HUD).
7. **Die & recover.** If a hit takes you to *Incapacitated*, you respawn **Wounded** back at the
   spaceport med bay — **credits kept**, some gear durability lost, half your loose inventory
   dropped (nothing dropped if insured). The Wounded state heals on its own over Director ticks, or
   an ally can `/heal` you. There are no healing potions.

That loop — **farm CP in the spaceport → raise skills → insure → travel to a lethal zone → kill for
loot / die and respawn** — is the current heart of the game.

---

## 3. Characters & species

- **Quick-start build [LIVE].** On first login for an account, the server builds a WEG character:
  every attribute starts at the species minimum, then the remaining pips fill round-robin until
  exactly **18D (54 pips)** are spent, all within species min/max. No skills are pre-trained. The
  sheet is persisted as JSON and immediately drives combat.
- **Nine species [LIVE].** Each has per-attribute min/max dice and a WEG **Move** rate that becomes
  real-time speed (`speed = 6.5 × species_move / 10`). Wookiees are fastest (Move 11 → ~7.15) and
  have the highest Strength range (up to 6D); Mon Calamari are slower on land (Move 9). Species
  *special abilities* (Wookiee rage, Trandoshan regeneration, etc.) are **flavor data only** —
  not mechanically applied yet.
- **Starting kit [LIVE].** Equipped: `blaster_pistol` (4D energy) + `blast_vest` (+1D energy/+1D
  physical, torso). In inventory: a spare pistol & vest, a `hold_out_blaster` (3D+1), a
  `blast_helmet`. Plus **1000 credits** and **1 Force Point**.
- **Custom point-buy [LATENT].** The server's `register_account` fully validates a custom
  `{attributes, skills}` build (18D attributes, up to 7D of skills over their attribute), but the
  shipped client only ever sends a quick-start. There is **no in-game attribute/skill allocator UI**,
  and species is chosen only via the `--species` flag — no interactive picker.
- **Character sheet [LIVE].** `V` toggles a panel: species, the six attributes (DEX/KNO/MEC/PER/STR/
  TEC), your trained skills, equipped weapon/armor, credits, CP wallet, and a "(Force-sensitive)"
  tag once/if you ever awaken. Note it shows *equipped* gear only — **it does not list your
  inventory** (a known gap; see §12).

---

## 4. Progression — Character Points & skills

This is a **dual-track CP** system (divergence DIV-0007): a fast *gameplay* track and a slow
*prestige/RP* track, both spendable on skill raises (gameplay drained first).

- **You start with 0 spendable CP. [IMPORTANT]** The sheet writes a legacy `character_points: 5`
  field, but the spendable wallet the raise code reads is separate and starts at **0/0**. So a brand
  new character pressing `K` immediately gets `Raise failed: insufficient_cp` — you must **earn CP
  first** by disabling a target.
- **Earning CP [LIVE].** The only live earner is **+3 gameplay CP per combat disable** — and that
  includes the safe training dummy in the spaceport, so you never have to risk death to start
  progressing. The prestige/RP track has no wired earner yet.
- **Raising a skill [LIVE].** Cost = the number of *dice* in the skill's current total pool, so the
  price steps up at each die boundary (4D→4D+1 costs 4 CP; 5D→5D+1 costs 5). Raises apply to combat
  immediately and persist.
  - `K` = raise **Blaster** one pip (hardcoded shortcut).
  - `/raise <skill>` = raise **any** of the ~75 WEG skills by its key: `/raise dodge`,
    `/raise first_aid`, `/raise brawling`, `/raise bargain`, etc. Skill keys are lower_snake_case
    (the server even accepts an unknown key and defaults its governing attribute to Dexterity).
  - Training `first_aid` makes you a better medic; `bargain` earns you shop discounts;
    `dodge`/`brawling`/`melee_combat` improve defense and melee — all through this one path.

---

## 5. Combat — the WEG action window

Every ground fight is **server-authoritative WEG D6**. You press keys to *stage* a shot, then
`LMB` to submit a **fire intent**; the server collects everyone's intents and resolves them
together every **5 seconds** (the "action window"), owning all dice and seeds.

**The dice core [LIVE]:** a pool `ND+P` rolls N-1 plain d6 + one **Wild Die**. The Wild Die
**explodes** on a 6 (re-roll and add, uncapped) and is a **complication** on a 1 (contributes 0 and
you drop your highest plain die). Difficulties: Very Easy 5 / Easy 10 / Moderate 15 / Difficult 20 /
Very Difficult 25 / Heroic 30. Initiative each window is a **Perception** roll.

**Staging your shot (before you press LMB):**

| Key | Effect |
|-----|--------|
| `RMB` | **Aim** +1D per press, **max +3D** |
| `C`   | Cycle staged **Character Points** 0→5 (each is an exploding bonus die added to the attack) |
| `F`   | **Force Point** — doubles *all* your dice for the window (attack, dodge, soak, **and damage**) |
| `X`   | Toggle **1/4 cover** (raises the difficulty of incoming return fire) |
| `Z`   | **Active dodge** — you still attack (at −1D for the second action) but add a dodge roll to incoming difficulty |
| `G`   | **Full dodge** — forgo your attack this window for a maximum defensive roll |
| `LMB` | **Fire** (submits everything staged, then resets aim/CP/FP/cover/dodge) |

**Resolution [LIVE]:** attack pool (DEX + equipped-weapon skill) + aim − penalties, vs a
range/cover/dodge difficulty; then weapon **damage vs soak** (Strength + armor). The damage-minus-
soak margin maps to the wound ladder:

| Margin | Result |
|--------|--------|
| ≤0 | No damage |
| 1–3 | Stunned |
| 4–8 | Wounded |
| 9–12 | Incapacitated *(out — can't act)* |
| 13–15 | Mortally Wounded *(out)* |
| 16+ | Killed |

**Wound penalties [LIVE]:** Stunned −1D, Wounded −1D, Wounded-Twice −2D; Incapacitated and worse are
"out" (can neither move nor fire until healed). Armor adds soak on the energy channel, has a hit-
location coverage table, and **degrades one pip per damaging hit** (two if the hit was severe).

**Combat notes & current edges:**

- **Force Points don't regenerate.** You start with exactly 1 and nothing in the combat loop grants
  more, so FP-doubling is effectively a **one-shot**. FP is also mutually exclusive with staged CP —
  if any CP is staged, the Force Point silently no-ops (CP wins).
- **Cover** only exposes 1/4 via `X`; the 1/2, 3/4, and full (targeting-blocking) levels exist in
  the rules but aren't bound to a key.
- **Defensive CP** (spending CP on soak) and **cross-scale** (vehicle/walker) combat are coded and
  tested but **[LATENT]** — no live path uses them; ground play is character-vs-character.
- There's **no reticle or target-picking** in the MMO — `LMB` always fires at the server-chosen
  shared target (the training dummy, or the one zone hostile). Where you walk doesn't change who you
  shoot.
- **Combat is now visually legible [LIVE].** The target renders as a low-poly monster/remote mesh in
  front of you, and each resolved exchange throws **muzzle flashes, hit sparks, and floating damage
  numbers**, so you can read the fight without watching the console log.

---

## 6. Death, respawn, loot & insurance — the lethal loop *(Wave F)*

This is the newest system and the reason combat now has stakes.

- **Where death happens [LIVE].** Only in **lethal zones**: the two *contested* zones (Spaceport
  Fringe, Market District) and the *lawless* Dune Sea. The **secured spaceport is hard-safe** —
  no hostiles spawn and all return fire is capped non-lethal. You must deliberately `T`/`/travel`
  out to be at risk. (A zone can also transiently slip one tier more dangerous if Hutt influence
  gets very high.)
- **Hostiles [LIVE].** Each Director tick (~30s) the server keeps every lethal zone that has players
  stocked with **one seeded hostile creature** (from a roster of ~16 — glim worms, stalker lizards,
  Tusken warriors, up to an acklay). All players in the zone share/fight the same one. The lawless
  Dune Sea *always* arms a hostile; contested zones only do when the random roll lands on one.
  - **Gotcha:** a hostile only hurts you as **return fire inside your own 5s window** — if you never
    fire at it, it never hits you.
- **Dying [LIVE].** A hit that takes you to **Incapacitated (severity 3)** kills you (v1 skips the
  mortally-wounded grace roll). You get a **full-screen death card**, then:
  - **Credits are always kept.**
  - Equipped gear loses **10% durability** (uninsured).
  - **Half** of your *unequipped* inventory drops (equipped items never drop).
  - You respawn **Wounded** at the secured spaceport med bay.
- **Insurance [LIVE].** `/insure` = 500 credits for **3 covered deaths**. A covered death drops
  **nothing** and takes only **3%** durability.
- **Loot [LIVE].** Downing a hostile pays the killer **15–45 credits × pack size** (40–90 for
  human-scale enemies) plus a 25% chance of a 20–60 salvage bundle — on top of the +3 CP. Rewards
  now pop up as on-screen **toasts**.
- **Player-vs-Player [PARTIAL].** The PvP backend is now wired (DIV-0019): fire aimed at another
  player is server-gated to **lawless zones only** (secured and contested reject it — no consent
  handshake, purely zone-based), re-checked at resolution to close a mid-window tier flip, and it
  reuses the same lethal combat + death path. In a lawless zone a PvP kill is **full-loot** and your
  client lights up a floating **"TARGET" marker** over whoever is being shot. **The catch:** the
  interactive client has **no way to select a player as your target** — the normal `LMB` still fires
  at the shared PvE target, and player-targeting is currently reachable only through headless test
  flags (`--fire-target`, `--fire-nearest`). So PvP mechanically works but **is not yet playable at
  the keyboard**; a target-selection UI is the missing piece.
- **Corpse looting [PARTIAL].** Your dropped items are written to a corpse manifest, but **no one can
  pick them up yet** — dropped loot is effectively gone until a corpse-pickup RPC lands.

---

## 7. Economy — credits, vendors, buy/sell

A WEG-anchored credit layer (DIV-0018), separate from your CP wallet.

- **Earning:** loot from kills (§6), or selling gear back to a vendor.
- **The shop [LIVE].** `B` (or `/shop`) now opens a **real on-screen panel** with the 12 priced items
  — 10 blasters + 2 armor pieces — each with its own **Buy / Sell buttons** and your current
  credits / reputation / price multiplier shown at the top. There's no physical vendor NPC; "the shop"
  is a global command that works from any zone. Prices are WEG list values (blaster pistol 500, heavy
  blaster pistol 750, vibroblade 250, blast vest 300…).
- **Buying [LIVE]:** click **Buy** on the panel, or type `/buy <item_key>`. The **sink**: you buy at
  list price and sell back at only **40%**.
  - ⚠️ The `/buy` text hint prints `/buy heavy_blaster`, but that key doesn't exist — the real key is
    **`heavy_blaster_pistol`** (the panel buttons use the correct key, so clicking is safer than
    typing the hint).
- **Selling [LIVE]:** `/sell <item_key>` — but only for **owned, unequipped** items, so you can't
  sell your starting loadout.
- **Discounts:** a **Bargain** skill discounts buy prices (3% per die, and yes — `/raise bargain`
  trains it in normal play). Reputation-tier discounts (friendly 5% / allied 10%) are coded but
  **[LATENT]** because they require an org you can't join yet. Director events (`trade_boom`,
  `merchant_arrival`) also cheapen goods temporarily.

> **Reality check (see §12):** because there is **no equip command** in live play, weapons/armor you
> buy go into an inventory you also can't view, and can never be wielded. Today the only meaningful
> thing to spend credits on is **insurance**. The earn side (loot) is real; the spend side is a stub.

---

## 8. Wounds & healing — the medical loop

You get hurt only through combat. Two ways back to health, both grounded in WEG Guide 19:

- **Natural recovery [LIVE].** Every Director tick (~30s), each connected wounded character rolls its
  own **Strength** vs a difficulty (Stunned 8 / Wounded 11) and, on success, heals one step.
- **First Aid [LIVE].** `H` (or `/heal`) makes you a medic: it auto-targets the **nearest wounded
  ally in your zone** and rolls your **Technical + First Aid** skill vs their wound difficulty; success
  drops their wound one step. Untrained you roll a raw 2D (only reliably clears Stunned) — `/raise
  first_aid` to treat worse wounds. You can't heal yourself this way, and there's a per-target retry
  gate so you can't spam it.
- **HUD support [LIVE].** Your own condition is a color-coded HUD line; other players show their wound
  tier on their nameplate so a medic can spot who's hurt.
- **No consumables.** There is no bacta, medpac, stimpack, or medical droid. "Med bay" is just the
  respawn label. Several deeper recovery rules (stun auto-clear, the mortally-wounded death roll, a
  post-death −1D debuff timer) exist in the model but are **[LATENT]** — not called in live play.

---

## 9. The world — zones, travel, the Director

- **Four Tatooine zones [LIVE]:** Mos Eisley **Spaceport** (secured, your spawn), **Spaceport
  Fringe** (contested), **Market District** (contested), and **The Dune Sea** (lawless).
- **Travel [LIVE]:** `T` cycles to the next zone; `/travel <zone_id>` jumps to a specific one. It's
  instant command fast-travel — no routes, fuel, or distance. Your zone persists across logins.
- **Zone-scoped everything [LIVE]:** you only see players, ambient NPCs, local chat, and combat in
  *your current* zone.
- **The Director [LIVE]:** a slow autonomous world-sim tick (~30s) that decays faction influence,
  derives an **alert level** and a **security overlay**, fires **world events** from a 12-event menu
  (Republic crackdowns, bounty surges, sandstorms, trade booms — each with a Clone Wars headline shown
  on your NEWS banner), advances a small **ambient NPC** roster (decorative crowd — clone troopers,
  Jawas, smugglers — not yet interactable), respawns hostiles, runs wound recovery, and **persists the
  whole mutable world so it survives a server restart.**

---

## 10. Factions, orgs & territory — *mostly gated*

A complete faction/guild/territory economy exists end-to-end — org membership, **`/claim`** and
**`/release`** of territory nodes, treasury income, rank authority, faction-influence-through-play,
faction tags on nameplates, and cross-zone **`/org`** chat.

**But there is no way to *join* a faction in live play** — membership is meant to originate from an
owner-gated faction-join flow that isn't implemented. So for a normal player all of this rejects with
`no_org`. It's reachable only via the **test-only** `--allow-test-org` server flag + client self-grant
flags, for headless verification. Treat this whole layer as **[GATED]** — built and tested, waiting on
your access-policy decision. (Siege/hostile-takeover of territory is deliberately not built at all,
pending owner rulings on durations and capture thresholds.)

---

## 11. The Force — *earned, rare, and currently cosmetic*

The access policy is the **SWG "Village" model** (DIV-0011): you can't pick Force-sensitivity at
chargen and you can't buy it. Instead every character carries a hidden, dormant **awakening track**
that silently accrues "attunement" from ordinary play — exploring new zones (weight ×3), disabling
foes, healing allies, surviving danger. Once attuned, a **rare** per-tick roll (~2%) can begin a
4-phase awakening; clearing all phases plus a final ~10% roll flips you Force-sensitive and prints
*"You feel the Force awaken within you."* It's deliberately hard to reach (soft server cap of ~8
latents), and only progresses while you're connected.

> **Set expectations:** awakening today is **essentially a cosmetic status flag.** It seeds the three
> WEG Force skills (Control/Sense/Alter) at 0D but there is **no power list, no way to invoke them,
> and no Dark Side economy** — Force powers remain owner-gated. So even a fully awakened character
> can't yet *do* anything with the Force.

Separately, the **Force Point** (`F` key in combat, §5) is a normal WEG resource everyone has,
unrelated to being Force-sensitive — don't confuse the two.

---

## 12. Chat & social

Press `Enter` to open the chat/command bar (`Esc` cancels). It parses game commands first, otherwise
treats your text as chat.

- **Channels:** `/say` (`/s`, or just plain text) = local to your zone · `/ooc` (`/o`) = galaxy-wide ·
  `/emote` (`/em`, `/me`, `/e`) = local action pose · `/org` (`/g`) = your org, cross-zone (needs an
  org, so gated). Text is sanitized and clamped to 256 chars.
- **`/who`** lists players in your zone with their condition and faction tag; **`/help`** prints the
  full command + keybind list.

---

## 13. The solo drills (default scene, `main.tscn`)

If you just run the project without CLI flags, this is what you get — two self-contained,
single-player WEG sandboxes on the Mos Eisley set. No accounts, no persistence, no economy; RNG is
*not* seeded here so outcomes vary each run.

- **Blaster training range [LIVE].** You spawn at the firing line facing five WEG targets (static,
  laterally-moving, behind cover at increasing range, and a walker-scale plate). `LMB` fires from a
  real crosshair (the MMO has none); `RMB` aims. Stage the round with `C` cover, `Q` dodge, `F` full
  dodge, `P`/`O` attack/soak CP, `G` Force Point. Remotes fire back on a live 6-second clock (`Z`
  pauses, `V` forces a volley now), with a rich behavior state machine (suppression, pinning, peeking,
  flanking, morale, fallback) shown as floating badges. `E` inspects any target for a full dossier;
  `H` opens a demo character sheet; `R` resets the drill.
- **2.5D space "bridge" [LIVE].** `M` toggles a full-screen tactical overlay of the Mos Eisley
  approach lane — now with an **isometric 3D tactical view** — with five scripted contacts and range
  rings (a recent fix also cleared a bug that could trap you in the overlay). Run WEG **ship** actions
  as single keys: `N` sensor sweep, `I` identify, `X` comms hail, `B` gunnery (with counterfire), `J`
  shields, `K` damage-control repair, `Y` astrogation, `L` maneuver (with a live route/hazard
  preview), `U` crew-station assists. `T` pauses the live traffic clock, `;` steps it one tick,
  `Tab`/`,`/`.` cycle the selected contact. There's a hidden hostile ("Sensor Shadow") that builds a
  firing solution and shoots you if you don't out-maneuver or out-shoot it.

None of this solo content exists in the MMO scene, and none of it links to your MMO character.

---

## 14. Controls reference

**⚠️ Two different keymaps — same letters, different meaning. Keys are hardcoded and not rebindable.**

| Key | MMO (`net_world.tscn`) | Solo range (`main.tscn`) |
|-----|------------------------|--------------------------|
| `WASD` / mouse / `Space` | move / look / jump | move / look / jump |
| `LMB` | fire (server target) | fire at crosshair target |
| `RMB` | aim +1D | aim +1D |
| `C` | cycle staged CP 0–5 | toggle cover |
| `F` | Force Point (double dice) | full dodge |
| `X` | toggle 1/4 cover | — |
| `Z` | active dodge | pause/resume remotes |
| `G` | full-dodge stance | Force Point |
| `Q` | — | declare dodge |
| `P` / `O` | — | queue attack CP / soak CP |
| `V` | **character sheet** | force an incoming volley |
| `H` | **First Aid nearest ally** | **character sheet** |
| `E` | — | inspect target |
| `K` | raise Blaster (spend CP) | *(space: repair)* |
| `T` | travel to next zone | *(space: pause traffic)* |
| `B` | open shop | *(space: gunnery)* |
| `M` | — | open/close space bridge |
| `N I X J Y L U` `;` `Tab , .` | — | space-bridge actions (see §13) |
| `Enter` | open chat/command bar | — |
| `Esc` | release mouse / cancel chat | release mouse |

**MMO slash commands:** `/raise <skill>` · `/travel <zone>` · `/heal` · `/shop` · `/buy <item>` ·
`/sell <item>` · `/insure` · `/who` · `/help` · `/claim <node>` · `/release <node>` *(orgs gated)* ·
`/say /ooc /org /emote`.

**Key launch flags** (everything after the bare `--`): server → `--server`, `--combat-window <s>`,
`--director-tick <s>`, `--resource-tick <s>`; client → `--connect <host>`, `--account <id>`,
`--name <n>`, `--species <k>`, `--quickstart`, `--secret <s>`, `--zone <id>`. There are also many
headless one-shot automation flags (`--autofire`, `--raise-skill`, `--buy`, `--travel`, `--equip`,
`--say`, …) and test-only flags (`--allow-test-org`, `--force-hostile`, `--force-awaken`) intended for
scripted two-process verification, not interactive play.

---

## 15. Known limitations — what is *not* playable yet

Being upfront so nothing surprises you:

1. **You cannot equip gear in normal play.** There is no `/equip` command and no keybind — equipping
   is reachable only via the headless `--equip` test flag. So anything you `/buy` lands in an
   inventory you also **can't view**, and can never be wielded. **Net effect: the only real credit
   sink today is `/insure`.** The loot/credit loop and the CP loop are coherent; the *gear* loop is a
   stub.
2. **No inventory screen** — the `V` sheet shows equipped items only.
3. **PvP has no target-selection UI** — the server-side PvP loop is wired (lawless-only, DIV-0019),
   but the interactive client can't aim at another player; `LMB` still hits the shared PvE target, and
   player-targeting only works through headless test flags. So players can't yet fight each other at
   the keyboard.
4. **No quest board yet** — a quest/mission model with starter quests exists (DIV-0020) but isn't
   wired to a giver/notice board or fed live events, so quests can't be accepted or completed in play.
5. **Corpse loot is unrecoverable** — dropped items are gone; no one can pick them up.
6. **Factions/orgs/territory are gated** — no way to join a faction, so `/claim`, `/org`, treasuries,
   and faction tags are unreachable without a test flag.
7. **The Force is cosmetic** — awakening flips a flag but grants no usable powers.
8. **No custom chargen UI** — you always get the deterministic quick-start; the point-buy builder is
   server-side only.
9. **Force Points don't regenerate** — 1 per character, effectively single-use.
10. **No matchmaking/menu for the MMO** — it's CLI-launch only; a plain run opens the solo range.

---

## 16. Why it works this way — design notes

The mechanics above follow WEG D6 R&E as the authority, with deliberate, documented divergences
recorded in `docs/DIVERGENCE_LEDGER.md`. The ones you'll actually feel in play:

- **DIV-0006** death penalty: partial loss + insurance, **credits always kept** (a mainstream-MMO
  retention choice over hardcore full-loot).
- **DIV-0007** dual-track CP: fast gameplay progression plus a slow prestige/RP track.
- **DIV-0016 / DIV-0017** lethality: the secured spaceport is a non-lethal **sparring** zone (return
  fire capped at Wounded) so the wound/medical loop is safe to learn; travel to contested/lawless
  zones lifts the cap for real, lethal creature combat and the death loop.
- **DIV-0018** economy: WEG list prices are the buy anchor; the 40% sell buy-back is the money sink.
- **DIV-0011** Force: the earned, rare "SWG Village" unlock instead of chargen-selectable Jedi.
- **DIV-0019** PvP: zone-based (lawless-only) open PvP with **no consent handshake**, reusing the
  same combat + death loop; full-loot in lawless.
- **DIV-0020** quests: a MUD/MMO objective-and-reward translation (WEG has no formal quest rule),
  rewards reusing the existing credit + CP tracks. Pure model today; live wiring is a follow-up.

For the current build state, roadmap, and what's queued next, see `docs/SESSION_HANDOFF.md`,
`docs/WAVE_F_HANDOFF.md`, and `docs/UNATTENDED_BACKLOG.md`.

---

*This guide reflects the code at HEAD `7746019`. The build is under active development and moves
under you — as Wave F continues (a PvP target UI, equip/inventory UI, corpse looting, a quest board,
faction access), the [PARTIAL]/[LATENT]/[GATED] items above are the most likely to flip to [LIVE].
Check the divergence ledger and handoffs for the current frontier.*
