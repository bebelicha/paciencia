extends Node2D
var hand = null 
func _ready():
	print("O JOGO COMEÇOU!")  
	$Aim.done.connect(onAimDone)
	createTestCard(1, 2, 200, 200) 
	createTestCard(10, 1, 500, 200)

func createTestCard(r, s, x, y):
	var cardScene = preload("res://scenes/Card.tscn") 
	var newCard = cardScene.instantiate() 
	newCard.setup(r, s) 
	newCard.position = Vector2(x, y) 
	add_child(newCard) 
func onAimDone(obj):
	if hand == null:
		hand = obj 
		hand.modulate.a = 0.5 
		print("Pegou!")
	else:
		hand.global_position = $Aim.global_position
		hand.modulate.a = 1.0 
		hand = null 
		print("Soltou!")
func _process(delta):
	if hand != null:
		hand.global_position = $Aim.global_position
