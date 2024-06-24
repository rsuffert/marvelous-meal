extends Control

@onready var punctuation_label = $ColorRect/CenterContainer/VBoxContainer/PunctutationLabel
@onready var message_label = $ColorRect/CenterContainer/VBoxContainer/MessageLabel
@onready var restart_instruction_label = $ColorRect/CenterContainer/VBoxContainer/RestartInstructionLabel
@export var game_scene_path : String = "res://scenes/game.tscn"
var day = 1
var score = 0
var is_game_over = true
var lives = 3

func _process(delta : float) -> void:
	if Input.is_action_just_released("ui_accept"):
		var main_scene = load(game_scene_path).instantiate()
		if !is_game_over:
			main_scene.call_deferred("set_score", score)
			main_scene.call_deferred("set_day", day)
			main_scene.call_deferred("set_lives", lives)
		get_tree().root.add_child(main_scene)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = main_scene

func set_score(new_score: int) -> void:
	score = new_score
	punctuation_label.text = "Points:  " + str(new_score)
	
func game_over(boolean: bool):
	is_game_over = boolean

func set_day(new_day: int):
	day = new_day + 1
	
func set_lives(number: int):
	lives = number

func set_message(message: String, restart_instruction_text: String) -> void:
	message_label.text = message
	restart_instruction_label.text = restart_instruction_text
	
