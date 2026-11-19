extends Screen
## Record money going in or out: amount + date. For funds/ETFs/crypto the app
## works out the units from that day's real price (you can enter exact figures instead).

var holding_id := ""
var kind := "deposit"
var movement_id := ""
var _mv: Dictionary = {}
var _holding_opt: OptionButton
var _kind_opt: OptionButton
var _date: DateField
var _amount: LineEdit
var _fee: LineEdit
var _exact: CheckButton
var _units: LineEdit
var _price: LineEdit
var _note: LineEdit
var _repeat: CheckButton
var _preview: Label
var _form: VBoxContainer
var _built := false


func _init(hid: String = "", k: String = "", mid: String = "") -> void:
	super()
	holding_id = hid
	kind = k if k != "" else "deposit"
	movement_id = mid


func title() -> String:
	if movement_id != "":
		return "Edit entry"
	return Catalog.MOVEMENT_KINDS.get(kind, "New entry") if holding_id != "" else "New entry"


func auto_refresh() -> bool:
	return false


func refresh() -> void:
	if _built:
		return
	_built = true
	if movement_id != "":
		for m in Store.data["movements"]:
			if m["id"] == movement_id:
				_mv = m
		kind = _mv.get("kind", kind)
		holding_id = _mv.get("holding_id", holding_id)
	if holding_id == "" and not Store.data["holdings"].is_empty():
		holding_id = Store.data["holdings"][0]["id"]
	if holding_id == "":
		add_child(Ui.label("Add a holding first.", "Muted"))
		return
	if movement_id == "" and _mv.is_empty():
		var hs := []
		for h in Store.data["holdings"]:
			hs.append([h["id"], "%s · %s" % [h["name"], Store.portfolio.account(h["account_id"]).get("name", "")]])
		_holding_opt = Ui.option(hs, holding_id)
		_holding_opt.item_selected.connect(func(_i):
			holding_id = Ui.option_value(_holding_opt)
			_build_form())
		add_child(Ui.field("Holding", _holding_opt))
	_form = Ui.vbox(14)
	add_child(_form)
	_build_form()


func _holding() -> Dictionary:
	return Store.portfolio.holding(holding_id)


func _is_market() -> bool:
	return Catalog.holding_type(_holding().get("type", ""))["valuation"] == "market"


func _build_form() -> void:
	Ui.clear(_form)
	var h := _holding()
	var kinds := Catalog.movement_kinds_for(h)
	if kind not in kinds:
		kind = kinds[0]
	var kitems := []
	for k in kinds:
		kitems.append([k, Catalog.MOVEMENT_KINDS[k]])
	_kind_opt = Ui.option(kitems, kind)
	_kind_opt.item_selected.connect(func(_i):
		kind = Ui.option_value(_kind_opt)
		_build_form())
	_form.add_child(Ui.field("Type", _kind_opt))
	var cur: String = Store.setting("currency", "EUR")
	var amount_title := "Amount (%s)" % Money.symbol(cur)
	match kind:
		"valuation":
			amount_title = "Amount you still owe (%s)" % Money.symbol(cur) if h.get("type", "") == "loan" else "Current value (%s)" % Money.symbol(cur)
		"deposit":
			amount_title = "Amount put in (%s)" % Money.symbol(cur)
		"withdrawal":
			amount_title = "Amount taken out (%s)" % Money.symbol(cur)
	_amount = Ui.line_edit("0,00", Money.format_scaled(_mv["amount_cents"], 100, 2) if _mv.has("amount_cents") else "", "decimal")
	_amount.text_changed.connect(func(_t): _update_preview())
	_form.add_child(Ui.field(amount_title, _amount))
	_date = DateField.new(_mv.get("date", Dates.today()))
	for o in _date.get_children():
		o.item_selected.connect(func(_i): _update_preview())
	_form.add_child(Ui.field("Date", _date))
	_fee = null
	_exact = null
	_units = null
	_price = null
	_preview = null
	if _is_market() and kind in ["deposit", "withdrawal"]:
		if kind == "deposit":
			_fee = Ui.line_edit("0,00", Money.format_scaled(_mv.get("fee_cents", 0), 100, 2) if _mv.get("fee_cents", 0) > 0 else "", "decimal")
			_fee.text_changed.connect(func(_t): _update_preview())
			_form.add_child(Ui.field("Fees included (optional)", _fee, "Part of the amount that went to fees, not to buying units."))
		_preview = Ui.label("", "Muted", true)
		_form.add_child(_preview)
		_exact = CheckButton.new()
		_exact.text = "Enter exact units and price"
		_exact.focus_mode = Control.FOCUS_NONE
		_exact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_exact.button_pressed = _mv.get("units_6") != null
		_form.add_child(_exact)
		var exact_box := Ui.vbox(14)
		_units = Ui.line_edit("e.g. 4,2531", Money.format_scaled(_mv["units_6"], Money.UNIT_SCALE, 6, true) if _mv.get("units_6") != null else "", "decimal")
		_price = Ui.line_edit("e.g. 117,52", Money.format_scaled(_mv["price_4"], Money.PRICE_SCALE, 4, true) if _mv.get("price_4") != null else "", "decimal")
		exact_box.add_child(Ui.field("Units", _units))
		exact_box.add_child(Ui.field("Price per unit (in the fund's currency)", _price))
		exact_box.visible = _exact.button_pressed
		_exact.toggled.connect(func(on): exact_box.visible = on)
		_form.add_child(exact_box)
		_update_preview()
	_repeat = null
	if movement_id == "" and kind in ["deposit", "withdrawal"]:
		_repeat = CheckButton.new()
		_repeat.text = "Repeat every month"
		_repeat.focus_mode = Control.FOCUS_NONE
		_repeat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_form.add_child(_repeat)
		_form.add_child(Ui.label("Same amount on the same day each month. If the date is in the past, the months up to today are added too — handy for a regular savings plan.", "Faint", true))
	_note = Ui.line_edit("Optional", _mv.get("note", ""))
	_form.add_child(Ui.field("Note", _note))
	_form.add_child(Ui.spacer(4))
	_form.add_child(Ui.button("Save", "Primary", _save))
	if movement_id != "":
		_form.add_child(Ui.button("Delete entry", "Danger", func():
			app.confirm("Delete this entry?", "This cannot be undone.", "Delete", func():
				Store.delete_movement(movement_id)
				app.pop(), true)))


func _update_preview() -> void:
	if _preview == null:
		return
	var h := _holding()
	var amt: Variant = Money.parse_cents(_amount.text)
	var date := _date.value()
	var p: Portfolio = Store.portfolio
	var pr := p.price_at(h.get("price_key", ""), date)
	if pr.is_empty():
		_preview.text = "The price for this date isn't loaded yet. It will be fetched automatically — or enter the exact units below."
		return
	var pcur: String = h.get("currency", "") if h.get("currency", "") != "" else Store.setting("currency", "EUR")
	var price_txt := "%s on %s" % [Money.fmt_price(pr["price4"], pcur), Dates.pretty(pr["date"])]
	if amt == null or amt <= 0:
		_preview.text = "Price: " + price_txt
		return
	var fee: Variant = Money.parse_cents(_fee.text) if _fee != null and _fee.text.strip_edges() != "" else 0
	var mv := {"date": date, "kind": kind, "amount_cents": amt, "fee_cents": fee if fee != null else 0}
	var u := p.movement_units(h, mv)
	if u < 0:
		_preview.text = "Price: " + price_txt + " (exchange rate not loaded yet)"
		return
	_preview.text = "≈ %s units at %s" % [Money.fmt_units(u), price_txt]


func _save() -> void:
	var amt: Variant = Money.parse_cents(_amount.text)
	if amt == null or amt < 0 or (amt == 0 and kind != "valuation"):
		app.toast("Enter a valid amount")
		return
	var date := _date.value()
	if date > Dates.today():
		app.toast("The date can't be in the future")
		return
	var fields := {
		"holding_id": holding_id, "kind": kind, "date": date, "amount_cents": amt,
		"fee_cents": 0, "units_6": null, "price_4": null, "note": _note.text.strip_edges(),
	}
	if _fee != null and _fee.text.strip_edges() != "":
		var fee: Variant = Money.parse_cents(_fee.text)
		if fee == null or fee < 0 or fee >= amt:
			app.toast("Fees must be less than the amount")
			return
		fields["fee_cents"] = fee
	if _exact != null and _exact.button_pressed:
		var u: Variant = Money.parse_decimal(_units.text, Money.UNIT_SCALE)
		var p: Variant = Money.parse_decimal(_price.text, Money.PRICE_SCALE) if _price.text.strip_edges() != "" else null
		if u == null or u <= 0:
			app.toast("Enter the number of units")
			return
		fields["units_6"] = u
		fields["price_4"] = p if p != null and p > 0 else Money.price_for(amt - fields["fee_cents"], u)
	if movement_id == "":
		Store.add_movement(fields)
		if _repeat != null and _repeat.button_pressed:
			var n_before: int = Store.data["movements"].size()
			Store.add_recurring({"holding_id": holding_id, "kind": kind, "amount_cents": fields["amount_cents"],
				"day": Dates.day(date), "start": date, "last": date})
			var extra: int = Store.data["movements"].size() - n_before
			if extra > 0:
				app.toast("Saved · %d past month%s added" % [extra, "s" if extra > 1 else ""])
		app.toast("Saved")
	else:
		Store.update_movement(movement_id, fields)
	app.pop()
	if _is_market() and fields["units_6"] == null and Store.portfolio.price_at(_holding().get("price_key", ""), date).is_empty():
		PriceService.refresh_all()
