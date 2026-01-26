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
var integrityTimer:=0.0
const enableIntegrityCheck:=true
var lastMousePressed:=false
var cardService
var scanService
var moveService
var uiService
var selectLogLabel:Label
var selectCounter:=0
@onready var confirmDialog:Control=$ConfirmNew
@onready var confirmYes:Control=$ConfirmNew/Yes
@onready var confirmNo:Control=$ConfirmNew/No
@onready var confirmBackDialog:Control=$ConfirmBack
@onready var confirmBackYes:Control=$ConfirmBack/Yes
@onready var confirmBackNo:Control=$ConfirmBack/No
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
	setupSelectLog()
	winResetTimer.timeout.connect(newGame)
	organizeSlots()
	createDeck()
	newGame()
	scanService.startScan("root")
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
func handleSelectClick():
	logSelect("mouse")
	scanService.handleScanSelect()
func setupSelectLog():
	var hud=$HUD
	selectLogLabel=Label.new()
	selectLogLabel.name="SelectLogLabel"
	selectLogLabel.text="Select: aguardando"
	selectLogLabel.position=Vector2(20,120)
	selectLogLabel.size=Vector2(520,24)
	selectLogLabel.autowrap_mode=TextServer.AUTOWRAP_OFF
	selectLogLabel.clip_text=true
	hud.add_child(selectLogLabel)
func logSelect(source:String, evt:Dictionary={}):
	selectCounter+=1
	var targetName:=""
	if scanService!=null and scanService.scanTargets.size()>0:
		var t=scanService.scanTargets[scanService.scanIndex]
		if t.has("name"):
			targetName=str(t["name"])
	var level:String=""
	if scanService!=null:
		level=scanService.scanLevel
	var timeMs:=Time.get_ticks_msec()
	var latencyMs:int = int(evt.get("latencyMs", -1))
	if latencyMs < 0:
		var evtTs:int = int(evt.get("timestamp", 0))
		if evtTs > 0:
			latencyMs = timeMs - evtTs
		else:
			latencyMs = -1
	var movementLabel := ""
	if evt.has("label"):
		movementLabel = str(evt.get("label", "")).strip_edges()
	if movementLabel == "":
		movementLabel = str(evt.get("name", "")).strip_edges()
	var stateLabel := ""
	var stateVal := str(evt.get("state", "")).strip_edges()
	if stateVal == "start":
		stateLabel = "ativo"
	elif stateVal == "end":
		stateLabel = "inativo"
	else:
		stateLabel = "desconhecido"
	var triggerInfo := ""
	if movementLabel != "":
		triggerInfo = " trigger=%s (%s)" % [movementLabel, stateLabel]
	var msg:="#%d %s%s level=%s target=%s t=%d"%[selectCounter,source,triggerInfo,level,targetName,timeMs]
	if latencyMs >= 0:
		msg += " latency=%dms" % latencyMs
	if selectLogLabel!=null:
		selectLogLabel.text="Select: %s"%msg
	print("SelectLog: ",msg)
func _process(delta):
	if not scanService.scanMode:
		scanService.startScan("root")
	if hand!=null:
		hand=null
		handStack.clear()
	if gazeBridge != null:
		while true:
			var evt = gazeBridge.popSelectEvent()
			if evt.size() == 0:
				break
			logSelect("conversia", evt)
			scanService.handleScanSelect()
	var pressed=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if pressed and not lastMousePressed:
		handleSelectClick()
	lastMousePressed=pressed
	if enableIntegrityCheck:
		integrityTimer+=delta
		if integrityTimer>=1.0:
			integrityTimer=0.0
			if hand==null and handStack.size()==0:
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
func goToGamesMenu():
	if OS.get_name()=="Web":
		JavaScriptBridge.eval("(function(){try{var msg={type:'command',command:'exit',reason:'user',timestamp:Date.now()};if(window.parent&&window.parent!==window){window.parent.postMessage(msg,'*');}if(window.top&&window.top!==window.parent){window.top.postMessage(msg,'*');}}catch(e){};if(window.EngineJS&&EngineJS.Games&&EngineJS.Games.open){EngineJS.Games.open();return;}if(window.EngineJS&&EngineJS.goToGames){EngineJS.goToGames();return;}if(window.goToGames){window.goToGames();return;}if(window.location){window.location.href='/games';}})();")
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
