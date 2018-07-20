extends Node

signal network_controller_on_game_started()
signal network_controller_on_game_over_with(winner, color)
signal network_controller_on_stalemate()
signal network_controller_on_player_ready_with(id, color)
signal network_controller_on_players_turn_with(id, color)
signal network_controller_on_clashed_pieces_with(neutral_piece, aggressive_piece, removed_piece)
signal network_controller_on_removed_both_pieces(neutral_piece, aggressive_piece)
signal network_controller_on_moved_piece(piece, color)

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
	
	func is_vacant():
		return state == BOARD_SLOT_STATE.vacant

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

enum PIECE {
	flag,
	private,
	sergeant,
	second_lieutenant,
	first_lieutenant,
	captain,
	major,
	lieutenant_colonel,
	colonel,
	one_star_general,
	two_star_general,
	three_star_general,
	four_star_general,
	five_star_general,
	spy
}

enum GAME_OVER_STATE {
	white_piece_wins,
	black_piece_wins,
	stalemate
}

var player_color_info = {}
var color_player_info = {}
var player_state_info = {}
var players = []

var board_slot_x = 9
var board_slot_y = 8
var board_slots = []

var pre_winning_color

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

func piece_string_for(piece):
	match int(piece):
		PIECE.flag: return str("(", piece, ") ", "Flag") 
		PIECE.private: return str("(", piece, ") ", "Private") 
		PIECE.sergeant: return str("(", piece, ") ", "Sergeant") 
		PIECE.second_lieutenant: return str("(", piece, ") ", "2nd Lieutenant") 
		PIECE.first_lieutenant: return str("(", piece, ") ", "1st Lieutenant") 
		PIECE.captain: return str("(", piece, ") ", "Captain") 
		PIECE.major: return str("(", piece, ") ", "Major") 
		PIECE.lieutenant_colonel: return str("(", piece, ") ", "Lieutenant Colonel") 
		PIECE.colonel: return str("(", piece, ") ", "Colonel") 
		PIECE.one_star_general: return str("(", piece, ") ", "1-Star General") 
		PIECE.two_star_general: return str("(", piece, ") ", "2-Star General") 
		PIECE.three_star_general: return str("(", piece, ") ", "3-Star General") 
		PIECE.four_star_general: return str("(", piece, ") ", "4-Star General") 
		PIECE.five_star_general: return str("(", piece, ") ", "5-Star General") 
		PIECE.spy: return str("(", piece, ") ", "Spy") 

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

func get_slots_for(player):
	var slots = []
	var color = player_color_info[player]
	for x in range(board_slot_x):
		for y in range(board_slot_y):
			var board_slot = board_slots[x][y]
			if board_slot.color != color: continue
			var slot = Vector3(x, y, board_slot.rank)
			slots.append(slot) 
	return slots

func notify_on_game_over_with(winner, player1, player2, color):
	rpc("on_game_over_with", winner, color)
	rpc_id(player1, "on_reveal_enemy_pieces_with", get_slots_for(player2))
	rpc_id(player2, "on_reveal_enemy_pieces_with", get_slots_for(player1))
	emit_signal("network_controller_on_game_over_with", winner, color_string_for(color))

func notify_on_stalemate_between(player1, player2):
	rpc("on_stalemate")
	rpc_id(player1, "on_reveal_enemy_pieces_with", get_slots_for(player2))
	rpc_id(player2, "on_reveal_enemy_pieces_with", get_slots_for(player1))
	emit_signal("network_controller_on_stalemate")

func has_winner_between(player1, player2):
	var game_over_state = check_game_over_state()
	
	if game_over_state == null:
		return false
	
	if game_over_state == GAME_OVER_STATE.stalemate:
		notify_on_stalemate_between(player1, player2)
		return false
	
	var winning_color
	
	match game_over_state():
		GAME_OVER_STATE.black_piece_wins:
			winning_color = PIECE_COLOR.black
			
		GAME_OVER_STATE.white_piece_wins:
			winning_color = PIECE_COLOR.white
	
	var winner = color_player_info[winning_color]
	notify_on_game_over_with(winner, player1, player2, winning_color)
	
	return true

func check_game_over_state():
	var has_white_pieces = false
	var has_black_pieces = false
	
	for x in range(board_slot_x):
		for y in range(board_slot_y):
			var board_slot = board_slots[x][y]
			
			if board_slot.color == null || \
				board_slot.state == BOARD_SLOT_STATE.vacant || \
				board_slot.color == PIECE_COLOR.white && has_white_pieces || \
				board_slot.color == PIECE_COLOR.black && has_black_pieces:
					continue
			
			match board_slot.color:
				PIECE_COLOR.white:
					has_white_pieces = true
					
				PIECE_COLOR.black:
					has_black_pieces = true
	
	if (not has_white_pieces && not has_black_pieces):
		return GAME_OVER_STATE.stalemate
	
	if (has_white_pieces && has_black_pieces):
		return null
	
	if not has_black_pieces:
		return GAME_OVER_STATE.black_piece_wins
	
	if not has_white_pieces:
		return GAME_OVER_STATE.white_piece_wins

func next_color_to_move_with(current_color):
	match current_color:
		PIECE_COLOR.white: 
			return PIECE_COLOR.black
			
		PIECE_COLOR.black: 
			return PIECE_COLOR.white

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
		
	var player1 = color_player_info[color]
	var player2
	match color:
		PIECE_COLOR.white:
			player2 = color_player_info[PIECE_COLOR.black]
			
		PIECE_COLOR.black:
			player2 = color_player_info[PIECE_COLOR.white]
		
	rpc_id(player2, "on_enemy_ready_with", rankless_slots)
	player_state_info[player1] = PLAYER_STATE.finished_setting_up_pieces
	
	emit_signal("network_controller_on_player_ready_with", player1, color_string_for(color))
	
	match player_state_info[player2]:
		PLAYER_STATE.finished_setting_up_pieces:
			var piece_color
			if ((randi() % 100) + 1) % 2 == 0:
				piece_color = PIECE_COLOR.white
			else:
				piece_color = PIECE_COLOR.black
			rpc("on_first_move_with", piece_color)
			emit_signal("network_controller_on_players_turn_with", color_player_info[piece_color], color_string_for(piece_color))

master func process_moved_piece_with(color, current_slot, destination_slot):
	var player1 = color_player_info[color]
	var player2
	match color:
		PIECE_COLOR.black:
			player2 = color_player_info[PIECE_COLOR.white]
			
		PIECE_COLOR.white:
			player2 = color_player_info[PIECE_COLOR.black]
	
	if pre_winning_color != null:
		var winner = color_player_info[pre_winning_color]
		notify_on_game_over_with(winner, player1, player2, pre_winning_color)
		return
	
	var current_board_slot = board_slots[current_slot.x][current_slot.y]
	var destination_board_slot = board_slots[destination_slot.x][destination_slot.y]
	
	if destination_board_slot.is_vacant():
		destination_board_slot.make_occupied_with(current_board_slot.rank, color)
		current_board_slot.make_vacant()
		match destination_board_slot.rank:
			PIECE.flag:
				match color:
					PIECE_COLOR.black:
						if destination_slot.y == 0:
							pre_winning_color = PIECE_COLOR.black
						
					PIECE_COLOR.white:
						if destination_slot.y == board_slot_y - 1:
							pre_winning_color = PIECE_COLOR.white
		rpc("on_moved_piece_from", current_slot, destination_slot, color)
		var next_color_to_move = next_color_to_move_with(color)
		rpc("on_next_move_with", next_color_to_move)
		emit_signal("network_controller_on_players_turn_with", color_player_info[next_color_to_move], color_string_for(next_color_to_move))
		emit_signal("network_controller_on_moved_piece", piece_string_for(destination_board_slot.rank), color_string_for(color))
		return
	
	var aggressive_rank = current_board_slot.rank
	var neutral_rank = destination_board_slot.rank
	var removed_rank
	
	# Flag vs Flag: The aggressive player will win
	if neutral_rank == PIECE.flag && aggressive_rank == PIECE.flag:
		var winner = player1
		notify_on_game_over_with(winner, player1, player2, color)
		return
		
	# Same rank: They are both out of the game
	if neutral_rank == aggressive_rank:
		current_board_slot.make_vacant()
		destination_board_slot.make_vacant()
		rpc("on_both_pieces_removed_with", current_slot, destination_slot)
		emit_signal("network_controller_on_removed_both_pieces", piece_string_for(destination_board_slot.rank), piece_string_for(current_board_slot.rank))
		
	# Spy vs Private: Spy will be eliminated, OR
	# Neutral rank is lower: It will be eliminated
	elif (neutral_rank == PIECE.spy && aggressive_rank == PIECE.private) || \
		(neutral_rank < aggressive_rank):
		removed_rank = current_board_slot.rank
		current_board_slot.make_vacant()
		destination_board_slot.make_occupied_with(aggressive_rank, color)
		rpc("on_removed_neutral_piece_with", current_slot, destination_slot)
		
	# Private vs Spy: Spy will be eliminated, OR
	# Aggressive rank is lower: It will be eliminated
	elif (neutral_rank == PIECE.private && aggressive_rank == PIECE.spy) || \
		(aggressive_rank < neutral_rank):
		removed_rank = current_board_slot.rank
		current_board_slot.make_vacant()
		rpc("on_removed_aggressive_piece_with", current_slot)
	
	if removed_rank != null:
		var neutral_piece_string = piece_string_for(destination_board_slot.rank)
		var aggressive_piece_string = piece_string_for(current_board_slot.rank)
		var removed_piece_string = piece_string_for(removed_rank)
		emit_signal("network_controller_on_clashed_pieces_with", "", "", "")
	
	if has_winner_between(player1, player2): return
	
	var next_color_to_move = next_color_to_move_with(color)
	rpc("on_next_move_with", next_color_to_move)
	emit_signal("network_controller_on_players_turn_with", color_player_info[next_color_to_move], color_string_for(next_color_to_move))