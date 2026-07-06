extends RefCounted

static func generate_uuid() -> String:
	return String.num_uint64(Time.get_ticks_usec() ^ randi())

static func create(template_id: String, display_name: String, kind: String, quality: float, max_condition: int, created_by: String, source_resources: Dictionary = {}, stats: Dictionary = {}) -> Dictionary:
	var uuid := generate_uuid()
	return {
		"instance_id": uuid,
		"template_id": template_id,
		"display_name": display_name,
		"kind": kind,
		"owner_id": "world",
		"container_id": "",
		"stack_count": 1,
		"quality": quality,
		"condition": max_condition,
		"max_condition": max_condition,
		"created_at": Time.get_unix_time_from_system(),
		"created_by": created_by,
		"source_resources": source_resources,
		"legal_status": "legal",
		"mass": 1.0,
		"volume": 1.0,
		"tags": [],
		"stats": stats,
		"tradeable": true,
		"bound": false
	}

static func create_from_output(output_def: Dictionary, quality: float, crafter_id: String, source_resources: Dictionary = {}) -> Dictionary:
	var template_id := String(output_def.get("template_id", output_def.get("template_key", "item")))
	var base_name := String(output_def.get("name", "Crafted Item"))
	var name := "%s (Q: %d%%)" % [base_name, int(quality)]
	var kind := String(output_def.get("kind", "utility"))
	var max_condition := int(output_def.get("max_condition", 1))
	var modifiers: Dictionary = output_def.get("modifiers", {})
	
	var item = create(template_id, name, kind, quality, max_condition, crafter_id, source_resources, modifiers)
	
	# Try to map some fields from the template definition if present
	if output_def.has("quantity"):
		item["stack_count"] = int(output_def["quantity"])
		
	return item

