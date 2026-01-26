extends Node
class_name MoveService
var main
func setup(mainRef):
	main=mainRef
func spawn(data,slot):
	var scene=preload("res://scenes/Card.tscn")
	var card=scene.instantiate()
	card.setup(data.rank,data.suit)
	main.add_child(card)
	slot.cards.append(card)
	card.slotParent=slot
	updateVisuals(slot)
	return card
func updateVisuals(slot):
	if slot.type==3:
		slot.updateHiddenLabel()
	elif slot.type==2:
		slot.cards.sort_custom(func(a,b): return a.rank<b.rank)
	for i in range(slot.cards.size()):
		var c=slot.cards[i]
		c.z_index=10+i
		if slot.type==3:
			c.position=slot.position+Vector2(0,40*i)
		else:
			c.position=slot.position
func revealFromHidden(slot):
	if slot.faceDownCards.size()==0:
		return null
	var data=slot.faceDownCards.pop_back()
	var card=spawn(data,slot)
	card.flip()
	return card
func drawCard():
	if main.stock.cards.size()>0:
		var card=main.stock.cards.pop_back()
		main.waste.cards.append(card)
		card.slotParent=main.waste
		card.flip()
		updateVisuals(main.stock)
		updateVisuals(main.waste)
		main.history.append({"type":"draw","cards":[card],"src":main.stock,"dst":main.waste,"score":0})
		main.moves+=1
		main.uiService.updateUi()
	else:
		if main.waste.cards.size()>0:
			var list=main.waste.cards.duplicate()
			main.waste.cards.clear()
			list.reverse()
			for c in list:
				c.flip()
				c.slotParent=main.stock
				main.stock.cards.append(c)
			updateVisuals(main.waste)
			updateVisuals(main.stock)
			main.history.append({"type":"recycle","cards":list,"src":main.waste,"dst":main.stock,"score":-100})
			if main.score>=100:
				main.score-=100
			else:
				main.score=0
			main.moves+=1
			main.uiService.updateUi()
func pickCard(card):
	var slot=card.slotParent
	var index=slot.cards.find(card)
	if index!=-1:
		main.hand=card
		main.handOrigin=slot
		main.handStack=slot.cards.slice(index)
		setDraggingState(main.handStack,true)
		slot.cards.resize(index)
		updateVisuals(slot)
func dropCard(target):
	if main.cardService.checkCardPlacement(main.hand,target):
		setDraggingState(main.handStack,false)
		var points=0
		if main.handOrigin.type==1 and target.type==3:
			points=5
		elif main.handOrigin.type==1 and target.type==2:
			points=10
		elif main.handOrigin.type==3 and target.type==2:
			points=10
		elif main.handOrigin.type==2 and target.type==3:
			points=-15
		main.score+=points
		if main.score<0:
			main.score=0
		main.moves+=1
		var revealed=null
		var revealedFromHidden=false
		var revealedData=null
		if main.handOrigin.type==3 and main.handOrigin.cards.size()==0 and main.handOrigin.faceDownCards.size()>0:
			revealed=revealFromHidden(main.handOrigin)
			revealedFromHidden=true
			revealedData={"rank":revealed.rank,"suit":revealed.suit}
			main.score+=5
			points+=5
		updateVisuals(main.handOrigin)
		forceMoveCardsToSlot(main.handStack,target)
		updateVisuals(target)
		var movedCards=main.handStack.duplicate()
		main.hand=null
		main.handStack.clear()
		repairOrphanCards()
		reflowAllSlots()
		main.history.append({"type":"move","cards":movedCards,"src":main.handOrigin,"dst":target,"revealed":revealed,"revealedFromHidden":revealedFromHidden,"revealedData":revealedData,"score":points})
		main.uiService.updateUi()
		main.uiService.checkWin()
	else:
		cancel()
func autoMoveStack(card,target):
	if main.hand!=null:
		cancel()
	if card==null or target==null:
		return
	var src=card.slotParent
	if src==null:
		return
	var index=src.cards.find(card)
	if index==-1:
		return
	if not main.cardService.checkCardPlacement(card,target):
		return
	var moving=src.cards.slice(index)
	setDraggingState(moving,false)
	src.cards.resize(index)
	var points=0
	if src.type==1 and target.type==3:
		points=5
	elif src.type==1 and target.type==2:
		points=10
	elif src.type==3 and target.type==2:
		points=10
	elif src.type==2 and target.type==3:
		points=-15
	main.score+=points
	if main.score<0:
		main.score=0
	main.moves+=1
	var revealed=null
	var revealedFromHidden=false
	var revealedData=null
	if src.type==3 and src.cards.size()==0 and src.faceDownCards.size()>0:
		revealed=revealFromHidden(src)
		revealedFromHidden=true
		revealedData={"rank":revealed.rank,"suit":revealed.suit}
		main.score+=5
		points+=5
	updateVisuals(src)
	forceMoveCardsToSlot(moving,target)
	updateVisuals(target)
	rebuildAllSlotLists()
	reflowAllSlots()
	main.history.append({"type":"move","cards":moving.duplicate(),"src":src,"dst":target,"revealed":revealed,"revealedFromHidden":revealedFromHidden,"revealedData":revealedData,"score":points})
	main.uiService.updateUi()
	main.uiService.checkWin()
func cancel():
	setDraggingState(main.handStack,false)
	for c in main.handStack:
		main.handOrigin.cards.append(c)
		c.slotParent=main.handOrigin
	updateVisuals(main.handOrigin)
	repairOrphanCards()
	reflowAllSlots()
	main.hand=null
	main.handStack.clear()
func setDraggingState(cards:Array,dragging:bool)->void:
	for c in cards:
		if c==null:
			continue
		c.set_meta("dragging",dragging)
func forceMoveCardsToSlot(cards:Array,target)->void:
	if target==null:
		return
	var slots:Array=[]
	if main.stock!=null:
		slots.append(main.stock)
	if main.waste!=null:
		slots.append(main.waste)
	slots.append_array(main.foundation)
	slots.append_array(main.table)
	for s in slots:
		if s==null or s==target:
			continue
		for c in cards:
			if c==null:
				continue
			while s.cards.has(c):
				s.cards.erase(c)
	for c in cards:
		if c==null:
			continue
		if not target.cards.has(c):
			target.cards.append(c)
		c.slotParent=target
func rebuildAllSlotLists()->void:
	var slots:Array=[]
	if main.stock!=null:
		slots.append(main.stock)
	if main.waste!=null:
		slots.append(main.waste)
	slots.append_array(main.foundation)
	slots.append_array(main.table)
	for s in slots:
		if s!=null:
			s.cards.clear()
	var slotToCards={}
	var allCards=get_tree().get_nodes_in_group("deck")
	for card in allCards:
		if not (card is StaticBody2D):
			continue
		if main.hand!=null and main.handStack.has(card):
			continue
		var sp=card.slotParent
		if sp!=null and sp.is_inside_tree() and slots.has(sp):
			if not slotToCards.has(sp):
				slotToCards[sp]=[]
			slotToCards[sp].append(card)
		else:
			var bestSlot=null
			var bestDist=INF
			for s in main.table:
				if s==null:
					continue
				var d=s.global_position.distance_to(card.global_position)
				if d<bestDist:
					bestDist=d
					bestSlot=s
			if bestSlot!=null:
				card.slotParent=bestSlot
				if not slotToCards.has(bestSlot):
					slotToCards[bestSlot]=[]
				slotToCards[bestSlot].append(card)
	for s in slots:
		if s==null:
			continue
		var list=slotToCards.get(s,[])
		list.sort_custom(func(a,b): return a.global_position.y<b.global_position.y)
		s.cards=list
func onUndo():
	if main.history.size()==0:
		return
	var act=main.history.pop_back()
	main.score-=act.score
	if main.score<0:
		main.score=0
	main.moves-=1
	main.uiService.updateUi()
	if act.type=="move":
		for c in act.cards:
			act.dst.cards.erase(c)
			act.src.cards.append(c)
			c.slotParent=act.src
		if act.revealedFromHidden and act.revealed!=null:
			act.src.cards.erase(act.revealed)
			act.revealed.queue_free()
			if act.revealedData!=null:
				act.src.faceDownCards.append(act.revealedData)
		elif act.revealed!=null:
			act.revealed.flip()
		updateVisuals(act.src)
		updateVisuals(act.dst)
	elif act.type=="draw":
		var c=act.cards[0]
		act.dst.cards.erase(c)
		act.src.cards.append(c)
		c.slotParent=act.src
		c.flip()
		updateVisuals(act.src)
		updateVisuals(act.dst)
	elif act.type=="recycle":
		for c in act.cards:
			act.dst.cards.erase(c)
		var rev=act.cards.duplicate()
		rev.reverse()
		for c in rev:
			c.flip()
			c.slotParent=act.src
			act.src.cards.append(c)
		updateVisuals(act.src)
		updateVisuals(act.dst)
	reflowAllSlots()
func reflowAllSlots():
	var slots:Array=[]
	if main.stock!=null:
		slots.append(main.stock)
	if main.waste!=null:
		slots.append(main.waste)
	slots.append_array(main.foundation)
	slots.append_array(main.table)
	normalizeSlotCards(slots)
	for s in slots:
		if s==null:
			continue
		updateVisuals(s)
func normalizeSlotCards(slots:Array)->bool:
	var changed=false
	var cardToSlot={}
	for s in slots:
		if s==null:
			continue
		var i:=0
		while i<s.cards.size():
			var c=s.cards[i]
			if c==null:
				s.cards.remove_at(i)
				changed=true
				continue
			if cardToSlot.has(c):
				s.cards.remove_at(i)
				changed=true
				continue
			cardToSlot[c]=s
			i+=1
	var allCards=get_tree().get_nodes_in_group("deck")
	for card in allCards:
		if not (card is StaticBody2D):
			continue
		if main.hand!=null and main.handStack.has(card):
			continue
		if cardToSlot.has(card):
			continue
		var sp=card.slotParent
		if sp!=null and sp.is_inside_tree() and slots.has(sp):
			sp.cards.append(card)
			cardToSlot[card]=sp
			changed=true
		else:
			var bestSlot=null
			var bestDist=INF
			for s in main.table:
				if s==null:
					continue
				var d=s.global_position.distance_to(card.global_position)
				if d<bestDist:
					bestDist=d
					bestSlot=s
			if bestSlot!=null:
				bestSlot.cards.append(card)
				card.slotParent=bestSlot
				cardToSlot[card]=bestSlot
				changed=true
	return changed
func repairOrphanCards():
	var slots:Array=[]
	if main.stock!=null:
		slots.append(main.stock)
	if main.waste!=null:
		slots.append(main.waste)
	slots.append_array(main.foundation)
	slots.append_array(main.table)
	var cardsInSlots={}
	for s in slots:
		if s==null:
			continue
		for c in s.cards:
			cardsInSlots[c]=s
	var allCards=get_tree().get_nodes_in_group("deck")
	for card in allCards:
		if not (card is StaticBody2D):
			continue
		if main.hand!=null and main.handStack.has(card):
			continue
		if cardsInSlots.has(card):
			continue
		var bestSlot=null
		var bestDist=INF
		for s in main.table:
			if s==null:
				continue
			var d=s.global_position.distance_to(card.global_position)
			if d<bestDist:
				bestDist=d
				bestSlot=s
		if bestSlot!=null:
			bestSlot.cards.append(card)
			card.slotParent=bestSlot
func validateAndRepairCards():
	var slots:Array=[]
	if main.stock!=null:
		slots.append(main.stock)
	if main.waste!=null:
		slots.append(main.waste)
	slots.append_array(main.foundation)
	slots.append_array(main.table)
	var repaired:=normalizeSlotCards(slots)
	if repaired:
		reflowAllSlots()
