# Persistence Model — What Survives a Restart, and Where It Lives

Status: DESIGN (docs + data schemas only — no gameplay code). Author:
world-sim-designer. Companion to `docs/WORLD_SIM_DESIGN.md` and
`docs/FACTION_TERRITORY_DESIGN.md`. This is the **M1.4 persistence backbone**
design (`docs/MULTIPLAYER_FOUNDATION.md` roadmap: accounts/characters,
save/load position + sheet; JSON first, then SQLite per the architecture).

The owner direction is **player-driven & persistent world**: a server restart must
resume the *same galaxy* — same character positions and sheets, same faction
influence, same territory claims, same in-flight sieges, same city footprints. This
document enumerates **exactly what server state must persist** and the **storage
path: SQLite first, PostgreSQL later** (per `docs/PHASED_PLAN.md` Phase 4), with
table/collection sketches keyed to the data schemas.

## 0. Principles

1. **Server owns all durable truth.** Persistence mirrors the in-memory
   authoritative state (`scripts/net/world_state.gd` and the sibling world-sim
   models). Clients never persist gameplay state; the server saves and loads it.
2. **Pure models, side-effecting store.** The pure sim/rules models stay
   socket-free and DB-free (headlessly testable). A thin persistence layer
   (engineer-built) serializes them to/from the store. The schemas in
   `data/schemas/*.json` are the **on-the-wire/at-rest contract**; SQL columns
   below map onto them.
3. **Restart-survival is the acceptance test.** For every system: kill the server
   mid-activity, restart, and the world resumes — character where they stood, a
   siege in `active` still counting down, influence intact.
4. **Transient state is deliberately NOT persisted.** PvP challenge/consent flags,
   the per-session lawless-entry acknowledgement, and the LLM dynamic ambient pool
   are intentionally lost on restart (a stale PvP flag from yesterday is a bug).
   Everything else persists.
5. **Forward-compat via JSON `extra`.** Every schema carries an `extra` JSON blank;
   every table below carries an `extra TEXT` (SQLite) / `extra JSONB` (Postgres)
   column. New fields go into `extra` with **zero migration** — the project's
   idiomatic "blank space" (matches the MUSH's `attributes`/`ai_config_json`
   convention noted in `ambient_npc_life_design_v1` §5.3).
6. **Additive, versioned migrations.** A `schema_version` (PRAGMA user_version in
   SQLite) gates additive `CREATE TABLE IF NOT EXISTS` / `ADD COLUMN` migrations.
   Land empty tables early so a later feature never migrates a hot, populated DB.

---

## 1. What must persist (the enumeration)

Grouped by owner and keyed to the schema that defines its shape.

### A. Accounts & characters (player save)
| State | Persist? | Schema / table |
|---|---|---|
| Account (login identity, owned-character list) | **Yes** | `accounts` table |
| Character identity, species, name | **Yes** | `player_persistence` → `characters` |
| Last authoritative position (zone, pos, yaw) | **Yes** | `player_persistence.position` |
| WEG D6 sheet (attributes, skills, CP, FP, Force flag, wound state, credits) | **Yes** | `player_persistence.sheet` |
| Org membership (faction, rank, rep, guilds, switch cooldown) | **Yes** | `player_persistence.org` |
| City role (founder/mayor/citizen/…, home cooldown, banishment expiry) | **Yes** | `player_persistence.city_role` |
| Pending zone-influence credit (uncommitted deltas) | **Yes** | `player_persistence.world_hooks.pending_zone_influence` |
| Active-bounty flag | **Yes** | `player_persistence.world_hooks.active_bounty` |
| Per-session lawless-warning ack | **No** (session) | reset on login |
| Inventory / equipment (future) | **Yes** (deferred) | `extra` now; own table later |

### B. Director world sim
| State | Persist? | Schema / table |
|---|---|---|
| Per-zone faction influence (republic/cis/hutt/independent) | **Yes** | `faction_zone_state` → `faction_zone_state` |
| Derived alert level + security overlay | **Yes** (cache; re-derivable) | same row |
| Active world-event instances (type, zones, expiry) | **Yes** | `world_event_instances` |
| Era-progression milestones already fired | **Yes** | `world_milestones` |
| News / director log (headlines, audit, optional token cost) | **Yes** | `director_log` |
| Static ambient pool keys | **Yes** (authored data) | data files, not DB |
| Dynamic ambient pool (LLM-generated) | **No** (transient) | in-memory; re-generated |

### C. Security zones
| State | Persist? | Schema / table |
|---|---|---|
| Zone security base tier, faction overrides, overlay rules, incentives | **Yes** | `security_zone` → `security_zones` |
| Transient effective-security overlay | **No** (re-derived each tick) | computed from B + claims + cities |
| PvP challenge/consent flags | **No** (transient) | in-memory |

### D. Territory, cities, sieges
| State | Persist? | Schema / table |
|---|---|---|
| Per-(org,zone) territory influence + decay timer | **Yes** | `territory_influence` |
| Territory claims (node, org, security, guard, maintenance, income) | **Yes** | `territory_claim` → `territory_claims` |
| Guard NPC state | **Yes** (on claim row) | `territory_claims.guard_*` |
| **In-flight sieges (state machine, timers, score, consent scope)** | **Yes** | `siege_state` → `sieges` |
| Resolved-siege history (audit, news) | **Yes** | `sieges` (terminal rows) + `director_log` |
| Player cities (name, founder, mayor, tier, zone, tax, MOTD, rate cap) | **Yes** | `cities` |
| City rooms (HQ/expansion, citizen-only flag) | **Yes** | `city_rooms` |
| City banishments / guest list | **Yes** | `city_members` |

### E. Organizations
| State | Persist? | Schema / table |
|---|---|---|
| Org identity, axis, treasury, rank table | **Yes** | `orgs` |
| Org shared storage (resources/items from claims) | **Yes** | `org_storage` |
| Membership roster (also denormalized on character) | **Yes** | `org_members` |

### F. Ambient NPC life (post-launch; scaffold early per `ambient_npc_life_design_v1`)
| State | Persist? | Schema / table |
|---|---|---|
| Per-NPC ambient goal/room/move state | **Yes** | `npc_ambient_state` |
| NPC↔NPC relationship affinity | **Yes** | `npc_ambient_relationship` |

> Per `ambient_npc_life_design_v1` §5/§6: land these two **empty** tables
> pre-launch (lowest-risk `CREATE TABLE IF NOT EXISTS`), build the sim against the
> already-present schema post-launch — never migrate a live, populated DB.

---

## 2. Storage path — SQLite first, Postgres later

Per `docs/PHASED_PLAN.md` Phase 4 ("PostgreSQL for durable state when SQLite stops
being enough") and `docs/MULTIPLAYER_FOUNDATION.md` M1.4 ("JSON first, then SQLite
per the architecture doc").

**Staged plan:**

1. **JSON-file save (prototype / M1.4 first cut).** Per-character JSON blobs +
   a world-state JSON, written on the autosave/logout tick. Cheapest to stand up;
   exactly the `player_persistence` / `faction_zone_state` schema shapes serialized
   to disk. Good enough for a few players and headless tests. Risk: no concurrency
   control, no queries.
2. **SQLite (single-server durable).** One file DB the dedicated server opens. WAL
   mode for concurrent read during write. All tables below. This is the **default
   target** for a single shard: transactional, queryable, restart-safe, zero ops.
   The MUSH itself runs on SQLite at MUSH scale, so the model is proven.
3. **PostgreSQL (multi-shard / scale).** When one server/shard is no longer enough
   (Phase 4 boundary): the **same logical schema** moves to Postgres with minimal
   change — `TEXT`→`TEXT`, `INTEGER`→`INTEGER`/`BIGINT`, `REAL`→`DOUBLE PRECISION`,
   and the JSON `extra` columns become `JSONB` (gaining indexable JSON queries).
   Designed so the migration is mechanical: no schema redesign, just a dialect port
   + a data copy. Cross-shard concerns (a character moving between shard-owned
   zones, global org/city/siege records) are resolved by making org/city/siege/
   world-sim tables **globally owned** (one authoritative writer) while character
   and per-zone rows can be shard-local — but that boundary is a Phase-4 detail,
   flagged in Open Questions, not decided here.

**Why this order:** start with the lowest-ops thing that survives a restart (JSON),
graduate to SQLite the moment you need transactions and queries (claims, sieges,
influence), and only pay for Postgres when concurrency across shards forces it.
Observability (structured logs, admin audit = `director_log`) is present from
SQLite onward (Phase 4 "observability from day one").

---

## 3. Table / collection sketches (SQLite dialect; Postgres notes inline)

Types: SQLite `TEXT`/`INTEGER`/`REAL`. Postgres: `TEXT`/`INTEGER`(or `BIGINT`)/
`DOUBLE PRECISION`, and every `extra TEXT` → `extra JSONB`. `*_unix` are epoch
seconds (`REAL`). Composite/JSON sub-objects from the schemas are stored as JSON in
a single column unless called out as their own table.

```sql
-- A. ACCOUNTS & CHARACTERS -------------------------------------------------
CREATE TABLE IF NOT EXISTS accounts (
    account_id     TEXT PRIMARY KEY,
    login          TEXT UNIQUE NOT NULL,
    auth_hash      TEXT NOT NULL,            -- never store plaintext
    created_unix   REAL,
    last_login_unix REAL,
    extra          TEXT DEFAULT '{}'
);

-- shape: data/schemas/player_persistence.schema.json
CREATE TABLE IF NOT EXISTS characters (
    character_id   TEXT PRIMARY KEY,
    account_id     TEXT NOT NULL REFERENCES accounts(account_id),
    name           TEXT NOT NULL,
    species        TEXT,
    -- position (world_state.gd units): zone + x/y/z + yaw
    pos_zone_id    TEXT,
    pos_x          REAL, pos_y REAL, pos_z REAL, yaw REAL,
    -- WEG sheet stored as JSON (attributes/skills are dice-code maps)
    sheet_json     TEXT NOT NULL,            -- attributes, skills, cp, fp, force_sensitive, wound_state, credits
    -- org membership (denormalized for fast login; org_members is source of truth)
    faction_id     TEXT, faction_axis TEXT, faction_rank INTEGER DEFAULT 0,
    faction_rep    INTEGER DEFAULT 0, faction_switch_cooldown_unix REAL,
    guild_ids_json TEXT DEFAULT '[]',
    -- city role
    city_id        TEXT, city_role TEXT,
    city_home_cooldown_unix REAL, banished_until_unix REAL,
    -- world hooks (durable cooldowns / pending credit)
    pending_influence_json TEXT DEFAULT '[]',
    active_bounty  INTEGER DEFAULT 0,
    created_unix   REAL, last_saved_unix REAL,
    extra          TEXT DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_char_account ON characters(account_id);
CREATE INDEX IF NOT EXISTS idx_char_zone    ON characters(pos_zone_id);

-- B. DIRECTOR WORLD SIM ----------------------------------------------------
-- shape: data/schemas/faction_zone_state.schema.json
CREATE TABLE IF NOT EXISTS faction_zone_state (
    zone_id        TEXT PRIMARY KEY,
    inf_republic   INTEGER DEFAULT 30,
    inf_cis        INTEGER DEFAULT 10,
    inf_hutt       INTEGER DEFAULT 30,
    inf_independent INTEGER DEFAULT 30,
    alert_level    TEXT,                     -- derived cache
    security_base  TEXT,                     -- mirror of security_zones (denorm for hot read)
    security_overlay TEXT,                   -- derived cache, nullable
    ambient_static_key TEXT,
    tick           INTEGER DEFAULT 0,
    last_recompute_unix REAL,
    extra          TEXT DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS world_event_instances (
    event_id       TEXT PRIMARY KEY,
    type           TEXT NOT NULL,            -- fixed-menu enum
    zones_json     TEXT NOT NULL,            -- affected zone ids
    headline       TEXT,
    started_at_tick  INTEGER,
    expires_at_tick  INTEGER,
    expired         INTEGER DEFAULT 0,
    extra          TEXT DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_event_active ON world_event_instances(expired);

CREATE TABLE IF NOT EXISTS world_milestones (
    milestone_key  TEXT PRIMARY KEY,         -- e.g. 'republic_grip'; fires once
    fired_unix     REAL,
    extra          TEXT DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS director_log (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    ts_unix        REAL,
    kind           TEXT,                     -- 'faction_turn'|'narrative_event'|'siege'|'milestone'
    summary        TEXT,                     -- player-facing news line
    details_json   TEXT,
    token_cost_in  INTEGER DEFAULT 0,        -- optional LLM accounting
    token_cost_out INTEGER DEFAULT 0,
    extra          TEXT DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_dlog_ts ON director_log(ts_unix);

-- C. SECURITY ZONES --------------------------------------------------------
-- shape: data/schemas/security_zone.schema.json
CREATE TABLE IF NOT EXISTS security_zones (
    zone_id        TEXT PRIMARY KEY,
    display_name   TEXT,
    domain         TEXT DEFAULT 'ground',    -- 'ground'|'space'
    security_base  TEXT NOT NULL,            -- 'secured'|'contested'|'lawless'
    faction_overrides_json TEXT DEFAULT '[]',
    overlay_rules_json     TEXT DEFAULT '{}',
    lawless_incentives_json TEXT DEFAULT '{}',
    extra          TEXT DEFAULT '{}'
);

-- D. TERRITORY / CITIES / SIEGES -------------------------------------------
CREATE TABLE IF NOT EXISTS territory_influence (
    org_id         TEXT NOT NULL,
    zone_id        TEXT NOT NULL,
    score          INTEGER DEFAULT 0,        -- 0..150
    last_presence_unix REAL,                 -- decay timer
    last_activity_unix REAL,
    extra          TEXT DEFAULT '{}',
    PRIMARY KEY (org_id, zone_id)
);

-- shape: data/schemas/territory_claim.schema.json
CREATE TABLE IF NOT EXISTS territory_claims (
    claim_id       TEXT PRIMARY KEY,
    node_id        TEXT UNIQUE NOT NULL,     -- one claim per node
    zone_id        TEXT NOT NULL,
    org_id         TEXT NOT NULL,
    claimed_by_char_id TEXT,
    security_effective TEXT,
    influence_tier_at_claim TEXT,
    guard_npc_id   TEXT, guard_template_key TEXT, guard_alive INTEGER, guard_stationed_unix REAL,
    maint_claim_weekly INTEGER DEFAULT 200, maint_guard_weekly INTEGER DEFAULT 100, maint_next_unix REAL,
    income_last_unix REAL, income_last_json TEXT,
    siege_id       TEXT,                     -- back-pointer when contested, else NULL
    claimed_at_unix REAL, last_presence_unix REAL,
    extra          TEXT DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_claim_org  ON territory_claims(org_id);
CREATE INDEX IF NOT EXISTS idx_claim_zone ON territory_claims(zone_id);

-- shape: data/schemas/siege_state.schema.json  (THE Drop-6D state machine)
CREATE TABLE IF NOT EXISTS sieges (
    siege_id       TEXT PRIMARY KEY,
    claim_id       TEXT NOT NULL,
    node_id        TEXT NOT NULL,
    zone_id        TEXT NOT NULL,
    defender_org_id TEXT NOT NULL,
    attacker_org_id TEXT NOT NULL,
    state          TEXT NOT NULL,            -- declared|active|lockout|resolving|captured|repelled|aborted
    phase_started_unix REAL, phase_deadline_unix REAL,
    config_json    TEXT,                     -- snapshot of timers/thresholds at declaration
    pvp_consent_active INTEGER DEFAULT 0, pvp_scope_json TEXT DEFAULT '[]',
    attacker_points REAL DEFAULT 0, defender_points REAL DEFAULT 0,
    contributions_json TEXT DEFAULT '[]',    -- audit log of scoring events
    outcome_json   TEXT,                     -- set on terminal state
    declared_unix  REAL,
    extra          TEXT DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_siege_state ON sieges(state);
CREATE INDEX IF NOT EXISTS idx_siege_node  ON sieges(node_id);

CREATE TABLE IF NOT EXISTS cities (
    city_id        TEXT PRIMARY KEY,
    name           TEXT UNIQUE NOT NULL,
    org_id         TEXT NOT NULL,
    founder_char_id TEXT, mayor_char_id TEXT,
    hq_tier        TEXT,                     -- outpost|chapter_house|fortress
    zone_id        TEXT NOT NULL,
    state          TEXT DEFAULT 'active',    -- active|dissolved
    tax_rate       REAL DEFAULT 0.0, rate_cap REAL DEFAULT 0.10,
    motd           TEXT,
    founded_unix   REAL,
    extra          TEXT DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS city_rooms (
    city_id        TEXT NOT NULL REFERENCES cities(city_id),
    node_id        TEXT NOT NULL,
    kind           TEXT NOT NULL,            -- 'hq'|'expansion'
    citizen_only   INTEGER DEFAULT 0,
    PRIMARY KEY (city_id, node_id)
);

CREATE TABLE IF NOT EXISTS city_members (
    city_id        TEXT NOT NULL REFERENCES cities(city_id),
    char_id        TEXT NOT NULL,
    role           TEXT NOT NULL,            -- founder|mayor|citizen|guest|outsider|banished
    banished_until_unix REAL,
    extra          TEXT DEFAULT '{}',
    PRIMARY KEY (city_id, char_id)
);

-- E. ORGANIZATIONS ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS orgs (
    org_id         TEXT PRIMARY KEY,
    name           TEXT UNIQUE NOT NULL,
    axis           TEXT,                     -- republic|cis|hutt|independent
    treasury       INTEGER DEFAULT 0,
    rank_table_json TEXT,
    extra          TEXT DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS org_members (
    org_id         TEXT NOT NULL REFERENCES orgs(org_id),
    char_id        TEXT NOT NULL,
    rank           INTEGER DEFAULT 0, rep INTEGER DEFAULT 0, standing TEXT DEFAULT 'good',
    PRIMARY KEY (org_id, char_id)
);
CREATE TABLE IF NOT EXISTS org_storage (
    org_id         TEXT NOT NULL REFERENCES orgs(org_id),
    item_type      TEXT NOT NULL, qty INTEGER DEFAULT 0,
    PRIMARY KEY (org_id, item_type)
);

-- F. AMBIENT NPC LIFE (land empty pre-launch; build sim post-launch) -------
-- shape: ambient_npc_life_design_v1 §5.2
CREATE TABLE IF NOT EXISTS npc_ambient_state (
    npc_id         TEXT PRIMARY KEY,
    current_goal   TEXT DEFAULT '',
    current_node_id TEXT, dest_node_id TEXT,
    move_started_unix REAL, move_duration REAL, last_tick_unix REAL,
    activity       TEXT DEFAULT '',
    extra          TEXT DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_npc_amb_node ON npc_ambient_state(current_node_id);

CREATE TABLE IF NOT EXISTS npc_ambient_relationship (
    npc_id_a       TEXT NOT NULL, npc_id_b TEXT NOT NULL,
    affinity       INTEGER DEFAULT 0,        -- -100..100
    extra          TEXT DEFAULT '{}',
    PRIMARY KEY (npc_id_a, npc_id_b)
);
```

---

## 4. Save/load lifecycle

- **On login:** load `accounts` → owned `characters`; hydrate the character into
  the in-memory authoritative player dict (`world_state.gd` shape) + D6 sheet;
  spawn at `position` (fallback to a safe node if the zone is unavailable); reset
  session-scoped fields (lawless-warning ack).
- **On the autosave tick** (part of the slow-tick schedule) **and on logout:**
  snapshot the character row from authoritative memory (`last_saved_unix`). Fold
  any `pending_influence_json` into `faction_zone_state` at the next recompute,
  then clear it.
- **World-sim save:** the slow tick writes `faction_zone_state`, event instances,
  milestones, territory influence/claims, sieges, and city state transactionally as
  it mutates them — so a crash mid-tick leaves a consistent prior state, never a
  half-applied one.
- **Restart resume:** load all of B–F; **re-derive** transient caches (alert level,
  security overlay, siege `pvp_consent` flag) from persisted truth on the first
  slow tick; do **not** restore transient PvP/consent/ambient-dynamic state.
- **Siege resume specifically:** a siege in `active` with a future
  `phase_deadline_unix` keeps counting from where it was; one whose deadline passed
  during downtime advances to `resolving` on the first tick after restart — the
  contest is honored, not silently dropped.

---

## 5. OPEN OWNER DECISIONS (flagged — NOT decided here)

The persistence layer **stores** these but does not set their rules; the rule
decisions belong to the owner (see `docs/WORLD_SIM_DESIGN.md` §7 and
`docs/FACTION_TERRITORY_DESIGN.md` §9):

1. **Force / Jedi scarcity & access** — persisted as `sheet.force_sensitive`
   (boolean hook). What grants it, and how rare, is undecided.
2. **Death / loot penalty model** — persisted as `sheet.wound_state`. What happens
   to position/inventory/credits at `incapacitated`/`dead` (and whether it varies
   by security tier) is undecided; the inventory table that a loot-drop model would
   touch is deferred (lives in `extra` until then).
3. **CP progression pace** — persisted as `sheet.character_points`. No earn rate or
   weekly cap is encoded; the optional RP-evaluator CP trickle and lawless CP bonus
   are on/off hooks only.

These are data fields with no baked policy. Any divergence from WEG/MUSH a chosen
policy creates gets a `docs/DIVERGENCE_LEDGER.md` row first.

---

## 6. Open questions for the owner

1. **JSON-first or straight to SQLite for M1.4?** JSON is faster to stand up but
   has no transactions/queries; sieges and claims really want SQLite. Recommend a
   thin JSON cut to prove save/load of position+sheet, then SQLite before territory
   ships.
2. **Autosave cadence.** How often to snapshot characters (every slow tick is
   wasteful; too rare risks loss on crash)? Recommend ~60 s autosave + always-on
   logout save, tunable.
3. **Shard ownership boundary (Phase 4).** When moving to Postgres/multi-shard,
   which records are global-single-writer (orgs, cities, sieges, world-sim) vs.
   shard-local (characters, per-zone influence for shard-owned zones)? Recommend
   global for anything cross-org/cross-zone; defer the detailed cut to Phase 4.
4. **Backup / retention.** SQLite WAL checkpoint cadence and off-box backup
   frequency for a persistent world? Recommend periodic snapshot + WAL archive.
5. **Soft-delete vs. hard-delete.** Characters/cities/orgs on disband — purge or
   tombstone (for audit/restore)? Recommend tombstone via a `deleted_unix` in
   `extra` initially.
6. **Inventory/equipment table timing.** Currently deferred to `extra`. When the
   death/loot-penalty decision lands, a real `character_inventory` table is needed;
   recommend designing it alongside that decision so the loot model and the storage
   land together.

---

## Schemas referenced

- `data/schemas/player_persistence.schema.json`
- `data/schemas/faction_zone_state.schema.json`
- `data/schemas/security_zone.schema.json`
- `data/schemas/territory_claim.schema.json`
- `data/schemas/siege_state.schema.json`

Design context: `docs/WORLD_SIM_DESIGN.md`, `docs/FACTION_TERRITORY_DESIGN.md`,
`docs/MULTIPLAYER_FOUNDATION.md`, `docs/PHASED_PLAN.md`.
