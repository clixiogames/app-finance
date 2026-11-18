class_name Screen
extends VBoxContainer
## Base class for every screen. The app shell provides the header, scrolling and tabs.

var app  # Main (src/ui/main.gd)


func _init() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Title shown in the header.
func title() -> String:
	return ""


## Optional buttons on the right of the header.
func header_actions() -> Array:
	return []


## Rebuild the content from Store data. Called when shown and when data changes.
func refresh() -> void:
	pass


## Return false to keep a form open while data changes in the background.
func auto_refresh() -> bool:
	return true
