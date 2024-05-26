extends Control

@onready var punctuation_label = $ColorRect/CenterContainer/VBoxContainer/PunctutationLabel

func set_score(score: int) -> void:
	punctuation_label.text = "Points:  " + str(score)
