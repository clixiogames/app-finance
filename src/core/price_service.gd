extends Node
## Fetches real market prices and exchange rates from free public sources.
## Only instrument identifiers (ticker / ISIN / coin id) and dates are sent — never personal data.
##
## Sources:
##  - ETFs, funds, stocks: Yahoo Finance public chart data (unofficial, free, no key).
##    Browsers block it (CORS), so the website goes through our small relay (see /relay).
##  - Crypto: CoinGecko public API (free, keyless; history limited to the last 365 days).
##  - Exchange rates: European Central Bank rates via Frankfurter (free, no key).

signal status_changed(text: String)
signal refreshed

const YAHOO := "https://query2.finance.yahoo.com"
const COINGECKO := "https://api.coingecko.com/api/v3"
const FRANKFURTER := "https://api.frankfurter.dev/v1"
## Default relay for the website. Replace after deploying /relay/worker.js (see README).
const DEFAULT_RELAY := ""

var busy := false
var last_error := ""


func relay_url() -> String:
	var r: String = Store.setting("relay_url", "")
	return r if r != "" else DEFAULT_RELAY


func _needs_relay(url: String) -> bool:
	return OS.has_feature("web") and url.begins_with(YAHOO)


func _get_json(url: String) -> Dictionary:
	var final_url := url
	if _needs_relay(url):
		var relay := relay_url()
		if relay == "":
			return {"ok": false, "error": "Prices for funds/ETFs on the website need the price relay (Settings › Price relay)."}
		final_url = relay.trim_suffix("/") + "/?url=" + url.uri_encode()
	var req := HTTPRequest.new()
	req.timeout = 20.0
	add_child(req)
	var headers := PackedStringArray(["Accept: application/json"])
	if not OS.has_feature("web"):
		headers.append("User-Agent: Mozilla/5.0 (Linux; Android 14) AppFinance/0.1")
	var err := req.request(final_url, headers)
	if err != OK:
		req.queue_free()
		return {"ok": false, "error": "Could not start the request (%d)." % err}
	var res: Array = await req.request_completed
	req.queue_free()
	var result: int = res[0]
	var code: int = res[1]
	var body: PackedByteArray = res[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "No connection to the price source."}
	if code == 429:
		return {"ok": false, "error": "The price source is busy. Try again in a minute."}
	if code < 200 or code >= 300:
		return {"ok": false, "error": "Price source answered with error %d." % code}
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null:
		return {"ok": false, "error": "Unexpected answer from the price source."}
	return {"ok": true, "data": parsed}


# ---------------- search ----------------

## Finds ETFs/funds/stocks by ISIN, ticker or name.
## Returns {ok, results: [{symbol, name, exchange, type}], error}
func search_market(query: String) -> Dictionary:
	var url := YAHOO + "/v1/finance/search?quotesCount=10&newsCount=0&listsCount=0&q=" + query.strip_edges().uri_encode()
	var r := await _get_json(url)
	if not r["ok"]:
		return {"ok": false, "results": [], "error": r["error"]}
	var out := []
	for q in r["data"].get("quotes", []):
		if not q.has("symbol"):
			continue
		var qt: String = q.get("quoteType", "")
		if qt not in ["ETF", "EQUITY", "MUTUALFUND", "INDEX", "CRYPTOCURRENCY", ""]:
			continue
		out.append({
			"symbol": q["symbol"],
			"name": q.get("longname", q.get("shortname", q["symbol"])),
			"exchange": q.get("exchDisp", q.get("exchange", "")),
			"type": qt,
		})
	return {"ok": true, "results": out, "error": ""}


## Finds crypto coins. Returns {ok, results: [{id, name, symbol}], error}
func search_crypto(query: String) -> Dictionary:
	var r := await _get_json(COINGECKO + "/search?query=" + query.strip_edges().uri_encode())
	if not r["ok"]:
		return {"ok": false, "results": [], "error": r["error"]}
	var out := []
	for c in r["data"].get("coins", []).slice(0, 10):
		out.append({"id": c["id"], "name": c.get("name", c["id"]), "symbol": str(c.get("symbol", "")).to_upper()})
	return {"ok": true, "results": out, "error": ""}


# ---------------- history ----------------

## Downloads daily prices for a Yahoo symbol since `from_date`.
## Returns {ok, currency, points: {date: price4}, error}
func fetch_yahoo(symbol: String, from_date: String) -> Dictionary:
	var p1 := Dates.to_days(from_date) * 86400
	var p2 := Dates.to_days(Dates.today()) * 86400 + 2 * 86400
	var url := "%s/v8/finance/chart/%s?interval=1d&period1=%d&period2=%d" % [YAHOO, symbol.uri_encode(), p1, p2]
	var r := await _get_json(url)
	if not r["ok"]:
		return {"ok": false, "error": r["error"]}
	return PriceParsers.parse_yahoo_chart(r["data"])




## Daily crypto prices in the base currency (last 365 days max on the free plan).
func fetch_coingecko(coin_id: String, currency: String) -> Dictionary:
	var url := "%s/coins/%s/market_chart?vs_currency=%s&days=365&interval=daily" % [COINGECKO, coin_id.uri_encode(), currency.to_lower()]
	var r := await _get_json(url)
	if not r["ok"]:
		return {"ok": false, "error": r["error"]}
	return PriceParsers.parse_coingecko(r["data"], currency)




## ECB rates: base-currency per 1 unit of `currency`, ×1e6.
func fetch_fx(currency: String, base: String, from_date: String) -> Dictionary:
	var url := "%s/%s..?from=%s&to=%s" % [FRANKFURTER, from_date, currency, base]
	var r := await _get_json(url)
	if not r["ok"]:
		return {"ok": false, "error": r["error"]}
	return PriceParsers.parse_frankfurter(r["data"], base)




# ---------------- refresh everything ----------------

## Updates prices for every market holding, plus exchange rates. Saves when done.
func refresh_all() -> void:
	if busy:
		return
	busy = true
	last_error = ""
	status_changed.emit("Updating prices…")
	var base: String = Store.setting("currency", "EUR")
	var p: Portfolio = Store.portfolio
	var done := {}
	var currencies := {}
	var errors := []
	for h in Store.data["holdings"]:
		var key: String = h.get("price_key", "")
		if key == "" or done.has(key):
			continue
		done[key] = true
		var movs := p.movements(h["id"])
		var from := Dates.add_days(Dates.today(), -30)
		if not movs.is_empty():
			from = Dates.add_days(movs[0]["date"], -10)
		var needed_from := from
		from = _incremental_from(Store.data["prices"].get(key, {}).get("points", {}), from)
		var r := {}
		if key.begins_with("y:"):
			r = await fetch_yahoo(key.substr(2), from)
		elif key.begins_with("cg:"):
			r = await fetch_coingecko(key.substr(3), base)
		if r.get("ok", false):
			Store.merge_prices(key, r["currency"], r["points"], "yahoo" if key.begins_with("y:") else "coingecko")
			if r["currency"] != base:
				if not currencies.has(r["currency"]) or needed_from < currencies[r["currency"]]:
					currencies[r["currency"]] = needed_from
			if h.get("currency", "") != r["currency"]:
				h["currency"] = r["currency"]
		else:
			errors.append("%s: %s" % [h.get("name", key), r.get("error", "unknown error")])
	for cur in currencies:
		var fx_from := _incremental_from(Store.data["fx"].get(cur, {}).get("points", {}), currencies[cur])
		var fr := await fetch_fx(cur, base, fx_from)
		if fr["ok"]:
			Store.merge_fx(cur, fr["points"])
		else:
			errors.append("Exchange rate %s: %s" % [cur, fr["error"]])
	Store.data["settings"]["prices_updated"] = Store.now_iso()
	Store.commit()
	busy = false
	last_error = "\n".join(errors)
	status_changed.emit("Prices updated" if errors.is_empty() else "Some prices could not be updated")
	refreshed.emit()


## If we already have prices covering `needed_from`, only fetch the last few days.
static func _incremental_from(existing: Dictionary, needed_from: String) -> String:
	if existing.is_empty():
		return needed_from
	var keys := existing.keys()
	keys.sort()
	if keys[0] <= Dates.add_days(needed_from, 7):
		return Dates.add_days(keys[keys.size() - 1], -5)
	return needed_from
