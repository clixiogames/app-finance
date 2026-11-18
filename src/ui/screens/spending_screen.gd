extends Screen
## Daily income & expenses from bank statements — separate from Wealth. Coming next.


func title() -> String:
	return "Spending"


func refresh() -> void:
	Ui.clear(self)
	var c := Ui.card(10)
	var b := Ui.body(c)
	b.add_child(Ui.label("Coming next", "Strong"))
	b.add_child(Ui.label("Import your bank statements (CSV / OFX / Excel) to see where your money goes each month: categories, income vs. expenses, trends.", "Muted", true))
	b.add_child(Ui.label("This section is kept completely separate from your savings and investments.", "Muted", true))
	add_child(c)
