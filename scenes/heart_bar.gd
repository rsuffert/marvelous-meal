extends HBoxContainer

@export var heart_texture_path : String = "res://assets/icons/hp-heart.png"
@export var initial_health : int = 3

func _ready() -> void:
	var heart_texture = load(heart_texture_path)
	scale = Vector2(0.25, 0.25)
	for i in range(initial_health):
		var heart = TextureRect.new()
		heart.texture = heart_texture
		add_child(heart)

func decrement_health() -> void:
	if get_child_count() <= 0: return
	get_child(get_child_count()-1).free()
