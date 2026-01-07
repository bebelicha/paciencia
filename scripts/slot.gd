extends StaticBody2D
# 0 = Stock (Monte Fechado)
# 1 = Waste (Monte Aberto)
# 2 = Foundation (As 4 pilhas de cima para Ás->Rei)
# 3 = Tableau (As 7 colunas de jogo)
@export var type = 3 
var cards = [] 
func getTopCard():
	if cards.size() > 0:
		return cards.back()
	return null
