extends Screen
## First launch: currency, monthly income and how to handle savings interest.

var _currency: OptionButton
var _income: LineEdit
var _mode := "auto"
var _built := false


func title() -> String:
	return ""


func auto_refresh() -> bool:
	return false


func refresh() -> void:
	if _built:
		return
	_built = true
	add_child(Ui.spacer(24))
	var logo := TextureRect.new()
	logo.texture = load("res://assets/icon.svg")
	logo.custom_minimum_size = Vector2(56, 56)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(logo)
	add_child(Ui.label("All your savings and investments, in one place.", "Title", true))
	add_child(Ui.label("Your data stays on this device. Only the names of the funds you track are used to look up public prices.", "Muted", true))
	add_child(Ui.spacer(6))
	_currency = Ui.option([["EUR", "Euro (€)"], ["USD", "US dollar ($)"], ["GBP", "Pound (£)"], ["CHF", "Swiss franc (CHF)"]], "EUR")
	add_child(Ui.field("Main currency", _currency))
	_income = Ui.line_edit("e.g. 2 500", "", "decimal")
	add_child(Ui.field("Monthly net income (optional)", _income, "Used only to show your savings rate. You can change it any time."))
	var modes := [
		["auto", "Calculate it for me", "Uses official rates and the half-month rules. Shown as an estimate."],
		["manual", "I'll enter it when paid", "Usually once a year, from your bank statement."],
		["none", "Don't track interest", "Only deposits and withdrawals."],
	]
	add_child(Ui.field("Interest on savings accounts (Livret A, LDDS, LEP…)", Ui.choices(modes, _mode, func(id): _mode = id), "You can change this per account later."))
	add_child(Ui.spacer(6))
	add_child(Ui.button("Get started", "Primary", _start))
	add_child(Ui.label("For information only — this app does not give financial advice.", "Faint", true))


func _start() -> void:
	var income: Variant = 0
	if _income.text.strip_edges() != "":
		income = Money.parse_cents(_income.text)
		if income == null or income < 0:
			app.toast("Enter a valid income or leave it empty")
			return
	Store.set_settings({
		"currency": Ui.option_value(_currency),
		"monthly_income_cents": income,
		"interest_mode": _mode,
		"onboarded": true,
	})
	app.finish_onboarding()
