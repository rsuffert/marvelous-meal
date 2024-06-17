extends Node2D

### REFERENCES TO UI COMPONENTS
@onready var score_label = $UserInterface/StatsContainer/ScoreLabel
@onready var time_label = $UserInterface/StatsContainer/TimeLabel
@onready var wave_label = $UserInterface/StatsContainer/WaveLabel
@onready var orders_container = $UserInterface/OrdersContainer
@onready var player : CharacterBody2D = $Player
@onready var heart_bar = $UserInterface/HeartBar
var ingredients_panel : Panel
var dishes_panel : Panel
var delivery_panel : Panel
var dishes_buttons_container : GridContainer

### EXPORTED VARIABLES THAT CONTAIN THE PATH TO DIRECTORIES OF ASSETS USED IN THE GAME
@export var scenes_dir_path : String = "res://scenes/"
@export var dishes_dir_path : String = "res://assets/icons/dishes/"
@export var heroes_dir_path : String = "res://assets/icons/heroes/"
@export var ingredients_dir_path : String = "res://assets/icons/ingredients/"
@export var game_font_path : String = "res://assets/fonts/Emulogic-zrEw.ttf"

### GAME CLASSES
class Dish:
	var name: String
	var time: float
	var ingredients #Array[String]
	
	func _init(_name, _time, _ingredients):
		self.ingredients = _ingredients
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

### INTERNAL VARIABLES
var rng = RandomNumberGenerator.new()
const ORDERS_CREATION_INTERVAL : int = 10
const MAX_WAVES : int = 3
const DISH_TIME_REDUCTION_PERCENTAGE_PER_WAVE : float = 0.2
const TOTAL_GAME_DURATION_SECONDS : int = 120
var remaining_time : int = TOTAL_GAME_DURATION_SECONDS
var current_score : int = 0
var current_wave : int = 1
var lives : int = 3
var last_hero : String = "" # avoids selecting the same hero twice in a row for the order
var heroes : Array[String] = ['deadpool', 'hulk', 'spiderman'] # available heroes
var heroes_in_use : Array[String] = [] # evita que herois em uso aparecam fazendo um novo pedido
var dishes : Array[Dish] = [
	Dish.new('Batata', 10, ['Potato']),
	Dish.new('MacTudo', 30, ['Bacon', 'Bread', 'Cheese', 'Onion', 'Pickle', 'Potato', 'Steak'])
] # available dishes
var orders : Array[Order] = [] # current orders
var ingredients : Array[String] = [] # currently selected ingredients

### MAIN GAME FUNCTIONS
func _ready() -> void:
	# initialize score, time & wave labels
	score_label.text = "Score:" + str(current_score)
	time_label.text = "Time:" + str(remaining_time)
	wave_label.text = "Wave: " + str(current_wave)
	# initialize UI panels
	initialize_ingredients_panel()
	initialize_dishes_panel()
	initialize_delivery_panel()
	
# Chamada a cada segundo
func _on_timer_timeout() -> void:
	check_existing_orders()
	if remaining_time > 0 and lives > 0:
		game_loop()
	else: # time's up. change to game over scene
		var gameover_scene = load(scenes_dir_path + "game_over.tscn").instantiate()
		gameover_scene.call_deferred("set_score", current_score)
		var message : String = "Time's up!" if remaining_time <= 0 else "You have no lives left!"
		gameover_scene.call_deferred("set_message", message)
		get_tree().root.add_child(gameover_scene)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = gameover_scene

# Itera sobre os pedidos existentes e apaga aqueles cujo tempo acabou
func check_existing_orders() -> void:
	for i in range(len(orders) - 1, -1, -1): # itera de tras para frente
		var order : Order = orders[i]
		order.current_time += 1
		# atualizar imagem dos herois de acordo com o tempo transcorrido (humor)
		if order.current_time / order.dish.time >= 2.0/3.0: # humor "bravo" (angry)
			var hero_texture : TextureRect = orders_container.get_child(i).get_child(0)
			var new_hero_texture_path : String = heroes_dir_path + "%s.angry.png" % order.hero
			hero_texture.texture = load(new_hero_texture_path)
			hero_texture.tooltip_text = order.hero.capitalize() + " (angry)"
		elif order.current_time / order.dish.time >= 1.0/3.0: # humor "normal"
			var hero_texture : TextureRect = orders_container.get_child(i).get_child(0)
			var new_hero_texture_path : String = heroes_dir_path + "%s.normal.png" % order.hero
			hero_texture.texture = load(new_hero_texture_path)
			hero_texture.tooltip_text = order.hero.capitalize() + " (normal)"
		if order.current_time == order.dish.time: # tempo do pedido acabou
			lives -= 1
			heart_bar.call_deferred("decrement_health")
			delete_order(order, i)

# Loop do jogo, com as acoes de atualizacao da UI e de coordenacao/controle do jogo
func game_loop():
	remaining_time -= 1
	time_label.text = "Time:" + str(remaining_time)
	score_label.text = "Score:" + str(current_score)
	if remaining_time % ORDERS_CREATION_INTERVAL == 0 and len(heroes) > 0:
		create_order(get_hero(), get_dish())
	if should_increment_wave(): # move on to the next wave
		for dish in dishes:
			dish.time *= (1-DISH_TIME_REDUCTION_PERCENTAGE_PER_WAVE)
		current_wave += 1
		wave_label.text = "Wave: " + str(current_wave)

### CALLBACK FUNCTIONS FOR AREAS IN THE SCENARIO ENTERED
# Called when a body enters the delivery area
func _on_delivery_area_body_entered(body: Node2D) -> void:
	if body == player and not orders.is_empty():
		orders_container.visible = false
		delivery_panel.visible = true

# Called when a body leaves the delivery area
func _on_delivery_area_body_exited(body: Node2D) -> void:
	if body == player:
		orders_container.visible = true
		delivery_panel.visible = false

# Called when a body enters the ingredients area
func _on_ingredients_area_body_entered(body: Node2D) -> void:
	if body == player:
		ingredients_panel.visible = true

# Called when a body leaves the ingredients area
func _on_ingredients_area_body_exited(body: Node2D) -> void:
	if body == player:
		ingredients_panel.visible = false
		dishes_panel.visible = false
		set_panel_checkboxes(ingredients_panel, false)

### CALLBACK FUNCTIONS FOR UI COMPONENTS ACTIONS (PRESSED, TOGGLED ETC.)
# Called when an ingredient checkbox is toggled, receiving as parameter a reference to the checkbox that was toggled and whether or not it is checked
func _on_ingredient_checkbox_toggled(checkbox : CheckBox, checked : bool) -> void:
	if checked:
		ingredients.append(checkbox.tooltip_text)
	else:
		ingredients.remove_at(ingredients.find(checkbox.tooltip_text))

# Replaces the ingredients panel with the dishes panel
func _on_create_dish_button_pressed() -> void:
	ingredients_panel.visible = false
	
	# remove current plates being rendered
	for child in dishes_buttons_container.get_children():
		child.queue_free()
		
	# populate dishes panel with possible dishes using the ingredients currently selected (when clicked, add dish to player's inventory)
	for dish in dishes:
		if are_all_elements_present(dish.ingredients, ingredients): # this dish can be produced with selected ingredients
			var button : Button = Button.new()
			button.tooltip_text = dish.name
			button.name = dish.name + "PossibleButton"
			button.icon = load(dishes_dir_path + dish.name + ".png")
			button.pressed.connect(func(): _on_possible_dish_button_pressed(button))
			dishes_buttons_container.add_child(button)
	dishes_panel.scale = Vector2(0.2,0.2)
	dishes_panel.visible = true

# Called when a possible dish button is pressed
func _on_possible_dish_button_pressed(button: Button):
	player.call('pickup_dish', button.icon, button.tooltip_text)
	
# Called when a hero button is pressed for delivery
func _on_hero_delivery_button_pressed(button : Button):
	for i in range(len(orders)):
		var order = orders[i]
		if order.dish.name == player.current_dish and button.tooltip_text.to_lower() == order.hero: # correct answer
			player.deliver_dish()
			current_score += order.dish.time - order.current_time
			delete_order(order, i)
			return
	# se chegar ate essa parte do codigo, clicou no heroi errado (penalizar com a perda de 10% da pontuação atual)
	if current_score > 0:
		current_score -= current_score*0.1
	
### FUNCIONS FOR MANAGING & INITIALIZING UI COMPONENTS
func initialize_ingredients_panel() -> void:
	ingredients_panel = Panel.new()
	ingredients_panel.visible = false
	ingredients_panel.name = "IngredientsPanel"
	ingredients_panel.position = Vector2(5,85)
	var ingredients_vbox : VBoxContainer = VBoxContainer.new()
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
	var create_dish_button : Button = Button.new()
	create_dish_button.text = 'Create dish'
	create_dish_button.pressed.connect(_on_create_dish_button_pressed)
	ingredients_vbox.add_child(ingredients_container)
	ingredients_vbox.add_child(create_dish_button)
	ingredients_panel.add_child(ingredients_vbox)
	$UserInterface.add_child(ingredients_panel)

func initialize_dishes_panel() -> void:
	dishes_panel = Panel.new()
	dishes_panel.visible = false
	dishes_panel.name = "DishesPanel"
	dishes_panel.position = Vector2(5,85)
	var dishes_vbox : VBoxContainer = VBoxContainer.new()
	var dishes_container : GridContainer = GridContainer.new()
	dishes_container.columns = 2
	var label : Label = Label.new()
	label.text = "Select a dish to pick up:"
	label.add_theme_font_size_override("font_size", 40)
	var font = load(game_font_path)
	label.add_theme_font_override("font", font)
	dishes_vbox.add_child(label)
	dishes_vbox.add_child(dishes_container)
	dishes_panel.add_child(dishes_vbox)
	$UserInterface.add_child(dishes_panel)
	dishes_buttons_container = dishes_container

func initialize_delivery_panel() -> void:
	delivery_panel = Panel.new()
	delivery_panel.visible = false
	delivery_panel.name = "DeliveryPanel"
	delivery_panel.position = Vector2(5, 85)
	var heroes_container: GridContainer = GridContainer.new()
	heroes_container.scale = Vector2(0.05,0.05)
	heroes_container.columns = 3
	for hero in heroes_in_use+heroes:
		var hero_button : Button = Button.new()
		hero_button.icon = load(heroes_dir_path + hero + ".normal.png")
		hero_button.tooltip_text = hero.capitalize()
		hero_button.pressed.connect(func(): _on_hero_delivery_button_pressed(hero_button))
		heroes_container.add_child(hero_button)
	delivery_panel.add_child(heroes_container)
	$UserInterface.add_child(delivery_panel)
	
# Cria um pedido dado um heroi e um prato e o adiciona a tela
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
	hero_icon.tooltip_text = hero.capitalize() + " (happy)"
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

# Deleta um certo pedido
func delete_order(order : Order, index: int) -> void:
	# liberar o heroi em uso das listas internas
	var hero : String = order.hero
	heroes.append(hero)
	heroes_in_use.remove_at(index)
	
	# remover o pedido da lista interna de controle
	orders.remove_at(index)
	
	# remover o pedido da tela
	var child : Panel = orders_container.get_child(index)
	orders_container.remove_child(child)
	child.queue_free()
	
### AUXILIARY FUNCTIONS
# Checks if all elements in list1 are present in list2
func are_all_elements_present(list1: Array, list2: Array) -> bool:
	for e in list1:
		if e not in list2:
			return false
	return true
	
# Gera um heroi aleatorio para ser adicionado a um pedido, retornando seu nome (o heroi gerado eh diferente do ultimo)
func get_hero() -> String:
	var hero : String = last_hero
	var pos : int
	while (hero == last_hero):
		pos = rng.randi_range(0, len(heroes)-1)
		hero = heroes[pos]
	last_hero = hero
	heroes_in_use.append(hero)
	heroes.remove_at(pos)
	return hero
	
# Gera um prato aleatorio para ser adicionado a um pedido
func get_dish() -> Dish:
	var pos : int = rng.randi_range(0, len(dishes)-1)
	var dish : Dish = dishes[pos]
	return dish
	
# Enables or disables all checkboxes in a panel (ingredients or delivery panel)
func set_panel_checkboxes(panel : Panel, pressed: bool) -> void:
	for child in panel.get_child(0).get_child(0).get_children():
		if child is CheckBox:
			child.set_pressed(pressed)

func should_increment_wave() -> bool:
	if current_wave >= MAX_WAVES: return false
	var wave_duration : int = TOTAL_GAME_DURATION_SECONDS / MAX_WAVES
	var current_wave_end = wave_duration*current_wave
	return current_wave_end < (TOTAL_GAME_DURATION_SECONDS-remaining_time)
