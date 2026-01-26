extends Node
class_name ScanService
class ScanHighlight:
	extends Node2D
	var rect_size:Vector2=Vector2.ZERO
	var fill_color:Color=Color(0.11,0.73,0.94,0.18)
	var border_color:Color=Color(0.11,0.73,0.94,0.9)
	var border_width:float=4.0
	func _draw():
		if rect_size==Vector2.ZERO:
			return
		draw_rect(Rect2(Vector2.ZERO,rect_size),fill_color)
		draw_rect(Rect2(Vector2.ZERO,rect_size),border_color,false,border_width)
var main
var scanMode=false
var scanLevel="root"
var scanTargets:Array=[]
var scanIndex=0
var scanTimer:Timer
var scanLayer:CanvasLayer
var scanHighlight:ScanHighlight
var scanStepSeconds=3.0
var scanBackRect:=Rect2(Vector2(20,20),Vector2(140,50))
var selectedTableSlot=null
var lastSelectTime:= -1.0
const selectCooldown:=0.0
func setup(mainRef):
	main=mainRef
	scanTimer=Timer.new()
	scanTimer.one_shot=false
	scanTimer.wait_time=scanStepSeconds
	scanTimer.timeout.connect(onScanStep)
	add_child(scanTimer)
	scanLayer=CanvasLayer.new()
	scanLayer.layer=100
	main.get_tree().root.add_child.call_deferred(scanLayer)
	scanHighlight=ScanHighlight.new()
	scanHighlight.visible=false
	scanHighlight.z_index=3500
	scanHighlight.set_as_top_level(true)
	scanLayer.add_child.call_deferred(scanHighlight)
	main.confirmDialog.visible=false
func startScan(level="root"):
	scanMode=true
	scanLevel=level
	main.confirmDialog.visible=level=="confirmNew"
	main.confirmBackDialog.visible=level=="confirmBack"
	if level!="tableCards":
		selectedTableSlot=null
	scanTargets=buildScanTargets(level)
	scanIndex=0
	applyScanHighlight()
	if scanTargets.size()>0:
		scanTimer.start(scanStepSeconds)
	else:
		scanTimer.stop()
func stopScan():
	scanMode=false
	scanTimer.stop()
	scanHighlight.visible=false
	scanTargets.clear()
	scanLevel="root"
	main.confirmDialog.visible=false
	main.confirmBackDialog.visible=false
func onScanStep():
	if scanTargets.size()==0:
		return
	scanIndex=(scanIndex+1)%scanTargets.size()
	applyScanHighlight()
func applyScanHighlight():
	if scanTargets.size()==0:
		scanHighlight.visible=false
		return
	var rect:Rect2=scanTargets[scanIndex]["rect"]
	scanHighlight.global_position=rect.position
	scanHighlight.rect_size=rect.size
	scanHighlight.queue_redraw()
	scanHighlight.visible=true
func handleScanSelect():
	var nowSec:=Time.get_ticks_msec()/1000.0
	if lastSelectTime>0.0 and (nowSec-lastSelectTime)<selectCooldown:
		return
	lastSelectTime=nowSec
	if scanTargets.size()==0:
		return
	var target=scanTargets[scanIndex]
	match scanLevel:
		"root":
			handleRootSelection(target)
		"menu":
			handleMenuSelection(target)
		"confirmNew":
			handleConfirmNewSelection(target)
		"confirmBack":
			handleConfirmBackSelection(target)
		"stock":
			handleStockSelection(target)
		"table":
			handleTableSelection(target)
		"tableCards":
			handleTableCardsSelection(target)
		"foundation":
			handleFoundationSelection(target)
	if scanMode:
		refreshScanTargets()
func handleRootSelection(target):
	match target["name"]:
		"menu":
			startScan("menu")
		"stock":
			startScan("stock")
		"table":
			startScan("table")
		"foundation":
			startScan("foundation")
		"back_to_games":
			startScan("confirmBack")
func handleMenuSelection(target):
	match target["name"]:
		"undo":
			main.onUndo()
			startScan("root")
		"new":
			startScan("confirmNew")
		"voltar":
			scanGoBack()
func handleStockSelection(target):
	if target["name"]=="voltar":
		scanGoBack()
		return
	if target["name"]=="comprar":
		main.drawCard()
		startScan("stock")
		return
	if target["name"]=="waste_move":
		if main.waste!=null:
			var wasteTop=main.waste.getTopCard()
			if wasteTop!=null:
				var dest=main.cardService.findDestinationForCardSequence(wasteTop)
				if dest!=null:
					main.autoMoveStack(wasteTop,dest)
	startScan("stock")
func handleConfirmNewSelection(target):
	if target["name"]=="yes":
		main.confirmDialog.visible=false
		main.newGame()
		startScan("root")
	elif target["name"]=="no":
		main.confirmDialog.visible=false
		startScan("menu")
func handleConfirmBackSelection(target):
	if target["name"]=="yes":
		main.confirmBackDialog.visible=false
		main.goToGamesMenu()
		startScan("root")
	elif target["name"]=="no":
		main.confirmBackDialog.visible=false
		startScan("root")
func handleTableSelection(target):
	if target["name"]=="voltar":
		scanGoBack()
		return
	if target.has("slot"):
		selectedTableSlot=target["slot"]
		startScan("tableCards")
		if scanMode:
			refreshScanTargets()
func handleFoundationSelection(target):
	if target["name"]=="voltar":
		scanGoBack()
		return
	if not target.has("slot"):
		return
	var src=target["slot"]
	var card=src.getTopCard()
	if card==null:
		return
	var dest=main.cardService.findTableDestination(card,src)
	if dest!=null:
		main.autoMoveStack(card,dest)
	startScan("foundation")
func handleTableCardsSelection(target):
	if target["name"]=="voltar":
		startScan("table")
		return
	if not target.has("card"):
		return
	var card=target["card"]
	if card==null or not card.is_inside_tree():
		return
	var dest=main.cardService.findDestinationForCardSequence(card)
	if dest!=null:
		main.autoMoveStack(card,dest)
	startScan("tableCards")
	if scanMode:
		refreshScanTargets()
func scanGoBack():
	match scanLevel:
		"confirmNew":
			startScan("menu")
		"confirmBack":
			startScan("root")
		"menu":
			startScan("root")
		"stock":
			startScan("root")
		"table":
			startScan("root")
		"tableCards":
			startScan("table")
		"foundation":
			startScan("root")
		_:
			startScan("root")
func refreshScanTargets():
	scanTargets=buildScanTargets(scanLevel)
	if scanTargets.size()==0:
		scanHighlight.visible=false
		scanTimer.stop()
		scanIndex=0
		return
	scanIndex=scanIndex%scanTargets.size()
	applyScanHighlight()
	if scanTimer.is_stopped():
		scanTimer.start(scanStepSeconds)
func buildScanTargets(level:String)->Array:
	var targets:Array=[]
	if level=="root":
		targets.append({"name":"back_to_games","rect":rectForControl(main.get_node("HUD/btnBack"))})
		targets.append({"name":"menu","rect":rectForMenu()})
		targets.append({"name":"stock","rect":rectForStock()})
		targets.append({"name":"table","rect":rectForTable()})
		targets.append({"name":"foundation","rect":rectForFoundation()})
	elif level=="menu":
		targets.append({"name":"voltar","rect":rectForControl(main.get_node("HUD/btnBack"))})
		targets.append({"name":"undo","rect":rectForControl(main.get_node("HUD/btnUndo"))})
		targets.append({"name":"new","rect":rectForControl(main.get_node("HUD/btnNew"))})
	elif level=="confirmBack":
		main.confirmBackDialog.visible=true
		targets.append({"name":"yes","rect":rectForControl(main.confirmBackYes)})
		targets.append({"name":"no","rect":rectForControl(main.confirmBackNo)})
	elif level=="stock":
		targets.append({"name":"voltar","rect":rectForControl(main.get_node("HUD/btnBack"))})
		if main.stock!=null:
			targets.append({"name":"comprar","rect":getSlotRect(main.stock)})
		if main.waste!=null:
			targets.append({"name":"waste_move","rect":getSlotRect(main.waste)})
	elif level=="confirmNew":
		main.confirmDialog.visible=true
		targets.append({"name":"yes","rect":rectForControl(main.confirmYes)})
		targets.append({"name":"no","rect":rectForControl(main.confirmNo)})
	elif level=="table":
		targets.append({"name":"voltar","rect":rectForControl(main.get_node("HUD/btnBack"))})
		for s in main.table:
			if s.cards.size()>0:
				targets.append({"name":"column","slot":s,"rect":getSlotRect(s)})
	elif level=="tableCards":
		targets.append({"name":"voltar","rect":rectForControl(main.get_node("HUD/btnBack"))})
		if selectedTableSlot!=null:
			for c in selectedTableSlot.cards:
				if c.isFaceUp:
					targets.append({"name":"card","card":c,"slot":selectedTableSlot,"rect":getCardRect(c)})
	elif level=="foundation":
		targets.append({"name":"voltar","rect":rectForControl(main.get_node("HUD/btnBack"))})
		for f in main.foundation:
			targets.append({"name":"foundation","slot":f,"rect":getSlotRect(f)})
	return targets
func rectForControl(ctrl:Control)->Rect2:
	if ctrl==null:
		return Rect2(Vector2.ZERO,Vector2(10,10))
	var rect:=ctrl.get_global_rect()
	if rect.size==Vector2.ZERO:
		var ctrlSize=ctrl.get_combined_minimum_size()
		return Rect2(ctrl.global_position,ctrlSize)
	return rect
func rectUnion(rects:Array)->Rect2:
	if rects.size()==0:
		return Rect2(Vector2.ZERO,Vector2(10,10))
	var minX=rects[0].position.x
	var minY=rects[0].position.y
	var maxX=rects[0].position.x+rects[0].size.x
	var maxY=rects[0].position.y+rects[0].size.y
	for r in rects:
		minX=min(minX,r.position.x)
		minY=min(minY,r.position.y)
		maxX=max(maxX,r.position.x+r.size.x)
		maxY=max(maxY,r.position.y+r.size.y)
	return Rect2(Vector2(minX,minY),Vector2(maxX-minX,maxY-minY))
func rectForMenu()->Rect2:
	var rects:Array=[rectForControl(main.get_node("HUD/btnUndo")),rectForControl(main.get_node("HUD/btnNew"))]
	return rectUnion(rects)
func rectForStock()->Rect2:
	var rects:Array=[]
	if main.stock!=null:
		rects.append(getSlotRect(main.stock))
	if main.waste!=null:
		rects.append(getSlotRect(main.waste))
	return rectUnion(rects)
func rectForTable()->Rect2:
	var rects:Array=[]
	for s in main.table:
		rects.append(getSlotRect(s))
	return rectUnion(rects)
func rectForFoundation()->Rect2:
	var rects:Array=[]
	for f in main.foundation:
		rects.append(getSlotRect(f))
	return rectUnion(rects)
func getSlotRect(slot)->Rect2:
	if slot==null:
		return Rect2(Vector2.ZERO,Vector2(10,10))
	var rectSize=Vector2(120,140)
	var rectPos=slot.global_position-rectSize/2.0
	var shapeNode=slot.get_node_or_null("CollisionShape2D")
	if shapeNode!=null and shapeNode.shape is RectangleShape2D:
		rectSize=shapeNode.shape.size
		rectPos=slot.to_global(shapeNode.position-rectSize/2.0)
	if slot.type==3:
		var stackHeight=rectSize.y+max(0,slot.cards.size()-1)*40
		rectSize=Vector2(rectSize.x,stackHeight)
	return Rect2(rectPos,rectSize)
func getCardRect(card)->Rect2:
	if card==null:
		return Rect2(Vector2.ZERO,Vector2(10,10))
	var rectSize=Vector2(96,120)
	var rectPos=card.global_position-rectSize/2.0
	var shapeNode=card.get_node_or_null("CollisionShape2D")
	if shapeNode!=null and shapeNode.shape is RectangleShape2D:
		rectSize=shapeNode.shape.size
		rectPos=card.to_global(shapeNode.position-rectSize/2.0)
	return Rect2(rectPos,rectSize)
