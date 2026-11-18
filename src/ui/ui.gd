class_name Ui
## Small helpers to build screens in code with the app's design system.


static func label(text: String, variation: String = "", wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func vbox(sep: int = 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func hbox(sep: int = 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


## Lets a control take the free width. Labels shrink with "…" instead of pushing the layout wider.
static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if c is Label and c.autowrap_mode == TextServer.AUTOWRAP_OFF:
		shrinkable(c)
	return c


static func shrinkable(l: Label) -> Label:
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


static func spacer(h: int = 8) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s


static func hspacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


## A rounded card. Add content to card.get_meta("body").
static func card(sep: int = 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Card"
	var v := vbox(sep)
	p.add_child(v)
	p.set_meta("body", v)
	return p


static func body(card_node: PanelContainer) -> VBoxContainer:
	return card_node.get_meta("body")


static func button(text: String, variation: String = "", cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	if cb.is_valid():
		b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func line_edit(placeholder: String = "", text: String = "", kind: String = "text") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.select_all_on_focus = kind != "text"
	match kind:
		"decimal":
			e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
		"number":
			e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	return e


## Label above a control.
static func field(title: String, control: Control, hint: String = "") -> VBoxContainer:
	var v := vbox(6)
	v.add_child(label(title, "Section"))
	v.add_child(control)
	if hint != "":
		v.add_child(label(hint, "Faint", true))
	return v


## items: Array of [id, label]. Returns OptionButton; read value with option_value().
static func option(items: Array, selected_id: Variant = null) -> OptionButton:
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.fit_to_longest_item = false
	o.focus_mode = Control.FOCUS_NONE
	o.clip_text = true
	var sel := 0
	for i in items.size():
		if items[i][0] is String and items[i][0] == "__sep__":
			o.add_separator(items[i][1])
			continue
		o.add_item(items[i][1])
		var idx := o.item_count - 1
		o.set_item_metadata(idx, items[i][0])
		if typeof(items[i][0]) == typeof(selected_id) and items[i][0] == selected_id:
			sel = idx
	if o.item_count > 0:
		o.select(sel)
		if o.is_item_separator(sel):
			for i in o.item_count:
				if not o.is_item_separator(i):
					o.select(i)
					break
	return o


static func option_value(o: OptionButton) -> Variant:
	if o.selected < 0:
		return null
	return o.get_item_metadata(o.selected)


## Row of pill buttons, one selected. cb(index) on change.
static func segmented(labels: Array, selected: int, cb: Callable) -> HBoxContainer:
	var h := hbox(4)
	var group := ButtonGroup.new()
	for i in labels.size():
		var b := button(labels[i], "Chip")
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == selected
		b.pressed.connect(func(): cb.call(i))
		h.add_child(b)
	return h


## Vertical list of large selectable cards. items: [[id, title, description]]
static func choices(items: Array, selected_id: String, cb: Callable) -> VBoxContainer:
	var v := vbox(8)
	var normal := AppTheme.box(AppTheme.c("surface"), 14, AppTheme.c("border"), 16, 12)
	var on := AppTheme.box(AppTheme.c("surface"), 14, AppTheme.c("text"), 16, 12)
	on.set_border_width_all(2)
	var cards := []
	for it in items:
		var p := PanelContainer.new()
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.add_theme_stylebox_override("panel", on if it[0] == selected_id else normal)
		var inner := vbox(2)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := label(it[1], "Strong")
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(t)
		if it.size() > 2 and it[2] != "":
			var d := label(it[2], "Muted", true)
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(d)
		p.add_child(inner)
		cards.append(p)
		var id: String = it[0]
		p.gui_input.connect(func(e: InputEvent):
			if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed):
				for c in cards:
					c.add_theme_stylebox_override("panel", normal)
				p.add_theme_stylebox_override("panel", on)
				cb.call(id))
		v.add_child(p)
	return v


## Two-column row: label left, value right.
static func kv(left: String, right: String, right_variation: String = "") -> HBoxContainer:
	var h := hbox()
	h.add_child(expand(label(left, "Muted")))
	var r := label(right, right_variation)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(r)
	return h


static func separator() -> HSeparator:
	return HSeparator.new()


static func gain_variation(cents: int) -> String:
	if cents > 0:
		return "Gain"
	if cents < 0:
		return "Loss"
	return "Muted"


static func clear(n: Node) -> void:
	for ch in n.get_children():
		n.remove_child(ch)
		ch.queue_free()


## Accent shades for charts (few colours: one hue, varying strength).
static func shade(i: int, n: int) -> Color:
	var acc := AppTheme.c("accent")
	var t := 0.0 if n <= 1 else float(i) / float(n - 1)
	var bg := AppTheme.c("surface2")
	return acc.lerp(bg, t * 0.8)
