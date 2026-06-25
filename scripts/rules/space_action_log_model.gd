extends RefCounted

const DEFAULT_LIMIT := 4
const DEFAULT_TEXT_LIMIT := 72

static func append_entry(log_entries: Array, category: String, text: String, limit: int = DEFAULT_LIMIT, text_limit: int = DEFAULT_TEXT_LIMIT, tag: String = "") -> Array:
	var next_entries := log_entries.duplicate(true)
	var clean_category := category.strip_edges()
	if clean_category == "":
		clean_category = "Action"
	var clean_text := text.strip_edges().replace("\n", " ")
	var clean_tag := tag.strip_edges()
	if text_limit > 0 and clean_text.length() > text_limit:
		clean_text = clean_text.substr(0, maxi(text_limit - 3, 0)) + "..."
	next_entries.append({
		"category": clean_category,
		"text": clean_text,
		"tag": clean_tag,
	})
	while next_entries.size() > maxi(limit, 1):
		next_entries.pop_front()
	return next_entries

static func tag_for_cue_level(cue_level: String) -> String:
	match cue_level:
		"critical":
			return "Alert"
		"threat":
			return "Threat"
		"repair":
			return "Repair"
		"notice":
			return "Status"
		"guidance":
			return "Next"
	return ""

static func consume_cue_tag(cue_level: String) -> Dictionary:
	return {
		"tag": tag_for_cue_level(cue_level),
		"cue_level": "",
	}

static func summary_text(log_entries: Array) -> String:
	if log_entries.is_empty():
		return "Recent: none"
	var parts := PackedStringArray()
	for entry_value in log_entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var category := String(entry.get("category", "Action"))
		var tag := String(entry.get("tag", "")).strip_edges()
		if tag != "":
			category = "%s (%s)" % [category, tag]
		parts.append("%s: %s" % [category, String(entry.get("text", ""))])
	if parts.is_empty():
		return "Recent: none"
	return "Recent: %s" % " | ".join(parts)
