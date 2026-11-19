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
	report("OpenFIGI: listings for an ISIN", s["ok"] and not s["results"].is_empty(),
		str(s["results"].slice(0, 4)) if s["ok"] else s["error"])
	var s2: Dictionary = await PriceService.search_market("LU1681043599")
	report("OpenFIGI: Amundi MSCI World (CW8) on Paris", s2["ok"] and s2["results"].any(func(x): return x["symbol"] == "CW8.PAR"),
		str(s2["results"].slice(0, 3)) if s2["ok"] else s2["error"])
	var key := OS.get_environment("AV_KEY")
	if key != "":
		Store.data["settings"]["av_key"] = key
		var a: Dictionary = await PriceService.fetch_alpha_vantage("EUNL.DEX", "EUR", Dates.add_days(Dates.today(), -400), {})
		report("Alpha Vantage: EUNL.DEX daily + weekly", a.get("ok", false) and a["points"].size() > 100,
			("%d points" % a["points"].size()) if a.get("ok", false) else a["error"])
	else:
		print("SKIP Alpha Vantage — no AV_KEY secret set")

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
