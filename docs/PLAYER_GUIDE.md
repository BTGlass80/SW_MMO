# SW MMO Prototype â€” Player Guide & Systems Manual

*Clone Wars-era (20 BBY) Mos Eisley Â· West End Games Star Wars D6 R&E Â· Godot 4.6.3*

Written 2026-07-02, **reconciled 2026-07-03 to HEAD `62ded70`** (Wave G in progress). This is a
**living prototype** under active daily development â€” so this manual does two things at once: it tells
you how to *play* what exists today, and it is honest about what is **built but not yet reachable at
the keyboard** so you always know where the edges are. Every mechanic below was read straight out of
the current source, not the older design docs.

A quick legend used throughout:

- **[LIVE]** â€” works in normal keyboard play right now.
- **[PARTIAL]** â€” works, but capped, half-wired, or only through a narrow path.
- **[LATENT]** â€” the code and rules exist and are unit-tested, but you can't reach them at the keyboard
  (usually server-wired with no client button/command yet).
- **[GATED]** â€” deliberately blocked behind an owner decision.

> **The recurring theme of this build:** *the backend keeps landing ahead of the client input.* Many
> systems below are fully wired server-side and verified by tests, but have no keybind, command, or
> screen yet â€” so they're **[LATENT]** for a keyboard player. Where that's true, this guide says so
> plainly.

---

## 0. What changed recently (Wave F â†’ Wave G)

Since the last edition, the dev loop shipped a large batch. The headline changes:

- **Death is now tiered â€” you don't instantly die anymore.** A takeout puts you **downed-in-field**
  (recoverable) at Incapacitated/Mortally-Wounded; only a *killing* hit actually kills. New **`Y`** key
  to yield, and First Aid now revives the downed. (Â§6 â€” the biggest change.)
- **Hostiles now shoot first.** In lawless/contested zones a spawned creature attacks idle players
  unprovoked every combat window. The old "if you never fire, nothing hits you" rule is **gone.** (Â§5)
- **New PvE kill vectors:** creature **venom and restraint/grapple** now tick real damage that
  *accumulates*, and **threat tiers** mean apex predators (krayt dragon, rancor, merdeth) only appear
  in escalated/dangerous zones. (Â§5â€“Â§6)
- **Kills now pay** â€” **harvest** (field-dressing) credits on top of loot, and loot **scales with the
  creature's danger tier.** Shops now **stock different gear per zone.** (Â§6â€“Â§7)
- **Named NPCs you can talk to** (press **`E`**), 22 of them across the zones, plus a cantina-plaza
  landmark. (Â§9)
- **Quests exist and track** (20 of them; completion pops a toast) â€” but there's still no board or
  command to *accept/turn in* one at the keyboard. (Â§15)
- **Content grew:** 39 creatures Â· 46 weapons Â· 31 armor Â· 20 quests Â· 22 named NPCs.
- Under the hood: corpse-looting, armor repair, cumulative PvP wounds, and PvP defender-dodge are all
  wired server-side but not yet reachable by keyboard (Â§15).

---

## 1. The single most important thing: there are two different games in this repo

A normal launch (double-click / plain run) opens the **SOLO scene** â€” `scenes/main.tscn` â€” the single-
player **blaster training range** + a **2.5D space "bridge" tactical drill**. It's a WEG-rules
sandbox: no accounts, no persistence, no economy.

The actual **server-authoritative MMO** lives in `scenes/net_world.tscn` and is **only reachable from
the command line**. Everything below is about the MMO unless it says "solo."

> âš ï¸ **The same keys mean different things in the two scenes.** In the solo range `H` opens the sheet
> and `F` is a full-dodge; in the MMO `H` is First Aid and `F` is a Force Point. Full keymaps in Â§14.

---

## 2. Quickstart â€” your first 15 minutes in the MMO

Two terminals: one server, one client.

**Terminal 1 â€” server (headless):**
```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --headless --path . res://scenes/net_world.tscn -- --server
```
Wait for `[net] server listening on port 24555` (port is hard-coded).

**Terminal 2 â€” client (GUI), unique account name:**
```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64.exe" --path . res://scenes/net_world.tscn -- --connect 127.0.0.1 --account alice --name Alice --species human
```
`--account` is required (your character's identity; each player needs a distinct one). `--species` /
`--quickstart` are optional. Species: `human, bothan, duros, mon_calamari, rodian, sullustan,
trandoshan, twilek, wookiee`. (Heads-up: canonical Star Wars names are silently rejected â€” see Â§3.)

Then, in the client:
1. **You spawn first-person at Docking Bay 94** in the *secured* Mos Eisley Spaceport, mouse captured.
   `WASD` move, mouse look, `Space` jump, `Esc` frees the cursor. HUD shows Zone / CP / Condition /
   Credits (1000).
2. **Farm your first CP â€” safely.** You start with **0 spendable CP**, so `LMB`-fire the **B1 Training
   Silhouette**. Shots resolve every **5 seconds**; tap `RMB` (up to 3Ã—) for aim. The dummy is capped
   non-lethal here â€” you can't die in the spaceport. Each disable = **+3 CP**, and it respawns.
3. **Spend CP.** `V` opens your sheet; `K` raises Blaster (or `/raise <skill>` for any skill).
4. **Meet the locals.** Walk up to a **named NPC** and press **`E`** to talk. Wander east to the
   **cantina plaza** (around world xâ‰ˆ40). `/who` lists players in your zone; `/help` prints everything.
5. **Insure before you risk it.** `B` (or `/shop`) opens the vendor; `/insure` = 500 cr for 3 covered
   deaths. Note the shop stocks different gear in each zone.
6. **Go dangerous.** `T` to travel until the zone reads **"The Dune Sea"** (lawless), or
   `/travel tatooine.dune_sea`. **Now you're at risk even standing still** â€” a spawned creature will
   fire on you.
7. **Fight â€” or get dropped.** Disable the creature for **+3 CP, loot credits (scaled by its danger
   tier), and auto-harvest credits**. If *it* drops *you*: a hit to **Incapacitated** now puts you
   **DOWNED** (an amber "You are DOWN" banner), not dead. **Wait for an ally's First Aid, or press `Y`
   to yield** (accept death â†’ respawn at the spaceport, credits kept). Only a true killing blow (or
   bleeding out while Mortally Wounded) actually kills you.

That loop â€” **farm CP in the spaceport â†’ raise skills â†’ insure â†’ travel to a lethal zone â†’ kill for
loot/harvest, or get downed and yield/revive** â€” is the current heart of the game.

---

## 3. Characters & species

- **Quick-start build [LIVE].** First login builds a WEG character: 18D (54 pips) of attributes at
  species min/max, no pre-trained skills. Persisted as JSON, drives combat immediately.
- **Nine species [LIVE].** Each has attribute ranges and a WEG **Move** rate that sets real-time speed
  (Wookiee fastest at ~7.15, Mon Calamari slower). Special abilities are flavor data, not yet applied.
- **Starting kit [LIVE].** Equipped `blaster_pistol` (4D) + `blast_vest`; a spare pistol/vest,
  `hold_out_blaster`, and `blast_helmet` in inventory; **1000 credits**; **1 Force Point**.
- **Reserved names [LIVE].** ~48 canonical Star Wars names (Kenobi, Skywalker, Ahsoka, Rex, Grievous,
  Vader, Bobaâ€¦) are **silently rejected** at registration â€” your character quietly loads under your
  account id instead (no on-screen message yet). Made-up names like "Kenobiwan" pass.
- **Custom point-buy [LATENT].** The server validates a full custom `{attributes, skills}` build, but
  the client only ever sends a quick-start â€” no in-game allocator UI, and no interactive species picker
  (species is the `--species` flag).
- **Character sheet [LIVE].** `V` toggles a panel: species, the six attributes, trained skills,
  equipped weapon/armor, credits, CP wallet, and a "(Force-sensitive)" tag if you ever awaken. It shows
  *equipped* gear only â€” **no inventory list** (a known gap).

---

## 4. Progression â€” Character Points & skills

A **dual-track CP** system (DIV-0007): fast *gameplay* CP + a slow *prestige/RP* track, both spent on
skill raises (gameplay first).

- **You start with 0 spendable CP.** A fresh character can't raise anything until it earns CP â€”
  pressing `K` immediately fails. Disable a target (even the safe spaceport dummy) for **+3 CP**.
- **Earning CP [LIVE].** +3 per combat disable is the live earner. Quest rewards *also* grant CP
  (2â€“8 each) â€” but see Â§15 on why quests aren't keyboard-claimable yet. Prestige track has no earner.
- **Raising a skill [LIVE].** Cost = the number of *dice* in the skill's current pool (steps up at
  each die boundary). `K` = raise Blaster (shortcut); **`/raise <skill>`** raises any of ~75 WEG skills
  (`/raise dodge`, `/raise first_aid`, `/raise bargain`, `/raise survival`â€¦). Applies immediately.

---

## 5. Combat â€” the WEG action window

Every ground fight is **server-authoritative WEG D6**. You stage a shot with keys, then `LMB` to submit
a **fire intent**; the server resolves all intents together every **5 seconds** (the "action window").

**Dice core [LIVE]:** a pool `ND+P` rolls N-1 plain d6 + a **Wild Die** (explodes on 6, complication on
1). Difficulties: Very Easy 5 / Easy 10 / Moderate 15 / Difficult 20 / Very Difficult 25 / Heroic 30.
Initiative each window is a Perception roll.

**Staging your shot (before `LMB`):**

| Key | Effect |
|-----|--------|
| `RMB` | **Aim** +1D per press, max +3D |
| `C`   | Cycle staged **Character Points** 0â†’5 (exploding bonus dice) |
| `F`   | **Force Point** â€” doubles all your dice for the window (one-shot; no regen) |
| `X`   | Toggle **1/4 cover** (raises incoming difficulty) |
| `Z`   | **Active dodge** â€” attack at âˆ’1D but add a dodge roll to incoming difficulty |
| `G`   | **Full dodge** â€” forgo your attack for a maximum defensive roll |
| `LMB` | **Fire** (submits, then resets aim/CP/FP/cover/dodge) |

**Resolution [LIVE]:** attack (DEX + weapon skill) + aim âˆ’ penalties vs a range/cover/dodge difficulty;
then damage vs soak (Strength + armor). Margin maps to the wound ladder: â‰¤0 none Â· 1â€“3 Stunned Â· 4â€“8
Wounded Â· 9â€“12 Incapacitated Â· 13â€“15 Mortally Wounded Â· 16+ Killed.

### What's new and important in combat

- **âš ï¸ Hostiles now initiate [LIVE].** In a **lawless or contested** zone, a spawned creature fires an
  unprovoked, **real** (uncapped) shot at *every same-zone player who didn't shoot that window* â€” every
  5 seconds. **Standing still no longer keeps you safe.** (The old "a hostile only hurts you as return
  fire" rule is dead.) Secured zones stay safe.
- **Venom & restraint [LIVE].** Some creatures inject a **venom** rider (ticks real damage vs *bare*
  Strength â€” armor doesn't help â€” on a schedule) or a **restraint/grapple** (an opposed Strength break
  check each window; failure crushes you). Both **accumulate** and can down or kill you over time. A
  re-bite refreshes venom rather than stacking it.
- **Cumulative wounds â€” partial [PARTIAL/LATENT].** Wounds now climb the WEG ladder cumulatively
  (`escalate()`) on the **PvP** path and for **venom/restraint** riders (so two sub-lethal ticks can
  stack you to Incapacitated, and the Wounded-Twice âˆ’2D tier is now real). **Plain creature gunfire is
  still highest-single-hit-wins** â€” two glancing blaster hits don't stack. (PvP itself is not
  keyboard-reachable yet â€” Â§15.)
- **Threat tiers [LIVE].** Creatures are graded tier 1â€“4. Spawns are **banded by zone alert**: calm/
  secured zones cap at tier 2; a standard lawless/contested frontier reaches tier 3; only an *escalated*
  alert (lockdown/high-alert/unrest/underworld) unlocks **tier-4 apex** creatures. So **krayt dragons,
  rancors, and the merdeth are never ambient** â€” they require a dangerous, escalated zone.
- **Force Points** still don't regenerate (1 per character, effectively one-shot), and are ignored if
  you've staged CP the same window (CP wins). **Cover** only exposes 1/4 via `X`. **Range is still a
  fixed nominal distance** (12m PvP / 10m creature) â€” where you actually stand doesn't change the hit
  difficulty yet.
- There's still **no reticle or player-target picking** at the keyboard â€” `LMB` fires at the server-
  chosen shared target (the dummy, or your zone's one hostile).

---

## 6. Getting dropped â€” downed, death, respawn, loot *(Wave G)*

This is the section that changed the most. **Being taken out is no longer an instant death.**

**The three tiers** (a takeout only happens in a lethal zone â€” creatures in lawless/contested, PvP in
lawless; secured zones are always non-lethal):

- **Incapacitated (severity 3) â†’ DOWNED [LIVE].** You're frozen where you fell (can't act), but
  **stable â€” you never auto-die.** An amber banner reads *"You are DOWN â€” press Y to yield & respawn,
  or wait for a medic."* You wait for either.
- **Mortally Wounded (severity 4) â†’ DOWNED, bleeding out [LIVE].** Same downed state, but each 5-second
  window the server rolls to see if you bleed out (2D vs rounds elapsed â€” **death becomes certain by
  ~13 windows / ~1 minute** if untreated). A First Aid that lifts you back to Incapacitated **stops the
  bleed-out.**
- **Killed (severity 5) â†’ DEATH [LIVE].** Only a true killing blow triggers the death penalty below.

**Two ways out of a downed state:**
- **`Y` â€” Yield [LIVE].** Accept death â†’ respawn. Always available while downed (works at sev 3 or 4).
  *This key is only shown on the amber downed banner, not the normal controls line.*
- **A medic's First Aid [LIVE].** An ally presses **`H`** near you; success drops your wound one level.
  Dropping you below Incapacitated **revives** you ("A medic revived you."). First Aid difficulty is
  steep at these tiers (Incapacitated 16, Mortally Wounded 21), so a trained `first_aid` medic matters.

**The death penalty (severity 5, or after you yield) [LIVE]:**
- **Credits are always kept.**
- Respawn **Wounded** at the secured spaceport med bay.
- Equipped gear loses **10% durability** (3% if insured).
- **~half** your *unequipped* inventory drops to a corpse (nothing drops if insured, or if you somehow
  died in a secured zone).
- Logging out while downed is **not** a softlock â€” the state is restored on next login.

**Insurance [LIVE].** `/insure` = 500 credits for **3 covered deaths** (no drop, only 3% durability).

**Kills pay you [LIVE].** Downing a hostile gives the killer **+3 CP**, **loot credits scaled by the
creature's threat tier** (Ã—1.0 up to Ã—3.0 â€” a riskier kill is worth more), plus **auto-harvest credits**
(Â§7). A tier-4 apex head can pay ~270 cr + harvest.

**Corpse looting [LATENT].** The server fully supports a third party looting your dropped corpse in
lawless zones (within 12m, before it decays; credits never drop) â€” but there is **no keybind, command,
or UI to do it yet**, so in practice dropped loot is still unrecoverable at the keyboard.

**PvP [LATENT].** All the lethal machinery (zone-gated to lawless, cumulative wounds, defender dodge,
full-loot corpses) is wired server-side, but **you can't target another player from the keyboard** â€”
player-targeting is headless-CLI-only. So players can't yet duel at the keyboard.

---

## 7. Economy â€” credits, vendors, harvest

A WEG-anchored credit layer (DIV-0018), separate from your CP wallet. **Kills are now a genuine credit
faucet**, not just a sink.

- **Earning:** loot from kills (**tier-scaled**, Â§6) + **harvest [LIVE]**: killing a *harvestable*
  creature (~15 of the 39 carry a harvest good â€” krayt pearl 300 cr, acklay chitin 60, various meats
  12â€“14â€¦) auto-field-dresses it and pays the value as instant credits on top of loot. No command â€” it's
  automatic on the killing blow. (The client doesn't pop a harvest toast yet; you just see the wallet
  tick up.) You can also `/sell` owned, unequipped gear back at 40%.
- **The shop [LIVE].** `B` (or `/shop`) opens a panel of priced items with Buy/Sell buttons.
  **Stock now varies by zone:** Spaceport (secured) = legal sidearms; Port Fringe / Market District
  (contested) = mid-tier + civilian variety; Dune Sea (lawless) = heavy hardware. `/buy <item_key>`,
  `/sell <item_key>`. Prices shift with the zone security tier, Director events, your Bargain skill,
  and reputation.
- **No more buyâ†’sell exploit [LIVE].** The discount floor is now clamped strictly above the 40%
  buy-back, so you can never bargain a purchase below its own resale value (that arbitrage is closed).
- **Armor can break [LATENT input].** A damaging hit degrades armor quality; at the bottom (âˆ’6 pips)
  it's **"broken" and its soak is halved** until repaired. The server has a **repair** action (priced
  off the buy-back dial), but there's **no repair command or armor-condition readout in the client
  yet**.
- **Catalog vs buyable:** 46 weapons + 31 armor exist, but only ~12 are vendor-stocked and split across
  zones; the rest are contraband/faction data that never appears in a shop.

> **The honest catch (still true):** because there's **no equip command, keybind, or inventory screen**
> at the keyboard, weapons/armor you `/buy` go into an inventory you can't view and **can't wield**. The
> server *fully* supports equipping (it drives combat) â€” it's just reachable only via a headless
> `--equip` test flag. So the earn side (loot + harvest) is now rich, but the *gear* side of spending
> is still a stub. The one clearly useful sink is **insurance**.

---

## 8. Wounds & healing â€” the medical loop

You get hurt only in combat (or from venom/restraint). Recovery, both grounded in WEG Guide 19:

- **Natural recovery [LIVE].** Each Director tick (~30s), a connected wounded character rolls its own
  **Strength** vs a difficulty and, on success, heals one step. (Applies to the "can still act" tiers.)
- **First Aid [LIVE].** `H` (or `/heal`) auto-targets the **nearest wounded ally in your zone** and
  rolls your **Technical + First Aid** vs their wound difficulty; success drops it one level. This is
  now also the **revive path for downed players** (Â§6) and can **stop a bleed-out**. You can't self-heal
  this way; there's a retry gate against spamming.
- **The mortally-wounded death roll is now LIVE** (it used to be a latent rule): a downed Mortally-
  Wounded player bleeds out over time unless treated.
- **Still no consumables** â€” no bacta, medpac, stimpack, or medical droid. Healing is the Strength tick,
  a medic's First Aid, or (for the downed) yielding.

---

## 9. The world â€” zones, travel, NPCs, the Director

- **Four Tatooine zones [LIVE]:** Mos Eisley **Spaceport** (secured, your spawn), **Spaceport Fringe**
  and **Market District** (contested), **The Dune Sea** (lawless). `T` cycles zones; `/travel <id>`
  jumps. Instant fast-travel; your zone persists across logins.
- **Named NPCs you can talk to [LIVE].** 22 hand-authored Clone Wars locals (Wuher, Chalmun, clone
  troopers, Hutt enforcers, a back-alley medic, Jawa tradersâ€¦) populate the zones as distinct low-poly
  figures with name/role plates. Walk within ~6m and press **`E`** to hear a rotating dialogue line.
  *(They're flavor: even though quest data lists some as "givers," talking does not open or turn in
  quests, and the vendor-flagged NPCs don't open a shop on talk.)*
- **A cantina plaza landmark [LIVE]** sits east of Spaceport Row (world xâ‰ˆ40) â€” a domed cantina with
  bar, booths, storage huts, stalls, and vaporators. Pure set-dressing (solid collision, no interaction).
- **The old ambient crowd [LIVE]** still exists as muted capsule markers (clone troopers, Jawas,
  smugglers) â€” decorative, *not* talkable. Two layers coexist.
- **The Director [LIVE].** A ~30s world-sim tick: decays faction influence, derives an **alert level**
  and **security overlay**, fires **world events** (12-event menu with Clone Wars headlines on your NEWS
  banner), advances ambient NPCs, **spawns tier-banded hostiles** in lethal zones, runs recovery, and
  **persists the whole world across restarts.** Alert level now also gates which creature tiers spawn.

---

## 10. Factions, orgs & territory â€” *mostly gated*

A complete faction/guild/territory economy exists end-to-end â€” org membership, `/claim` and `/release`
of territory nodes, treasury income, rank authority, faction tags, cross-zone `/org` chat â€” **but there
is still no way to *join* a faction in normal play** (owner-gated faction-join isn't implemented). So
for a normal player this all rejects with `no_org`; it's reachable only via the test-only
`--allow-test-org` server flag. Treat the whole layer as **[GATED]**.

**Org sieges** (a full declaredâ†’musterâ†’assaultâ†’resolution takeover state machine) and **PvP consent**
(opt-in duels + funded bounties) are **[LATENT]** â€” coded and tested as pure models, but not wired into
live netcode. No one can declare a siege, place a bounty, or accept a duel yet.

---

## 11. The Force â€” *earned, rare, and still cosmetic*

Access is the **SWG "Village" model** (DIV-0011): not chargen-selectable, not buyable. A hidden dormant
**awakening track** silently accrues attunement from play (exploring, disabling foes, healing, surviving
danger); a rare per-tick roll can begin a 4-phase awakening that eventually flips you Force-sensitive
and prints *"You feel the Force awaken within you."* It's deliberately hard to reach (soft cap ~8).

> **Set expectations:** awakening is still **essentially a cosmetic flag.** It seeds the three WEG Force
> skills at 0D but there's **no power list, no way to invoke them, no Dark Side economy** â€” Force powers
> remain owner-gated. Even a fully awakened character can't yet *do* anything with the Force.

The **Force Point** (`F` in combat) is a separate universal resource, unrelated to Force-sensitivity.

---

## 12. Chat & social

`Enter` opens the chat/command bar (`Esc` cancels). Game commands parse first, else it's chat.

- **Channels:** `/say` (`/s`, or plain text) = local Â· `/ooc` (`/o`) = galaxy-wide Â· `/emote`
  (`/em`, `/me`, `/e`) = local action Â· `/org` (`/g`) = your org, cross-zone (gated). Clamped to 256 chars.
- **`/who`** lists players in your zone with condition + faction tag; **`/help`** prints the full
  command + keybind list.

---

## 13. The solo drills (default scene, `main.tscn`)

A plain run opens this â€” two single-player WEG sandboxes on the Mos Eisley set (no accounts/persistence;
RNG unseeded, so outcomes vary):

- **Blaster training range [LIVE].** Spawn at the firing line facing five WEG targets (static, moving,
  behind cover, a walker plate). `LMB` fires from a real crosshair; `RMB` aims; stage the round with `C`
  cover, `Q` dodge, `F` full dodge, `P`/`O` attack/soak CP, `G` Force Point. Remotes fire back on a live
  clock with a rich behavior state machine. `E` inspects a target; `H` opens a demo sheet; `R` resets.
- **2.5D space "bridge" [LIVE].** `M` toggles a tactical overlay (now with an **isometric 3D view**) of
  the Mos Eisley approach with five contacts. Run WEG ship actions as single keys: `N` sensors, `I` id,
  `X` hail, `B` gunnery, `J` shields, `K` repair, `Y` astrogation, `L` maneuver, `U` crew assists; `T`
  pauses the traffic clock, `;` steps it, `Tab`/`,`/`.` cycle contacts. A hidden hostile builds a firing
  solution and shoots you if you don't out-fly or out-shoot it.

None of the solo content exists in the MMO scene, and it doesn't link to your MMO character.

---

## 14. Controls reference

**âš ï¸ Two different keymaps â€” same letters, different meaning. Keys are hardcoded, not rebindable.**

| Key | MMO (`net_world.tscn`) | Solo range (`main.tscn`) |
|-----|------------------------|--------------------------|
| `WASD` / mouse / `Space` | move / look / jump | move / look / jump |
| `LMB` | fire (server target) | fire at crosshair target |
| `RMB` | aim +1D | aim +1D |
| `C` | cycle staged CP 0â€“5 | toggle cover |
| `F` | Force Point | full dodge |
| `X` | toggle 1/4 cover | â€” |
| `Z` | active dodge | pause/resume remotes |
| `G` | full-dodge stance | Force Point |
| `Q` | â€” | declare dodge |
| `P` / `O` | â€” | queue attack CP / soak CP |
| `V` | character sheet | force an incoming volley |
| `H` | **First Aid / revive nearest ally** | character sheet |
| `E` | **talk to nearest named NPC** (within ~6m) | inspect target |
| `Y` | **yield (only while downed)** | â€” |
| `K` | raise Blaster (spend CP) | *(space: repair)* |
| `T` | travel to next zone | *(space: pause traffic)* |
| `B` | open shop | *(space: gunnery)* |
| `M` | â€” | open/close space bridge |
| `N I X J Y L U` `;` `Tab , .` | â€” | space-bridge actions (Â§13) |
| `Enter` | open chat/command bar | â€” |
| `Esc` | release mouse / cancel | release mouse |

**MMO slash commands** (unchanged set): `/raise <skill>` Â· `/travel <zone>` Â· `/heal` Â· `/shop` Â·
`/buy <item>` Â· `/sell <item>` Â· `/insure` Â· `/who` Â· `/help` Â· `/claim <node>` Â· `/release <node>`
*(orgs gated)* Â· `/say /ooc /org /emote`. **There is no quest, equip, repair, or loot command yet.**

**Key launch flags** (after the bare `--`): server â†’ `--server`, `--combat-window <s>`,
`--director-tick <s>`, `--resource-tick <s>`; client â†’ `--connect <host>`, `--account <id>`,
`--name <n>`, `--species <k>`, `--quickstart`, `--secret <s>`, `--zone <id>`. Many headless one-shot
test flags exist (`--autofire`, `--accept-quest`, `--claim-quest`, `--equip`, `--talk`, `--yield`,
`--buy`, â€¦) â€” these drive the not-yet-keyboard-reachable systems for automated tests, not play.

---

## 15. Known limitations â€” what is *not* keyboard-playable yet

The build's backend consistently runs ahead of its client input. Fully-working server systems you still
can't reach at the keyboard:

1. **You cannot equip gear** â€” no `/equip`, keybind, or inventory screen (server RPC works; `--equip`
   test flag only). Bought gear can't be wielded. **Insurance is still the one clearly useful credit
   sink.**
2. **No inventory screen** â€” the `V` sheet shows equipped items only; `/sell` needs item keys you can't
   browse.
3. **Quests are server-live but not keyboard-playable [PARTIAL].** 20 quests load, objectives auto-track
   (kill N / reach zone / earn credits), and completion pops a toast â€” but **accepting and claiming are
   CLI-only** (`--accept-quest`/`--claim-quest`); there's no quest board, command, or NPC hand-in. So
   nothing tracks unless a quest was accepted via CLI.
4. **PvP has no target UI** â€” the full PvP loop (lawless-gated, cumulative wounds, defender dodge,
   full-loot corpses) is wired server-side, but you can't target another player at the keyboard.
5. **Corpse looting** works server-side (lawless, 12m) but has **no client trigger** â€” dropped loot is
   unrecoverable in practice.
6. **Armor repair** works server-side (armor can break â†’ soak halved), but there's **no repair command
   or armor-condition readout**.
7. **Factions/orgs/territory are gated** (no faction-join); **sieges and duels/bounties are latent**
   (coded, unwired).
8. **Positional range is latent** â€” combat still uses fixed 12m/10m distances; moving doesn't change hit
   difficulty.
9. **The Force is cosmetic** â€” awakening flips a flag but grants no usable powers.
10. **No custom chargen UI, no matchmaking/menu for the MMO** (CLI-launch only), **Force Points don't
    regenerate**, and reserved-name rejection is **silent** (no message).

---

## 16. Why it works this way â€” design notes

Mechanics follow WEG D6 R&E as the authority, with documented divergences in
`docs/DIVERGENCE_LEDGER.md`. The ones you'll feel:

- **DIV-0006 / DIV-0027** death: partial loss + insurance, **credits always kept**; and the new **tiered
  downed-in-field** model (incapacitated is stable, mortally-wounded bleeds out, `Y` to yield, First Aid
  revives) â€” the owner-decided "true tiering."
- **DIV-0017 / DIV-0024** PvE lethality: hostiles initiate unprovoked in lawless/contested; venom &
  restraint are real accumulating kill vectors.
- **DIV-0016** the secured spaceport stays a non-lethal **sparring** zone so you can learn the loop safely.
- **DIV-0018 / DIV-0023 / DIV-0026** economy: WEG list prices, 40% sell sink, per-zone stock, **harvest**
  as a kill-faucet, and an **armor-repair** sink; the buyâ†’sell arbitrage floor is closed.
- **DIV-0019** PvP: zone-based (lawless) open PvP with cumulative wounds and reaction dodge (wired
  server-side; no keyboard targeting yet). Duels/bounties (DIV-0022) and sieges (DIV-0021) are designed
  but latent.
- **DIV-0020** quests: a MUD/MMO objective-and-reward layer (server-live, no client board yet).
- **DIV-0011** Force: the earned, rare "SWG Village" unlock instead of chargen-selectable Jedi.

For the current build state, the active work queue, and what's next, see `docs/WAVE_G_BACKLOG.md`,
`docs/OVERNIGHT_QUEUE.md`, and the divergence ledger.

---

*This guide reflects the code at HEAD `62ded70`. The build changes daily under active development â€”
the most likely near-term flips from [LATENT] to [LIVE] are a quest board + accept/claim commands, an
equip/inventory UI, a PvP target selector, and corpse-loot/repair commands (the client-input catch-up).
Check the divergence ledger and the Wave G backlog for the current frontier.*
