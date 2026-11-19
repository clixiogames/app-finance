extends Screen
## Daily income & expenses from bank statements — kept separate from Wealth.

const ImportScreen = preload("res://src/ui/screens/spending_import_screen.gd")
const TxEdit = preload("res://src/ui/screens/transaction_edit_screen.gd")

static var month := ""
static var filter_cat := ""


func title() -> String:
	return "Spending"


func header_actions() -> Array:
	if Store.transactions().is_empty():
		return []
	return [Ui.button("Import", "Ghost", pick_file)]


func pick_file() -> void:
	Files.open_bytes(PackedStringArray(["*.csv", "*.ofx", "*.txt", "*.CSV", "*.OFX"]), func(bytes: PackedByteArray, fname: String):
		var result := Spending.parse(Spending.decode(bytes))
		app.push(ImportScreen.new(result, fname)), func(err: String): app.toast(err))


func refresh() -> void:
	Ui.clear(self)
	var cur: String = Store.setting("currency", "EUR")
	var txs: Array = Store.transactions()
	if txs.is_empty():
		_empty_state()
		return
	if month == "":
		month = _latest_month(txs)

	# Month selector
	var nav := Ui.hbox(4)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_child(Ui.button("‹", "Ghost", func():
		month = Dates.month_key_add(month, -1)
		filter_cat = ""
		refresh()))
	var ml := Ui.label(Dates.month_label(month), "Strong")
	ml.custom_minimum_size = Vector2(120, 0)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(ml)
	var next := Ui.button("›", "Ghost", func():
		month = Dates.month_key_add(month, 1)
		filter_cat = ""
		refresh())
	next.disabled = month >= Dates.month_key(Dates.today())
	nav.add_child(next)
	add_child(nav)

	var s := Spending.month_summary(txs, month)

	# Summary
	var sc := Ui.card(6)
	var sb := Ui.body(sc)
	var row := Ui.hbox(12)
	row.add_child(_stat("Money in", Money.fmt(s["income"], cur, false, 0), ""))
	row.add_child(_stat("Money out", Money.fmt(-s["expenses"], cur, false, 0), ""))
	row.add_child(_stat("Balance", Money.fmt(s["net"], cur, true, 0), Ui.gain_variation(s["net"])))
	sb.add_child(row)
	if s["transfers"] != 0:
		sb.add_child(Ui.label("Transfers between your own accounts are not counted (%s)." % Money.fmt(s["transfers"], cur, true, 0), "Faint", true))
	add_child(sc)

	# Categories
	var cats: Dictionary = s["by_category"]
	var exp_ids := []
	for k in cats:
		if cats[k] < 0:
			exp_ids.append(k)
	exp_ids.sort_custom(func(a, b): return cats[a] < cats[b])
	if not exp_ids.is_empty():
		var cc := Ui.card(10)
		var cb := Ui.body(cc)
		var ch := Ui.hbox()
		ch.add_child(Ui.expand(Ui.label("Where it went", "Strong")))
		if filter_cat != "":
			ch.add_child(Ui.button("Show all", "Ghost", func():
				filter_cat = ""
				refresh()))
		cb.add_child(ch)
		var total_out: int = -s["expenses"]
		for id in exp_ids:
			cb.add_child(_category_row(id, -cats[id], total_out, cur))
		add_child(cc)

	# Trend
	var tc := Ui.card(8)
	var tb := Ui.body(tc)
	tb.add_child(Ui.label("Last 6 months", "Strong"))
	var chart := TrendChart.new()
	chart.set_items(Spending.trend(txs, 6, month), cur)
	tb.add_child(chart)
	var legend := Ui.hbox(16)
	legend.add_child(_dot("Money in", AppTheme.c("faint")))
	legend.add_child(_dot("Money out", AppTheme.c("accent")))
	tb.add_child(legend)
	add_child(tc)

	# Transactions
	var lc := Ui.card(2)
	var lb := Ui.body(lc)
	var lh := Ui.hbox()
	lh.add_child(Ui.expand(Ui.label("Transactions" + ("" if filter_cat == "" else " · " + Spending.category_label(filter_cat)), "Strong")))
	lh.add_child(Ui.button("+ Add", "Ghost", func(): app.push(TxEdit.new())))
	lb.add_child(lh)
	var list := txs.filter(func(t): return Dates.month_key(t["date"]) == month and (filter_cat == "" or t.get("category", "") == filter_cat))
	list.sort_custom(func(a, b): return a["date"] > b["date"] or (a["date"] == b["date"] and a["amount_cents"] < b["amount_cents"]))
	if list.is_empty():
		lb.add_child(Ui.label("No transactions this month.", "Muted"))
	var last_date := ""
	for t in list:
		if t["date"] != last_date:
			last_date = t["date"]
			var dl := Ui.label(Dates.pretty(t["date"]), "Section")
			lb.add_child(Ui.spacer(4))
			lb.add_child(dl)
		lb.add_child(_tx_row(t, cur))
	add_child(lc)
	add_child(Ui.label("Imported from your bank statements. Not linked to your Wealth section.", "Faint", true))


func _latest_month(txs: Array) -> String:
	var latest := ""
	for t in txs:
		if t["date"] > latest:
			latest = t["date"]
	return Dates.month_key(latest) if latest != "" else Dates.month_key(Dates.today())


func _stat(t: String, v: String, variation: String) -> VBoxContainer:
	var b := Ui.vbox(0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_child(Ui.label(t, "Muted"))
	var l := Ui.label(v, variation if variation != "" else "Strong")
	l.add_theme_font_size_override("font_size", 18)
	b.add_child(l)
	return b


func _dot(text: String, col: Color) -> HBoxContainer:
	var h := Ui.hbox(6)
	var d := ColorRect.new()
	d.color = col
	d.custom_minimum_size = Vector2(10, 10)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(d)
	h.add_child(Ui.label(text, "Muted"))
	return h


func _category_row(id: String, amount: int, total: int, cur: String) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = "Row"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 46)
	btn.pressed.connect(func():
		filter_cat = "" if filter_cat == id else id
		refresh())
	var v := Ui.vbox(4)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 4
	v.offset_right = -4
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var h := Ui.hbox()
	h.add_child(Ui.expand(Ui.label(Spending.category_label(id), "Strong" if filter_cat == id else "")))
	h.add_child(Ui.label(Money.pct(amount, total, false, 0), "Muted"))
	var al := Ui.label(Money.fmt(amount, cur, false, 0), "Strong")
	al.custom_minimum_size = Vector2(80, 0)
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(al)
	v.add_child(h)
	var bar := AllocBar.new()
	bar.custom_minimum_size = Vector2(0, 5)
	bar.set_values([amount, maxi(total - amount, 0)], [AppTheme.c("accent"), Color(0, 0, 0, 0)])
	v.add_child(bar)
	for n in [v, h, bar] + h.get_children():
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(v)
	return btn


func _tx_row(t: Dictionary, cur: String) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = "Row"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 52)
	var tid: String = t["id"]
	btn.pressed.connect(func(): app.push(TxEdit.new(tid)))
	var row := Ui.hbox(10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_right = -4
	var left := Ui.vbox(0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shown := Spending.merchant_key(t["label"]).capitalize()
	left.add_child(Ui.shrinkable(Ui.label(shown if shown != "" else t["label"])))
	left.add_child(Ui.shrinkable(Ui.label(Spending.category_label(t.get("category", "other")), "Muted")))
	row.add_child(left)
	var amt: int = t["amount_cents"]
	var v := Ui.label(Money.fmt(amt, cur, true), "Gain" if amt > 0 else "")
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	for n in [row, left, v] + left.get_children():
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)
	return btn


func _empty_state() -> void:
	var c := Ui.card(12)
	var b := Ui.body(c)
	b.add_child(Ui.label("See where your money goes", "Title"))
	b.add_child(Ui.label("Import a statement from your bank (CSV or OFX). Transactions are sorted into categories automatically, and the app learns from your corrections.", "Muted", true))
	b.add_child(Ui.button("Import a bank statement", "Primary", pick_file))
	b.add_child(Ui.button("Add a transaction by hand", "", func(): app.push(TxEdit.new())))
	add_child(c)
	var h := Ui.card(6)
	var hb := Ui.body(h)
	hb.add_child(Ui.label("How to get the file", "Strong"))
	hb.add_child(Ui.label("On your bank's website, open your account, then look for “Télécharger”, “Exporter” or “Export” and choose CSV (or OFX / Money). Most French banks work: Boursorama, Crédit Agricole, BNP, Société Générale, LCL, Caisse d'Épargne, La Banque Postale, Crédit Mutuel, Fortuneo, Revolut, N26…", "Muted", true))
	hb.add_child(Ui.label("Your statement stays on this device. This section is separate from Wealth.", "Faint", true))
	add_child(h)
