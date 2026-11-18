extends Screen
## Monthly income used for the savings rate: a default amount plus optional per-month amounts.

var _default: LineEdit
var _rows := {}
var _built := false


func title() -> String:
	return "Monthly income"


func auto_refresh() -> bool:
	return false


func refresh() -> void:
	if _built:
		return
	_built = true
	add_child(Ui.label("Used only to calculate your savings rate. Leave a month empty to use the usual amount.", "Muted", true))
	_default = Ui.line_edit("0,00", Money.format_scaled(Store.setting("monthly_income_cents", 0), 100, 2), "decimal")
	add_child(Ui.field("Usual monthly net income", _default))
	var c := Ui.card(8)
	var b := Ui.body(c)
	b.add_child(Ui.label("Specific months", "Strong"))
	var inc: Dictionary = Store.data["income"]
	var key := Dates.month_key(Dates.today())
	for i in 12:
		var k := Dates.month_key_add(key, -i)
		var row := Ui.hbox()
		var l := Ui.label(Dates.month_label(k))
		l.custom_minimum_size = Vector2(110, 0)
		row.add_child(l)
		var e := Ui.line_edit("usual", Money.format_scaled(inc[k], 100, 2) if inc.has(k) else "", "decimal")
		row.add_child(e)
		_rows[k] = e
		b.add_child(row)
	add_child(c)
	add_child(Ui.button("Save", "Primary", _save))


func _save() -> void:
	var d: Variant = Money.parse_cents(_default.text) if _default.text.strip_edges() != "" else 0
	if d == null or d < 0:
		app.toast("Enter a valid amount")
		return
	for k in _rows:
		var t: String = _rows[k].text.strip_edges()
		if t == "":
			Store.data["income"].erase(k)
		else:
			var v: Variant = Money.parse_cents(t)
			if v == null or v < 0:
				app.toast("Check the amount for " + Dates.month_label(k))
				return
			Store.data["income"][k] = v
	Store.set_setting("monthly_income_cents", d)
	app.pop()
	app.toast("Income saved")
