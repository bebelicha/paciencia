extends Node2D

var deck = []
var hand = null
var handStack = []
var handOrigin = null
var stock = null
var waste = null
var tableau = []
var foundation = []

var score = 0
var moves = 0
var time = 0.0
var history = []
var gameActive = false
var victory_elapsed = -1.0

@onready var lblScore = $HUD/ScoreLabel
@onready var lblTime = $HUD/TimeLabel
@onready var lblMoves = $HUD/MovesLabel

@onready var victoryScreen = $VictoryScreen
@onready var lblFinalScore = $VictoryScreen/FinalScoreLabel
@onready var lblFinalTime = $VictoryScreen/FinalTimeLabel
@onready var lblFinalMoves = $VictoryScreen/FinalMovesLabel
@onready var win_reset_timer = $VictoryScreen/WinResetTimer

var gaze_bridge: Node
var last_mouse_pos = Vector2.ZERO
var using_head_input = false

func _ready():
	gaze_bridge = preload("res://scripts/ConversiaGazeBridge.gd").new()
	add_child(gaze_bridge)
	win_reset_timer.timeout.connect(newGame)
	
	var viewport_size = get_viewport_rect().size
	last_mouse_pos = viewport_size / 2
	$Aim.global_position = last_mouse_pos
	
	organizeSlots()
	$Aim.done.connect(onAimDone)
	createDeck()
	newGame()

func organizeSlots():
	var all = get_tree().get_nodes_in_group("slot")
	all.sort_custom(func(a, b): return a.position.x < b.position.x)
	for s in all:
		if s.type == 0: stock = s
		elif s.type == 1: waste = s
		elif s.type == 2: foundation.append(s)
		elif s.type == 3: tableau.append(s)

func createDeck():
	deck.clear()
	for s in range(1, 5):
		for r in range(1, 14):
			deck.append({"rank": r, "suit": s})

func newGame():
	if not win_reset_timer.is_stopped():
		win_reset_timer.stop()
	victory_elapsed = -1.0
	score = 0
	moves = 0
	time = 0.0
	history.clear()
	if handStack.size() > 0:
		for c in handStack:
			c.queue_free()
	hand = null
	handStack.clear()
	$Aim.holding_card = false
	gameActive = true
	victoryScreen.visible = false
	updateUI()
	
	for s in tableau:
		for c in s.cards: c.queue_free()
		s.cards.clear()
		s.face_down_cards.clear()
	for s in foundation:
		for c in s.cards: c.queue_free()
		s.cards.clear()
		s.face_down_cards.clear()
	if stock != null:
		for c in stock.cards: c.queue_free()
		stock.cards.clear()
		stock.face_down_cards.clear()
	if waste != null:
		for c in waste.cards: c.queue_free()
		waste.cards.clear()
		waste.face_down_cards.clear()
	
	createDeck()
	deck.shuffle()
	
	for i in range(tableau.size()):
		var slot = tableau[i]
		slot.face_down_cards.clear()
		for j in range(i + 1):
			if deck.size() > 0:
				var data = deck.pop_back()
				if j == i:
					var card = spawn(data, slot)
					card.flip()
				else:
					slot.face_down_cards.append(data)
		updateVisuals(slot)
	
	while deck.size() > 0:
		spawn(deck.pop_back(), stock)

func spawn(data, slot):
	var scene = preload("res://scenes/Card.tscn")
	var card = scene.instantiate()
	card.setup(data.rank, data.suit)
	add_child(card)
	slot.cards.append(card)
	card.slotParent = slot
	updateVisuals(slot)
	return card

func updateVisuals(slot):
	if slot.type == 3:
		slot.update_hidden_label()
	for i in range(slot.cards.size()):
		var c = slot.cards[i]
		c.z_index = 10 + i 
		if slot.type == 3:
			c.position = slot.position + Vector2(0, 40 * i)
		else:
			c.position = slot.position

func reveal_from_hidden(slot):
	if slot.face_down_cards.size() == 0:
		return null
	var data = slot.face_down_cards.pop_back()
	var card = spawn(data, slot)
	card.flip()
	return card

func _input(event):
	if not gaze_bridge.is_ready or not gaze_bridge.is_head_tracking_active():
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			last_mouse_pos = event.position
			using_head_input = false
		elif event is InputEventScreenTouch and event.pressed:
			last_mouse_pos = event.position
			using_head_input = false

func _process(delta):
	var viewport_size = get_viewport_rect().size
	var yaw = gaze_bridge.gaze_data.get('headYaw', 0.5)
	var pitch = gaze_bridge.gaze_data.get('headPitch', 0.5)
	var roll = gaze_bridge.gaze_data.get('headRoll', 0.5)
	var aim_source = "mouse"
	var applied_pos = last_mouse_pos

	if gaze_bridge.is_ready and gaze_bridge.is_head_tracking_active():
		var clamped_yaw = clamp(yaw, 0.0, 1.0)
		var clamped_pitch = clamp(pitch, 0.0, 1.0)
		$Aim.global_position = Vector2(
			clamped_yaw * viewport_size.x,
			clamped_pitch * viewport_size.y
		)
		applied_pos = $Aim.global_position
		using_head_input = true
		aim_source = "head"
	elif last_mouse_pos != Vector2.ZERO:
		$Aim.global_position = last_mouse_pos
		applied_pos = last_mouse_pos
		using_head_input = false
		aim_source = "mouse"
	
	if hand != null:
		var pos = $Aim.global_position + Vector2(0, 15)
		for i in range(handStack.size()):
			handStack[i].global_position = pos + Vector2(0, 40 * i)
			handStack[i].z_index = 200 + i
	
	if gameActive:
		time += delta
		var minutes = int(time / 60)
		var seconds = int(time) % 60
		lblTime.text = "Time: %02d:%02d" % [minutes, seconds]
	elif victory_elapsed >= 0.0:
		victory_elapsed += delta
		if victory_elapsed >= 10.0:
			newGame()

func updateUI():
	lblScore.text = "Score: " + str(score)
	lblMoves.text = "Moves: " + str(moves)

func checkWin():
	var total = 0
	for f in foundation:
		total += f.cards.size()
	
	if total == 52:
		gameActive = false
		
		var minutes = int(time / 60)
		var seconds = int(time) % 60
		lblFinalScore.text = "Score: " + str(score)
		lblFinalTime.text = "Time: %02d:%02d" % [minutes, seconds]
		lblFinalMoves.text = "Moves: " + str(moves)
		
		gaze_bridge.send_stats(score, "1")
		
		victoryScreen.visible = true
		win_reset_timer.start(10)
		victory_elapsed = 0.0

func onAimDone(obj):
	if obj.is_in_group("ui"):
		if obj.name == "btnUndo":
			onUndo()
		elif obj.name == "btnNew":
			newGame()
		return

	if not gameActive: return

	if hand == null:
		var isStock = false
		if obj == stock: isStock = true
		if obj.is_in_group("deck") and obj.slotParent.type == 0: isStock = true
		
		if isStock:
			drawCard()
			return
		
		if obj.is_in_group("deck"):
			if obj.isFaceUp:
				pickCard(obj)
			else:
				if obj == obj.slotParent.getTopCard():
					obj.flip()
					score += 5
					updateUI()
	else:
		var target = null
		if obj.is_in_group("slot"): 
			target = obj
		elif obj.is_in_group("deck"): 
			target = obj.slotParent
		
		if target != null:
			dropCard(target)
		else:
			cancel()

func drawCard():
	if stock.cards.size() > 0:
		var card = stock.cards.pop_back()
		waste.cards.append(card)
		card.slotParent = waste
		card.flip()
		updateVisuals(stock)
		updateVisuals(waste)
		
		history.append({
			"type": "draw",
			"cards": [card],
			"src": stock,
			"dst": waste,
			"score": 0
		})
		moves += 1
		updateUI()
	else:
		if waste.cards.size() > 0:
			var list = waste.cards.duplicate()
			waste.cards.clear()
			list.reverse()
			for c in list:
				c.flip()
				c.slotParent = stock
				stock.cards.append(c)
			updateVisuals(waste)
			updateVisuals(stock)
			
			history.append({
				"type": "recycle",
				"cards": list,
				"src": waste,
				"dst": stock,
				"score": -100
			})
			if score >= 100: score -= 100
			else: score = 0
			moves += 1
			updateUI()

func pickCard(card):
	var slot = card.slotParent
	var index = slot.cards.find(card)
	if index != -1:
		hand = card
		handOrigin = slot
		handStack = slot.cards.slice(index)
		slot.cards.resize(index)
		$Aim.holding_card = true
		updateVisuals(slot)

func dropCard(target):
	if check(hand, target):
		var points = 0
		if handOrigin.type == 1 and target.type == 3: points = 5
		elif handOrigin.type == 1 and target.type == 2: points = 10
		elif handOrigin.type == 3 and target.type == 2: points = 10
		elif handOrigin.type == 2 and target.type == 3: points = -15
		
		score += points
		if score < 0: score = 0
		moves += 1
		var revealed = null
		var revealed_from_hidden = false
		var revealed_data = null
		if handOrigin.type == 3 and handOrigin.cards.size() == 0 and handOrigin.face_down_cards.size() > 0:
			revealed = reveal_from_hidden(handOrigin)
			revealed_from_hidden = true
			revealed_data = {"rank": revealed.rank, "suit": revealed.suit}
			score += 5
			points += 5
		
		updateVisuals(handOrigin)
		for c in handStack:
			target.cards.append(c)
			c.slotParent = target
		updateVisuals(target)
		
		history.append({
			"type": "move",
			"cards": handStack.duplicate(),
			"src": handOrigin,
			"dst": target,
			"revealed": revealed,
			"revealed_from_hidden": revealed_from_hidden,
			"revealed_data": revealed_data,
			"score": points
		})
		
		hand = null
		handStack.clear()
		$Aim.holding_card = false
		updateUI()
		checkWin()
	else:
		cancel()

func cancel():
	for c in handStack:
		handOrigin.cards.append(c)
	updateVisuals(handOrigin)
	hand = null
	$Aim.holding_card = false
	handStack.clear()

func onUndo():
	if history.size() == 0: return
	
	var act = history.pop_back()
	score -= act.score
	if score < 0: score = 0
	moves -= 1
	updateUI()
	
	if act.type == "move":
		for c in act.cards:
			act.dst.cards.erase(c)
			act.src.cards.append(c)
			c.slotParent = act.src
		if act.revealed_from_hidden and act.revealed != null:
			act.src.cards.erase(act.revealed)
			act.revealed.queue_free()
			if act.revealed_data != null:
				act.src.face_down_cards.append(act.revealed_data)
		elif act.revealed != null:
			act.revealed.flip()
			
		updateVisuals(act.src)
		updateVisuals(act.dst)
		
	elif act.type == "draw":
		var c = act.cards[0]
		act.dst.cards.erase(c)
		act.src.cards.append(c)
		c.slotParent = act.src
		c.flip()
		updateVisuals(act.src)
		updateVisuals(act.dst)
		
	elif act.type == "recycle":
		for c in act.cards:
			act.dst.cards.erase(c)
		
		var rev = act.cards.duplicate()
		rev.reverse()
		for c in rev:
			c.flip()
			c.slotParent = act.src
			act.src.cards.append(c)
			
		updateVisuals(act.src)
		updateVisuals(act.dst)

func check(card, slot):
	var top = slot.getTopCard()
	if slot.type == 3:
		if top == null: return card.rank == 13
		else:
			return (card.isRed() != top.isRed()) and (card.rank == top.rank - 1)
	elif slot.type == 2:
		if top == null: return card.rank == 1
		else:
			return (card.suit == top.suit) and (card.rank == top.rank + 1)
	return false
