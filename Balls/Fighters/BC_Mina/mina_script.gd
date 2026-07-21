## This is shooty's behaviour script
## Showcases basic projectile spawning and aiming mechanics

extends BehaviourScript
## Set up bullet resource
var bullet_res = preload("res://Balls/Fighters/BC_Mina/MinaBullet.tscn")

## Set references to nodes
@onready var rotater: Rotater = $"../Rotater"
@onready var looper: Node = $Looper
@onready var meter_autogain: Node = $MeterAutogain
@onready var meter_manager: MeterManager = $"../MeterManager"

## In our ready, connect to our looper
## It's looping trigger causes us to shoot cyclically
## Meter autogain emits when meter is full
## Triggers level_up function
func _ready():
	super()
	looper.trigger.connect(shoot)
	meter_autogain.meter_full.connect(level_up)

## Levelup is called when our meter is full
## Calls a special version of shoot and clears meter
func level_up():
	shoot(true)
	meter_manager.clear_meter()

## Shoot aims at nearest enemy then shoots a bullet using spawn_thing
## If it's special, the bullet has different properties
func shoot(special = false):
	var target = Global.dir_closest_ball(ball,rotater.vec_dir())
	if target != Vector2.ZERO:
		await Global.rotate_to(rotater, target.angle(),0.1)
	SoundQueue.play("res://Sounds/layered-gunshot-7_A_minor.wav",1,0.7)
	var dir =Vector2.RIGHT.rotated(rotater.rotation)
	var newb = spawn_thing(bullet_res)
	newb.set_velocity(dir*1050)
	newb.global_position=$"../Rotater/WeaponHolder/WeaponFlipper/WeaponHitbox".global_position
	if special:
		var script=newb.behaviour_script
		script.set_special()
