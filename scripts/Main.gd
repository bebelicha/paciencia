extends Node2D
var deck=[]
var hand=null
var handStack=[]
var handOrigin=null
var stock=null
var waste=null
var table=[]
var foundation=[]
var score=0
var moves=0
var time=0.0
var history=[]
var gameActive=false
var victoryElapsed=-1.0
@onready var lblScore=$HUD/ScoreLabel
@onready var lblTime=$HUD/TimeLabel
@onready var lblMoves=$HUD/MovesLabel
@onready var victoryScreen=$VictoryScreen
@onready var lblFinalScore=$VictoryScreen/FinalScoreLabel
@onready var lblFinalTime=$VictoryScreen/FinalTimeLabel
@onready var lblFinalMoves=$VictoryScreen/FinalMovesLabel
@onready var winResetTimer=$VictoryScreen/WinResetTimer
var gazeBridge:Node
var lastMousePos=Vector2.ZERO
var usingHeadInput=false
var integrityTimer:=0.0
const enableIntegrityCheck:=true
var cardService
var scanService
var moveService
var uiService
@onready var confirmDialog:Control=$ConfirmNew
@onready var confirmYes:Control=$ConfirmNew/Yes
@onready var confirmNo:Control=$ConfirmNew/No
@onready var confirmBackDialog:Control=$ConfirmBack
@onready var confirmBackYes:Control=$ConfirmBack/Yes
@onready var confirmBackNo:Control=$ConfirmBack/No
@onready var aim:Node=get_node_or_null("Aim")
func _ready():
	gazeBridge=preload("res://scripts/ConversiaGazeBridge.gd").new()
	add_child(gazeBridge)
	cardService=preload("res://scripts/CardService.gd").new()
	add_child(cardService)
	cardService.setup(self)
	scanService=preload("res://scripts/ScanService.gd").new()
	add_child(scanService)
	scanService.setup(self)
	moveService=preload("res://scripts/MoveService.gd").new()
	add_child(moveService)
	moveService.setup(self)
	uiService=preload("res://scripts/UiService.gd").new()
	add_child(uiService)
	uiService.setup(self)
	winResetTimer.timeout.connect(newGame)
	var viewportSize=get_viewport_rect().size
	lastMousePos=viewportSize/2
	if aim!=null:
		aim.global_position=lastMousePos
	organizeSlots()
	if aim!=null:
		aim.done.connect(onAimDone)
	createDeck()
	newGame()
func organizeSlots():
	var all=get_tree().get_nodes_in_group("slot")
	all.sort_custom(func(a,b): return a.position.x<b.position.x)
	for s in all:
		if s.type==0:
			stock=s
		elif s.type==1:
			waste=s
		elif s.type==2:
			foundation.append(s)
		elif s.type==3:
			table.append(s)
func createDeck():
	deck.clear()
	for s in range(1,5):
		for r in range(1,14):
			deck.append({"rank":r,"suit":s})
func newGame():
	for node in get_tree().get_nodes_in_group("deck"):
		if node is StaticBody2D:
			node.queue_free()
	if not winResetTimer.is_stopped():
		winResetTimer.stop()
	victoryElapsed=-1.0
	score=0
	moves=0
	time=0.0
	history.clear()
	if handStack.size()>0:
		for c in handStack:
			c.queue_free()
	hand=null
	handStack.clear()
	if aim!=null:
		aim.holdingCard=false
	gameActive=true
	victoryScreen.visible=false
	uiService.updateUi()
	for s in table:
		for c in s.cards:
			c.queue_free()
		s.cards.clear()
		s.faceDownCards.clear()
	for s in foundation:
		for c in s.cards:
			c.queue_free()
		s.cards.clear()
		s.faceDownCards.clear()
	if stock!=null:
		for c in stock.cards:
			c.queue_free()
		stock.cards.clear()
		stock.faceDownCards.clear()
	if waste!=null:
		for c in waste.cards:
			c.queue_free()
		waste.cards.clear()
		waste.faceDownCards.clear()
	createDeck()
	deck.shuffle()
	for i in range(table.size()):
		var slot=table[i]
		slot.faceDownCards.clear()
		for j in range(i+1):
			if deck.size()>0:
				var data=deck.pop_back()
				if j==i:
					var card=moveService.spawn(data,slot)
					card.flip()
				else:
					slot.faceDownCards.append(data)
		moveService.updateVisuals(slot)
	while deck.size()>0:
		moveService.spawn(deck.pop_back(),stock)
	moveService.reflowAllSlots()
func _input(event):
	if not gazeBridge.isReady or (not gazeBridge.isHeadTrackingActive() and not gazeBridge.isGazeActive()):
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			lastMousePos=event.position
			usingHeadInput=false
		elif event is InputEventScreenTouch and event.pressed:
			lastMousePos=event.position
			usingHeadInput=false
		elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			if scanService.scanMode:
				scanService.handleScanSelect()
			else:
				if aim!=null:
					var target=aim.target
					if target!=null:
						aim.reset()
						onAimDone(target)
func _process(delta):
	var viewportSize=get_viewport_rect().size
	var yaw=gazeBridge.gazeData.get("headYaw",0.5)
	var pitch=gazeBridge.gazeData.get("headPitch",0.5)
	var usingHead=gazeBridge.isReady and gazeBridge.isHeadTrackingActive()
	var usingGaze=gazeBridge.isReady and gazeBridge.isGazeReliable() and not usingHead
	var shouldScan=(not usingHead) and (not usingGaze)
	if shouldScan:
		if not scanService.scanMode:
			scanService.startScan("root")
	else:
		if scanService.scanMode:
			scanService.stopScan()
		if usingGaze:
			var gp=gazeBridge.getGazePoint()
			if aim!=null:
				aim.global_position=Vector2(clamp(gp.x,0.0,1.0)*viewportSize.x,clamp(gp.y,0.0,1.0)*viewportSize.y)
			usingHeadInput=true
		elif usingHead:
			var clampedYaw=clamp(yaw,0.0,1.0)
			var clampedPitch=clamp(pitch,0.0,1.0)
			if aim!=null:
				aim.global_position=Vector2(clampedYaw*viewportSize.x,clampedPitch*viewportSize.y)
			usingHeadInput=true
		elif lastMousePos!=Vector2.ZERO:
			if aim!=null:
				aim.global_position=lastMousePos
			usingHeadInput=false
	if aim!=null:
		aim.visible=not scanService.scanMode
	if scanService.scanMode and hand!=null:
		hand=null
		handStack.clear()
		if aim!=null:
			aim.holdingCard=false
	if hand!=null:
		var aimPos=lastMousePos
		if aim!=null:
			aimPos=aim.global_position
		var pos=aimPos+Vector2(0,15)
		for i in range(handStack.size()):
			handStack[i].global_position=pos+Vector2(0,40*i)
			handStack[i].z_index=200+i
	if gazeBridge.consumeSelectRequest():
		if scanService.scanMode:
			scanService.handleScanSelect()
		else:
			if aim!=null:
				var target=aim.target
				if target!=null:
					aim.reset()
					onAimDone(target)
	if enableIntegrityCheck:
		integrityTimer+=delta
		if integrityTimer>=1.0:
			integrityTimer=0.0
			var isHolding=aim!=null and aim.holdingCard
			if hand==null and handStack.size()==0 and not isHolding:
				moveService.validateAndRepairCards()
	if gameActive:
		time+=delta
		var minutes=int(time/60)
		var seconds=int(time)%60
		lblTime.text="Time: %02d:%02d"%[minutes,seconds]
	elif victoryElapsed>=0.0:
		victoryElapsed+=delta
		if victoryElapsed>=10.0:
			newGame()
func onAimDone(obj):
	if obj.is_in_group("ui"):
		if obj.name=="btnUndo":
			onUndo()
		elif obj.name=="btnNew":
			newGame()
		elif obj.name=="btnBack":
			scanService.startScan("confirmBack")
		elif obj.name=="Yes" and obj.get_parent()==confirmBackDialog:
			goToGamesMenu()
		elif obj.name=="No" and obj.get_parent()==confirmBackDialog:
			confirmBackDialog.visible=false
			if scanService.scanMode:
				scanService.startScan("root")
		return
	if not gameActive:
		return
	if hand==null:
		var isStock=false
		if obj==stock:
			isStock=true
		if obj.is_in_group("deck") and obj.slotParent.type==0:
			isStock=true
		if isStock:
			moveService.drawCard()
			return
		if obj.is_in_group("deck"):
			if obj.isFaceUp:
				moveService.pickCard(obj)
			else:
				if obj==obj.slotParent.getTopCard():
					obj.flip()
					score+=5
					uiService.updateUi()
	else:
		var target=null
		if obj.is_in_group("slot"):
			target=obj
		elif obj.is_in_group("deck"):
			target=obj.slotParent
		if target!=null:
			moveService.dropCard(target)
		else:
			moveService.cancel()
func goToGamesMenu():
	if OS.get_name()=="Web":
		JavaScriptBridge.eval("(function(){if(window.EngineJS&&EngineJS.Games&&EngineJS.Games.open){EngineJS.Games.open();return;}if(window.EngineJS&&EngineJS.goToGames){EngineJS.goToGames();return;}if(window.goToGames){window.goToGames();return;}if(window.location){window.location.href='/games';}})();")
	else:
		print("Back to games requested (non-web environment)")
func performStockAction():
	if not gameActive:
		return
	if hand!=null:
		moveService.cancel()
	var wasteTop=waste.getTopCard() if waste!=null else null
	if wasteTop!=null:
		var dest=cardService.findDestinationForCardSequence(wasteTop)
		if dest!=null:
			moveService.autoMoveStack(wasteTop,dest)
			return
	moveService.drawCard()
func drawCard():
	moveService.drawCard()
func pickCard(card):
	moveService.pickCard(card)
func dropCard(target):
	moveService.dropCard(target)
func autoMoveStack(card,target):
	moveService.autoMoveStack(card,target)
func cancel():
	moveService.cancel()
func setDraggingState(cards:Array,dragging:bool)->void:
	moveService.setDraggingState(cards,dragging)
func forceMoveCardsToSlot(cards:Array,target)->void:
	moveService.forceMoveCardsToSlot(cards,target)
func rebuildAllSlotLists()->void:
	moveService.rebuildAllSlotLists()
func onUndo():
	moveService.onUndo()
func reflowAllSlots():
	moveService.reflowAllSlots()
func normalizeSlotCards(slots:Array)->bool:
	return moveService.normalizeSlotCards(slots)
func repairOrphanCards():
	moveService.repairOrphanCards()
func validateAndRepairCards():
	moveService.validateAndRepairCards()
