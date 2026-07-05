extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const JOBS := [
	{
		"scene": "res://docs/gpt/visual_direction/godot_scene_examples/ground_spaceport_visual_blockout.tscn",
		"out": "res://docs/gpt/visual_direction/captures/ground_spaceport_visual_blockout_godot.png",
	},
	{
		"scene": "res://docs/gpt/visual_direction/godot_scene_examples/isometric_space_visual_blockout.tscn",
		"out": "res://docs/gpt/visual_direction/captures/isometric_space_visual_blockout_godot.png",
	},
	{
		"scene": "res://docs/gpt/visual_direction/godot_scene_examples/ground_asset_kitbash_reference.tscn",
		"out": "res://docs/gpt/visual_direction/captures/ground_asset_kitbash_reference_godot.png",
	},
	{
		"scene": "res://docs/gpt/visual_direction/godot_scene_examples/isometric_space_asset_reference.tscn",
		"out": "res://docs/gpt/visual_direction/captures/isometric_space_asset_reference_godot.png",
	},
]

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = CAPTURE_SIZE
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(CAPTURE_SIZE)

	var output_dir := ProjectSettings.globalize_path("res://docs/gpt/visual_direction/captures")
	DirAccess.make_dir_recursive_absolute(output_dir)

	for job in JOBS:
		var packed: PackedScene = load(job["scene"])
		if packed == null:
			push_error("Unable to load scene: %s" % job["scene"])
			continue

		var scene := packed.instantiate()
		get_root().add_child(scene)

		await process_frame
		await process_frame
		await process_frame

		var image := get_root().get_texture().get_image()
		var out_path := ProjectSettings.globalize_path(job["out"])
		var err := image.save_png(out_path)
		if err != OK:
			push_error("Failed to save %s: %s" % [out_path, err])
		else:
			print("Saved reference capture: %s" % out_path)

		scene.queue_free()
		await process_frame

	quit()
