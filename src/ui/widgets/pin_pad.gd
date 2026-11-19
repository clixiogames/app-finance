class_name PinPad
extends VBoxContainer
## Number pad with dots, for entering a PIN. Emits `completed(pin)` when `length` digits are typed.

signal completed(pin: String)

var length := 4
var _pin := ""
var _dots: HBoxContainer
var _msg: Label


func _init(pin_length: int = 4) -> void:
	length = pin_length
	add_theme_constant_override("separation", 18)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_dots = Ui.hbox(14)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_dots)
	_msg = Ui.label(" ", "Muted")
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_msg)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]:
		if k == "":
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(72, 60)
			grid.add_child(sp)
			continue
		var b := Ui.button(k, "Ghost" if k == "⌫" else "")
		b.custom_minimum_size = Vector2(72, 60)
		b.add_theme_font_size_override("font_size", 24)
		var key: String = k
		b.pressed.connect(func(): _press(key))
		grid.add_child(b)
	add_child(grid)
	_draw_dots()


func set_message(text: String, error: bool = false) -> void:
	_msg.text = text if text != "" else " "
	_msg.theme_type_variation = "Loss" if error else "Muted"


func clear() -> void:
	_pin = ""
	_draw_dots()


func _press(k: String) -> void:
	if k == "⌫":
		_pin = _pin.substr(0, maxi(0, _pin.length() - 1))
	elif _pin.length() < length:
		_pin += k
	_draw_dots()
	if _pin.length() == length:
		var p := _pin
		await get_tree().create_timer(0.12).timeout
		completed.emit(p)


func _draw_dots() -> void:
	Ui.clear(_dots)
	for i in length:
		var d := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(8)
		if i < _pin.length():
			sb.bg_color = AppTheme.c("text")
		else:
			sb.bg_color = Color(0, 0, 0, 0)
			sb.set_border_width_all(2)
			sb.border_color = AppTheme.c("faint")
		d.add_theme_stylebox_override("panel", sb)
		d.custom_minimum_size = Vector2(16, 16)
		_dots.add_child(d)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and is_visible_in_tree():
		var u: int = event.unicode
		if u >= 48 and u <= 57:
			_press(char(u))
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_BACKSPACE:
			_press("⌫")
			get_viewport().set_input_as_handled()


## Salted SHA-256 of the PIN (the PIN itself is never stored).
static func hash_pin(pin: String, salt: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((salt + ":" + pin).to_utf8_buffer())
	return ctx.finish().hex_encode()


static func new_salt() -> String:
	var c := Crypto.new()
	return c.generate_random_bytes(16).hex_encode()
