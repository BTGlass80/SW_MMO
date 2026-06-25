extends RefCounted

static func selectable_contact_ids(contacts: Array) -> Array:
	var ids: Array = []
	for contact_value in contacts:
		if typeof(contact_value) != TYPE_DICTIONARY:
			continue
		var contact: Dictionary = contact_value
		var contact_id := String(contact.get("id", "")).strip_edges()
		if contact_id == "":
			continue
		if bool(contact.get("selection_disabled", false)):
			continue
		ids.append(contact_id)
	return ids

static func cycle_contact_id(contacts: Array, current_id: String, direction: int) -> String:
	var ids := selectable_contact_ids(contacts)
	if ids.is_empty():
		return ""
	var step := 1 if direction >= 0 else -1
	var current_index := ids.find(current_id)
	if current_index < 0:
		return String(ids[0]) if step > 0 else String(ids[ids.size() - 1])
	var next_index := posmod(current_index + step, ids.size())
	return String(ids[next_index])
