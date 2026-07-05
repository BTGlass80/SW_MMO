extends SceneTree

func _initialize() -> void:
	print("Initial children in root:")
	for child in root.get_children():
		print(" - ", child.name, " (", child.get_class(), ")")
		
	# Wait 2 frames
	await process_frame
	await process_frame
	
	print("Children in root after 2 frames:")
	for child in root.get_children():
		print(" - ", child.name, " (", child.get_class(), ")")
		
	quit()
