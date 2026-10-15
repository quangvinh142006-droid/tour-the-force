extends CharacterBody2D
class_name StickUnit

enum State { IDLE, MOVE, ATTACK, DEAD }

@export_category("Cấu hình Phe & Hướng")
## 0: Phe mình, 1: Phe địch
@export var team_id: int = 0
## 1.0: Đi sang phải, -1.0: Đi sang trái, 0.0: Đứng yên (Idle)
@export var move_direction: float = 1.0
## Tắt biến này nếu muốn lính đứng yên thủ tại chỗ (chạy anim idle)
@export var auto_march: bool = true

@export_category("Chỉ số Nhân vật")
@export var move_speed: float = 100.0
@export var max_hp: float = 100.0
@export var attack_damage: float = 20.0
## Đặt 0.6 giây để khớp với thời lượng 6 frame (0.6s) của anim attack
@export var attack_cooldown: float = 0.6

var current_hp: float
var current_state: State = State.MOVE
var current_target: StickUnit = null

# Đường dẫn khớp với cây node WarriorBot hiện tại
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

	# Lật hướng nhân vật và vùng tấn công (nếu move_direction != 0)
	if move_direction != 0:
		var dir_sign = sign(move_direction)
		visuals.scale.x = abs(visuals.scale.x) * dir_sign
		attack_range.scale.x = abs(attack_range.scale.x) * dir_sign


func _physics_process(_delta: float) -> void:
	if current_state == State.DEAD:
		return

	update_target()

	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			play_anim("idle")

		State.MOVE:
			velocity = Vector2(move_direction * move_speed, 0)
			move_and_slide()
			play_anim("walk")

		State.ATTACK:
			velocity = Vector2.ZERO
			play_anim("attack")


func update_target() -> void:
	# Giữ nguyên mục tiêu nếu mục tiêu vẫn còn sống và nằm trong tầm đánh
	if is_instance_valid(current_target) and current_target.current_state != State.DEAD:
		if attack_range.overlaps_body(current_target):
			return

	current_target = null

	for body in attack_range.get_overlapping_bodies():
		if body is StickUnit and body != self:
			if body.team_id != team_id and body.current_state != State.DEAD:
				current_target = body
				break

	# Chuyển đổi trạng thái IDLE / MOVE / ATTACK
	if current_target != null:
		if current_state != State.ATTACK:
			current_state = State.ATTACK
			attack_timer.start()
	else:
		attack_timer.stop()
		if not auto_march or move_direction == 0.0:
			current_state = State.IDLE
		else:
			current_state = State.MOVE


func _on_timer_timeout() -> void:
	if current_state == State.ATTACK and is_instance_valid(current_target):
		if current_target.current_state != State.DEAD:
			current_target.take_damage(attack_damage)


func take_damage(amount: float) -> void:
	if current_state == State.DEAD:
		return

	current_hp -= amount

	# Hiệu ứng nháy đỏ khi trúng đòn
	visuals.modulate = Color(1.0, 0.3, 0.3)
	get_tree().create_timer(0.12).timeout.connect(func():
		if is_instance_valid(visuals) and current_state != State.DEAD:
			visuals.modulate = Color.WHITE
	)

	if current_hp <= 0:
		die()


func die() -> void:
	current_state = State.DEAD
	attack_timer.stop()
	$CollisionShape2D.set_deferred("disabled", true)

	# Vì bạn chỉ mới tạo idle, walk, attack (chưa có anim die),
	# dừng AnimationPlayer và dùng Tween làm hiệu ứng ngã ngửa + mờ dần
	if is_instance_valid(anim_player):
		anim_player.stop()

	var fall_dir = sign(move_direction) if move_direction != 0 else 1.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(visuals, "rotation_degrees", -90.0 * fall_dir, 0.4)
	tween.tween_property(visuals, "modulate:a", 0.0, 0.5)

	await tween.finished
	queue_free()


func play_anim(anim_name: String) -> void:
	if not is_instance_valid(anim_player):
		return

	# Tự động kiểm tra cả chữ thường ("idle") và viết hoa chữ đầu ("Idle")
	var target_anim: String = ""
	if anim_player.has_animation(anim_name):
		target_anim = anim_name
	elif anim_player.has_animation(anim_name.capitalize()):
		target_anim = anim_name.capitalize()

	if target_anim != "" and anim_player.current_animation != target_anim:
		anim_player.play(target_anim)
