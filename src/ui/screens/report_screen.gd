extends Screen
## Dividends, interest and fees per calendar year.

static var year := 0


func title() -> String:
	return "Dividends, interest & fees"


func refresh() -> void:
	Ui.clear(self)
	var p: Portfolio = Store.portfolio
	var cur: String = Store.setting("currency", "EUR")
	var years := p.report_years()
	if years.is_empty():
		add_child(Ui.label("Nothing recorded yet.", "Muted"))
		return
	if year == 0 or year not in years:
		year = years[0]

	# Year selector
	var nav := Ui.hbox(4)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	var prev := Ui.button("‹", "Ghost", func():
		year -= 1
		refresh())
	prev.disabled = year <= years[-1]
	nav.add_child(prev)
	var yl := Ui.label(str(year), "Strong")
	yl.custom_minimum_size = Vector2(90, 0)
	yl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(yl)
	var next := Ui.button("›", "Ghost", func():
		year += 1
		refresh())
	next.disabled = year >= years[0]
	nav.add_child(next)
	add_child(nav)

	var r := p.income_report(year)

	# Totals
	var tc := Ui.card(6)
	var tb := Ui.body(tc)
	tb.add_child(Ui.label("Net result" + (" so far" if r["partial"] else ""), "Muted"))
	tb.add_child(Ui.label(Money.fmt(r["net"], cur, true), "Big"))
	tb.add_child(Ui.spacer(4))
	tb.add_child(Ui.kv("Dividends received", Money.fmt(r["dividends"], cur)))
	tb.add_child(Ui.kv("Interest" + (" (estimated)" if r["estimated"] else ""), Money.fmt(r["interest"], cur)))
	tb.add_child(Ui.kv("Fees paid", Money.fmt(-r["fees"], cur) if r["fees"] > 0 else Money.fmt(0, cur), "Loss" if r["fees"] > 0 else ""))
	add_child(tc)

	# Per holding
	var hc := Ui.card(2)
	var hb := Ui.body(hc)
	hb.add_child(Ui.label("By holding", "Strong"))
	if r["rows"].is_empty():
		hb.add_child(Ui.label("No dividends, interest or fees recorded in %d." % year, "Muted", true))
	for row in r["rows"]:
		var btn := Button.new()
		btn.theme_type_variation = "Row"
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 56)
		var hid: String = row["id"]
		btn.pressed.connect(func(): app.push(preload("res://src/ui/screens/holding_screen.gd").new(hid)))
		var line := Ui.hbox(10)
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.offset_left = 4
		line.offset_right = -4
		var left := Ui.vbox(0)
		left.alignment = BoxContainer.ALIGNMENT_CENTER
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_child(Ui.shrinkable(Ui.label(row["name"])))
		var parts := []
		if row["dividends"] != 0:
			parts.append("dividends " + Money.fmt(row["dividends"], cur, false, 0))
		if row["interest"] != 0:
			parts.append("interest " + Money.fmt(row["interest"], cur, false, 0) + (" est." if row["estimated"] else ""))
		if row["fees"] != 0:
			parts.append("fees " + Money.fmt(row["fees"], cur, false, 0))
		left.add_child(Ui.shrinkable(Ui.label(" · ".join(parts), "Muted")))
		line.add_child(left)
		var net: int = row["dividends"] + row["interest"] - row["fees"]
		var v := Ui.label(Money.fmt(net, cur, true), Ui.gain_variation(net))
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(v)
		for n in [line, left, v] + left.get_children():
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(line)
		hb.add_child(btn)
	add_child(hc)

	# All years
	if years.size() > 1:
		var yc := Ui.card(6)
		var yb := Ui.body(yc)
		yb.add_child(Ui.label("Every year", "Strong"))
		var head := Ui.hbox()
		for t in [["Year", 60], ["Dividends", 0], ["Interest", 0], ["Fees", 0]]:
			var l := Ui.label(t[0], "Faint")
			if t[1] > 0:
				l.custom_minimum_size = Vector2(t[1], 0)
			else:
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			head.add_child(l)
		yb.add_child(head)
		for y in years:
			var ry := p.income_report(y)
			var line2 := Ui.hbox()
			var y_l := Ui.label(str(y), "Strong" if y == year else "")
			y_l.custom_minimum_size = Vector2(60, 0)
			line2.add_child(y_l)
			for v2 in [ry["dividends"], ry["interest"], -ry["fees"]]:
				var l2 := Ui.label(Money.fmt(v2, cur, false, 0), "Small")
				l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				line2.add_child(l2)
			yb.add_child(line2)
		add_child(yc)

	var notes := Ui.vbox(4)
	notes.add_child(Ui.label("Dividends and fees come from the entries you record (“Dividend paid out”, “Fee”, and fees included in deposits). Interest on savings accounts set to automatic is estimated from official rates.", "Faint", true))
	notes.add_child(Ui.label("For information only — not tax advice. Your bank's yearly statement (IFU) is the official figure.", "Faint", true))
	add_child(notes)
