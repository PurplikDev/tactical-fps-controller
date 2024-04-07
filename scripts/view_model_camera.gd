class_name ViewModelCamera
extends Camera3D



@onready var fps_rig: Node3D = $fps_rig
@onready var rig_anchor: Node3D = $fps_rig/rig_anchor

var is_lowered: bool = true

const lerp_speed = 5.0



# methods

func _process(delta):
	if is_lowered:
		rig_anchor.rotation.y = lerp(rig_anchor.rotation.y, deg_to_rad(80), delta * lerp_speed )
	else:
		rig_anchor.rotation.y = lerp(rig_anchor.rotation.y, 0.0, delta * (lerp_speed * 2))
	
	rig_anchor.rotation.x = lerp(rig_anchor.rotation.x, 0.0 , delta * lerp_speed * 1.5)
	rig_anchor.rotation.y = lerp(rig_anchor.rotation.y, 0.0 , delta * lerp_speed * 1.5)

func sway(sway_amount):
	rig_anchor.rotation.y += deg_to_rad(sway_amount.x * 0.005)
	rig_anchor.rotation.x += deg_to_rad(sway_amount.y * 0.005)

