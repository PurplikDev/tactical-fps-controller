class_name Player
extends CharacterBody3D

# export variables

@export var default_speed: float = 2.5
@export var sprint_modifier: float = 2.25
@export var crouch_modifier: float = 0.65
@export var jump_velocity: float = 4.5

@export var mouse_sensitivity: float = 0.025

@export var lerp_speed: float = 7.5



# onready variables

@onready var current_speed: float = default_speed

@onready var body: Node3D = $body
@onready var neck: Node3D = $body/neck
@onready var head: Node3D = $body/neck/head
@onready var eyes = $body/neck/head/eyes
@onready var camera: Camera3D = $body/neck/head/eyes/player_camera
@onready var normal_collision_shape: CollisionShape3D = $normal_collision_shape
@onready var crouch_collision_shape: CollisionShape3D = $crouch_collision_shape
@onready var crouch_raycast: RayCast3D = $crouch_raycast
@onready var gun_raycast = $body/neck/head/eyes/player_camera/gun_raycast
@onready var view_model_camera: ViewModelCamera = $SubViewportContainer/SubViewport/view_model_camera



# states

var walking: bool = false
var sprinting: bool = false
var crouching: bool = false
var free_looking: bool = false
var leaning: bool = false



# misc variables

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var direction: Vector3 = Vector3.ZERO
var crouch_depth: float = -0.5
var free_look_tilt_amount: float = 8
var lean_direction: float = 0

var head_bobbing_vector: Vector2 = Vector2.ZERO
var head_bobbing_index: float = 0.0
var head_bobbing_current_intensity: float = 0.0

const head_bobbing_springing_speed: float = 22.0
const head_bobbing_walking_speed: float = 14.0
const head_bobbing_crouching_speed: float = 5.0

const head_bobbing_sprinting_intensity: float = 0.25
const head_bobbing_walking_intensity: float = 0.125
const head_bobbing_crouching_intensity: float = 0.05

const lean_distance: float = 20.0



# methods

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	$SubViewportContainer/SubViewport.size = DisplayServer.window_get_size()

func _input(event):
	if event is InputEventMouseMotion:
		if free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-110), deg_to_rad(110))
		else:
			rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
		view_model_camera.sway(Vector2(event.relative.x, event.relative.y))

func _physics_process(delta):
	
	view_model_camera.global_transform = camera.global_transform
	view_model_camera.is_lowered = (gun_raycast.is_colliding() || sprinting || !is_on_floor())
	
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	# state management
	
	if Input.is_action_pressed("crouch"):
		current_speed = default_speed * crouch_modifier
		
		normal_collision_shape.disabled = true
		crouch_collision_shape.disabled = false
		
		head.position.y = lerp(head.position.y, crouch_depth, delta * lerp_speed)
		
	elif !crouch_raycast.is_colliding():
		normal_collision_shape.disabled = false
		crouch_collision_shape.disabled = true
		
		head.position.y = lerp(head.position.y, 0.0, delta * lerp_speed)
		
		if Input.is_action_pressed("sprint"):
			current_speed = default_speed * sprint_modifier
			switch_state(false, true, false, free_looking, false)
		else:
			current_speed = default_speed
			switch_state(true, false, false, free_looking, leaning)
	
	
	
	# leaning
	
	if (Input.is_action_pressed("lean_left") || Input.is_action_pressed("lean_right")) && !sprinting:
		switch_state(walking, sprinting, crouching, free_looking, true)
		lean_direction = Input.get_axis("lean_right", "lean_left")
		body.rotation.z = lerp(body.rotation.z, deg_to_rad(lean_distance) * lean_direction, delta * (lerp_speed / 2))
	else:
		switch_state(walking, sprinting, crouching, free_looking, false)
		lean_direction = 0
		body.rotation.z = lerp(body.rotation.z, 0.0, delta * lerp_speed)
	
	
	
	# free look handling
	
	if Input.is_action_pressed("free_look"):
		switch_state(walking, sprinting, crouching, true, leaning)
		camera.rotation.z = deg_to_rad(neck.rotation.y * free_look_tilt_amount)
	else:
		switch_state(walking, sprinting, crouching, false, leaning)
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta * lerp_speed)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, delta * lerp_speed)
	
	
	
	# head bobbing
	
	if sprinting:
		head_bobbing_current_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_springing_speed * delta
	elif walking:
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
	elif crouching:
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed * delta
	
	if is_on_floor() && input_dir != Vector2.ZERO:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index / 2) + 0.5
		
		head_bobbing_current_intensity = head_bobbing_current_intensity * velocity.project(quaternion * Vector3.FORWARD).normalized().length()
		
		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_current_intensity / 3), delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x * (head_bobbing_current_intensity / 2), delta * lerp_speed)
		
		view_model_camera.rig_anchor.position.y = lerp(view_model_camera.rig_anchor.position.y, head_bobbing_vector.y * (head_bobbing_current_intensity / 4) - 0.25, delta * lerp_speed * 0.5)
		view_model_camera.rig_anchor.position.x = lerp(view_model_camera.rig_anchor.position.x, head_bobbing_vector.x * (head_bobbing_current_intensity / 3) -0.15, delta * lerp_speed * 0.5)
	else:
		eyes.position = lerp(eyes.position, Vector3.ZERO, delta * lerp_speed)
		view_model_camera.rig_anchor.position = lerp(view_model_camera.rig_anchor.position, Vector3(-0.15, -0.25, -1.5), delta * lerp_speed)
	
	
	
	# jumping
	
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	if is_on_floor():
		direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_speed)
	else:
		direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * (lerp_speed / 20))
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

func _process(delta):
	move_and_slide()

func switch_state(par_walking: bool, par_sprinting: bool, par_crouching: bool, par_free_looking: bool, par_leaning: bool):
	walking = par_walking
	sprinting = par_sprinting
	crouching = par_crouching
	free_looking = par_free_looking
	leaning = par_leaning
