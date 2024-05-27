extends Node2D

const ORDERS_CREATION_INTERVAL = 10
var rng = RandomNumberGenerator.new()
@onready var game_duration_seconds : int = 60
@onready var current_score : int = 0
@onready var score_label = $UserInterface/StatsContainer/ScoreLabel
@onready var time_label = $UserInterface/StatsContainer/TimeLabel
@onready var orders_container = $UserInterface/OrdersContainer
@onready var player : CharacterBody2D = $Player

# exported variables that contain the path to the directories of scenes, dishes assets and heroes assets
@export var scenes_dir_path : String = "res://scenes/"
@export var dishes_dir_path : String = "res://assets/icons/dishes/"
@export var heroes_dir_path : String = "res://assets/icons/heroes/"

class Dish:
	var name: String
	var time: float
	
	func _init(name, time):
		self.name = name
		self.time = time

class Order:
	var hero: String
	var dish: Dish
	var current_time: float

	func _init(hero, dish):
		self.hero = hero
		self.dish = dish
		self.current_time = 0.0

# Listas para controle interno de pratos, herois e pedidos
var heroes : Array[String] = ['deadpool', 'hulk', 'spider']
var heroes_in_use : Array[String] = [] # evita que herois em uso aparecam fazendo um novo pedido
var dishes : Array[Dish] = [Dish.new('Batata', 10), Dish.new('MacTudo', 30)] # [[nome do prato, tempo max de espera]]
var orders : Array[Order] = [] # [[nome do heroi, nome do prato, tempo max de espera, tempo que passou]]

func _ready() -> void:
	score_label.text = "Score: " + str(current_score)
	time_label.text = "Time: " + str(game_duration_seconds)

# Chamada a cada segundo
func _on_timer_timeout() -> void:
	check_existing_orders()
	if game_duration_seconds > 0:
		game_loop()
	else: # time's up. change to game over scene
		var gameover_scene = load(scenes_dir_path + "game_over.tscn").instantiate()
		gameover_scene.call_deferred("set_score", current_score)
		get_tree().root.add_child(gameover_scene)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = gameover_scene

# Itera sobre os pedidos existentes e apaga aqueles cujo tempo acabou
func check_existing_orders() -> void:
	for i in range(len(orders) - 1, -1, -1): # itera de tras para frente
		var order : Order = orders[i]
		order.current_time += 1
		if order.current_time / order.dish.time >= 2.0/3.0:
			var hero_texture_path : String = heroes_dir_path + "%s.angry.png" % order.hero
			orders_container.get_child(i).get_child(0).texture = load(hero_texture_path)
		elif order.current_time / order.dish.time >= 1.0/3.0:
			var hero_texture_path : String = heroes_dir_path + "%s.normal.png" % order.hero
			orders_container.get_child(i).get_child(0).texture = load(hero_texture_path)
		if order.current_time == order.dish.time: # tempo do pedido acabou
			current_score -= order.dish.time/3 # penalizar o jogador por nao entregar o pedido com a perda de 1/3 de sua duracao
			delete_order(order, i)

# Loop do jogo, com as acoes de atualizacao da UI e de coordenacao/controle do jogo
func game_loop():
	game_duration_seconds -= 1
	time_label.text = "Time: " + str(game_duration_seconds)
	score_label.text = "Score: " + str(current_score)
	if game_duration_seconds % ORDERS_CREATION_INTERVAL == 0 and len(heroes) > 0:
		create_order(get_hero(), get_dish())

# Gera um heroi aleatorio para ser adicionado a um pedido, retornando seu nome
func get_hero() -> String:
	var pos : int = rng.randf_range(0, len(heroes))
	var hero : String = heroes[pos]
	heroes_in_use.append(hero)
	heroes.remove_at(pos)
	return hero
	
# Gera um prato aleatorio para ser adicionado a um pedido, retornando um array com o nome (string) e duracao (int) do pedido, nessa ordem
func get_dish() -> Dish:
	var pos : int = rng.randf_range(0, len(dishes))
	var dish : Dish = dishes[pos]
	return dish

# Cria um pedido dado um heroi e um prato (Array[string, int] (nome do prato e duracao)) e o adiciona a tela
func create_order(hero: String, dish: Dish) -> void:
	# criar o pedido na lista de controle interno
	orders.append(Order.new(hero, dish)) # nome do heroi, nome do prato, tempo do prato, tempo que está demorando para fazer
	
	# gerar os caminhos das texturas do heroi e do prato p/ adicionar na UI
	var hero_texture_path : String = heroes_dir_path + "%s.happy.png" % hero
	var food_texture_path : String = dishes_dir_path + "%s.png" % dish.name
	
	# criar o painel que vai conter as duas texturas na tela (fundo cinza)
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(120,0)
	
	# carregar as texturas em dois objetos TextureRect e arrumar os tamanhos, posicao no painel etc.
	var hero_icon : TextureRect = TextureRect.new()
	hero_icon.size = Vector2(64, 64)
	hero_icon.texture = load(hero_texture_path)
	hero_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_icon.position = Vector2(0, 0)
	var food_icon : TextureRect = TextureRect.new()
	food_icon.size = Vector2(64, 64)
	food_icon.texture = load(food_texture_path)
	food_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	food_icon.position = Vector2(64, 0)
	
	# adicionar as texturas carregadas no painel
	panel.add_child(hero_icon)
	panel.add_child(food_icon)
	
	# adicionar o painel na tela
	orders_container.add_child(panel)

# Deleta um certo pedido (Array[String, String, int, int] (nome do heroi, nome do prato, tempo do prato, tempo que esta demorando para fazer))
func delete_order(order : Order, index: int) -> void:
	# liberar o heroi em uso das listas internas
	#var hero : String = order.hero
	#heroes.append(hero)
	heroes_in_use.remove_at(index)
	
	# remover o pedido da lista interna de controle
	orders.remove_at(index)
	
	# remover o pedido da tela
	var child : Panel = orders_container.get_child(index)
	orders_container.remove_child(child)
	child.queue_free()

# Called when a body enters the delivery area
func _on_delivery_area_body_entered(body: Node2D) -> void:
	if body != player: return
	print("Delivery area entered")

# Called when a body leaves the delivery area
func _on_delivery_area_body_exited(body: Node2D) -> void:
	if body != player: return
	print("Delivery area exited")

# Called when a body enters the ingredients area
func _on_ingredients_area_body_entered(body: Node2D) -> void:
	if body != player: return
	print("Ingredients area entered")

# Called when a body leaves the ingredients area
func _on_ingredients_area_body_exited(body: Node2D) -> void:
	if body != player: return
	print("Ingredients area exited")
