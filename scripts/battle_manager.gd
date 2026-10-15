# File: res://scripts/battle_manager.gd
extends Node

enum Command { RETREAT, DEFEND, ATTACK }

# Tín hiệu phát đi toàn bản đồ mỗi khi đổi lệnh
signal command_changed(team_id: int, new_command: Command)

# Lưu trạng thái hiện tại của Phe 0 (Người chơi) và Phe 1 (Máy)
var team_commands: Dictionary = {
	0: Command.DEFEND, # Mặc định vào trận phe mình đứng thủ ở nhà
	1: Command.ATTACK  # Mặc định phe máy luôn tiến công
}

func set_team_command(team_id: int, new_command: Command) -> void:
	if team_commands.get(team_id) == new_command:
		return
	team_commands[team_id] = new_command
	command_changed.emit(team_id, new_command)

func get_team_command(team_id: int) -> Command:
	return team_commands.get(team_id, Command.ATTACK)
