extends Button

func _ready() -> void:
	# Kết nối sự kiện bấm nút
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	# Thay đường dẫn "res://scenes/gameplay.tscn" thành file màn hình game thực tế của bạn
	get_tree().change_scene_to_file("res://scenes/warrior_bot.tscn")
