extends TextureButton

func _on_pressed() -> void:
	SceneManager.push_scene("res://settings.tscn")
