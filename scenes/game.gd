extends Node2D

@onready var game_duration_seconds : int = 60
@onready var current_score : int = 0
@onready var score_label = $UserInterface/StatsContainer/ScoreLabel
@onready var time_label = $UserInterface/StatsContainer/TimeLabel
@onready var orders_container = $UserInterface/OrdersContainer
const ORDERS_CREATION_INTERVAL = 10

var rng = RandomNumberGenerator.new()

# Listas para controle interno de pratos, herois e pedidos
var heroes = ['deadpool', 'hulk', 'spider']
var heroes_in_use = []
var dishes = [['Batata', 10], ['MacTudo', 30]]
var orders = []

func _ready() -> void:
	score_label.text = "Score: " + str(current_score)
	time_label.text = "Time: " + str(game_duration_seconds)

func _on_timer_timeout() -> void:
	check_existing_orders()
	if game_duration_seconds > 0:
		game_loop()
	else:
		pass # change to game over scene

# Loop do jogo, com as acoes de atualizacao da UI e de coordenacao
func game_loop():
	game_duration_seconds -= 1
	time_label.text = "Time: " + str(game_duration_seconds)
	if game_duration_seconds % ORDERS_CREATION_INTERVAL == 0 and len(heroes) > 0:
		create_order(get_hero(), get_dish())

# Gera um heroi aleatorio para ser adicionado a um pedido, retornando seu nome
func get_hero():
	var pos = rng.randf_range(0, len(heroes))
	var hero = heroes[pos]
	heroes_in_use.append(hero)
	heroes.remove_at(pos)	
	return hero
	
# Gera um prato aleatorio para ser adicionado a um pedido, retornando seu nome e sua duracao
func get_dish():
	var pos = rng.randf_range(0, len(dishes))
	var dish = dishes[pos]
	return dish

# Itera sobre os pedidos existentes e apaga aqueles cujo tempo acabou
func check_existing_orders():
	for i in range(len(orders) - 1, -1, -1):
		var order = orders[i]
		order[3] += 1
		if order[3] == order[2]: # tempo do pedido acabou
			var hero = order[0]
			heroes.append(hero)
			heroes_in_use.remove_at(i)
			orders.remove_at(i)
			delete_order(i)

func create_order(hero, dish):
	var hero_texture_path = "res://assets/icons/heroes/%s.happy.png" % hero
	var food_texture_path = "res://assets/icons/dishes/%s.png" % dish[0]
	
	# nome do heroi, nome do prato, tempo do prato, tempo que está demorando para fazer
	orders.append([hero, dish[0], dish[1], 0])
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

func delete_order(index: int):
	var child = orders_container.get_child(index)
	orders_container.remove_child(child)
	child.queue_free()
