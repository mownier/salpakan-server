extends Control

const SERVER_PORT = 9120

onready var status_text_view = get_node("status_text_view")

func _ready():
	get_tree().connect("network_peer_connected"   , self, "player_on_connected"        )
	get_tree().connect("network_peer_disconnected", self, "player_on_disconnected"     )
	get_tree().connect("connected_to_server"      , self, "server_on_connected"        )
	get_tree().connect("connection_failed"        , self, "server_on_failed_connection")
	get_tree().connect("server_disconnected"      , self, "server_on_disconnected"     )
	
	network_controller.connect("network_controller_on_game_started", self, "on_game_started")
	network_controller.connect("network_controller_on_player_ready_with", self, "on_player_ready_with")
	network_controller.connect("network_controller_on_players_turn_with", self, "on_players_turn_with")

func _on_start_button_pressed():
	var host = NetworkedMultiplayerENet.new()
	host.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_RANGE_CODER)
	var err = host.create_server(SERVER_PORT, 2)
	if err != OK:
		update_status_with("can't host, address in use.")
		return
	get_tree().set_network_peer(host)
	update_status_with("started server")

func _on_stop_button_pressed():
	get_tree().set_network_peer(null)
	update_status_with("stopped server")

func update_status_with(text):
	status_text_view.add_text("> " + text + "\n")

func player_on_connected(id):
	update_status_with(str("player ", id, " is connected"))
	network_controller.add_player_with(id)
	var assigned_color = network_controller.assign_color_to_player_with(id)
	network_controller.notify_other_players_on_new_player_with(id)
	update_status_with(str("player ", id, " is assigned to ", assigned_color, " pieces"))

func player_on_disconnected(id):
	update_status_with(str("player ", id, " is disconnected"))

func server_on_connected():
	update_status_with("server connected")

func server_on_failed_connection():
	update_status_with("server failed to connect")

func server_on_disconnected():
	update_status_with("server disconnected")

func on_game_started():
	update_status_with("game started")

func on_player_ready_with(id, color):
	update_status_with(str("[", color, "] player ", id, " is ready"))

func on_players_turn_with(id, color):
	update_status_with(str("[", color, "] player ", id, "'s turn to move"))
