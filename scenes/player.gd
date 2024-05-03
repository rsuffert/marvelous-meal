extends CharacterBody2D

@export var speed = 150.0
@onready var sprite = $AnimatedSprite2D
	
func get_8way_input():
	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed
	
func animate():
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
	
func move_8way(delta):
	get_8way_input()
	animate()
	move_and_slide()
	
func _physics_process(delta):
	move_8way(delta)
