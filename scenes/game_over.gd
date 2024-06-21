extends Control

@onready var punctuation_label = $ColorRect/CenterContainer/VBoxContainer/PunctutationLabel
@onready var message_label = $ColorRect/CenterContainer/VBoxContainer/MessageLabel
@onready var restart_instruction_label = $ColorRect/CenterContainer/VBoxContainer/RestartInstructionLabel
@export var game_scene_path : String = "res://scenes/game.tscn"

func _process(delta : float) -> void:
	if Input.is_action_just_released("ui_accept"):
		var main_scene = load(game_scene_path).instantiate()
		get_tree().root.add_child(main_scene)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = main_scene

func set_score(score: int) -> void:
	punctuation_label.text = "Points:  " + str(score)

func set_message(message: String, restart_instruction_text: String) -> void:
	message_label.text = message
	restart_instruction_label.text = restart_instruction_text
	
