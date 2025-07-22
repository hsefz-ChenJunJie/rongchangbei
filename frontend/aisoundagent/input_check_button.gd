extends CheckButton

@onready var timer: Timer = $"../Timer"
@export var interval: int = 10

func load_api_config():
	var config_path = "user://config.json"
	var file = FileAccess.open(config_path, FileAccess.READ)
	
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		file.close()
		
		if error == OK:
			var config = json.get_data()
			interval = config["interval"]
			print("Interval:",interval)
		else:
			push_error("Failed to parse config.json: " + json.get_error_message())
	else:
		push_error("Failed to open config.json")

func _ready():
	load_api_config()

func _on_toggled(toggled_on: bool) -> void:
	if toggled_on:
		print("Interval:",interval)
		timer.start(interval)
	else:
		timer.stop()
