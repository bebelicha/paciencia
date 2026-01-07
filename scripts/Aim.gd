extends CharacterBody2D

signal done(obj)

@onready var bar = $Bar

var target = null
var t = 0.0
var limit = 0.4

func _physics_process(delta):
	global_position = get_global_mouse_position()
	
	var bestUI = null
	var uiNodes = get_tree().get_nodes_in_group("ui")
	
	for node in uiNodes:
		if node is Control and node.is_visible_in_tree():
			if node.get_global_rect().has_point(global_position):
				bestUI = node
				break
	
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collide_with_bodies = true
	query.collide_with_areas = true 
	
	var results = space.intersect_point(query)
	
	var bestCard = null
	var bestSlot = null
	var highestZ = -9999
	
	for result in results:
		var obj = result.collider
		if obj.is_in_group("deck"):
			if obj.z_index > highestZ:
				highestZ = obj.z_index
				bestCard = obj
		elif obj.is_in_group("slot"):
			if bestSlot == null:
				bestSlot = obj
	
	var finalTarget = null
	
	if bestUI != null:
		finalTarget = bestUI
	elif bestCard != null:
		finalTarget = bestCard
	elif bestSlot != null:
		if bestCard == null:
			finalTarget = bestSlot
			
	if finalTarget != null:
		if target != finalTarget:
			target = finalTarget
			t = 0.0
			bar.visible = true
		
		t += delta
		bar.value = (t / limit) * 100
		
		if t >= limit:
			t = 0.0
			emit_signal("done", target)
			bar.value = 0
			bar.visible = false
	else:
		reset()

func reset():
	target = null
	t = 0.0
	bar.visible = false
	bar.value = 0
