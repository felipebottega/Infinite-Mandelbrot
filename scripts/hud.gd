extends CanvasLayer


func _ready() -> void:
	$Version.text ="v" + ProjectSettings.get_setting("application/config/version")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
