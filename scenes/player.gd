extends CharacterBody2D

@export var speed = 150.0
@onready var sprite = $AnimatedSprite2D
@onready var texture_react_banner = $Control/TextureRect
	
func get_8way_input():
	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed
	
func display_image_in_banner(image: Texture2D):
	texture_react_banner.size = Vector2(16,16)
	texture_react_banner.texture = image
	texture_react_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_react_banner.stretch_mode = TextureRect.STRETCH_SCALE
	
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
