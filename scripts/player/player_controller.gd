extends CharacterBody3D

const ModalOverlayModel = preload("res://scripts/rules/modal_overlay_model.gd")
const SPEED = 6.5
const JUMP_VELOCITY = 5.0
const MOUSE_SENSITIVITY = 0.0025

var _yaw := 0.0
var _pitch := -0.18
var _gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_body()

func _input(event: InputEvent) -> void:
	if _modal_overlay_active():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clamp(_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.25, 0.8)
		rotation.y = _yaw
		_head.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if _modal_overlay_active():
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		move_and_slide()
		return

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Vector2.ZERO
	input_dir.y -= 1.0 if Input.is_key_pressed(KEY_W) else 0.0
	input_dir.y += 1.0 if Input.is_key_pressed(KEY_S) else 0.0
	input_dir.x -= 1.0 if Input.is_key_pressed(KEY_A) else 0.0
	input_dir.x += 1.0 if Input.is_key_pressed(KEY_D) else 0.0
	input_dir = input_dir.normalized()

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction.length_squared() > 0.001:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.7
	collision.shape = capsule
	collision.position.y = 0.85
	add_child(collision)

	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.36
	mesh.height = 1.7
	body.mesh = mesh
	body.position.y = 0.85
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.28, 0.34)
	material.roughness = 0.88
	body.material_override = material
	add_child(body)

func get_camera() -> Camera3D:
	return _camera

func _modal_overlay_active() -> bool:
	return ModalOverlayModel.is_modal_overlay_active(get_tree())
