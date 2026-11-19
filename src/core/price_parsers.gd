class_name PriceParsers
## Turns answers from the price sources into exact scaled integers.
##  - Funds, ETFs, stocks: Alpha Vantage (each user's own free personal key).
##  - Finding an instrument by ISIN: OpenFIGI (free, open, run by Bloomberg).
##  - Crypto: CoinGecko public API.  - Exchange rates: European Central Bank (Frankfurter).

## Stock exchanges we support, with their Alpha Vantage suffix, currency and OpenFIGI codes.
const EXCHANGES := [
	{"suffix": ".PAR", "label": "Euronext Paris", "currency": "EUR", "figi": ["FP"]},
	{"suffix": ".DEX", "label": "Xetra", "currency": "EUR", "figi": ["GY", "GR"]},
	{"suffix": ".AMS", "label": "Euronext Amsterdam", "currency": "EUR", "figi": ["NA"]},
	{"suffix": ".BRU", "label": "Euronext Brussels", "currency": "EUR", "figi": ["BB"]},
	{"suffix": ".LIS", "label": "Euronext Lisbon", "currency": "EUR", "figi": ["PL"]},
	{"suffix": ".FRK", "label": "Frankfurt", "currency": "EUR", "figi": ["GF"]},
	{"suffix": "", "label": "United States", "currency": "USD", "figi": ["US", "UN", "UW", "UQ", "UA", "UP", "UR", "UF", "UV"]},
	{"suffix": ".TRT", "label": "Toronto", "currency": "CAD", "figi": ["CN", "CT"]},
	{"suffix": ".LON", "label": "London", "currency": "", "figi": []},
]


static func exchange_for_symbol(symbol: String) -> Dictionary:
	var dot := symbol.rfind(".")
	var suffix := symbol.substr(dot) if dot > 0 else ""
	for e in EXCHANGES:
		if e["suffix"] == suffix:
			return e
	return {"suffix": suffix, "label": suffix.substr(1), "currency": "", "figi": []}


static func exchange_for_figi(code: String) -> Dictionary:
	for e in EXCHANGES:
		if code in e["figi"]:
			return e
	return {}


## Alpha Vantage keys are short strings of letters and digits.
static func looks_like_key(k: String) -> bool:
	var t := k.strip_edges()
	if t.length() < 8 or t.length() > 40:
		return false
	for ch in t:
		if not ((ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9")):
			return false
	return true


static func is_isin(s: String) -> bool:
	var t := s.strip_edges().to_upper()
	if t.length() != 12:
		return false
	for i in 2:
		if t[i] < "A" or t[i] > "Z":
			return false
	return t[11] >= "0" and t[11] <= "9"


## "128.2250" -> 1282250 (exact, no floats)
static func _price(v: Variant, divisor: int = 1) -> int:
	var p: Variant = Money.parse_decimal(str(v), Money.PRICE_SCALE)
	if p == null:
		return 0
	return int(p) / divisor if divisor > 1 else int(p)


## Errors and limits are returned by Alpha Vantage inside a normal 200 answer.
static func av_problem(d: Variant) -> String:
	if not d is Dictionary:
		return "Unexpected answer from Alpha Vantage."
	if d.has("Error Message"):
		return "Alpha Vantage doesn't have this instrument. Try another listing (e.g. Xetra or Paris)."
	for k in ["Note", "Information"]:
		if d.has(k):
			var msg := str(d[k]).to_lower()
			if msg.contains("premium"):
				return "This data needs a paid Alpha Vantage plan."
			if msg.contains("rate limit") or msg.contains("requests per day") or msg.contains("frequency") or msg.contains("25 requests"):
				return "LIMIT"
			return "Alpha Vantage: " + str(d[k]).substr(0, 140)
	return ""


## Daily ("Time Series (Daily)") or weekly ("Weekly Time Series") closes.
## quote_currency "GBX"/"GBp" means prices are in pence -> converted to pounds.
static func parse_av_series(d: Variant, quote_currency: String = "") -> Dictionary:
	var problem := av_problem(d)
	if problem != "" and not (d is Dictionary and (d.has("Time Series (Daily)") or d.has("Weekly Time Series"))):
		return {"ok": false, "error": "Daily limit of your free Alpha Vantage key reached — prices will update tomorrow." if problem == "LIMIT" else problem, "limit": problem == "LIMIT", "points": {}}
	var series: Variant = d.get("Time Series (Daily)", d.get("Weekly Time Series", null))
	if not series is Dictionary or series.is_empty():
		return {"ok": false, "error": "No prices found for this instrument.", "limit": false, "points": {}}
	var divisor := 100 if quote_currency in ["GBX", "GBp"] else 1
	var points := {}
	for dt in series:
		var row: Dictionary = series[dt]
		var close: Variant = row.get("4. close", null)
		if close != null and Dates.is_valid(str(dt)):
			var p := _price(close, divisor)
			if p > 0:
				points[str(dt)] = p
	return {"ok": not points.is_empty(), "error": "" if not points.is_empty() else "No prices found.", "limit": false, "points": points}


## SYMBOL_SEARCH -> [{symbol, name, exchange, currency, type}]
static func parse_av_search(d: Variant) -> Dictionary:
	var problem := av_problem(d)
	if problem != "":
		return {"ok": false, "results": [], "error": "Daily limit of your free Alpha Vantage key reached. Try again tomorrow." if problem == "LIMIT" else problem}
	var out := []
	for m in d.get("bestMatches", []):
		var sym: String = m.get("1. symbol", "")
		if sym == "":
			continue
		var ex := exchange_for_symbol(sym)
		var cur: String = m.get("8. currency", ex.get("currency", ""))
		out.append({
			"symbol": sym, "name": m.get("2. name", sym), "type": m.get("3. type", ""),
			"exchange": m.get("4. region", ex["label"]), "currency": cur,
		})
	return {"ok": true, "results": out, "error": ""}


## OpenFIGI mapping/search -> one result per supported listing.
static func parse_openfigi(d: Variant) -> Array:
	var rows := []
	if d is Array:
		for job in d:
			if job is Dictionary:
				rows.append_array(job.get("data", []))
	elif d is Dictionary:
		rows = d.get("data", [])
	var out := []
	var seen := {}
	for r in rows:
		var ex := exchange_for_figi(str(r.get("exchCode", "")))
		if ex.is_empty():
			continue
		var ticker := str(r.get("ticker", "")).replace(" ", "")
		if ticker == "" or ticker.contains("/"):
			continue
		var sym: String = ticker + ex["suffix"]
		if seen.has(sym):
			continue
		seen[sym] = true
		out.append({
			"symbol": sym, "name": str(r.get("name", ticker)).capitalize(), "type": str(r.get("securityType2", "")),
			"exchange": ex["label"], "currency": ex["currency"],
		})
	# Most useful listings first: Paris, Xetra, Amsterdam… (order of EXCHANGES)
	out.sort_custom(func(a, b): return _ex_rank(a["symbol"]) < _ex_rank(b["symbol"]))
	return out


static func _ex_rank(symbol: String) -> int:
	var ex := exchange_for_symbol(symbol)
	for i in EXCHANGES.size():
		if EXCHANGES[i]["suffix"] == ex["suffix"]:
			return i
	return 99


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


## Converts an old Yahoo symbol (v0.1/v0.2 data) to the Alpha Vantage format.
static func yahoo_to_av(symbol: String) -> String:
	var map := {".PA": ".PAR", ".DE": ".DEX", ".AS": ".AMS", ".BR": ".BRU", ".LS": ".LIS", ".L": ".LON", ".F": ".FRK", ".TO": ".TRT"}
	var dot := symbol.rfind(".")
	if dot < 0:
		return symbol
	var suf := symbol.substr(dot)
	return symbol.substr(0, dot) + map.get(suf, suf)
