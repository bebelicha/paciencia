extends CharacterBody2D
signal done(obj)
@onready var bar = $Bar  
var target = null  
var t = 0.0        
var limit = 1.0    
func _physics_process(delta):
	global_position = get_global_mouse_position()
	var hit = move_and_collide(Vector2.ZERO, true, true)
	if hit:
		var obj = hit.get_collider() 
		if obj.is_in_group("deck"):
			checkTarget(obj, delta)
		else:
			reset()
	else:
		reset()
func checkTarget(obj, delta):
	if target != obj:
		target = obj
		t = 0.0
		bar.visible = true
	else:
		t = t + delta 
		bar.value = (t / limit) * 100
		if t >= limit:
			emit_signal("done", target) 
			reset() 
func reset():
	target = null
	t = 0.0
	bar.visible = false
	bar.value = 0
