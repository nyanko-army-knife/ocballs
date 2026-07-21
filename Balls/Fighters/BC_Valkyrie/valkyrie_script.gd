extends BehaviourScript
@onready var meter_manager:MeterManager = $"../MeterManager"
var active = false
var triggered=false
@onready var weapon = $"../Rotater/WeaponHolder/WeaponFlipper/WeaponHitbox/WeaponVisual/Weapon"
@onready var weapon_2 = $"../Rotater/WeaponHolder/WeaponFlipper/WeaponHitbox/WeaponVisual/Weapon2"
@onready var rotater = $"../Rotater"
@onready var hitbox_damager = $"../Rotater/WeaponHolder/WeaponFlipper/WeaponHitbox/HitboxDamager"
@onready var weapon_hitbox = $"../Rotater/WeaponHolder/WeaponFlipper/WeaponHitbox"
var gain_meter_rate = 5
var lost_meter_rate = 40
var level = 1
func _ready():
	super()
	weapon_hitbox.hit_weapon.connect(clash_gain.unbind(1))
	sc=ball.stat_controller

	EventManager.status_effected.connect(status_handle)

@onready var default: Node2D = $"../Visuals/Default"


func status_handle(data):
	pass

@onready var after_imager: Node = $AfterImager


func clash_gain():
	if active:
		return
	#meter_manager.gain_meter(7.5)

var charge_hit_list=[]

func hit_process(data):
	if data["ID"]!="Trident":
		return
	var attacker=data["ATTACKER"]
	var victim = data["VICTIM"]
	var critcheck = data["CRIT"]
	if attacker==ball:
		var effects = StatusEffectManager.get_effects(victim)
		var strength=2+level
		if critcheck:
			strength=1+level*2
		StatusEffectManager.set_effect(ball,victim,"CHILLED",strength)


		if victim.is_in_group("AntiInteract"):
			return

		if !active:
			return
		else:
			var mul=victim.get_value_scale()


func charge():

	if active==true or triggered==true:
		return
	charge_hit_list.clear()
	triggered=true
	await delay(0.4)
	SoundQueue.play("res://Sounds/acceleration-sfx_G_minor.wav")
	await delay(0.4)

	if !Global.can_act(ball):
		return


	ball.set_velocity(Vector2.RIGHT.rotated(rotater.rotation) * ball.get_velocity().length())
	charge_start()

func charge_start():
	level = min(level+1, 3)
	sc.set_base_stat("HitboxDamager.damage",2+1*level)
	gain_meter_rate = level+3
	lost_meter_rate = 40-level*7
	if %LV:
		%LV.text = "LV:" + str(level)

	after_imager.active=true
	$"../Rotater/WeaponHolder".position=Vector2(20,0)
	sc.set_base_stat("HitProcessor.damage_scale", 0.3)
	active=true
	weapon.visible=false
	weapon_2.visible=true
	sc.set_base_stat("Ball.velocity",1250)
	sc.set_base_stat("Ball.normalizer_speed_up",100)
	sc.set_base_stat("Rotater.rotation_rate",0.01)
	sc.set_base_stat("Rotater.normalizer_rate",70)
	sc.set_base_stat("Rotater.bounce_spin_boost",0.0)
	sc.set_base_stat("Rotater.flipper_min",0.0)
	sc.set_base_stat("ClashBouncer.disable",true)
	sc.set_base_stat("ClashBouncer.cleave",true)
	sc.set_base_stat("HitboxDamager.knockback",400.0)
	sc.set_base_stat("HitboxDamager.self_knockback",500.0)
	sc.set_base_stat("HitboxDamager.crit_chance",0.3)

	sc.set_base_stat("Mood.disabled",true)


func charge_end():

	after_imager.active=false
	$"../Rotater/WeaponHolder".position=Vector2(76,0)
	sc.set_base_stat("HitProcessor.damage_scale", 1)
	triggered=false
	active=false
	weapon.visible=true
	weapon_2.visible=false
	sc.set_base_stat("Ball.velocity",500)
	sc.set_base_stat("Ball.normalizer_speed_up",20)
	sc.set_base_stat("Rotater.rotation_rate",1)
	sc.set_base_stat("Rotater.normalizer_rate",7)
	sc.set_base_stat("Rotater.bounce_spin_boost",3)
	sc.set_base_stat("Rotater.flipper_min",10)
	sc.set_base_stat("ClashBouncer.cleave",false)
	sc.set_base_stat("ClashBouncer.disable",false)
	sc.set_base_stat("HitboxDamager.self_knockback",150.0)
	sc.set_base_stat("HitboxDamager.knockback",100.0)
	sc.set_base_stat("HitboxDamager.crit_chance",0.0)
	sc.set_base_stat("Mood.disabled",false)


func _physics_process(delta):
	if ball.freezed==true:
		return
	if active:
		var val = ball.get_velocity().angle()

		rotater.rotation = lerp_angle(rotater.rotation, val, 0.125)

		meter_manager.lose_meter(lost_meter_rate*delta)
		if meter_manager.meter<=0:
			charge_end()

	else:
		meter_manager.gain_meter(gain_meter_rate*delta)

	if meter_manager.is_full():
		charge()
