
extends CharacterBody2D
class_name StickUnit

enum State { MOVE, ATTACK, DEAD }

@export_category("Cấu hình Phe & Hướng")
@export var team_id: int = 0
@export var move_direction: float = 1.0

@export_category("Chỉ số Nhân vật")
@export var move_speed: float = 100.0
@export var max_hp: float = 100.0
@export var attack_damage: float = 20.0
@export var attack_cooldown: float = 1.0

var current_hp: float
var current_state: State = State.MOVE
var current_target: StickUnit = null

# Đường dẫn đã sửa theo cây node hiện tại
@onready var visuals: Node2D = $AnimateAgent/Sprite2D
@onready var anim_player: AnimationPlayer = $AnimateAgent/AnimationPlayer
@onready var attack_range: Area2D = $Area2D
@onready var attack_timer: Timer = $Timer


func _ready() -> void:
	current_hp = max_hp

	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = false

	if not attack_timer.timeout.is_connected(_on_timer_timeout):
		attack_timer.timeout.connect(_on_timer_timeout)

	# Lật hướng nhân vật và vùng tấn công
	visuals.scale.x = abs(visuals.scale.x) * sign(move_direction)
	attack_range.scale.x = abs(attack_range.scale.x) * sign(move_direction)


func _physics_process(_delta: float) -> void:
	if current_state == State.DEAD:
		return

	update_target()

	match current_state:
		State.MOVE:
			velocity = Vector2(move_direction * move_speed, 0)
			move_and_slide()
			play_anim("walk")

		State.ATTACK:
			velocity = Vector2.ZERO
			play_anim("attack")


func update_target() -> void:
	if is_instance_valid(current_target):
		if current_target.current_state != State.DEAD:
			return

	current_target = null

	for body in attack_range.get_overlapping_bodies():
		if body is StickUnit and body != self:
			if body.team_id != team_id:
				if body.current_state != State.DEAD:
					current_target = body
					break

	if current_target != null:
		if current_state != State.ATTACK:
			current_state = State.ATTACK
			attack_timer.start()
	else:
		if current_state != State.MOVE:
			current_state = State.MOVE
			attack_timer.stop()


func _on_timer_timeout() -> void:
	if current_state == State.ATTACK:
		if is_instance_valid(current_target):
			if current_target.current_state != State.DEAD:
				current_target.take_damage(attack_damage)


func take_damage(amount: float) -> void:
	if current_state == State.DEAD:
		return

	current_hp -= amount

	if current_hp <= 0:
		die()


func die() -> void:
	current_state = State.DEAD
	attack_timer.stop()

	$CollisionShape2D.set_deferred("disabled", true)
	play_anim("die")

	await get_tree().create_timer(1.0).timeout
	queue_free()


func play_anim(anim_name: String) -> void:
	if is_instance_valid(anim_player):
		if anim_player.has_animation(anim_name):
			if anim_player.current_animation != anim_name:
				anim_player.play(anim_name)
