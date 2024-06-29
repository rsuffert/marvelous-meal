extends Label

var blink_thread : Thread = Thread.new()
@export var blink_cycle_duration_seconds : float = 1
@export var blink_cycle_count : int = 6

func blink() -> void:
	if not blink_thread.is_alive():
		blink_thread.start(_blink)
		
func _blink() -> void:
	print("Blinking")
	for i in range(blink_cycle_count):
		var blinking : bool = (i % 2 == 0)
		if blinking:
			call_deferred("update_color", Color(1, 0, 0)) # Red
		else:
			call_deferred("update_color", Color(1, 1, 1)) # White
		OS.delay_msec(int(blink_cycle_duration_seconds * 1000))
	call_deferred("update_color", Color(1, 1, 1)) # Ensure color switches back to white after blinking

func update_color(color: Color) -> void:
	self.add_theme_color_override("font_color", color)
