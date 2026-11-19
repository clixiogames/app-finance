extends Screen
## Create or edit a holding: an ETF, a fund, a Livret A, crypto, property…

var holding_id := ""
var account_id := ""
var _h: Dictionary = {}
var _account: OptionButton
var _type: OptionButton
var _name: LineEdit
var _dynamic: VBoxContainer
var _built := false
# market selection
var _price_key := ""
var _currency := ""
var _quote_currency := ""
var _picked_label: Label
var _results: VBoxContainer
var _query: LineEdit
# interest
var _rate: LineEdit
var _mode := "auto"


func _init(hid: String = "", aid: String = "") -> void:
	super()
	holding_id = hid
	account_id = aid


func title() -> String:
	return "New holding" if holding_id == "" else "Edit holding"


func auto_refresh() -> bool:
	return false


func refresh() -> void:
	if _built:
		return
	_built = true
	if holding_id != "":
		_h = Store.portfolio.holding(holding_id)
		account_id = _h.get("account_id", "")
		_price_key = _h.get("price_key", "")
		_currency = _h.get("currency", "")
		_quote_currency = _h.get("quote_currency", "")
		_mode = _h.get("interest_mode", Store.setting("interest_mode", "auto"))
	else:
		_mode = Store.setting("interest_mode", "auto")
	var accs := []
	for a in Store.data["accounts"]:
		accs.append([a["id"], a["name"]])
	_account = Ui.option(accs, account_id)
	add_child(Ui.field("Account", _account))
	var types := []
	var last_group := ""
	for t in Catalog.HOLDING_TYPES:
		if t["group"] != last_group:
			types.append(["__sep__", t["group"]])
			last_group = t["group"]
		types.append([t["id"], t["label"]])
	_type = Ui.option(types, _h.get("type", _default_type()))
	_type.item_selected.connect(func(_i):
		_name.placeholder_text = _placeholder()
		_build_dynamic())
	add_child(Ui.field("What is it?", _type))
	_name = Ui.line_edit("", _h.get("name", ""))
	_name.placeholder_text = _placeholder()
	add_child(Ui.field("Name", _name))
	_dynamic = Ui.vbox(14)
	add_child(_dynamic)
	_build_dynamic()
	add_child(Ui.spacer(6))
	add_child(Ui.button("Save" if holding_id != "" else "Save and add a deposit", "Primary", _save))
	if holding_id != "":
		add_child(Ui.button("Delete holding", "Danger", func():
			app.confirm("Delete this holding?", "All its deposits and history will be deleted. This cannot be undone.", "Delete", func():
				Store.delete_holding(holding_id)
				app.pop_to_root(), true)))


func _default_type() -> String:
	var a: Dictionary = Store.portfolio.account(account_id)
	match a.get("kind", ""):
		"bank_savings":
			return "livret_a"
		"crypto":
			return "crypto"
		"assurance_vie":
			return "euro_fund"
		"property":
			return "property"
		"employee", "per":
			return "retirement"
	return "etf"


func _placeholder() -> String:
	var t := _type_info()
	match t["valuation"]:
		"market":
			return "Filled in when you pick it below"
	return t["label"]


func _type_info() -> Dictionary:
	return Catalog.holding_type(Ui.option_value(_type))


func _build_dynamic() -> void:
	Ui.clear(_dynamic)
	var t := _type_info()
	match t["valuation"]:
		"market":
			_build_market(t)
		"interest":
			_build_interest(t)
		_:
			var txt := "You update its value yourself from time to time (for example from your yearly statement). Use “Value update” in the holding."
			if t["id"] == "loan":
				txt = "Enter the amount you still owe with “Value update” whenever you like. It is subtracted from your total wealth."
			_dynamic.add_child(Ui.label(txt, "Muted", true))


func _build_market(t: Dictionary) -> void:
	var is_crypto: bool = t["source"] == "coingecko"
	if not _price_key.begins_with("cg:" if is_crypto else "av:"):
		_price_key = ""
	var hint := "Search by name or symbol, e.g. “bitcoin”" if is_crypto else "Search by ISIN, ticker or name, e.g. “IE00B4L5Y983” or “MSCI World”"
	_query = Ui.line_edit("ISIN, ticker or name" if not is_crypto else "Coin name or symbol")
	var row := Ui.hbox()
	row.add_child(_query)
	row.add_child(Ui.button("Search", "", func(): _search(is_crypto)))
	_query.text_submitted.connect(func(_t): _search(is_crypto))
	_dynamic.add_child(Ui.field("Find the real price", row, hint))
	_picked_label = Ui.label("", "Accent", true)
	_dynamic.add_child(_picked_label)
	_update_picked()
	_results = Ui.vbox(4)
	_dynamic.add_child(_results)
	if not is_crypto:
		if not PriceService.has_key():
			var note := Ui.card(8)
			var nb := Ui.body(note)
			nb.add_child(Ui.label("Live prices need your free price key", "Strong"))
			nb.add_child(Ui.label("You can save this holding now — the value will show the money you put in until prices are connected.", "Muted", true))
			nb.add_child(Ui.button("Set up live prices (1 minute)", "", func(): app.push(preload("res://src/ui/screens/price_setup_screen.gd").new())))
			_dynamic.add_child(note)
		_dynamic.add_child(Ui.label("Funds without a public price (common in assurance vie): choose “Euro fund” or “Other asset” and update the value yourself.", "Faint", true))


func _update_picked() -> void:
	if _picked_label == null:
		return
	if _price_key == "":
		_picked_label.text = "No price source selected yet."
		_picked_label.theme_type_variation = "Muted"
	else:
		var sym := _price_key.substr(_price_key.find(":") + 1)
		var where := ""
		if _price_key.begins_with("av:"):
			where = " · " + PriceParsers.exchange_for_symbol(sym)["label"]
		_picked_label.text = "✓ " + sym + where + ((" · " + _currency) if _currency != "" else "")
		_picked_label.theme_type_variation = "Accent"


func _search(is_crypto: bool) -> void:
	var q := _query.text.strip_edges()
	if q == "":
		return
	Ui.clear(_results)
	_results.add_child(Ui.label("Searching…", "Muted"))
	var r: Dictionary
	if is_crypto:
		r = await PriceService.search_crypto(q)
	else:
		r = await PriceService.search_market(q)
	if not is_instance_valid(_results):
		return
	Ui.clear(_results)
	if not r["ok"]:
		_results.add_child(Ui.label(r["error"], "Loss", true))
		return
	if r["results"].is_empty():
		_results.add_child(Ui.label("Nothing found. Try the ISIN from your statement, the ticker (e.g. CW8) or the fund's name.", "Muted", true))
		return
	for it in r["results"]:
		var b := Button.new()
		b.theme_type_variation = "Row"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 54)
		var v := Ui.vbox(0)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 4
		v.offset_right = -4
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		var title_l := Ui.shrinkable(Ui.label(it["name"]))
		var sub := ""
		if is_crypto:
			sub = it["symbol"]
		else:
			sub = "%s · %s%s" % [it["symbol"], it["exchange"], (" · " + it["currency"]) if it.get("currency", "") != "" else ""]
		var sub_l := Ui.shrinkable(Ui.label(sub, "Muted"))
		v.add_child(title_l)
		v.add_child(sub_l)
		for n in [v, title_l, sub_l]:
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var item: Dictionary = it
		b.pressed.connect(func():
			if is_crypto:
				_price_key = "cg:" + item["id"]
				_currency = Store.setting("currency", "EUR")
				_quote_currency = ""
			else:
				_price_key = "av:" + item["symbol"]
				_quote_currency = item.get("currency", "")
				_currency = "GBP" if _quote_currency in ["GBX", "GBp"] else _quote_currency
				if _currency == "":
					_currency = PriceParsers.exchange_for_symbol(item["symbol"]).get("currency", "")
			if _name.text.strip_edges() == "":
				_name.text = item["name"]
			Ui.clear(_results)
			_update_picked())
		_results.add_child(b)


func _build_interest(t: Dictionary) -> void:
	var src: String = t.get("rate", "fixed")
	if src != "fixed":
		var bps := RegulatedRates.current_bps(src)
		_dynamic.add_child(Ui.label("Official %s rate today: %s. Rate changes are applied automatically." % [RegulatedRates.LABELS[src], Money.fmt_bps(bps)], "Muted", true))
		_rate = null
	else:
		var cur_bps: int = _h.get("fixed_rate_bps", 0)
		_rate = Ui.line_edit("e.g. 3,00", Money.format_scaled(cur_bps, 100, 2) if cur_bps > 0 else "", "decimal")
		_dynamic.add_child(Ui.field("Annual interest rate (%)", _rate))
	var modes := []
	for k in Catalog.INTEREST_MODES:
		var desc := ""
		match k:
			"auto":
				desc = "Calculated with the official half-month rules. Marked as estimated."
			"manual":
				desc = "Add the interest when your bank pays it (usually once a year)."
			"none":
				desc = "Only deposits and withdrawals are tracked."
		modes.append([k, Catalog.INTEREST_MODES[k], desc])
	_dynamic.add_child(Ui.field("Interest", Ui.choices(modes, _mode, func(id): _mode = id)))


func _save() -> void:
	var t := _type_info()
	var nm := _name.text.strip_edges()
	if nm == "":
		nm = t["label"]
	var fields := {
		"account_id": Ui.option_value(_account),
		"type": t["id"],
		"name": nm,
	}
	match t["valuation"]:
		"market":
			if _price_key == "":
				app.toast("Search and pick the instrument first")
				return
			fields["price_key"] = _price_key
			fields["currency"] = _currency if _currency != "" else _h.get("currency", Store.setting("currency", "EUR"))
			fields["quote_currency"] = _quote_currency
		"interest":
			fields["rate_source"] = t.get("rate", "fixed")
			fields["interest_mode"] = _mode
			if _rate != null:
				var r: Variant = Money.parse_decimal(_rate.text, 100) if _rate.text.strip_edges() != "" else 0
				if r == null or r < 0 or r > 5000:
					app.toast("Enter a valid rate, e.g. 3,00")
					return
				fields["fixed_rate_bps"] = r
			fields["price_key"] = ""
		_:
			fields["price_key"] = ""
	if holding_id == "":
		var hid := Store.add_holding(fields)
		app.pop()
		app.push(preload("res://src/ui/screens/holding_screen.gd").new(hid))
		app.push(preload("res://src/ui/screens/movement_edit_screen.gd").new(hid, "deposit" if t["id"] != "loan" else "valuation"))
		if fields.get("price_key", "") != "":
			PriceService.refresh_all()
	else:
		var key_changed: bool = fields.get("price_key", "") != _h.get("price_key", "")
		Store.update_holding(holding_id, fields)
		app.pop()
		if key_changed and fields.get("price_key", "") != "":
			PriceService.refresh_all()
