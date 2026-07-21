## Hitprocessor recieves the damage data signals from EventManager
## Processes the data and rest of ball reacts to it

extends Node
class_name HitProcessor

@export var ball:BallBodyBase

@export_category("Properties")
## Make ball immune to any damage source
@export var immune:bool=false

## Make ball immune to crits
@export var crit_immune:bool=false

## Scale hitstop and critstop
@export_range(0,1) var hitstop_scale:float=1.0

## Cap damage ball can take
## I currently use for things that take 1 dmg at a time
@export var damage_cap:float=999

## Scale damage ball takes
## Less that 1 counts as damage resistance
@export var damage_scale:float=1.0

## Scale the knockback force they recieve
@export var knockback_scale:float=1.0

## Mute damage numbers from appearing
@export var mute_numbers:bool=false

## Scale meter people can gain off of it
@export var meter_scale:float=1.0


var negated_damage:float=0.0
var stat_controller:StatController
## Emitted when ball is damaged
signal damaged
## Emitted when set immune
signal set_immune

func _enter_tree():
	EventManager.hit.connect(hit_reg)


func _ready():
	stat_controller=ball.stat_controller
	stat_controller.stat_changed.connect(update_stats)
	stat_controller.set_base_stat("HitProcessor.immune",immune)
	stat_controller.add_alias("HitProcessor.immune", "HitProcessor.immune")

	stat_controller.set_base_stat("HitProcessor.crit_immune",crit_immune)
	stat_controller.add_alias("HitProcessor.crit_immune", "HitProcessor.crit_immune")

	stat_controller.set_base_stat("HitProcessor.hitstop_scale",hitstop_scale)
	stat_controller.add_alias("HitProcessor.hitstop_scale", "HitProcessor.hitstop_scale")

	stat_controller.set_base_stat("HitProcessor.damage_scale",damage_scale)
	stat_controller.add_alias("HitProcessor.damage_scale", "HitProcessor.damage_scale")

	stat_controller.set_base_stat("HitProcessor.knockback_scale",knockback_scale)
	stat_controller.add_alias("HitProcessor.knockback_scale", "HitProcessor.knockback_scale")

	EventManager.lock_health.connect(lock_health)

func lock_health():
	health_lock=true
	stat_controller.set_base_stat("HitProcessor.immune",true)

var health_lock=false

signal set_damage_scale

func update_stats(stat_name,new_val):
	match stat_name:
		"HitProcessor.immune":
			immune=new_val
			set_immune.emit(immune)
		"HitProcessor.crit_immune":
			crit_immune=new_val
		"HitProcessor.hitstop_scale":
			hitstop_scale=new_val
		"HitProcessor.damage_scale":
			damage_scale=new_val
			set_damage_scale.emit(new_val)
		"HitProcessor.knockback_scale":
			knockback_scale=new_val

signal hit_data_extend
## Hit registration called when hit signal emitted
func hit_reg(data):
	##If we are immune ignore
	negated_damage=0.0

	##Extract the data
	var victim=data.get("VICTIM",null)
	var attacker=data.get("ATTACKER",null)
	var dir = data.get("DIRECTION",null)
	var knockback = data.get("KNOCKBACK",-1.0)
	var self_knockback = data.get("SELF_KNOCKBACK",null)
	var crit_chance = data.get("CRIT_CHANCE",0.0)
	var crit_multiplier = data.get("CRIT_MULTIPLIER",null)
	var dmg = data.get("DAMAGE",0.0)
	var type = data.get("TYPE",[])
	var sfx = data.get("SFX","")
	var id = data.get("ID","")
	var mute_num = data.get("MUTE",false)
	var misc = data.get("MISC",{})
	var directional_strength = data.get("DIR_STRENGTH",1.0)
	var vfx_particle = data.get("VFX_PARTICLE",null)
	var vfx_particle_dir = data.get("VFX_PARTICLE_DIRECTION",Vector2.RIGHT)
	var eff_ks=knockback_scale
	if stat_controller.get_stat("HealthManager.overhealth")!=null:
		var oh = stat_controller.get_stat("HealthManager.overhealth")
		if oh>0:
			eff_ks=eff_ks * (1.0-(min(oh,10.0)/10.0))

	if stat_controller.get_stat("HealthManager.armor")!=null:
		if stat_controller.get_stat("HealthManager.armor")>0:
			eff_ks=0.0


	##Check if victim is ball
	if victim==ball:

		if immune or health_lock:
			return
		if dir!=null and knockback!=-1.0:

			var velocity = ball.get_velocity()
			var new_dir: Vector2 = dir
			knockback*=eff_ks
			##Use directional strength to determine knockback angle
			##Lerp between 0 to 1 to determine how much influence over the ball's
			##Direction we influence to our target direction
			if velocity!=Vector2.ZERO:
				var body_dir = velocity.normalized()
				new_dir = body_dir.lerp(dir,directional_strength*eff_ks).normalized()


			if knockback!=0.0:
				var new_knockback
				if knockback < 1.0:
					new_knockback = velocity.length()
				else:
					new_knockback = velocity.length() + knockback
				ball.set_velocity(new_dir * new_knockback)
		##VFX ON HIT
		##WIP
		if vfx_particle!=null:
			var particle = ParticleSpawner._spawn_particle_effect(load(vfx_particle),ball.global_position,vfx_particle_dir)

		var critted=false
		var reduced=false
		var amplified=false
		##Check if it crits
		if crit_chance!=null:
			##If it crits
			if randf()<crit_chance and (crit_immune==false):
				critted=true
				EventManager.critted.emit(ball)
				if attacker!=null:
					EventManager.critter.emit(attacker)
				if dmg!=0.0 and crit_multiplier!=null:
					dmg=dmg*crit_multiplier
					dmg=dmg_update(dmg)

				if dmg!=0.0 and !is_muted(mute_num):
					PopUpManager.damage_number(dmg, ball.global_position, "CRIT")

			##If no crit, reduce dmg
			else:
				dmg=min(dmg,damage_cap)
				if damage_scale < 1.0 and !type.has("STATUS_EFFECT"):
					var reduced_dmg = dmg * damage_scale
					negated_damage = dmg - reduced_dmg
					dmg = reduced_dmg  # always apply the scale
					if !is_muted(mute_num):
						reduced=true

			##Regardless of crit or not, if damage scale is above 1, amplify it
			if damage_scale>1.0 and !type.has("STATUS_EFFECT"):
				var multiplied_dmg=dmg*damage_scale
				dmg=multiplied_dmg
				dmg=dmg_update(dmg)
				amplified=true

			dmg=dmg_update(dmg)
			##If numbers arent muted, display
			if !is_muted(mute_num):
				if reduced:
					var label = "REDUCED"
					PopUpManager.damage_number(dmg, ball.global_position, label)
				elif amplified:
					PopUpManager.damage_number(dmg, ball.global_position,"AMPLIFIED")
				elif critted==false:
					PopUpManager.damage_number(dmg, ball.global_position)


		#if dmg>=1.0:
			#dmg = int(dmg)


		var val_hitstop = Global.hitstop
		if critted:
			val_hitstop = Global.critstop
			val_hitstop *= data.get("CRITSTOP_SCALE",1.0)
		else:
			val_hitstop *= data.get("HITSTOP_SCALE",1.0)
		val_hitstop *= hitstop_scale
		HitstopManager.set_histop(val_hitstop)

		var success_data={"ATTACKER":attacker,"VICTIM":victim,"TYPE":type,"CRIT":critted,"ID":id,"DAMAGE":dmg,"MISC":misc,
		"NEGATED_DMG":negated_damage,"SFX":sfx}

		EventManager._successfully_damaged_.emit(success_data)
		if !attacker==null:
			var damager=attacker.get_root_creator()
			var attribute_data={"ATTACKER":damager,"VICTIM":victim,"DAMAGE":dmg}
			EventManager.attribute_damage.emit(attribute_data)

		damaged.emit(dmg,critted)
		hit_data_extend.emit(data)

	##If we hit someone
	elif attacker==ball:
		if self_knockback!=null and dir!=null and !victim.is_in_group("AntiSelfKnockback"):
			## Knock ourselves away based off directional strength too
			if self_knockback>0.0:
				await get_tree().physics_frame
				var velocity = ball.get_velocity()
				var new_dir:Vector2 =-dir
				if velocity!=Vector2.ZERO:
					var body_dir = velocity.normalized()
					new_dir = body_dir.lerp(-dir,directional_strength).normalized()
				ball.set_velocity(new_dir * (velocity.length()+self_knockback))


func is_muted(mute_num):
	return mute_num or mute_numbers

func dmg_update(dmg):
	# dmg=min(dmg,damage_cap)
	dmg = round(dmg*10.0)/10.0
	return dmg
