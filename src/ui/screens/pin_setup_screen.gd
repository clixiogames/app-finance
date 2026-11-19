extends Screen
## Turn the app PIN on (type it twice) or off.

var _first := ""
var _pad: PinPad
var _title: Label
var _built := false


func title() -> String:
	return "App lock"


func auto_refresh() -> bool:
	return false


func refresh() -> void:
	if _built:
		return
	_built = true
	if str(Store.setting("pin_hash", "")) != "":
		add_child(Ui.label("The app asks for your PIN when it opens and after one minute in the background.", "Muted", true))
		add_child(Ui.button("Change PIN", "", func():
			Ui.clear(self)
			_build_pad()))
		add_child(Ui.button("Turn off app lock", "Danger", func():
			Store.set_settings({"pin_hash": "", "pin_salt": ""})
			app.pop()
			app.toast("App lock turned off")))
		return
	_build_pad()


func _build_pad() -> void:
	_built = true
	_title = Ui.label("Choose a 4-digit PIN", "Strong")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(Ui.spacer(10))
	add_child(_title)
	_pad = PinPad.new(4)
	_pad.completed.connect(_on_pin)
	add_child(_pad)
	add_child(Ui.label("If you forget it, the only way back in is to erase this device's data and restore a backup.", "Faint", true))


func _on_pin(pin: String) -> void:
	if _first == "":
		_first = pin
		_pad.clear()
		_title.text = "Type it again"
		return
	if pin != _first:
		_first = ""
		_pad.clear()
		_title.text = "Choose a 4-digit PIN"
		_pad.set_message("The two PINs were different — try again", true)
		return
	var salt := PinPad.new_salt()
	Store.set_settings({"pin_salt": salt, "pin_hash": PinPad.hash_pin(pin, salt), "pin_len": 4})
	app.pop()
	app.toast("App lock is on")
