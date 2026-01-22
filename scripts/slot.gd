extends StaticBody2D
# 0 = Stock (Monte Fechado)
# 1 = Waste (Monte Aberto)
# 2 = Foundation (As 4 pilhas de cima para Ás->Rei)
# 3 = Tableau (As 7 colunas de jogo)
@export var type = 3 
var cards = [] 
var faceDownCards = []
@onready var hiddenLabel = $HiddenLabel
func getTopCard():
	if cards.size() == 0:
		return null
	if type == 3:
		var top = cards[0]
		for c in cards:
			if c != null and c.global_position.y > top.global_position.y:
				top = c
		return top
	return cards.back()
func updateHiddenLabel():
	var count = faceDownCards.size()
	hiddenLabel.text = str(count)
	hiddenLabel.visible = count > 0
