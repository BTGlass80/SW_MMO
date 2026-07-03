extends RefCounted
## Pure quest / mission model (overnight C2 — the "things to do" substrate). Deterministic, NO RNG.
## Tracks a character's accepted quests + progress against in-play EVENTS (combat disables, travel,
## credit gains) and computes completion + a one-time reward. Consumes data/quests_clone_wars.json.
## The SERVER owns the live state (sheet.quests); this is the pure, headlessly-testable logic.
## MUSH has a mission system; WEG R&E has no formal quest rule — this is a MUD/MMO translation
## (DIV-0020), like DIV-0001's room->zone translation. Rewards reuse the existing economy + CP tracks.
##
## Objective kinds (objective.kind):
##   "disable"      — disable count creatures; optional target_key (a creature_key) narrows it.
##   "reach_zone"   — enter zone_id (progress 0->1).
##   "earn_credits" — accrue count credits (lifetime, summed from credit-gain events).
##
## Event shape (server feeds these): {type, ...}
##   {type:"disable", creature_key:String}   {type:"travel", zone_id:String}   {type:"credits", amount:int}

# A fresh, unaccepted quest-state block.
static func initial_quests() -> Dictionary:
	return {}

# How much `event` advances `objective` (0 if unrelated). Never negative.
static func objective_delta(objective: Dictionary, event: Dictionary) -> int:
	var kind := String(objective.get("kind", ""))
	var etype := String(event.get("type", ""))
	match kind:
		"disable":
			if etype != "disable":
				return 0
			var target := String(objective.get("target_key", ""))
			if target != "" and String(event.get("creature_key", "")) != target:
				return 0
			return 1
		"reach_zone":
			if etype == "travel" and String(event.get("zone_id", "")) == String(objective.get("zone_id", "")):
				return 1
			return 0
		"earn_credits":
			if etype == "credits":
				return maxi(int(event.get("amount", 0)), 0)
			return 0
	return 0

# Accept a quest (idempotent — re-accepting keeps existing progress). Non-mutating.
static func accept(quests: Dictionary, quest_id: String) -> Dictionary:
	var next := quests.duplicate(true)
	if not next.has(quest_id):
		next[quest_id] = {"progress": 0, "complete": false, "claimed": false}
	return next

# Apply one event to every ACCEPTED, unclaimed quest, advancing progress + flipping `complete`
# when progress reaches the objective count. Non-mutating; returns the new quest-state block.
static func record_event(quests: Dictionary, quest_defs: Dictionary, event: Dictionary) -> Dictionary:
	var next := quests.duplicate(true)
	for quest_id in next:
		var st: Dictionary = next[quest_id]
		if bool(st.get("claimed", false)) or bool(st.get("complete", false)):
			continue
		var qdef: Dictionary = quest_defs.get(quest_id, {})
		if qdef.is_empty():
			continue
		var count := int((qdef.get("objective", {}) as Dictionary).get("count", 1))
		var prog := int(st.get("progress", 0)) + objective_delta(qdef.get("objective", {}), event)
		st["progress"] = mini(prog, count)
		if int(st["progress"]) >= count:
			st["complete"] = true
		next[quest_id] = st
	return next

static func is_complete(quests: Dictionary, quest_id: String) -> bool:
	return bool((quests.get(quest_id, {}) as Dictionary).get("complete", false))

static func can_claim(quests: Dictionary, quest_id: String) -> bool:
	var st: Dictionary = quests.get(quest_id, {})
	return bool(st.get("complete", false)) and not bool(st.get("claimed", false))

# Claim a completed quest's reward ONCE. Returns {ok, quests, reward:{credits, cp}}; reward is zero
# when not claimable (not complete / already claimed / unknown). Non-mutating.
static func claim(quests: Dictionary, quest_defs: Dictionary, quest_id: String) -> Dictionary:
	if not can_claim(quests, quest_id):
		return {"ok": false, "quests": quests, "reward": {"credits": 0, "cp": 0}}
	var next := quests.duplicate(true)
	(next[quest_id] as Dictionary)["claimed"] = true
	var reward: Dictionary = (quest_defs.get(quest_id, {}) as Dictionary).get("reward", {})
	return {"ok": true, "quests": next, "reward": {"credits": int(reward.get("credits", 0)), "cp": int(reward.get("cp", 0))}}

# Load the quest_defs map ({quest_id -> def}) from the parsed data file's "quests" array.
static func defs_from_data(data: Dictionary) -> Dictionary:
	var out := {}
	for q in data.get("quests", []):
		if typeof(q) == TYPE_DICTIONARY and String((q as Dictionary).get("id", "")) != "":
			out[String((q as Dictionary)["id"])] = q
	return out
