extends CanvasLayer


func _ready() -> void:
	$Version.text ="v" + ProjectSettings.get_setting("application/config/version")
	
	var tween = create_tween()
	tween.tween_property($Title, "modulate", Color(1.0, 0.0, 0.0, 0.0), 5.0)
	await tween.finished
	remove_child($Title)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
