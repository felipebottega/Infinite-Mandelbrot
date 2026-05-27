extends CanvasLayer

func _ready() -> void:
	$Window.hide()

func _on_option_button_item_selected(index: int) -> void:
	Manager.resolution = (
		256 if index == 0
		else 512 if index == 1
		else 1024
	)
	
	var text = "You have selected a resolution of\n%d x %d.\nDo you wish to proceed?" % [Manager.resolution, Manager.resolution]
	$Window/Label.text = text
	$Window.show()
	
func _on_yes_pressed() -> void:
	var res := Vector2(Manager.resolution, Manager.resolution)
	get_window().size = res
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/fractal.tscn")

func _on_no_pressed() -> void:
	$Window.hide()
