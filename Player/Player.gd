extends RigidBody2D

onready var animated_sprite = $Turret/Muzzle/AnimatedSprite
onready var remote_transform_2d = $Turret/RemoteTransform2D
onready var camera = get_tree().current_scene.get_node('./Camera2D')
onready var label = $CanvasLayer/Control/Label
onready var tracks = $Tracks
onready var body = $Body
onready var target_x = $Turret/Target_x
onready var target_pos = $Turret/Target_x/TargetPos
onready var cpu_particles_2d_r = $"Tracks/Track-r/CPUParticles2D_r"
onready var turret = $Turret
onready var engine_sfx_loop = $AudioStreamPlayer
onready var muzzle = $Turret/Muzzle
onready var fire_round__sfx = $Fire_round_SFX
onready var line_2d = $Line2D
onready var ray_cast_2d = $Turret/RayCast2D
onready var bullet = preload("res://Player/Tank_round.tscn")

export var max_rpm = 1000
export var acceleration = 200
export var angular_acceleration = 1000
export var rot_degree = 150
export var turret_rot_degree = .05
export var turret_angle_sensitivity = 10
export var turret_to_speed = .5
export var turret_rotation_speed = PI

var engine_power = 0
var engine_rpm = 0
var vel = Vector2()
var rot_dir = 0
var turret_rot = 0
var turret_angle = 0
var turret_rotating = false
var input = Vector2()
var target_distance
var rotate_with_key = false
var interpolate_val = 2

func _ready():
	yield(get_tree(), "idle_frame")
	animated_sprite.visible = false
	camera.zoom = Vector2(30,30)
	tracks_play(false)

func _input(event):
	turret.set_as_toplevel(true)
	if event is InputEventMouseButton:
		if event.is_pressed():
			# zoom in
			if event.button_index == BUTTON_WHEEL_UP or Input.is_key_pressed(KEY_PAGEUP):
				camera.zoom -= Vector2(1,1) * 2
				# call the zoom function
			# zoom out
			if event.button_index == BUTTON_WHEEL_DOWN or Input.is_key_pressed(KEY_PAGEDOWN):
				camera.zoom += Vector2(1,1) * 2
				# call the zoom function
	if Input.is_key_pressed(KEY_I) and rotate_with_key:
		rotate_with_key = false
		print(rotate_with_key)
	elif Input.is_key_pressed(KEY_I) and !rotate_with_key:
		rotate_with_key = true
		print(rotate_with_key)
		
		
func _physics_process(delta):
	
	var target = global_position 
	var mid_x = (target.x + get_global_mouse_position().x) / 2
	var mid_y = (target.y + get_global_mouse_position().y) / 2

	remote_transform_2d.global_position = remote_transform_2d.global_position.linear_interpolate(Vector2(mid_x,mid_y), interpolate_val * delta) 
	
	
#	remote_transform_2d.global_position = (target_pos.global_position - global_position) + global_position
	
	var tmp_tur_rot = 0
	tmp_tur_rot = turret.rotation_degrees
	fire_round()
	
	#rotate particles with tank rotation
	cpu_particles_2d_r.process_material.set('angle', -1 * (rotation_degrees - 90))
	#debug overlay
	label.text = str('damp: ', linear_damp, '\nvel: ', floor(linear_velocity.length()),'\nangular vel: ', angular_velocity, '\nengine rpm: ', engine_power, '\nrot_deg: ', turret.rotation_degrees,' ,',turret_rot,' ,', rotation_degrees, '\n ', (target_pos.global_position - global_position))
	
	get_input(delta)
	#animation system
	if stepify(angular_velocity, .1) != 0 or floor(linear_velocity.length()) != 0:
		tracks_play(true)
	else:
		tracks_play(false)
	#acceleration system
	if input != 0:
		if engine_rpm < max_rpm:
			
			engine_sfx_loop.pitch_scale += engine_rpm / 100000
			engine_rpm += input * 10
		linear_damp = 2
		apply_central_impulse(transform.x * engine_power * delta * acceleration)
	else:
		if engine_rpm > 0:
			
			engine_sfx_loop.pitch_scale -=  engine_rpm / 100000
			engine_rpm -= 10
		linear_damp = 4
		pass
	engine_power = engine_rpm
	#turn system
	if rot_dir != 0:
		
		apply_torque_impulse(rot_dir * angular_acceleration)
		linear_damp = 4
		
	#turret rotation
	turret.global_position = global_position
	if turret_rotating and rotate_with_key:
		turret.rotation_degrees += turret_rot
	elif !turret_rotating and rotate_with_key:
		turret.rotation_degrees = tmp_tur_rot
		turret_rot = 0
	if !rotate_with_key:
		#get vec from turret to the mouse
		var v = get_global_mouse_position() - turret.global_position
		var angle = v.angle()
		var r = turret.global_rotation
		var angle_delta = turret_rotation_speed/2 * delta
		angle = lerp_angle(r, angle, 1.0)
		angle = clamp(angle, r - angle_delta, r + angle_delta)
		turret.global_rotation = angle
		target_x.global_position = get_global_mouse_position()
	#turret angle change
	if turret_angle != 0:
		target_x.position.x += turret_angle
	
func get_input(delta):
	rot_dir = 0
	turret_angle = 0
	turret_rot = clamp(turret_rot, -turret_to_speed,turret_to_speed)
	turret_rotating = false
	target_distance = (target_pos.global_position - muzzle.global_position).length() / 500
	
	if Input.is_action_pressed("turn_left"):
		rot_dir -= rot_degree
	if Input.is_action_pressed("turn_right"):
		rot_dir += rot_degree
	
	input = Input.get_axis("move_backward", "move_forward")
	
	if Input.is_action_pressed("rotate_turret_left"):
		turret_rotating = true
		turret_rot -= turret_rot_degree
	if Input.is_action_pressed("rotate_turret_right"):
		turret_rotating = true
		turret_rot += turret_rot_degree
	
	
	if Input.is_action_pressed("increase_turret_angle"):
		turret_angle += turret_angle_sensitivity * target_distance
	if Input.is_action_pressed("decrease_turret_angle"):
		turret_angle -= turret_angle_sensitivity * target_distance

func tracks_play(value):
	tracks.get_child(0).playing = value
	tracks.get_child(1).playing = value

func fire_round():
	if Input.is_action_just_pressed("shoot"):
		fire_round__sfx.play()
		var b = bullet.instance()
		var dir =(muzzle.global_position - turret.global_position).normalized()
		b.rotation_degrees = rad2deg(dir.angle())
		b.global_position = muzzle.global_position
		b.apply_central_impulse(dir * 10000)
		add_child(b)
		b.set_as_toplevel(true)
		animated_sprite.visible = true
		animated_sprite.play("fire")
		yield(animated_sprite, "animation_finished")
		animated_sprite.visible = false
