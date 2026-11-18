class_name PriceParsers
## Turns answers from the public price sources into scaled integer prices.


static func parse_yahoo_chart(d: Variant) -> Dictionary:
	var res: Variant = d.get("chart", {}).get("result", null) if d is Dictionary else null
	if not res is Array or res.is_empty():
		return {"ok": false, "error": "No prices found for this instrument."}
	var r0: Dictionary = res[0]
	var meta: Dictionary = r0.get("meta", {})
	var currency: String = meta.get("currency", "EUR")
	var divisor := 1.0
	if currency == "GBp" or currency == "GBX":
		currency = "GBP"
		divisor = 100.0
	elif currency == "ZAc":
		currency = "ZAR"
		divisor = 100.0
	var offset := int(meta.get("gmtoffset", 0))
	var ts: Array = r0.get("timestamp", [])
	var quotes: Array = r0.get("indicators", {}).get("quote", [{}])
	var closes: Array = quotes[0].get("close", []) if not quotes.is_empty() else []
	var points := {}
	for i in mini(ts.size(), closes.size()):
		if closes[i] == null:
			continue
		var dt := Dates.from_unix(int(ts[i]) + offset)
		points[dt] = Money.from_float(float(closes[i]) / divisor, Money.PRICE_SCALE)
	if meta.has("regularMarketPrice") and meta.has("regularMarketTime"):
		var dt2 := Dates.from_unix(int(meta["regularMarketTime"]) + offset)
		points[dt2] = Money.from_float(float(meta["regularMarketPrice"]) / divisor, Money.PRICE_SCALE)
	if points.is_empty():
		return {"ok": false, "error": "No prices found for this instrument."}
	return {"ok": true, "currency": currency, "points": points, "error": ""}


static func parse_coingecko(d: Variant, currency: String) -> Dictionary:
	var prices: Variant = d.get("prices", null) if d is Dictionary else null
	if not prices is Array or prices.is_empty():
		return {"ok": false, "error": "No prices found for this coin."}
	var points := {}
	for p in prices:
		points[Dates.from_unix(int(float(p[0]) / 1000.0))] = Money.from_float(float(p[1]), Money.PRICE_SCALE)
	return {"ok": true, "currency": currency.to_upper(), "points": points, "error": ""}


static func parse_frankfurter(d: Variant, base: String) -> Dictionary:
	var rates: Variant = d.get("rates", null) if d is Dictionary else null
	if not rates is Dictionary or rates.is_empty():
		return {"ok": false, "error": "No exchange rates found."}
	var points := {}
	for dt in rates:
		if rates[dt].has(base):
			points[dt] = Money.from_float(float(rates[dt][base]), Money.FX_SCALE)
	return {"ok": true, "points": points, "error": ""}
