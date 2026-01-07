extends StaticBody2D
var rank = 0       
var suit = 0      
var isFaceUp = false
var slotParent = null 
func setup(r, s):
	rank = r
	suit = s
	updateFace()
func flip():
	isFaceUp = !isFaceUp 
	updateFace()
func updateFace():
	if isFaceUp:
		var path = "res://assets/cards/" + str(rank) + "." + str(suit) + ".png"
		$Sprite2D.texture = load(path)
	else:
		$Sprite2D.texture = load("res://assets/cards/Back1.png") 
func isRed():
	return suit == 2 or suit == 4
