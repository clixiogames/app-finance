extends Screen
## One holding: value, gain, units, price, and the full history of movements.

const MovementEdit = preload("res://src/ui/screens/movement_edit_screen.gd")
const HoldingEdit = preload("res://src/ui/screens/holding_edit_screen.gd")

var holding_id := ""


func _init(hid: String = "") -> void:
	super()
	holding_id = hid


func title() -> String:
	return Store.portfolio.holding(holding_id).get("name", "Holding")


func header_actions() -> Array:
	return [Ui.button("Edit", "Ghost", func(): app.push(HoldingEdit.new(holding_id)))]


func refresh() -> void:
	Ui.clear(self)
	var p: Portfolio = Store.portfolio
	var h := p.holding(holding_id)
	if h.is_empty():
		return
	var cur: String = Store.setting("currency", "EUR")
	var s := p.holding_state(h)
	var t := Catalog.holding_type(h.get("type", "other"))

	var hero := Ui.card(4)
	var hb := Ui.body(hero)
	var sub: String = t["label"] + " · " + p.account(h.get("account_id", "")).get("name", "")
	hb.add_child(Ui.shrinkable(Ui.label(sub, "Muted")))
	hb.add_child(Ui.label(Money.fmt(s["value"], cur), "Big"))
	if h.get("type", "") != "loan":
		hb.add_child(Ui.label("%s  (%s)" % [Money.fmt(s["gain"], cur, true), Money.pct(s["gain"], s["invested"])], Ui.gain_variation(s["gain"])))
		hb.add_child(Ui.spacer(6))
		hb.add_child(Ui.kv("Money invested", Money.fmt(s["invested"], cur)))
		if s["deposits"] != s["invested"]:
			hb.add_child(Ui.kv("Deposits / withdrawals", "%s / %s" % [Money.fmt(s["deposits"], cur, false, 0), Money.fmt(s["withdrawals"], cur, false, 0)]))
	match s["valuation"]:
		"market":
			hb.add_child(Ui.kv("Units held", Money.fmt_units(s["units"])))
			if s["price_date"] != "":
				var pcur: String = s["currency"] if s["currency"] != "" else cur
				hb.add_child(Ui.kv("Last price", "%s · %s" % [Money.fmt_price(s["price4"], pcur), Dates.pretty(s["price_date"])]))
				if pcur != cur:
					hb.add_child(Ui.kv("Exchange rate", "1 %s = %s %s" % [pcur, Money.format_scaled(p.fx_at(pcur, Dates.today()), Money.FX_SCALE, 4), cur]))
			if s["missing_price"]:
				hb.add_child(Ui.label("No price yet — tap Refresh on the Overview, or enter exact units in each deposit.", "Faint", true))
			if s["dividends"] > 0:
				hb.add_child(Ui.kv("Dividends received", Money.fmt(s["dividends"], cur)))
			var pk: String = h.get("price_key", "")
			var sym := pk.substr(pk.find(":") + 1)
			if pk.begins_with("av:"):
				hb.add_child(Ui.kv("Listing", "%s · %s" % [sym, PriceParsers.exchange_for_symbol(sym)["label"]]))
				hb.add_child(Ui.label("Prices: Alpha Vantage, end of day.", "Faint"))
				if not PriceService.has_key():
					hb.add_child(Ui.button("Set up live prices", "", func(): app.push(preload("res://src/ui/screens/price_setup_screen.gd").new())))
			elif pk.begins_with("cg:"):
				hb.add_child(Ui.label("Prices: CoinGecko (data provided by CoinGecko).", "Faint"))
		"interest":
			var src: String = h.get("rate_source", "fixed")
			hb.add_child(Ui.kv("Interest rate today", Money.fmt_bps(RegulatedRates.current_bps(src, h.get("fixed_rate_bps", 0)))))
			hb.add_child(Ui.kv("Interest", Catalog.INTEREST_MODES.get(h.get("interest_mode", "auto"), "")))
			if s["interest"] != 0:
				hb.add_child(Ui.kv("Interest so far" + (" (estimated)" if s["estimated"] else ""), Money.fmt(s["interest"], cur)))
	var ar := p.annual_return(holding_id)
	if ar["ok"] and h.get("type", "") != "loan":
		hb.add_child(Ui.kv("Annual return", Money.pct(ar["bps"], 10000) + " / yr", Ui.gain_variation(ar["bps"])))
	add_child(hero)

	if p.movements(holding_id).size() >= 1 and h.get("type", "") != "loan":
		var cc := Ui.card(8)
		var cb := Ui.body(cc)
		cb.add_child(Ui.label("Value over time", "Strong"))
		var ch := LineChart.new()
		ch.custom_minimum_size = Vector2(0, 170)
		ch.set_points(p.series(0, holding_id), cur)
		cb.add_child(ch)
		add_child(cc)

	var actions := Ui.hbox(8)
	var kinds := Catalog.movement_kinds_for(h)
	var first: String = kinds[0]
	actions.add_child(Ui.expand(Ui.button("+ " + Catalog.MOVEMENT_KINDS[first], "Primary", func(): app.push(MovementEdit.new(holding_id, first)))))
	if kinds.size() > 1:
		actions.add_child(Ui.expand(Ui.button("Other…", "", func(): app.push(MovementEdit.new(holding_id, kinds[1])))))
	add_child(actions)

	var rules := Store.recurring_for(holding_id)
	if not rules.is_empty():
		var rc := Ui.card(4)
		var rb := Ui.body(rc)
		rb.add_child(Ui.label("Repeats every month", "Strong"))
		for r in rules:
			var row := Ui.hbox()
			var txt := "%s %s on day %d" % [Catalog.MOVEMENT_KINDS.get(r["kind"], r["kind"]), Money.fmt(r["amount_cents"], cur, false, 0), int(r["day"])]
			row.add_child(Ui.expand(Ui.label(txt)))
			var rid: String = r["id"]
			row.add_child(Ui.button("Stop", "Ghost", func():
				app.confirm("Stop repeating?", "Entries already added stay in the history.", "Stop", func(): Store.delete_recurring(rid))))
			rb.add_child(row)
		add_child(rc)

	var hist := Ui.card(2)
	var hib := Ui.body(hist)
	hib.add_child(Ui.label("History", "Strong"))
	var movs := p.movements(holding_id).duplicate()
	movs.reverse()
	if movs.is_empty():
		hib.add_child(Ui.label("Nothing recorded yet.", "Muted"))
	for mv in movs:
		hib.add_child(_movement_row(h, mv, cur))
	add_child(hist)


func _movement_row(h: Dictionary, mv: Dictionary, cur: String) -> Button:
	var p: Portfolio = Store.portfolio
	var btn := Button.new()
	btn.theme_type_variation = "Row"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 54)
	var mid: String = mv["id"]
	btn.pressed.connect(func(): app.push(MovementEdit.new(holding_id, "", mid)))
	var row := Ui.hbox(10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_right = -4
	var left := Ui.vbox(0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(Ui.shrinkable(Ui.label(Catalog.MOVEMENT_KINDS.get(mv["kind"], mv["kind"]))))
	var detail := Dates.pretty(mv["date"])
	if Catalog.holding_type(h.get("type", ""))["valuation"] == "market" and mv["kind"] in ["deposit", "withdrawal"]:
		var u := p.movement_units(h, mv)
		if u >= 0:
			detail += " · %s units" % Money.fmt_units(u)
			var pr := p.movement_price(h, mv)
			if pr > 0:
				detail += " @ " + Money.fmt_price(pr, h.get("currency", cur) if h.get("currency", "") != "" else cur)
		else:
			detail += " · waiting for price"
	left.add_child(Ui.shrinkable(Ui.label(detail, "Muted")))
	row.add_child(left)
	var amt: int = mv.get("amount_cents", 0)
	var shown := amt
	if mv["kind"] in ["withdrawal", "fee"]:
		shown = -amt
	var v := Ui.label(Money.fmt(shown, cur, mv["kind"] != "valuation"), "Strong" if mv["kind"] == "deposit" else "")
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	for n in [row, left, v] + left.get_children():
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)
	return btn
