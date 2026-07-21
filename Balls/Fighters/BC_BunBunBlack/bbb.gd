## Vee's behaviour script
extends BehaviourScript
@onready var health_manager = $"../HealthManager"
@onready var grapple_transform = $"../Rotater/GrappleTransform"
@onready var rotater = $"../Rotater"
@onready var aggressive = $"../Aggressive"
@onready var danger_zone = $"../DangerZone"
@onready var counter_arms = $"../CounterArms"
@onready var meter_manager = $"../MeterManager"

@onready var default: Node2D = $"../Visuals/Default"


## Who we are grappling
var grappling:BallBodyBase=null
## If we are countering
var countering=false

func _ready():
	super()
	counter_arms.visible=false
	ball.bounce_wall.connect(slam_check)
	ball.tree_exiting.connect(grab_died)
	## Looper to trigger counter move
	$CounterLooper.trigger.connect(counter)
	## Hitbox of grabbed target
	sc.set_base_stat("Hitbox.collision_disabled",true)

func counter():
	if !Global.can_act(ball) or countering or grappling:
		return

	var dir = Global.dir_closest_ball(ball)
	if dir == Vector2.ZERO:
		return
	ball.set_velocity(dir*(ball.get_velocity().length()))

	sc.add_modifier("HitProcessor.crit_immune",2,true,"BBBCounter")
	sc.add_modifier("Ball.velocity",1,0.65,"BBBCounter")
	#meter_manager.gain_meter(5)
	countering=true
	#sc.add_modifier("Ball.linear_velocity",1,0.35,"VeeCountering")
	counter_arms.visible=true
	default.set_visual("Counter")
	sc.set_base_stat("HitProcessor.damage_scale",0.01)
	await delay(0.6 + 0.4*scaler())
	uncounter()


func uncounter():
	if countering==true:
		sc.remove_modifier("BBBCounter")
		sc.set_base_stat("HitProcessor.damage_scale",1)
		counter_arms.visible=false
		default.set_visual("Default")
		countering=false


func hit_process(data):
	var attacker=data["ATTACKER"]
	var victim = data["VICTIM"]
	var dmg = data["DAMAGE"]
	var id = data["ID"]
	var type = data["TYPE"]

	if health_manager.health>0:
		if countering and !type.has("STATUS_EFFECT"):
			for thing in danger_zone.get_overlapping_bodies():
				if !thing is BallBodyBase:
					continue
				if thing.team==ball.team:
					continue
				if !thing.is_in_group("AntiGrapple") and !thing.is_in_group("AntiInteract"):
					grapple(thing)
					return

		## If we are hit and countering, grapple them
		if victim==ball:
			if behaviour_active==false:
				return
			meter_manager.gain_meter(dmg*1.1)
			update_scale()


func update_scale():
	sc.set_base_stat("HitProcessor.damage_scale", 1.0-0.5*scaler())
	sc.set_base_stat("Ball.ball_scale",1.1+0.5*scaler())
	sc.set_base_stat("HitboxDamager.damage", 1.0+1.2*scaler())
	danger_zone.scale=Vector2(1.1+0.5*scaler(), 1.1+0.5*scaler())

func scaler():
	return (meter_manager.meter/100.0)



func grapple(victim):
	if victim==null:
		return
	if grappling!=null:
		return
	SoundQueue.play("res://Sounds/hurt_sfx.wav")
	ball.add_to_group("AntiGrapple")
	uncounter()
	$"../Rotater/GrappleTransform/GrabHand".visible=true
	grappling=victim
	$Afterimager.active=true
	grappling.tree_exiting.connect(clear_grapple)
	## Disable enemy while we grab them
	grapple_status = StatusEffectManager.set_effect(ball,victim,"GRAPPLED",1,{"GRAPPLER":ball})
	if grapple_status==null:
		return
	grapple_transform.remote_path=victim.get_path()
	var dir = ball.global_position.direction_to(victim.global_position)
	rotater.rotation=dir.angle()
	rotater.angular_velocity=25
	rotater.prefreeze_a_velocity=25
	sc.set_base_stat("HitProcessor.immune",true)
	sc.set_base_stat("ContactDamager.enabled",false)
	sc.set_base_stat("Ball.gravity_scale",1.65)
	sc.set_base_stat("Mood.disabled",true)
	#ball.set_collision_mask_value(5,false)
	sc.set_base_stat("Ball.mass",3)
	default.set_visual("Grapple")

	sc.set_base_stat("Hitbox.collision_disabled",false)
	await get_tree().physics_frame
	var jump_dir = (ball.get_velocity().normalized()+Vector2.UP*2.0)/3.0
	ball.set_velocity(jump_dir*(950+400*(meter_manager.meter/100.0)))

var grapple_status=null

## Releases grabbed target and resets our values
func free_grabbed():
	if grappling!=null:
		$Afterimager.active=false
		if grapple_status:
			grapple_status.clear_grapple()
		sc.set_base_stat("Ball.mass",1)
		sc.set_base_stat("Hitbox.collision_disabled",true)
		grapple_transform.remote_path=NodePath()
		default.set_visual("Default")
		ball.remove_from_group("AntiGrapple")

## If we bounce on ground and are grappling, explode
func slam_check(wall):
	if wall.name=="Ground" and grappling!=null:
		grappling.tree_exiting.disconnect(clear_grapple)
		$"../Boom2".global_position=ball.global_position
		$"../Boom2/AnimationPlayer".play("Boom")
		SoundQueue.play("res://Assets/deltarune explosion.mp3",1,0.7)
		var bodies = danger_zone.get_overlapping_bodies()
		bodies.erase(ball)
		bodies.erase(grappling)
		grapple_damage(grappling)
		#await get_tree().process_frame
		free_grabbed()

		for i in bodies:
			if !i is BallBodyBase:
				continue
			if i.team==ball.team:
				continue
			grapple_damage(i)
		clear_grapple()

## If thing we are grabbing died somehow, cancel our grab
func grab_died():
	free_grabbed()
	ball.set_collision_mask_value(5,true)
	sc.set_base_stat("Hitbox.collision_disabled",true)
	grapple_transform.remote_path=NodePath()
	sc.set_base_stat("Ball.gravity_scale",0.0)
	grappling=null
	countering=false
	sc.set_base_stat("Mood.disabled",false)

	meter_manager.clear_meter()
	$"../Rotater/GrappleTransform/GrabHand".visible=false

	sc.set_base_stat("HitProcessor.immune",false)
	sc.set_base_stat("ContactDamager.enabled",true)

## Function to deal grapple damage to enemy and nearby enemies
func grapple_damage(victim):
	var dir = ball.global_position.direction_to(victim.global_position)
	var data_dict={"DAMAGE":7.0+8.0*scaler(),
				"ATTACKER":ball,
				"VICTIM":victim,
				"KNOCKBACK":380,
				"DIRECTION":dir,
				"SELF_KNOCKBACK":ball.get_velocity().length(),
				"CRIT_CHANCE":1.0,
				"CRIT_MULTIPLIER":1,
				"TYPE":["EXPLOSION"],
				"SFX":"",
				"ID":"BBBGrapple",
				"MISC":{"BURN":1}}
	EventManager.hit.emit(data_dict)

## Release what we were grappling if it died
func clear_grapple():
	$Afterimager.active=false
	default.set_visual("Default")
	sc.set_base_stat("Ball.gravity_scale",0.0)
	grappling=null
	countering=false
	sc.set_base_stat("Mood.disabled",false)
	await get_tree().physics_frame
	$"../Rotater/GrappleTransform/GrabHand".visible=false

	await delay(0.12)
	sc.set_base_stat("HitProcessor.immune",false)
	sc.set_base_stat("ContactDamager.enabled",true)
	sc.set_base_stat("Hitbox.collision_disabled",true)
