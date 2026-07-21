extends StatusEffect

@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D

var lose_value = 1
var expiring = false

func set_target(ball, value, data):
	super(ball, value, data)
	set_counter(value)
	gpu_particles_2d.global_position = baller.global_position

func update(value, data):
	set_counter(counter + value)
	check_freeze()
	return self

func check_apply(ball) -> bool:
	if !super(ball):
		return false
	if ball.is_in_group("AntiChill") or ball.is_in_group("AntiFreeze"):
		return false
	return true

func check_freeze():
	if counter >= 10:
		StatusEffectManager.set_effect(ball_source,baller, "FREEZE", 5, {})
		queue_free()

func scaler():
	return min(1.0, counter / 10.0)

func _process(delta):
	if expiring:
		return

	if is_instance_valid(baller):
		gpu_particles_2d.global_position = baller.global_position

	update_slow()
	gpu_particles_2d.amount_ratio = pow(scaler(), 1.5)

	set_counter(counter - delta * lose_value)
	if counter <= 0.0:
		_expire()

func _expire():
	expiring = true
	gpu_particles_2d.emitting = false
	gpu_particles_2d.one_shot = true
	gpu_particles_2d.restart()
	await gpu_particles_2d.finished
	queue_free()

func update_slow():
	baller.stat_controller.remove_modifier("CHILL_SLOW")
	baller.stat_controller.add_modifier("Ball.velocity", 1, 1.0 - (1.0 * scaler()), "CHILL_SLOW")

func on_leave():
	super()
	if !is_instance_valid(baller):
		return
	baller.stat_controller.remove_modifier("CHILL_SLOW")
