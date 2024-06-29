extends Node2D

var rng = RandomNumberGenerator.new()

### REFERENCES TO UI COMPONENTS
@onready var score_label = $UserInterface/StatsContainer/ScoreLabel
@onready var time_label = $UserInterface/StatsContainer/TimeLabel
@onready var wave_label = $UserInterface/StatsContainer/WaveLabel
@onready var day_label = $UserInterface/StatsContainer/DayLabel
@onready var orders_container = $UserInterface/OrdersContainer
@onready var player : CharacterBody2D = $Player
@onready var heart_bar = $UserInterface/HeartBar
@onready var soundtrack = $AudioStreamPlayer
var ingredients_panel : Panel
var dishes_panel : Panel
var delivery_panel : Panel
var dishes_buttons_container : GridContainer
var ingredients_buttons_container : GridContainer
var ingredients_buttons : Array[Button]
var heroes_buttons : Array[Button]
var dishes_buttons : Array[Button]
var current_panel_buttons : Array[Button] # buttons of the panel that is currently visible
var current_button_pointer : int # pointer to the button the user has currently selected (refers to the list of buttons of the currently visible panel)

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

### STATE CONTROL VARIABLES
const ORDERS_CREATION_INTERVAL : int = 10
const MAX_WAVES : int = 3
const DISH_TIME_REDUCTION_PERCENTAGE_PER_WAVE : float = 0.2
const TOTAL_GAME_DURATION_SECONDS : int = 120
const MAX_REMAINING_TIME_TO_RECEIVE_ORDER : int = 10
var remaining_time : int = TOTAL_GAME_DURATION_SECONDS
var current_score : int = 0
var current_wave : int = 1
var current_day : int = 1
var lives : int = 3
var last_hero : String = "" # avoids selecting the same hero twice in a row for the order
var heroes : Array[String] = ['deadpool', 'hulk', 'spiderman'] # available heroes
var heroes_in_use : Array[String] = [] # evita que herois em uso aparecam fazendo um novo pedido
var dishes : Array[Dish] = [
	Dish.new('Batata', 15, ['Potato']),
	Dish.new('MacTudo', 40, ['Bacon', 'Bread', 'Cheese', 'Onion', 'Pickle', 'Potato', 'Steak'])
] # available dishes
var orders : Array[Order] = [] # current orders
var ingredients : Array[String] = [] # currently selected ingredients

### UI VARIABLES
var normal_style : StyleBoxFlat
var selected_style : StyleBoxFlat
const PANELS_X_COORDINATE : int = 5
const PANELS_Y_COORDINATE : int = 120

### MAIN GAME FUNCTIONS
func _ready() -> void:
	initialize_button_styles()
	score_label.text = "Score:" + str(current_score)
	time_label.text = "Time:" + str(remaining_time)
	wave_label.text = "Wave: " + str(current_wave)
	day_label.text = "Day: " + str(current_day)
	ingredients_buttons = initialize_ingredients_panel()
	initialize_dishes_panel()
	heroes_buttons = initialize_delivery_panel()

# Moves the selection of buttons in the UI panels with the arrow keys
func _input(event) -> void:
	if current_panel_buttons.is_empty(): return
	if event.is_action_pressed("ui_left") and current_button_pointer > 0:
		current_button_pointer -= 1
		move_button_selection(current_button_pointer)
	elif event.is_action_pressed("ui_right") and current_button_pointer < len(current_panel_buttons)-1:
		current_button_pointer += 1
		move_button_selection(current_button_pointer)
	elif event.is_action_pressed("ui_accept"):
		current_panel_buttons[current_button_pointer].emit_signal("pressed")
	
# Called every second
func _on_timer_timeout() -> void:
	check_existing_orders()
	if (remaining_time > 0 or len(orders)) and lives > 0:
		game_loop()
		if remaining_time < 0:
			time_label.text = "Finsh your job!"
	else:
		game_over()

# Iterates over the existing orders and deletes those whose wait time are over
func check_existing_orders() -> void:
	for i in range(len(orders) - 1, -1, -1): # iterates backwards
		var order : Order = orders[i]
		order.current_time += 1
		# updates heroes' images according to the elapsed time (humour)
		if order.current_time / order.dish.time >= 2.0/3.0: # angry
			var hero_texture : TextureRect = orders_container.get_child(i).get_child(0)
			var new_hero_texture_path : String = heroes_dir_path + "%s.angry.png" % order.hero
			hero_texture.texture = load(new_hero_texture_path)
			hero_texture.tooltip_text = order.hero.capitalize() + " (angry)"
		elif order.current_time / order.dish.time >= 1.0/3.0: # normal
			var hero_texture : TextureRect = orders_container.get_child(i).get_child(0)
			var new_hero_texture_path : String = heroes_dir_path + "%s.normal.png" % order.hero
			hero_texture.texture = load(new_hero_texture_path)
			hero_texture.tooltip_text = order.hero.capitalize() + " (normal)"
		if order.current_time >= order.dish.time: # order wait time is over
			lives -= 1
			heart_bar.call_deferred("decrement_health")
			delete_order(order, i)

func set_day(day: int):
	current_day = day
	day_label.text = "Day: " + str(day)

func set_score(score: int):
	current_score = score
	score_label.text = "Score:" + str(score)
	
func set_lives(number: int):
	for i in range(lives - number):
		heart_bar.call_deferred("decrement_health")
	lives = number

# Game loop, handling updating the UI and coordinating/controlling the game
func game_loop():
	remaining_time -= 1
	time_label.text = "Time:" + str(remaining_time)
	score_label.text = "Score:" + str(current_score)
	if remaining_time % ORDERS_CREATION_INTERVAL == 0 and len(heroes) > 0 and MAX_REMAINING_TIME_TO_RECEIVE_ORDER <= remaining_time:
		create_order(get_hero(), get_dish())
	if should_increment_wave(): # move on to the next wave
		for dish in dishes:
			dish.time *= (1-DISH_TIME_REDUCTION_PERCENTAGE_PER_WAVE)
		current_wave += 1
		soundtrack.pitch_scale = soundtrack.pitch_scale + soundtrack.pitch_scale/(MAX_WAVES*2)
		wave_label.text = "Wave: " + str(current_wave)

# Handles terminating the game
func game_over() -> void:
	var gameover_scene = load(scenes_dir_path + "game_over.tscn").instantiate()
	gameover_scene.call_deferred("set_score", current_score)
	gameover_scene.call_deferred("set_day", current_day)
	gameover_scene.call_deferred("set_lives", lives)
	var message : String = ""
	var restart_message : String = ""
	if remaining_time <= 0 and lives > 0:
		message = "Good Job!"
		restart_message = "(Press SPACE to continue)"
		gameover_scene.call_deferred("game_over", false)
	else:
		message = "Game Over!"
		restart_message = "(Press SPACE to restart)"
	gameover_scene.call_deferred("set_message", message, restart_message)
	get_tree().root.add_child(gameover_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = gameover_scene

### CALLBACK FUNCTIONS FOR AREAS IN THE SCENARIO ENTERED
func _on_delivery_area_body_entered(body: Node2D) -> void:
	if body == player:
		if not orders.is_empty():
			orders_container.visible = false
			delivery_panel.visible = true
		current_button_pointer = 0
		current_panel_buttons = heroes_buttons
		move_button_selection(current_button_pointer)

func _on_delivery_area_body_exited(body: Node2D) -> void:
	if body == player:
		orders_container.visible = true
		delivery_panel.visible = false
		current_panel_buttons[current_button_pointer].add_theme_stylebox_override("normal", normal_style)
		

func _on_ingredients_area_body_entered(body: Node2D) -> void:
	if body == player:
		ingredients_panel.visible = true
		current_button_pointer = 0
		current_panel_buttons = ingredients_buttons
		move_button_selection(current_button_pointer)

func _on_ingredients_area_body_exited(body: Node2D) -> void:
	if body == player:
		ingredients_panel.visible = false
		current_panel_buttons[current_button_pointer].add_theme_stylebox_override("normal", normal_style)

func _on_preparation_area_body_entered(body: Node2D) -> void:
	if body == player:
		set_dishes_panel_buttons()
		dishes_panel.visible = true
		current_button_pointer = 0
		current_panel_buttons = dishes_buttons
		move_button_selection(current_button_pointer)

func _on_preparation_area_body_exited(body: Node2D) -> void:
	if body == player:
		dishes_panel.visible = false
		current_panel_buttons[current_button_pointer].add_theme_stylebox_override("normal", normal_style)

### CALLBACK FUNCTIONS FOR UI COMPONENTS ACTIONS (PRESSED, TOGGLED ETC.)
# Called when an ingredient button is pressed, receiving as parameter a reference to the button
func _on_ingredient_button_pressed(button : Button) -> void:
	var ingredient : String = button.tooltip_text
	var index : int = ingredients.find(ingredient)
	if index >= 0: # item is in the list, so remove it
		button.add_theme_stylebox_override("normal", normal_style)
		ingredients.remove_at(index)
	else: # item is not in the list, so add it
		button.add_theme_stylebox_override("normal", selected_style)
		ingredients.append(ingredient)

# Updates the buttons of the dishes panel according to the dishes that can be prepared with the currently ingredients being held
func set_dishes_panel_buttons() -> void:
	var buttons : Array[Button] = []
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
			button.add_theme_stylebox_override("normal", normal_style)
			buttons.append(button)
			dishes_buttons_container.add_child(button)
	dishes_buttons = buttons # reset the global reference to the dishes buttons
	dishes_panel.scale = Vector2(0.2,0.2)
	dishes_panel.visible = true

func _on_possible_dish_button_pressed(button: Button):
	ingredients.clear()
	reset_ingredients_buttons()
	player.call('pickup_dish', button.icon, button.tooltip_text)
	
func _on_hero_delivery_button_pressed(button : Button):
	# deliver current dish being held to the selected hero
	for i in range(len(orders)):
		var order = orders[i]
		if order.dish.name == player.current_dish and button.tooltip_text.to_lower() == order.hero: # correct answer
			player.deliver_dish()
			current_score += order.dish.time - order.current_time
			delete_order(order, i)
			return
	# if we get to this part of the code, the wrong hero has been clicked (player loses 10% of its current points)
	if current_score > 0:
		current_score -= current_score*0.1
	
### FUNCIONS FOR MANAGING & INITIALIZING UI COMPONENTS
func initialize_button_styles() -> void:
	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(1, 1, 1, 0.5)
	normal_style.set_corner_radius_all(5)
	normal_style.border_color = Color(0, 0, 0)
	normal_style.set_border_width_all(3)
	normal_style.set_content_margin_all(5)
	selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(1, 1, 1, 0.5)
	selected_style.set_corner_radius_all(5)
	selected_style.border_color = Color(1, 1, 1)
	selected_style.set_border_width_all(3)
	selected_style.set_content_margin_all(5)

func initialize_ingredients_panel() -> Array[Button]:
	var buttons: Array[Button] = []
	ingredients_panel = Panel.new()
	ingredients_panel.visible = false
	ingredients_panel.name = "IngredientsPanel"
	ingredients_panel.position = Vector2(PANELS_X_COORDINATE, PANELS_Y_COORDINATE)
	var ingredients_vbox : VBoxContainer = VBoxContainer.new()
	var ingredients_container : GridContainer = GridContainer.new()
	ingredients_container.columns = 7
	ingredients_container.scale = Vector2(1.25, 1.25)
	var ing_dir : DirAccess = DirAccess.open(ingredients_dir_path)
	if ing_dir:
		ing_dir.list_dir_begin()
		var file_name : String = ing_dir.get_next()
		while file_name != "":
			if not ing_dir.current_is_dir() and file_name.ends_with(".png"):
				var button : Button = Button.new()
				button.tooltip_text = file_name.split(".")[0]
				button.name = button.tooltip_text + "IngredientCheckBox"
				button.tooltip_text = button.tooltip_text.replace("-", " ")
				button.icon = load(ingredients_dir_path + file_name)
				button.pressed.connect(func(): _on_ingredient_button_pressed(button))
				button.add_theme_stylebox_override("normal", normal_style)
				buttons.append(button)
				ingredients_container.add_child(button)
			file_name = ing_dir.get_next()
	ingredients_buttons_container = ingredients_container
	ingredients_vbox.add_child(ingredients_container)
	ingredients_panel.add_child(ingredients_vbox)
	$UserInterface.add_child(ingredients_panel)
	return buttons

func initialize_dishes_panel() -> void:
	dishes_panel = Panel.new()
	dishes_panel.visible = false
	dishes_panel.name = "DishesPanel"
	dishes_panel.position = Vector2(PANELS_X_COORDINATE, PANELS_Y_COORDINATE)
	dishes_panel.scale = Vector2(0.2, 0.2)
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

func initialize_delivery_panel() -> Array[Button]:
	var buttons : Array[Button] = []
	delivery_panel = Panel.new()
	delivery_panel.visible = false
	delivery_panel.name = "DeliveryPanel"
	delivery_panel.position = Vector2(PANELS_X_COORDINATE, PANELS_Y_COORDINATE)
	var heroes_container: GridContainer = GridContainer.new()
	heroes_container.scale = Vector2(0.05, 0.05)
	heroes_container.columns = 4
	for hero in heroes_in_use+heroes:
		var hero_button : Button = Button.new()
		hero_button.icon = load(heroes_dir_path + hero + ".normal.png")
		hero_button.tooltip_text = hero.capitalize()
		hero_button.pressed.connect(func(): _on_hero_delivery_button_pressed(hero_button))
		hero_button.add_theme_stylebox_override("normal", normal_style)
		buttons.append(hero_button)
		heroes_container.add_child(hero_button)
	delivery_panel.add_child(heroes_container)
	$UserInterface.add_child(delivery_panel)
	return buttons

# Moves the focus to another UI button
func move_button_selection(button_pointer: int) -> void:
	var button : Button = current_panel_buttons[current_button_pointer]
	var stylebox = duplicate_stylebox(button.get_theme_stylebox("normal", "Button"))
	stylebox.bg_color = Color(0.1, 0.4, 1, 0.5)
	button.add_theme_stylebox_override("normal", stylebox)
	if button_pointer < len(current_panel_buttons)-1:
		var next_button : Button = current_panel_buttons[current_button_pointer+1]
		var next_stylebox = duplicate_stylebox(next_button.get_theme_stylebox("normal", "Button"))
		next_stylebox.bg_color = Color(1, 1, 1, 0.5)
		next_button.add_theme_stylebox_override("normal", next_stylebox)
	if button_pointer > 0:
		var previous_button : Button = current_panel_buttons[current_button_pointer-1]
		var prev_stylebox = duplicate_stylebox(previous_button.get_theme_stylebox("normal", "Button"))
		prev_stylebox.bg_color = Color(1, 1, 1, 0.5)
		previous_button.add_theme_stylebox_override("normal", prev_stylebox)

# Given a hero and a dish, creates an order, adding it to the screen and to the internal lists of the system to be tracked
func create_order(hero: String, dish: Dish) -> void:
	orders.append(Order.new(hero, dish))
	var hero_texture_path : String = heroes_dir_path + "%s.happy.png" % hero
	var food_texture_path : String = dishes_dir_path + "%s.png" % dish.name
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
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(hero_icon.size.x + food_icon.size.x, max(hero_icon.size.y, food_icon.size.y))
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", normal_style)
	panel.add_child(hero_icon)
	panel.add_child(food_icon)
	orders_container.add_child(panel)

# Deletes a given order, removing it from the screen and from the internal lists of the system
func delete_order(order : Order, index: int) -> void:
	var hero : String = order.hero
	heroes.append(hero)
	heroes_in_use.remove_at(index)
	orders.remove_at(index)
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

# Generates a random hero to be added to an order, returning their name (the generated hero is different from the last generated hero)
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
	
# Generates a random dish to be added to an order
func get_dish() -> Dish:
	var pos : int = rng.randi_range(0, len(dishes)-1)
	var dish : Dish = dishes[pos]
	return dish

func should_increment_wave() -> bool:
	if current_wave >= MAX_WAVES: return false
	var wave_duration : int = TOTAL_GAME_DURATION_SECONDS / MAX_WAVES
	var current_wave_end = wave_duration*current_wave
	return current_wave_end < (TOTAL_GAME_DURATION_SECONDS-remaining_time)

func reset_ingredients_buttons() -> void:
	for button in ingredients_buttons_container.get_children():
		button.add_theme_stylebox_override("normal", normal_style)

func duplicate_stylebox(stylebox : StyleBoxFlat) -> StyleBoxFlat:
	var new_stylebox = StyleBoxFlat.new()
	new_stylebox.bg_color = stylebox.bg_color
	new_stylebox.set_corner_radius_all(stylebox.corner_radius_bottom_left)
	new_stylebox.border_color = stylebox.border_color
	new_stylebox.set_border_width_all(stylebox.border_width_left)
	new_stylebox.set_content_margin_all(stylebox.content_margin_left)
	return new_stylebox
