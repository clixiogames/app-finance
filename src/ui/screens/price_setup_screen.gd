extends Screen
## Guided setup of the user's own free Alpha Vantage key (prices for funds, ETFs and stocks).

var _key: LineEdit
var _built := false


func title() -> String:
	return "Live prices"


func auto_refresh() -> bool:
	return false


func refresh() -> void:
	if _built:
		return
	_built = true
	var intro := Ui.card(8)
	var ib := Ui.body(intro)
	ib.add_child(Ui.label("Prices for funds, ETFs and stocks", "Strong"))
	ib.add_child(Ui.label("They come from Alpha Vantage, a market-data service with a free plan for personal use. Each person uses their own free key — that's what keeps it free and within their rules.", "Muted", true))
	ib.add_child(Ui.label("No payment card. Your key stays on this device and is never put in backups.", "Muted", true))
	add_child(intro)

	var steps := Ui.card(10)
	var sb := Ui.body(steps)
	sb.add_child(Ui.label("Get your free key — about 1 minute", "Strong"))
	var items := [
		"Tap “Open the sign-up page” below.",
		"Fill in the short form: say what describes you (e.g. investor) and your email, then tap the button to get your free key.",
		"Copy the key that appears (letters and numbers).",
		"Come back here, tap “Paste”, then “Save”.",
	]
	for i in items.size():
		var row := Ui.hbox(10)
		var n := Ui.label(str(i + 1), "Accent")
		n.custom_minimum_size = Vector2(18, 0)
		row.add_child(n)
		row.add_child(Ui.label(items[i], "", true))
		sb.add_child(row)
	sb.add_child(Ui.button("Open the sign-up page", "", func(): OS.shell_open(PriceService.KEY_SIGNUP_URL)))
	add_child(steps)

	_key = Ui.line_edit("Paste your key here", PriceService.av_key())
	_key.secret = false
	var row2 := Ui.hbox()
	row2.add_child(_key)
	row2.add_child(Ui.button("Paste", "", func():
		_key.text = DisplayServer.clipboard_get().strip_edges()))
	add_child(Ui.field("Your free key", row2))
	add_child(Ui.button("Save", "Primary", _save))
	if PriceService.has_key():
		add_child(Ui.label("Requests used today: %d of %d (resets every day)." % [PriceService.calls_used_today(), PriceService.DAILY_BUDGET], "Faint"))
		add_child(Ui.button("Remove key from this device", "Danger", func():
			Store.set_setting("av_key", "")
			app.pop()
			app.toast("Key removed")))

	var more := Ui.card(6)
	var mb := Ui.body(more)
	mb.add_child(Ui.label("Good to know", "Strong"))
	mb.add_child(Ui.label("• Prices are end-of-day and update once a day when you open the app.", "Muted", true))
	mb.add_child(Ui.label("• The free key allows 25 requests a day: plenty for about 20 funds.", "Muted", true))
	mb.add_child(Ui.label("• For dates older than ~5 months, the app uses that week's closing price. You can always type the exact figures from your statement.", "Muted", true))
	mb.add_child(Ui.label("• Crypto prices (CoinGecko) and exchange rates (European Central Bank) need no key.", "Muted", true))
	add_child(more)


func _save() -> void:
	var k := _key.text.strip_edges()
	if not PriceService.looks_like_key(k):
		app.toast("That doesn't look like a key — copy it again from the Alpha Vantage page", 3.5)
		return
	Store.set_setting("av_key", k)
	app.pop()
	app.toast("Saved — updating prices…")
	PriceService.refresh_all()
