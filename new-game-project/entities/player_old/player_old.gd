extends CharacterBody3D


@export var walk_speed: float = 5.0
@export var JUMP_VELOCITY: float = 4.5
@export var gravity: float = 20.0

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var camera = get_viewport().get_camera_3d()
	if camera:
		var camera_basis = camera.global_transform.basis
		var direction = (camera_basis.x * input_dir.x + camera_basis.z * input_dir.y).normalized()
		# Apply movement
		if direction.length() > 0.1:
			velocity.x = direction.x * walk_speed
			velocity.z = direction.z * walk_speed
		else:
			velocity.x = 0
			velocity.z = 0

	move_and_slide()
