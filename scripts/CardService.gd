extends Node
class_name CardService
var main
func setup(mainRef):
	main = mainRef
func checkCardPlacement(card, slot):
	var top = slot.getTopCard()
	if slot.type == 3:
		if top == null:
			return card.rank == 13
		return (card.isRed() != top.isRed()) and (card.rank == top.rank - 1)
	if slot.type == 2:
		if top == null:
			return card.rank == 1
		return (card.suit == top.suit) and (card.rank == top.rank + 1)
	return false
func findFoundationDestination(card, src):
	for f in main.foundation:
		if f != src and checkCardPlacement(card, f):
			return f
	return null
func findTableDestination(card, src):
	for t in main.table:
		if t != src and checkCardPlacement(card, t):
			return t
	return null
func findDestinationForCardSequence(card):
	var src = card.slotParent
	if src == null:
		return null
	var idx = src.cards.find(card)
	if idx == -1:
		return null
	var stackSize = src.cards.size() - idx
	if stackSize == 1:
		var foundationDest = findFoundationDestination(card, src)
		if foundationDest != null:
			return foundationDest
	return findTableDestination(card, src)
