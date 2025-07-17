extends TextureButton

@onready var brief_input: LineEdit = $"../BriefInput"
@onready var text_edit: TextEdit = $"../TextEdit"


func _on_pressed() -> void:
	text_edit.text += brief_input.text
	brief_input.text = ""
