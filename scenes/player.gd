extends CharacterBody2D

@export var speed = 150.0
@onready var sprite = $AnimatedSprite2D
@onready var dish_icon = $Control/DishIcon
var current_dish = null
	
func get_8way_input() -> void:
	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed
	
func pickup_dish(image : Texture2D, dish_name : String) -> void:
	current_dish = dish_name
	dish_icon.texture = image
	
func animate() -> void:
	if velocity.x > 0:		
		sprite.play("right")
	elif velocity.x < 0:
		sprite.play("left")
	elif velocity.y > 0:
		sprite.play("down")
	elif velocity.y < 0:
		sprite.play("up")
	else:
		sprite.stop()
	
func move_8way(delta) ->void:
	get_8way_input()
	animate()
	move_and_slide()
	
func _physics_process(delta) -> void:
	move_8way(delta)
