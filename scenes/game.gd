extends Node2D

@onready var game_duration_seconds : int = 60
@onready var time_label = $UserInterface/StatsContainer/TimeLabel
@onready var orders_container = $UserInterface/OrdersContainer

func _ready() -> void:
	time_label.text = "Time: " + str(game_duration_seconds)
	
	for i in range(2):
		create_order("res://assets/icons/free-spiderman-1502925-1273046.png", "res://assets/icons/4853280.png")

func _on_timer_timeout() -> void:
	game_duration_seconds -= 1
	time_label.text = "Time: " + str(game_duration_seconds)
	if game_duration_seconds <= 0:
		print("Game over!") # change to game over scene

func create_order(hero_texture_path, food_texture_path):
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(120,0)
	
	var hero_icon = TextureRect.new()
	hero_icon.size = Vector2(64, 64)
	hero_icon.texture = load(hero_texture_path)
	hero_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_icon.position = Vector2(0, 0)
	var food_icon = TextureRect.new()
	food_icon.size = Vector2(64, 64)
	food_icon.texture = load(food_texture_path)
	food_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	food_icon.position = Vector2(64, 0)
	
	panel.add_child(hero_icon)
	panel.add_child(food_icon)
	orders_container.add_child(panel)
