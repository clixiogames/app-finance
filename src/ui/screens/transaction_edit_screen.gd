extends Screen
## Add or edit a spending transaction. Changing the category can teach the app for next time.

var tx_id := ""
var _tx: Dictionary = {}
var _dir := "out"
var _label: LineEdit
var _amount: LineEdit
var _date: DateField
var _cat: OptionButton
var _learn: CheckButton
var _built := false


func _init(tid: String = "") -> void:
	super()
	tx_id = tid


func title() -> String:
	return "New transaction" if tx_id == "" else "Transaction"


func auto_refresh() -> bool:
	return false


func refresh() -> void:
	if _built:
		return
	_built = true
	for t in Store.transactions():
		if t["id"] == tx_id:
			_tx = t
	if not _tx.is_empty():
		_dir = "in" if _tx["amount_cents"] > 0 else "out"
		add_child(Ui.label(_tx["label"], "Muted", true))
	add_child(Ui.segmented(["Money out", "Money in"], 0 if _dir == "out" else 1, func(i): _dir = "out" if i == 0 else "in"))
	_amount = Ui.line_edit("0,00", Money.format_scaled(absi(_tx["amount_cents"]), 100, 2) if not _tx.is_empty() else "", "decimal")
	add_child(Ui.field("Amount (%s)" % Money.symbol(Store.setting("currency", "EUR")), _amount))
	_label = Ui.line_edit("e.g. Bakery", _tx.get("label", ""))
	add_child(Ui.field("Label", _label))
	_date = DateField.new(_tx.get("date", Dates.today()))
	add_child(Ui.field("Date", _date))
	var cats := []
	for c in Spending.CATEGORIES:
		cats.append([c["id"], c["label"]])
	_cat = Ui.option(cats, _tx.get("category", "other"))
	add_child(Ui.field("Category", _cat))
	if not _tx.is_empty():
		_learn = CheckButton.new()
		_learn.text = "Use this category for all “%s”" % Spending.merchant_key(_tx["label"]).capitalize()
		_learn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_learn.focus_mode = Control.FOCUS_NONE
		_learn.button_pressed = true
		add_child(_learn)
	add_child(Ui.spacer(4))
	add_child(Ui.button("Save", "Primary", _save))
	if not _tx.is_empty():
		add_child(Ui.button("Delete transaction", "Danger", func():
			app.confirm("Delete this transaction?", "It will be removed from your spending. Importing the same statement again would add it back.", "Delete", func():
				Store.delete_transaction(tx_id)
				app.pop(), true)))


func _save() -> void:
	var amt: Variant = Money.parse_cents(_amount.text)
	if amt == null or amt <= 0:
		app.toast("Enter a valid amount")
		return
	var signed: int = amt if _dir == "in" else -amt
	var label := _label.text.strip_edges()
	if label == "":
		label = Spending.category_label(Ui.option_value(_cat))
	var fields := {"amount_cents": signed, "label": label, "date": _date.value(), "category": Ui.option_value(_cat)}
	if _tx.is_empty():
		fields["bank"] = "Manual"
		Store.add_transaction(fields)
		app.pop()
		app.toast("Saved")
		return
	var cat_changed: bool = fields["category"] != _tx.get("category", "")
	var others := Store.update_transaction(tx_id, fields, cat_changed and _learn.button_pressed)
	app.pop()
	app.toast("Saved" + (" · %d similar updated" % others if others > 0 else ""))
