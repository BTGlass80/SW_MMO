extends StaticBody3D

var display_type: String = ""
var target_node: Node3D = null
var laser_beam: MeshInstance3D = null

var _hover_time: float = 0.0
var _boost_spin_speed: float = 0.0
var _anim_state: int = 0
var _laser_timer: float = 0.0

func _ready() -> void:
	# Randomize starting phase of hovering to prevent lockstep movement
	_hover_time = randf_range(0.0, 10.0)

func _process(delta: float) -> void:
	_hover_time += delta
	
	# Handle hover & spin for ships and models
	if display_type in ["speeder", "miner", "cargo", "prop"]:
		if target_node != null:
			# Slow default rotation + spin boost decay
			var spin := 0.65 + _boost_spin_speed
			target_node.rotate_y(spin * delta)
			_boost_spin_speed = lerp(_boost_spin_speed, 0.0, 3.5 * delta)
			
			# Hover up and down (ships only)
			if display_type != "prop":
				target_node.position.y = sin(_hover_time * 2.0) * 0.1
			
	# Handle B1 blaster laser beam flash decay
	if display_type == "b1_droid" and laser_beam != null:
		if _laser_timer > 0.0:
			_laser_timer -= delta
			if _laser_timer <= 0.0:
				laser_beam.visible = false
 
func inspect_interact() -> void:
	match display_type:
		"clone_commander", "wookiee", "jawa", "weequay", "abyssinian", "republic_officer":
			if target_node == null:
				return
			var anim_player: AnimationPlayer = target_node.find_child("AnimationPlayer", true, false)
			if anim_player != null:
				_anim_state = (_anim_state + 1) % 3
				match _anim_state:
					0:
						anim_player.play("walk")
					1:
						anim_player.play("aim")
					2:
						anim_player.stop()
						# Reset default rotations to neutral pose
						var bones_config := {
							"left_thigh": Vector3.ZERO,
							"left_shin": Vector3.ZERO,
							"right_thigh": Vector3.ZERO,
							"right_shin": Vector3.ZERO,
							"left_upper_arm": Vector3.ZERO,
							"left_forearm": Vector3.ZERO,
							"right_upper_arm": Vector3.ZERO,
							"right_forearm": Vector3.ZERO,
							"head": Vector3.ZERO,
							"blaster": Vector3.ZERO,
							"left_leg": Vector3.ZERO,
							"right_leg": Vector3.ZERO
						}
						for bone_name in bones_config.keys():
							var bone: Node3D = target_node.find_child("bone_" + bone_name, true, false)
							if bone != null:
								bone.rotation = Vector3.ZERO
								
		"b1_droid":
			if target_node == null:
				return
			var anim_player: AnimationPlayer = target_node.find_child("AnimationPlayer", true, false)
			if anim_player != null:
				anim_player.play("aim")
				
			# Fire red laser blaster beam!
			if laser_beam != null:
				laser_beam.visible = true
				_laser_timer = 0.22 # Flash for 220ms
				
		"speeder", "miner", "cargo", "prop":
			# Boost spin!
			_boost_spin_speed = 7.5
