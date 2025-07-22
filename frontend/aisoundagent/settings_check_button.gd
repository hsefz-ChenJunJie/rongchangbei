extends CheckButton

@onready var panel1: Panel = $"../Panel"
@onready var panel2: Panel = $"../Panel2"


func _on_toggled(toggled_on: bool) -> void:
	if not toggled_on:
		panel1.visible = false
		panel2.visible = true
	else:
		panel1.visible = true
		panel2.visible = false
