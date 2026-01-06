extends StaticBody2D
var rank = 0
var suit = 0
func setup(r, s):
	rank = r
	suit = s
	if s % 2 == 0:
		$ColorRect.color = Color.RED
	else:
		$ColorRect.color = Color.BLUE
		
