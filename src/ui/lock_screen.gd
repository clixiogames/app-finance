extends Control
## Full-screen lock shown when an app PIN is set.

var app
var _pad: PinPad
var _fails := 0
var _blocked_until := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = AppTheme.c("bg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := Ui.vbox(16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/icon.svg")
	logo.custom_minimum_size = Vector2(52, 52)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(logo)
	var t := Ui.label("Enter your PIN", "Title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_pad = PinPad.new(int(Store.setting("pin_len", 4)))
	_pad.completed.connect(_check)
	v.add_child(_pad)
	var forgot := Ui.button("Forgot PIN?", "Ghost", _forgot)
	forgot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(forgot)


func _check(pin: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _blocked_until:
		_pad.clear()
		_pad.set_message("Too many tries — wait %d s" % ceili(_blocked_until - now), true)
		return
	if PinPad.hash_pin(pin, str(Store.setting("pin_salt", ""))) == str(Store.setting("pin_hash", "")):
		app.unlock()
		return
	_fails += 1
	_pad.clear()
	if _fails >= 5:
		_blocked_until = now + 30.0
		_fails = 0
		_pad.set_message("Too many tries — wait 30 s", true)
	else:
		_pad.set_message("Wrong PIN", true)


func _forgot() -> void:
	app.show_dialog("Forgot your PIN?", Ui.label("Your data is only on this device, so the PIN can't be recovered. You can erase this device's data and start again — then restore your last backup file if you have one.", "", true), [
		["Cancel", "", Callable()],
		["Erase data", "Danger", func():
			Store.reset_all()
			app.unlock()
			app.reload_theme()],
	])
	# Keep the dialog above the lock
	move_to_front()
	app.overlay.move_to_front()
