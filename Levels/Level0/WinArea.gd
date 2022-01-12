extends Area

func _on_WinArea_body_entered(body : Node):
	if body.has_method("set_win"):
		body.set_win()
