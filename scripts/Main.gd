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

@onready var lblScore = $HUD/ScoreLabel
@onready var lblTime = $HUD/TimeLabel
@onready var lblMoves = $HUD/MovesLabel

@onready var victoryScreen = $VictoryScreen
@onready var lblFinalScore = $VictoryScreen/FinalScoreLabel
@onready var lblFinalTime = $VictoryScreen/FinalTimeLabel
@onready var lblFinalMoves = $VictoryScreen/FinalMovesLabel

func _ready():
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
	score = 0
	moves = 0
	time = 0.0
	history.clear()
	gameActive = true
	victoryScreen.visible = false
	updateUI()
	
	for s in tableau:
		for c in s.cards: c.queue_free()
		s.cards.clear()
	for s in foundation:
		for c in s.cards: c.queue_free()
		s.cards.clear()
	if stock != null:
		for c in stock.cards: c.queue_free()
		stock.cards.clear()
	if waste != null:
		for c in waste.cards: c.queue_free()
		waste.cards.clear()
	
	createDeck()
	deck.shuffle()
	
	for i in range(tableau.size()):
		var slot = tableau[i]
		for j in range(i + 1):
			if deck.size() > 0:
				var data = deck.pop_back()
				var card = spawn(data, slot)
				if j == i: card.flip()
	
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
	var off = 0
	for i in range(slot.cards.size()):
		var c = slot.cards[i]
		c.z_index = 10 + i 
		c.position = slot.position + Vector2(0, off)
		if slot.type == 3:
			if c.isFaceUp: off += 40
			else: off += 20
		else: off = 0

func _process(delta):
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
		
		victoryScreen.visible = true

func onAimDone(obj):
	if obj.is_in_group("ui"):
		if obj.name == "btnUndo":
			onUndo()
		elif obj.name == "btnNew" or obj.name == "btnVictoryNew":
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
		if obj.is_in_group("slot"): target = obj
		elif obj.is_in_group("deck"): target = obj.slotParent
		
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
		var top = handOrigin.getTopCard()
		if top != null and not top.isFaceUp:
			top.flip()
			revealed = top
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
			"score": points
		})
		
		hand = null
		handStack.clear()
		updateUI()
		checkWin()
	else:
		cancel()

func cancel():
	for c in handStack:
		handOrigin.cards.append(c)
	updateVisuals(handOrigin)
	hand = null
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
		
		if act.revealed != null:
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
