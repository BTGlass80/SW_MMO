extends SceneTree
## envelope_replay — dev command: re-run a recorded combat exchange from a pasted envelope.
## PT1 prep (Fable review "nearly-free win"): envelopes already carry the exchange seed, so a
## replay from seed+inputs gives combat debugging + player-dispute resolution for free.
##
## Usage (from the project root):
##   & "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --headless --path . \
##       --script res://tools/envelope_replay.gd -- --envelope <path-to-json>
##
## The JSON file may be: ONE envelope object, an ARRAY of envelopes, or a resolve_window
## dump {"envelopes": [...]}. Accepts absolute, res:// or user:// paths.
##
## Modes (logic lives in scripts/rules/envelope_replay_model.gd — pure, smoke-tested):
##  - FULL: the envelope carries the optional replay_inputs block
##    (combat_event_envelope_model.attach_replay_inputs) -> the exchange is re-resolved from the
##    recorded seed+inputs and compared event-by-event against what was recorded.
##  - PARTIAL: today's live envelopes (no replay_inputs) -> verifies what is verifiable from the
##    envelope alone: derived-field consistency + seed/round lineage across the recorded events.
##
## NOTE (HOT follow-up, next scripts/net tick): the producer wiring is ONE line in
## combat_arena.gd (resolve_window / resolve_hostile_aggression), right after
## envelope_for_result: wrap the envelope with
## CombatEventEnvelopeModel.attach_replay_inputs(envelope, record["state"], tstate, pools,
## distance, cover, defender_defense_stance, window_for_shooter) — server-side/log-side only;
## do NOT broadcast replay_inputs to clients (it contains both sheets' pools).
##
## Exit 0 = the replay REPRODUCES every recorded outcome; exit 1 = a mismatch (diff printed).

const EnvelopeReplayModel = preload("res://scripts/rules/envelope_replay_model.gd")

func _init() -> void:
	var path := _envelope_path_from_args()
	if path == "":
		printerr("envelope_replay: usage: --script res://tools/envelope_replay.gd -- --envelope <path-to-json>")
		quit(1)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("envelope_replay: cannot open '%s' (error %d)" % [path, FileAccess.get_open_error()])
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var envelopes := _collect_envelopes(parsed)
	if envelopes.is_empty():
		printerr("envelope_replay: '%s' holds no combat envelope (expected an object, an array, or {\"envelopes\": [...]})" % path)
		quit(1)
		return

	var rules: Node = (load("res://scripts/rules/d6_rules.gd") as GDScript).new()
	var all_match := true
	print("envelope_replay: %d envelope(s) from %s" % [envelopes.size(), path])
	for i in range(envelopes.size()):
		var envelope: Dictionary = envelopes[i]
		var report: Dictionary = EnvelopeReplayModel.replay(rules, envelope)
		print("")
		print("envelope %d/%d: kind=%s seed=%s round=%s" % [
			i + 1, envelopes.size(),
			String(envelope.get("exchange_kind", "?")),
			str(envelope.get("exchange_seed", "?")),
			str(envelope.get("round", "?")),
		])
		for line in report["lines"]:
			print(line)
		if bool(report["match"]):
			print("verdict: REPRODUCED (%s replay matches the recorded outcome)" % String(report["mode"]))
		else:
			all_match = false
			print("verdict: MISMATCH (%d differing field(s), %s mode)" % [(report["mismatches"] as Array).size(), String(report["mode"])])
	rules.free()
	print("")
	print("envelope_replay: %s" % ("ALL REPRODUCED" if all_match else "MISMATCH — recorded outcome NOT reproduced"))
	quit(0 if all_match else 1)

func _envelope_path_from_args() -> String:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var arg := String(args[i])
		if arg == "--envelope" and i + 1 < args.size():
			return String(args[i + 1])
		if arg.begins_with("--envelope="):
			return arg.substr("--envelope=".length())
		i += 1
	return ""

func _collect_envelopes(parsed: Variant) -> Array:
	var envelopes := []
	if typeof(parsed) == TYPE_DICTIONARY:
		var dict := parsed as Dictionary
		if typeof(dict.get("envelopes")) == TYPE_ARRAY:
			for entry in (dict["envelopes"] as Array):
				if typeof(entry) == TYPE_DICTIONARY:
					envelopes.append(entry)
		else:
			envelopes.append(dict)
	elif typeof(parsed) == TYPE_ARRAY:
		for entry in (parsed as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				envelopes.append(entry)
	return envelopes
