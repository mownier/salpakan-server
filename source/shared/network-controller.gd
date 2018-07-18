extends Node

signal network_controller_on_game_started()
signal network_controller_on_player_ready_with(id, color)
signal network_controller_on_players_turn_with(id, color)

class BoardSlot:
	
	var rank
	var state
	var color
	
	func _init():
		make_vacant()
	
	func make_vacant():
		rank = -1
		state = BOARD_SLOT_STATE.vacant
		color = null
	
	func make_occupied_with(piece_rank, piece_color):
		rank = piece_rank
		state = BOARD_SLOT_STATE.occupied
		color = piece_color
	
	func description():
		match state:
			BOARD_SLOT_STATE.vacant:
				return "vacant"
				
			BOARD_SLOT_STATE.occupied:
				return str("rank: ", rank, ", color: ", color)
	

enum PIECE_COLOR {
	white,
	black
}

enum BOARD_SLOT_STATE {
	vacant,
	occupied
}

enum PLAYER_STATE {
	none
	finished_setting_up_pieces
}

var player_color_info = {}
var color_player_info = {}
var player_state_info = {}
var players = []

var board_slot_x = 9
var board_slot_y = 8
var board_slots = []

func _ready():
	for x in range(board_slot_x):
		board_slots.append([])
		board_slots[x].resize(board_slot_y)
		for y in range(board_slot_y):
			board_slots[x][y] = BoardSlot.new()

func color_string_for(piece_color):
	match piece_color:
		PIECE_COLOR.white:
			return "white"
			
		PIECE_COLOR.black:
			return "black"

func add_player_with(id):
	players.append(id)

func assign_color_to_player_with(id):
	var color
	
	if !player_color_info.values().has(PIECE_COLOR.white):
		color = PIECE_COLOR.white
		
	elif !player_color_info.values().has(PIECE_COLOR.black):
		color = PIECE_COLOR.black
	
	if color != null:
		player_color_info[id] = color
		color_player_info[color] = id
		player_state_info[id] = PLAYER_STATE.none
		rpc_id(id, "on_assigned_piece_color", color)
	
	return color_string_for(color)

func notify_other_players_on_new_player_with(id):
	for player in players:
		if id == player: continue
		rpc_id(player, "on_new_connected_player_with", id, player_color_info[id])
		rpc_id(id, "on_already_connected_player_with", player, player_color_info[player])

master func start_game():
	emit_signal("network_controller_on_game_started")
	for player in players:
		rpc_id(player, "on_game_started")

master func register_initial_board_slots_for(color, slots):
	var rankless_slots = []
	for slot in slots:
		var rank = slot.z
		var board_slot = board_slots[slot.x][slot.y]
		board_slot.make_occupied_with(rank, color)
		rankless_slots.append(Vector2(slot.x, slot.y))
		
	var player = color_player_info[color]
	var enemy
	match color:
		PIECE_COLOR.white:
			enemy = color_player_info[PIECE_COLOR.black]
			
		PIECE_COLOR.black:
			enemy = color_player_info[PIECE_COLOR.white]
		
	rpc_id(enemy, "on_enemy_ready_with", rankless_slots)
	player_state_info[player] = PLAYER_STATE.finished_setting_up_pieces
	
	emit_signal("network_controller_on_player_ready_with", player, color_string_for(color))
	
	match player_state_info[enemy]:
		PLAYER_STATE.finished_setting_up_pieces:
			var piece_color
			if ((randi() % 100) + 1) % 2 == 0:
				piece_color = PIECE_COLOR.white
			else:
				piece_color = PIECE_COLOR.black
			rpc("on_first_move_with", piece_color)
			emit_signal("network_controller_on_players_turn_with", color_player_info[piece_color], color_string_for(piece_color))
 