extends Node
class_name UiService
var main
func setup(mainRef):
	main=mainRef
func updateUi():
	main.lblScore.text="Score: "+str(main.score)
	main.lblMoves.text="Moves: "+str(main.moves)
func checkWin():
	var total=0
	for f in main.foundation:
		total+=f.cards.size()
	if total==52:
		main.gameActive=false
		var minutes=int(main.time/60)
		var seconds=int(main.time)%60
		main.lblFinalScore.text="Score: "+str(main.score)
		main.lblFinalTime.text="Time: %02d:%02d"%[minutes,seconds]
		main.lblFinalMoves.text="Moves: "+str(main.moves)
		main.gazeBridge.sendStats(main.score,"1")
		main.victoryScreen.visible=true
		main.winResetTimer.start(10)
		main.victoryElapsed=0.0
