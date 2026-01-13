extends StaticBody2D
# 0 = Stock (Monte Fechado)
# 1 = Waste (Monte Aberto)
# 2 = Foundation (As 4 pilhas de cima para Ás->Rei)
# 3 = Tableau (As 7 colunas de jogo)
@export var type = 3 
var cards = [] 
var face_down_cards = []
@onready var hidden_label = $HiddenLabel
func getTopCard():
	if cards.size() > 0:
		return cards.back()
	return null
func update_hidden_label():
	var count = face_down_cards.size()
	hidden_label.text = str(count)
	hidden_label.visible = count > 0
