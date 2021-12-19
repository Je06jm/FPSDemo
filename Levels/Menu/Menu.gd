extends Control

func _ready():
	$Main/NewGame.grab_focus()
	
	if GameState.has_save_game():
		$Main/Continue.visible = true
	
	OS.window_maximized = true
	OS.window_fullscreen = true

func _Main_on_NewGame_pressed():
	$Main.visible = false
	$NewGame.visible = true
	
	$NewGame/Normal.grab_focus()

func _Main_on_Continue_pressed():
	GameState.load_game()
	GameState.load_level("TestLevels/Test00.tscn")

func _Main_on_Exit_pressed():
	get_tree().quit(0)


func _NewGame_on_Easy_pressed():
	GameState.set_difficulty(GameState.Difficulty.EASY)
	_newgame()

func _NewGame_on_Normal_pressed():
	GameState.set_difficulty(GameState.Difficulty.NORMAL)
	_newgame()

func _NewGame_on_Hard_pressed():
	GameState.set_difficulty(GameState.Difficulty.HARD)
	_newgame()

func _newgame():
	GameState.new_game()
	GameState.load_level("TestLevels/Test00.tscn")

func _NewGame_on_Back_pressed():
	$NewGame.visible = false
	$Main.visible = true
	
	$Main/NewGame.grab_focus()
