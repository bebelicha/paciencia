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
var victoryElapsed = -1.0

@onready var lblScore = $HUD/ScoreLabel
@onready var lblTime = $HUD/TimeLabel
@onready var lblMoves = $HUD/MovesLabel

@onready var victoryScreen = $VictoryScreen
@onready var lblFinalScore = $VictoryScreen/FinalScoreLabel
@onready var lblFinalTime = $VictoryScreen/FinalTimeLabel
@onready var lblFinalMoves = $VictoryScreen/FinalMovesLabel
@onready var winResetTimer = $VictoryScreen/WinResetTimer

var gazeBridge: Node
var lastMousePos = Vector2.ZERO
var usingHeadInput = false

func _ready():
	gazeBridge = preload("res://scripts/ConversiaGazeBridge.gd").new()
	add_child(gazeBridge)
	winResetTimer.timeout.connect(newGame)

	var viewportSize = get_viewport_rect().size
	lastMousePos = viewportSize / 2
	$Aim.global_position = lastMousePos
	
	organizeSlots()
	$Aim.done.connect(onAimDone)
	createDeck()
	newGame()

func organizeSlots():
	var all = get_tree().get_nodes_in_group("slot")
	all.sort_custom(func(a, b): return a.position.x < b.position.x)
	for s in all:
		if s.type == 0:
			stock = s
		elif s.type == 1:
			waste = s
		elif s.type == 2:
			foundation.append(s)
		elif s.type == 3:
			tableau.append(s)

func createDeck():
	deck.clear()
	for s in range(1, 5):
		for r in range(1, 14):
			deck.append({"rank": r, "suit": s})

func newGame():
	if not winResetTimer.is_stopped():
		winResetTimer.stop()
	victoryElapsed = -1.0
	score = 0
	moves = 0
	time = 0.0
	history.clear()
	if handStack.size() > 0:
		for c in handStack:
			c.queue_free()
	hand = null
	handStack.clear()
	$Aim.holdingCard = false
	gameActive = true
	victoryScreen.visible = false
	updateUI()
	
	for s in tableau:
		for c in s.cards: c.queue_free()
		s.cards.clear()
		s.faceDownCards.clear()
	for s in foundation:
		for c in s.cards: c.queue_free()
		s.cards.clear()
		s.faceDownCards.clear()
	if stock != null:
		for c in stock.cards: c.queue_free()
		stock.cards.clear()
		stock.faceDownCards.clear()
	if waste != null:
		for c in waste.cards: c.queue_free()
		waste.cards.clear()
		waste.faceDownCards.clear()
	
	createDeck()
	deck.shuffle()
	
	for i in range(tableau.size()):
		var slot = tableau[i]
		slot.faceDownCards.clear()
		for j in range(i + 1):
			if deck.size() > 0:
				var data = deck.pop_back()
				if j == i:
					var card = spawn(data, slot)
					card.flip()
				else:
					slot.faceDownCards.append(data)
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
		slot.updateHiddenLabel()
	for i in range(slot.cards.size()):
		var c = slot.cards[i]
		c.z_index = 10 + i 
		if slot.type == 3:
			c.position = slot.position + Vector2(0, 40 * i)
		else:
			c.position = slot.position

func revealFromHidden(slot):
	if slot.faceDownCards.size() == 0:
		return null
	var data = slot.faceDownCards.pop_back()
	var card = spawn(data, slot)
	card.flip()
	return card

func _input(event):
	if not gazeBridge.isReady or not gazeBridge.isHeadTrackingActive():
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			lastMousePos = event.position
			usingHeadInput = false
		elif event is InputEventScreenTouch and event.pressed:
			lastMousePos = event.position
			usingHeadInput = false

func _process(delta):
	var viewportSize = get_viewport_rect().size
	var yaw = gazeBridge.gazeData.get('headYaw', 0.5)
	var pitch = gazeBridge.gazeData.get('headPitch', 0.5)

	if gazeBridge.isReady and gazeBridge.isHeadTrackingActive():
		var clampedYaw = clamp(yaw, 0.0, 1.0)
		var clampedPitch = clamp(pitch, 0.0, 1.0)
		$Aim.global_position = Vector2(
			clampedYaw * viewportSize.x,
			clampedPitch * viewportSize.y
		)
		usingHeadInput = true
	elif lastMousePos != Vector2.ZERO:
		$Aim.global_position = lastMousePos
		usingHeadInput = false
	
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
	elif victoryElapsed >= 0.0:
		victoryElapsed += delta
		if victoryElapsed >= 10.0:
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
		
		gazeBridge.sendStats(score, "1")
		
		victoryScreen.visible = true
		winResetTimer.start(10)
		victoryElapsed = 0.0

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
		$Aim.holdingCard = true
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
		var revealedFromHidden = false
		var revealedData = null
		if handOrigin.type == 3 and handOrigin.cards.size() == 0 and handOrigin.faceDownCards.size() > 0:
			revealed = revealFromHidden(handOrigin)
			revealedFromHidden = true
			revealedData = {"rank": revealed.rank, "suit": revealed.suit}
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
			"revealedFromHidden": revealedFromHidden,
			"revealedData": revealedData,
			"score": points
		})
		
		hand = null
		handStack.clear()
		$Aim.holdingCard = false
		updateUI()
		checkWin()
	else:
		cancel()

func cancel():
	for c in handStack:
		handOrigin.cards.append(c)
	updateVisuals(handOrigin)
	hand = null
	$Aim.holdingCard = false
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
		if act.revealedFromHidden and act.revealed != null:
			act.src.cards.erase(act.revealed)
			act.revealed.queue_free()
			if act.revealedData != null:
				act.src.faceDownCards.append(act.revealedData)
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
