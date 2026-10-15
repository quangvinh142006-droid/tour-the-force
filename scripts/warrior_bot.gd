extends CharacterBody2D
class_name StickUnit

enum State { IDLE, MOVE, ATTACK, DEAD }

@export_category("Cấu hình Phe & Hướng")
## 0: Phe người chơi (bên trái), 1: Phe máy (bên phải)
@export var team_id: int = 0
## Hướng tiến công chuẩn: 1.0 (qua phải) cho Phe 0, -1.0 (qua trái) cho Phe 1
@export var attack_direction: float = 1.0

@export_category("Tọa độ Căn cứ (Trục X)")
## Tọa độ X nơi lính đứng dàn hàng khi chọn chế độ Thủ (Khiên)
@export var defend_line_x: float = 250.0
## Tọa độ X phía sau thành nơi lính chạy về khi chọn Rút lui (Lâu đài)
@export var retreat_base_x: float = 80.0

@export_category("Chỉ số Nhân vật")
@export var move_speed: float = 100.0
@export var max_hp: float = 100.0
@export var attack_damage: float = 20.0
@export var attack_cooldown: float = 0.6

var current_hp: float
var current_state: State = State.IDLE
var current_target: StickUnit = null

# Tạo độ lệch ngẫu nhiên nhỏ để khi 10 con lính về Thủ không bị đứng đè khít lên nhau
var personal_offset_x: float = 0.0

@onready var visuals: Node2D = $AnimateAgent/Sprite2D
@onready var anim_player: AnimationPlayer = $AnimateAgent/AnimationPlayer
@onready var attack_range: Area2D = $Area2D
@onready var attack_timer: Timer = $Timer


func _ready() -> void:
	current_hp = max_hp
	personal_offset_x = randf_range(-35.0, 35.0)

	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = false
	if not attack_timer.timeout.is_connected(_on_timer_timeout):
		attack_timer.timeout.connect(_on_timer_timeout)

	# Lắng nghe lệnh từ BattleManager
	BattleManager.command_changed.connect(_on_command_changed)
	face_direction(attack_direction)


func _physics_process(_delta: float) -> void:
	if current_state == State.DEAD:
		return

	var current_cmd = BattleManager.get_team_command(team_id)

	match current_cmd:
		BattleManager.Command.RETREAT:
			process_retreat_mode()
		BattleManager.Command.DEFEND:
			process_defend_mode()
		BattleManager.Command.ATTACK:
			process_attack_mode()


# --- 1. CHẾ ĐỘ RÚT LUI (Bỏ qua địch, chạy thẳng về thành) ---
func process_retreat_mode() -> void:
	current_target = null
	attack_timer.stop()
	
	var target_x = retreat_base_x + personal_offset_x
	if abs(global_position.x - target_x) > 10.0:
		move_towards_x(target_x)
	else:
		# Đã về tới sau thành -> Đứng nghỉ và quay mặt ra ngoài canh gác
		stop_and_idle()
		face_direction(attack_direction)


# --- 2. CHẾ ĐỘ PHÒNG THỦ (Về vạch thủ đứng chờ, địch tới gần mới chém) ---
func process_defend_mode() -> void:
	update_target()
	
	# Nếu có địch lọt vào tầm kiếm ngay tại tuyến phòng thủ -> Đứng chém
	if current_target != null:
		stop_and_attack()
		return

	var target_x = defend_line_x + personal_offset_x
	if abs(global_position.x - target_x) > 10.0:
		# Chưa về tới vạch phòng thủ -> Chạy về vạch
		move_towards_x(target_x)
	else:
		# Đã đứng đúng vạch phòng thủ -> Đứng Idle và luôn nhìn về hướng địch
		stop_and_idle()
		face_direction(attack_direction)


# --- 3. CHẾ ĐỘ TIẾN CÔNG (Đi thẳng sang nhà địch, gặp địch là chém) ---
func process_attack_mode() -> void:
	update_target()
	
	if current_target != null:
		stop_and_attack()
	else:
		current_state = State.MOVE
		face_direction(attack_direction)
		velocity = Vector2(attack_direction * move_speed, 0)
		move_and_slide()
		play_anim("walk")


# --- CÁC HÀM HỖ TRỢ DI CHUYỂN & LẬT MẶT ---
func move_towards_x(target_x: float) -> void:
	current_state = State.MOVE
	var dir = sign(target_x - global_position.x)
	face_direction(dir)
	velocity = Vector2(dir * move_speed, 0)
	move_and_slide()
	play_anim("walk")


func stop_and_idle() -> void:
	current_state = State.IDLE
	velocity = Vector2.ZERO
	play_anim("idle")


func stop_and_attack() -> void:
	velocity = Vector2.ZERO
	# Quay mặt về phía mục tiêu đang đánh
	if is_instance_valid(current_target):
		var dir_to_enemy = sign(current_target.global_position.x - global_position.x)
		if dir_to_enemy != 0:
			face_direction(dir_to_enemy)
			
	if current_state != State.ATTACK:
		current_state = State.ATTACK
		attack_timer.start()
	play_anim("attack")


func face_direction(dir: float) -> void:
	if dir == 0:
		return
	var s = sign(dir)
	visuals.scale.x = abs(visuals.scale.x) * s
	attack_range.scale.x = abs(attack_range.scale.x) * s


func _on_command_changed(changed_team: int, _new_cmd: int) -> void:
	if changed_team == team_id and current_state != State.DEAD:
		# Reset mục tiêu ngay lập tức nếu người chơi bấm Rút lui
		if _new_cmd == BattleManager.Command.RETREAT:
			current_target = null
			attack_timer.stop()


func update_target() -> void:
	if is_instance_valid(current_target) and current_target.current_state != State.DEAD:
		if attack_range.overlaps_body(current_target):
			return

	current_target = null
	for body in attack_range.get_overlapping_bodies():
		if body is StickUnit and body != self:
			if body.team_id != team_id and body.current_state != State.DEAD:
				current_target = body
				break

	if current_target == null:
		attack_timer.stop()


func _on_timer_timeout() -> void:
	if current_state == State.ATTACK and is_instance_valid(current_target):
		if current_target.current_state != State.DEAD:
			current_target.take_damage(attack_damage)


func take_damage(amount: float) -> void:
	if current_state == State.DEAD:
		return
	current_hp -= amount
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
	if is_instance_valid(anim_player):
		anim_player.stop()

	var fall_dir = sign(visuals.scale.x)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(visuals, "rotation_degrees", -90.0 * fall_dir, 0.4)
	tween.tween_property(visuals, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()


func play_anim(anim_name: String) -> void:
	if not is_instance_valid(anim_player):
		return
	var target_anim: String = ""
	if anim_player.has_animation(anim_name):
		target_anim = anim_name
	elif anim_player.has_animation(anim_name.capitalize()):
		target_anim = anim_name.capitalize()

	if target_anim != "" and anim_player.current_animation != target_anim:
		anim_player.play(target_anim)
