extends Screen
## Preview of a bank statement before importing it.

var result: Dictionary
var file_name := ""
var _bank: LineEdit
var _built := false


func _init(r: Dictionary = {}, fname: String = "") -> void:
	super()
	result = r
	file_name = fname


func title() -> String:
	return "Import statement"


func auto_refresh() -> bool:
	return false


func refresh() -> void:
	if _built:
		return
	_built = true
	var cur: String = Store.setting("currency", "EUR")
	if not result.get("ok", false):
		var c := Ui.card(10)
		var b := Ui.body(c)
		b.add_child(Ui.label("This file couldn't be read", "Strong"))
		b.add_child(Ui.label(result.get("error", "Unknown error"), "Muted", true))
		b.add_child(Ui.label("Tip: choose the CSV (or OFX) export on your bank's website, not PDF or Excel.", "Faint", true))
		add_child(c)
		add_child(Ui.button("Back", "", func(): app.pop()))
		return
	var rows: Array = result["rows"]
	var existing := {}
	for t in Store.transactions():
		existing[t.get("key", "")] = true
	var keyed := Spending.keyed(rows)
	var fresh := keyed.filter(func(r): return not existing.has(r["key"]))
	var first := "9999"
	var last := ""
	for r in rows:
		first = r["date"] if r["date"] < first else first
		last = r["date"] if r["date"] > last else last

	var c2 := Ui.card(6)
	var b2 := Ui.body(c2)
	b2.add_child(Ui.label("%d transactions found" % rows.size(), "Strong"))
	b2.add_child(Ui.label("%s → %s" % [Dates.pretty(first), Dates.pretty(last)], "Muted"))
	if fresh.size() < rows.size():
		b2.add_child(Ui.label("%d already imported — they will be skipped." % (rows.size() - fresh.size()), "Muted", true))
	if result.get("info", "") != "":
		b2.add_child(Ui.label(result["info"], "Faint"))
	add_child(c2)

	_bank = Ui.line_edit("e.g. Boursorama", _guess_bank())
	add_child(Ui.field("Bank / account name", _bank))

	var pc := Ui.card(2)
	var pb := Ui.body(pc)
	pb.add_child(Ui.label("Preview", "Strong"))
	var rules: Dictionary = Store.data["spending"]["rules"]
	for r in fresh.slice(0, 8):
		var row := Ui.hbox(10)
		row.custom_minimum_size = Vector2(0, 44)
		var left := Ui.vbox(0)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.alignment = BoxContainer.ALIGNMENT_CENTER
		left.add_child(Ui.shrinkable(Ui.label(Spending.merchant_key(r["label"]).capitalize())))
		left.add_child(Ui.shrinkable(Ui.label("%s · %s" % [Dates.pretty(r["date"]), Spending.category_label(Spending.guess_category(r["label"], r["amount_cents"], rules))], "Muted")))
		row.add_child(left)
		var v := Ui.label(Money.fmt(r["amount_cents"], cur, true), "Gain" if r["amount_cents"] > 0 else "")
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(v)
		pb.add_child(row)
	if fresh.size() > 8:
		pb.add_child(Ui.label("…and %d more" % (fresh.size() - 8), "Faint"))
	add_child(pc)

	var btn := Ui.button("Import %d transactions" % fresh.size(), "Primary", func():
		var r := Store.import_transactions(rows, _bank.text.strip_edges())
		app.pop()
		app.toast("%d transactions imported" % r["added"]))
	btn.disabled = fresh.is_empty()
	add_child(btn)
	add_child(Ui.label("Categories are guessed automatically. Tap any transaction later to change it — the app will remember.", "Faint", true))


func _guess_bank() -> String:
	var n := file_name.to_lower()
	for b in [["bourso", "Boursorama"], ["credit agricole", "Crédit Agricole"], ["ca-", "Crédit Agricole"], ["bnp", "BNP Paribas"], ["sg", "Société Générale"], ["lcl", "LCL"], ["caisse", "Caisse d'Épargne"], ["banque postale", "La Banque Postale"], ["lbp", "La Banque Postale"], ["mutuel", "Crédit Mutuel"], ["fortuneo", "Fortuneo"], ["revolut", "Revolut"], ["n26", "N26"], ["hello", "Hello bank!"]]:
		if n.contains(b[0]):
			return b[1]
	return ""
