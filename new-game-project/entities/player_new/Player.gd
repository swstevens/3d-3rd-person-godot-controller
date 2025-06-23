extends CharacterBody3D

# Jump physics from first file
@export var jump_forces: Array[float] = [12.0, 13.0, 14.0, 15.0, 16.0]
@export var speed_to_jump_ratio: float = 3.0
@export var gravity_slow: float = 20.0
@export var gravity_fast: float = 40.0
@export var jump_control_threshold: float = 0.0

# Movement constants (hybrid approach)
@export var max_walk_speed: float = 8.0
@export var max_run_speed: float = 12.0
@export var acceleration: float = 50.0
@export var friction: float = 25.0
@export var air_acceleration: float = 15.0
@export var air_friction: float = 0.98

# Wall jump mechanics from second file
const WALL_JUMP_VELOCITY = 1.0
const WALL_FRICTION = 0.7
const WALL_JUMP_ALTERING = 20

@onready var spring_arm_3d: SpringArm3D = $SpringArm3D

# Get the gravity from the project settings
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# State management
const FLOOR = 0
const WALL = 1
const AIR = 2
var current_state := AIR
var previous_state := AIR

# Jump state tracking
var jump_released_this_frame: bool = false
var is_jump_held: bool = false

# Wall jump mechanics
var saved_direction := Vector3.ZERO
var wall_jump_lock: bool = false

func _ready():
	# Capture mouse for camera controls
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	handle_jump_input()
	apply_gravity(delta)
	handle_movement(delta)
	handle_jumping()
	
	move_and_slide()
	update_state()
	apply_friction(delta)

func handle_jump_input():
	# Track jump button state for variable jump heights
	if Input.is_action_just_released("ui_accept"):
		jump_released_this_frame = true
		is_jump_held = false
	elif Input.is_action_pressed("ui_accept"):
		is_jump_held = true
	else:
		is_jump_held = false

func apply_gravity(delta):
	if not is_on_floor():
		# Variable gravity based on jump state
		if velocity.y > jump_control_threshold and is_jump_held and not jump_released_this_frame:
			velocity.y -= gravity_slow * delta
		else:
			velocity.y -= gravity_fast * delta
	
	# Reset jump release flag
	jump_released_this_frame = false

func handle_movement(delta):
	# Get input using the camera-relative system from second file
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") 
	var camera = get_viewport().get_camera_3d()
	var wish_direction = Vector3.ZERO
	
	if camera and input_dir.length() > 0.1:
		# Camera-relative movement
		var camera_basis = camera.global_transform.basis
		wish_direction = (camera_basis.x * input_dir.x + camera_basis.z * input_dir.y).normalized()
	
	# Store direction for wall jumps
	if is_on_wall() and not wall_jump_lock:
		wall_jump_lock = true
	if not wall_jump_lock:
		saved_direction = velocity
	
	# Determine target speed
	var target_speed = max_run_speed if Input.is_action_pressed("run") else max_walk_speed
	
	# Apply movement based on state
	if is_on_floor():
		# Ground movement with smooth acceleration/deceleration
		if wish_direction.length() > 0.1:
			var target_velocity = wish_direction * target_speed
			var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
			horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration * delta)
			velocity.x = horizontal_velocity.x
			velocity.z = horizontal_velocity.z
		else:
			# Decelerate when no input
			var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
			horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, friction * delta)
			velocity.x = horizontal_velocity.x
			velocity.z = horizontal_velocity.z
	else:
		# Air movement with reduced control
		if wish_direction.length() > 0.1:
			velocity.x += wish_direction.x * air_acceleration * delta
			velocity.z += wish_direction.z * air_acceleration * delta

func handle_jumping():
	if Input.is_action_just_pressed("ui_accept"):
		if current_state == FLOOR:
			# SMB3-style speed-based jumping
			var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
			var speed_index = int(clamp(horizontal_speed / speed_to_jump_ratio, 0, jump_forces.size() - 1))
			velocity.y = jump_forces[speed_index]
			is_jump_held = true
			
			# Small momentum boost for maintaining speed
			if horizontal_speed > 0.1:
				var momentum_boost = 1.05 + (speed_index * 0.02)
				velocity.x *= momentum_boost
				velocity.z *= momentum_boost
				
		elif current_state == WALL:
			# Wall jump using stored direction
			velocity = saved_direction.bounce(get_wall_normal()) * WALL_JUMP_VELOCITY
			velocity.y += jump_forces[0] * 0.7  # Add some vertical boost
			wall_jump_lock = false

func update_state():
	previous_state = current_state
	
	if is_on_wall_only():
		current_state = WALL
	elif is_on_floor():
		current_state = FLOOR
		wall_jump_lock = false
	else:
		current_state = AIR

func apply_friction(delta):
	# Apply different friction based on state
	if current_state == AIR:
		velocity.x *= air_friction
		velocity.z *= air_friction
	elif current_state == WALL:
		velocity.y *= WALL_FRICTION

func _input(event):
	# Camera controls from second file
	if event is InputEventMouseMotion:
		spring_arm_3d.rotation.y -= event.relative.x * 0.005
		spring_arm_3d.rotation.x += event.relative.y * -0.005
		# Clamp vertical rotation to prevent camera flipping
		spring_arm_3d.rotation.x = clamp(spring_arm_3d.rotation.x, -PI/2, PI/2)
