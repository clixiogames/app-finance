extends Node
## Live check of the public price sources, using the app's own PriceService code.
## Needs internet. Run: godot --headless --path . res://tests/live_prices.tscn

var failures := 0


func report(name: String, ok: bool, detail: String) -> void:
	print(("OK   " if ok else "FAIL ") + name + " — " + detail)
	if not ok:
		failures += 1


func _ready() -> void:
	Store.persist = false
	var from := Dates.add_days(Dates.today(), -40)

	var s: Dictionary = await PriceService.search_market("IE00B4L5Y983")
	report("Yahoo search by ISIN", s["ok"] and not s["results"].is_empty(),
		str(s["results"].slice(0, 3)) if s["ok"] else s["error"])

	var y: Dictionary = await PriceService.fetch_yahoo("CW8.PA", from)
	report("Yahoo history CW8.PA", y.get("ok", false) and y["points"].size() > 15,
		("%d days, currency %s, last %s" % [y["points"].size(), y["currency"], _last(y["points"])]) if y.get("ok", false) else y["error"])

	var us: Dictionary = await PriceService.fetch_yahoo("AAPL", from)
	report("Yahoo history AAPL (USD)", us.get("ok", false) and us["currency"] == "USD",
		("%d days, currency %s" % [us["points"].size(), us["currency"]]) if us.get("ok", false) else us["error"])

	var c: Dictionary = await PriceService.search_crypto("bitcoin")
	report("CoinGecko search", c["ok"] and not c["results"].is_empty(),
		str(c["results"].slice(0, 2)) if c["ok"] else c["error"])

	var cg: Dictionary = await PriceService.fetch_coingecko("bitcoin", "EUR")
	report("CoinGecko history bitcoin/EUR", cg.get("ok", false) and cg["points"].size() > 300,
		("%d days, last %s" % [cg["points"].size(), _last(cg["points"])]) if cg.get("ok", false) else cg["error"])

	var fx: Dictionary = await PriceService.fetch_fx("USD", "EUR", from)
	report("ECB rates USD→EUR", fx.get("ok", false) and fx["points"].size() > 15,
		("%d days, last %s" % [fx["points"].size(), _last(fx["points"])]) if fx.get("ok", false) else fx["error"])

	print("Live prices: ", "all OK" if failures == 0 else "%d problem(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _last(points: Dictionary) -> String:
	var k := points.keys()
	k.sort()
	return "%s = %s" % [k[-1], points[k[-1]]] if not k.is_empty() else "-"
