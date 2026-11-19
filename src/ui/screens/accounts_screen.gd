extends Screen
## Wealth tab: every account (PEA, Livret A…) with its holdings and current values.

const AccountEdit = preload("res://src/ui/screens/account_edit_screen.gd")
const HoldingEdit = preload("res://src/ui/screens/holding_edit_screen.gd")
const HoldingView = preload("res://src/ui/screens/holding_screen.gd")


func title() -> String:
	return "Wealth"


func header_actions() -> Array:
	return [Ui.button("New account", "Ghost", func(): app.push(AccountEdit.new()))]


func refresh() -> void:
	Ui.clear(self)
	var p: Portfolio = Store.portfolio
	var cur: String = Store.setting("currency", "EUR")
	if Store.data["accounts"].is_empty():
		var c := Ui.card(12)
		var b := Ui.body(c)
		b.add_child(Ui.label("No accounts yet", "Strong"))
		b.add_child(Ui.label("An account is where your money sits: a PEA, a life-insurance contract, a bank, a crypto exchange…", "Muted", true))
		b.add_child(Ui.button("Add an account", "Primary", func(): app.push(AccountEdit.new())))
		add_child(c)
		return
	for a in Store.data["accounts"]:
		var c := Ui.card(4)
		var b := Ui.body(c)
		var hs := p.holdings_in(a["id"])
		var total := 0
		var states := {}
		for h in hs:
			states[h["id"]] = p.holding_state(h)
			total += states[h["id"]]["value"]
		# Biggest first; sold/emptied holdings at the end.
		hs.sort_custom(func(x, y):
			var sx: Dictionary = states[x["id"]]
			var sy: Dictionary = states[y["id"]]
			if sx["closed"] != sy["closed"]:
				return sy["closed"]
			return absi(sx["value"]) > absi(sy["value"]))
		var head := Ui.hbox()
		var titles := Ui.vbox(0)
		titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		titles.add_child(Ui.shrinkable(Ui.label(a["name"], "Strong")))
		var sub := Catalog.account_kind_label(a.get("kind", "other"))
		if a.get("institution", "") != "":
			sub += " · " + a["institution"]
		titles.add_child(Ui.shrinkable(Ui.label(sub, "Muted")))
		head.add_child(titles)
		var tv := Ui.label(Money.fmt(total, cur), "Strong")
		head.add_child(tv)
		var edit := Ui.button("⋯", "Ghost", func(): app.push(AccountEdit.new(a["id"])))
		edit.add_theme_color_override("font_color", AppTheme.c("muted"))
		head.add_child(edit)
		b.add_child(head)
		if not hs.is_empty():
			b.add_child(Ui.spacer(4))
		for h in hs:
			b.add_child(_holding_row(h, states[h["id"]], cur))
		var add := Ui.button("+ Add a holding", "Ghost", func(): app.push(HoldingEdit.new("", a["id"])))
		add.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_child(add)
		add_child(c)


func _holding_row(h: Dictionary, s: Dictionary, cur: String) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = "Row"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 58)
	btn.pressed.connect(func(): app.push(HoldingView.new(h["id"])))
	var row := Ui.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_right = -4
	var left := Ui.vbox(0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_l := Ui.label(h.get("name", "?"))
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	left.add_child(name_l)
	var t: Dictionary = Catalog.holding_type(h.get("type", "other"))
	var info: String = t["label"]
	if s["closed"]:
		info += " · closed"
	elif s["missing_price"]:
		info += " · no price yet"
	elif s["estimated"]:
		info += " · interest estimated"
	left.add_child(Ui.shrinkable(Ui.label(info, "Muted")))
	row.add_child(left)
	var right := Ui.vbox(0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	var v := Ui.label(Money.fmt(s["value"], cur), "")
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(v)
	if h.get("type", "") != "loan":
		var g := Ui.label(Money.pct(s["gain"], s["invested"]), Ui.gain_variation(s["gain"]))
		g.add_theme_font_size_override("font_size", 13)
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(g)
	row.add_child(right)
	for n in [row, left, right]:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in left.get_children() + right.get_children():
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)
	return btn
