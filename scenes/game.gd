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
@export var ingredients_dir_path : String = "res://assets/icons/ingredients/"

class Dish:
	var name: String
	var time: float
	
	func _init(_name, _time):
		self.name = _name
		self.time = _time

class Order:
	var hero: String
	var dish: Dish
	var current_time: float

	func _init(_hero, _dish):
		self.hero = _hero
		self.dish = _dish
		self.current_time = 0.0

# Listas para controle interno de pratos, herois, pedidos e ingredientes
var heroes : Array[String] = ['deadpool', 'hulk', 'spider']
var heroes_in_use : Array[String] = [] # evita que herois em uso aparecam fazendo um novo pedido
var dishes : Array[Dish] = [Dish.new('Batata', 10), Dish.new('MacTudo', 30)]
var orders : Array[Order] = []
var ingredients : Array[String] = [] # currently selected ingredients

var ingredients_panel : Panel = Panel.new()
var delivery_panel : Panel = Panel.new()

func _ready() -> void:
	# initialize score & time labels
	score_label.text = "Score: " + str(current_score)
	time_label.text = "Time: " + str(game_duration_seconds)
	
	# create ingredients panel
	ingredients_panel.visible = false
	ingredients_panel.name = "IngredientsPanel"
	ingredients_panel.position = Vector2(0,70)
	var ingredients_container : GridContainer = GridContainer.new()
	ingredients_container.columns = 4
	ingredients_container.scale = Vector2(1.25, 1.25)
	var ing_dir : DirAccess = DirAccess.open(ingredients_dir_path)
	if ing_dir:
		ing_dir.list_dir_begin()
		var file_name : String = ing_dir.get_next()
		while file_name != "":
			if not ing_dir.current_is_dir() and file_name.ends_with(".png"):
				var checkbox : CheckBox = CheckBox.new()
				checkbox.tooltip_text = file_name.split(".")[0]
				checkbox.name = checkbox.tooltip_text + "IngredientCheckBox"
				checkbox.tooltip_text = checkbox.tooltip_text.replace("-", " ")
				checkbox.icon = load(ingredients_dir_path + file_name)
				checkbox.toggled.connect(func(checked): _on_ingredient_checkbox_toggled(checkbox, checked))
				ingredients_container.add_child(checkbox)
			file_name = ing_dir.get_next()
	ingredients_panel.add_child(ingredients_container)
	$UserInterface.add_child(ingredients_panel)
	
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
			current_score -= int(order.dish.time/3) # penalizar o jogador por nao entregar o pedido com a perda de 1/3 de sua duracao
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
	var pos : int = rng.randi_range(0, len(heroes)-1)
	var hero : String = heroes[pos]
	heroes_in_use.append(hero)
	heroes.remove_at(pos)
	return hero
	
# Gera um prato aleatorio para ser adicionado a um pedido, retornando um array com o nome (string) e duracao (int) do pedido, nessa ordem
func get_dish() -> Dish:
	var pos : int = rng.randi_range(0, len(dishes)-1)
	var dish : Dish = dishes[pos]
	return dish

# Cria um pedido dado um heroi e um prato (Array[string, int] (nome do prato e duracao)) e o adiciona a tela
func create_order(hero: String, dish: Dish) -> void:
	# criar o pedido na lista de controle interno
	orders.append(Order.new(hero, dish)) # nome do heroi, nome do prato, tempo do prato, tempo que está demorando para fazer
	
	# gerar os caminhos das texturas do heroi e do prato p/ adicionar na UI
	var hero_texture_path : String = heroes_dir_path + "%s.happy.png" % hero
	var food_texture_path : String = dishes_dir_path + "%s.png" % dish.name
	
	# carregar as texturas em dois objetos TextureRect e arrumar os tamanhos, posicao no painel etc.
	var hero_icon : TextureRect = TextureRect.new()
	hero_icon.size = Vector2(45, 45)
	hero_icon.texture = load(hero_texture_path)
	hero_icon.tooltip_text = hero.capitalize()
	hero_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_icon.position = Vector2(0, 0)
	var food_icon : TextureRect = TextureRect.new()
	food_icon.size = Vector2(45, 45)
	food_icon.texture = load(food_texture_path)
	food_icon.tooltip_text = dish.name.capitalize()
	food_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	food_icon.position = Vector2(45, 0)
	
	# criar o painel que vai conter as duas texturas na tela (fundo cinza)
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(hero_icon.size.x + food_icon.size.x, max(hero_icon.size.y, food_icon.size.y))
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
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
	if body == player:
		delivery_panel.visible = true

# Called when a body leaves the delivery area
func _on_delivery_area_body_exited(body: Node2D) -> void:
	if body == player:
		delivery_panel.visible = false

# Called when a body enters the ingredients area
func _on_ingredients_area_body_entered(body: Node2D) -> void:
	if body == player:
		ingredients_panel.visible = true

# Called when a body leaves the ingredients area
func _on_ingredients_area_body_exited(body: Node2D) -> void:
	if body == player:
		ingredients_panel.visible = false
	
	# disable all checkboxes in ingredients_panel
	#for child in ingredients_panel.get_child(0).get_children():
	#	if child is CheckBox:
	#		child.set_pressed(false)

# Called when an ingredient checkbox is toggled, receiving as parameter a reference to the checkbox that was toggled and whether or not it is checked
func _on_ingredient_checkbox_toggled(checkbox : CheckBox, checked : bool) -> void:
	if checked:
		ingredients.append(checkbox.tooltip_text)
	else:
		ingredients.remove_at(ingredients.find(checkbox.tooltip_text))
