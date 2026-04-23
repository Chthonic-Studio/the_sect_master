extends Button

## When clicked, it will open the user's OS file explorer directly to the Mods folder.

func _ready() -> void:
	pressed.connect(_on_open_mods_pressed)

func _on_open_mods_pressed() -> void:
	var mod_path: String = "user://Mods"
	
	# ProjectSettings.globalize_path converts the virtual user:// path
	# into an absolute OS path (e.g., C:/Users/...)
	var absolute_path: String = ProjectSettings.globalize_path(mod_path)
	
	# OS.shell_open tells the operating system to open the path 
	# with the default program (in this case, the File Explorer)
	var err: Error = OS.shell_open(absolute_path)
	
	if err != OK:
		printerr("Failed to open Mods folder. Error code: ", err)
