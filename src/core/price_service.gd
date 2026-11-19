extends Node
## Fetches market prices and exchange rates. Only instrument identifiers and dates are sent —
## never amounts or personal data. All sources are free and used within their terms:
##  - Funds, ETFs, stocks: Alpha Vantage, with the user's OWN free personal key
##    (Alpha Vantage's free keys are for personal, non-commercial use — exactly this).
##    Free key limits: 25 requests/day; daily prices for the last 100 days + weekly closes
##    for older dates. Everything fetched is kept on the device, so history builds up.
##  - Finding an instrument from its ISIN: OpenFIGI (free and open, no key).
##  - Crypto: CoinGecko public API (attribution shown in the app).
##  - Exchange rates: European Central Bank reference rates via Frankfurter.

signal status_changed(text: String)
signal refreshed

const ALPHA_VANTAGE := "https://www.alphavantage.co/query"
const OPENFIGI := "https://api.openfigi.com/v3"
const COINGECKO := "https://api.coingecko.com/api/v3"
const FRANKFURTER := "https://api.frankfurter.dev/v1"
const KEY_SIGNUP_URL := "https://www.alphavantage.co/support/#api-key"
const DAILY_BUDGET := 25
const RESERVED_FOR_SEARCH := 3
const AV_SPACING := 12.5  # seconds between calls (free keys allow ~5 per minute)

var busy := false
var last_error := ""
var _last_av_call := -1000.0


# ---------------- key & budget ----------------

func av_key() -> String:
	return str(Store.setting("av_key", "")).strip_edges()


func has_key() -> bool:
	return av_key() != ""


static func looks_like_key(k: String) -> bool:
	return PriceParsers.looks_like_key(k)


func calls_used_today() -> int:
	var c: Dictionary = Store.setting("av_calls", {})
	return int(c.get("n", 0)) if c.get("date", "") == Dates.today() else 0


func _count_call() -> void:
	Store.data["settings"]["av_calls"] = {"date": Dates.today(), "n": calls_used_today() + 1}


func calls_left() -> int:
	return maxi(0, DAILY_BUDGET - calls_used_today())


# ---------------- HTTP ----------------

func _request(url: String, method: int = HTTPClient.METHOD_GET, body: String = "", extra_headers: Array = []) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 25.0
	add_child(req)
	var headers := PackedStringArray(["Accept: application/json"])
	for h in extra_headers:
		headers.append(h)
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return {"ok": false, "error": "Could not start the request (%d)." % err}
	var res: Array = await req.request_completed
	req.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "No internet connection, or the price source can't be reached."}
	var code: int = res[1]
	if code == 429:
		return {"ok": false, "error": "The price source is busy. Try again in a minute."}
	if code < 200 or code >= 300:
		return {"ok": false, "error": "The price source answered with error %d." % code}
	var parsed: Variant = JSON.parse_string(res[3].get_string_from_utf8())
	if parsed == null:
		return {"ok": false, "error": "Unexpected answer from the price source."}
	return {"ok": true, "data": parsed}


func _av(params: String) -> Dictionary:
	if not has_key():
		return {"ok": false, "error": "NO_KEY"}
	if calls_left() <= 0:
		return {"ok": false, "error": "Daily limit of your free Alpha Vantage key reached — prices will update tomorrow."}
	var wait := AV_SPACING - (Time.get_ticks_msec() / 1000.0 - _last_av_call)
	if wait > 0:
		await get_tree().create_timer(wait).timeout
	_last_av_call = Time.get_ticks_msec() / 1000.0
	_count_call()
	return await _request("%s?%s&apikey=%s" % [ALPHA_VANTAGE, params, av_key().uri_encode()])


# ---------------- search ----------------

## Finds funds, ETFs and stocks by ISIN, ticker or name.
## Returns {ok, results: [{symbol, name, exchange, currency, type}], error}
func search_market(query: String) -> Dictionary:
	var q := query.strip_edges()
	if q == "":
		return {"ok": true, "results": [], "error": ""}
	if PriceParsers.is_isin(q):
		var body := JSON.stringify([{"idType": "ID_ISIN", "idValue": q.to_upper()}])
		var r := await _request(OPENFIGI + "/mapping", HTTPClient.METHOD_POST, body, ["Content-Type: application/json"])
		if r["ok"]:
			var found := PriceParsers.parse_openfigi(r["data"])
			if not found.is_empty():
				return {"ok": true, "results": found, "error": ""}
			return {"ok": false, "results": [], "error": "No listing found for this ISIN on the supported exchanges. Try the fund's name or ticker."}
		if not has_key():
			return {"ok": false, "results": [], "error": "Couldn't look up this ISIN. Try the ticker (e.g. CW8) — or check your connection."}
	if not has_key():
		var body2 := JSON.stringify({"query": q})
		var r2 := await _request(OPENFIGI + "/search", HTTPClient.METHOD_POST, body2, ["Content-Type: application/json"])
		if r2["ok"]:
			return {"ok": true, "results": PriceParsers.parse_openfigi(r2["data"]).slice(0, 15), "error": ""}
		return {"ok": false, "results": [], "error": r2["error"]}
	var r3 := await _av("function=SYMBOL_SEARCH&keywords=" + q.uri_encode())
	if not r3["ok"]:
		return {"ok": false, "results": [], "error": r3["error"]}
	return PriceParsers.parse_av_search(r3["data"])


## Finds crypto coins. Returns {ok, results: [{id, name, symbol}], error}
func search_crypto(query: String) -> Dictionary:
	var r := await _request(COINGECKO + "/search?query=" + query.strip_edges().uri_encode())
	if not r["ok"]:
		return {"ok": false, "results": [], "error": r["error"]}
	var out := []
	for c in r["data"].get("coins", []).slice(0, 10):
		out.append({"id": c["id"], "name": c.get("name", c["id"]), "symbol": str(c.get("symbol", "")).to_upper()})
	return {"ok": true, "results": out, "error": ""}


# ---------------- history ----------------

## Daily closes (last 100 trading days) and, when `need_from` is older, weekly closes too.
func fetch_alpha_vantage(symbol: String, quote_currency: String, need_from: String, have: Dictionary) -> Dictionary:
	var points := {}
	var r := await _av("function=TIME_SERIES_DAILY&outputsize=compact&symbol=" + symbol.uri_encode())
	if not r["ok"]:
		return {"ok": false, "error": r["error"]}
	var d := PriceParsers.parse_av_series(r["data"], quote_currency)
	if not d["ok"]:
		return d
	points.merge(d["points"])
	var oldest_daily: String = d["points"].keys().min()
	var oldest_have: String = have.keys().min() if not have.is_empty() else "9999"
	if need_from < oldest_daily and need_from < oldest_have:
		var w := await _av("function=TIME_SERIES_WEEKLY&symbol=" + symbol.uri_encode())
		if w["ok"]:
			var wd := PriceParsers.parse_av_series(w["data"], quote_currency)
			if wd["ok"]:
				for dt in wd["points"]:
					if not points.has(dt):
						points[dt] = wd["points"][dt]
	return {"ok": true, "points": points, "error": ""}


func fetch_coingecko(coin_id: String, currency: String) -> Dictionary:
	var url := "%s/coins/%s/market_chart?vs_currency=%s&days=365&interval=daily" % [COINGECKO, coin_id.uri_encode(), currency.to_lower()]
	var r := await _request(url)
	if not r["ok"]:
		return {"ok": false, "error": r["error"]}
	return PriceParsers.parse_coingecko(r["data"], currency)


## ECB rates: base-currency per 1 unit of `currency`, ×1e6.
func fetch_fx(currency: String, base: String, from_date: String) -> Dictionary:
	var url := "%s/%s..?from=%s&to=%s" % [FRANKFURTER, from_date, currency, base]
	var r := await _request(url)
	if not r["ok"]:
		return {"ok": false, "error": r["error"]}
	return PriceParsers.parse_frankfurter(r["data"], base)


# ---------------- refresh everything ----------------

## Holdings that need a key-based price source but have none yet.
func waiting_for_key() -> int:
	if has_key():
		return 0
	var n := 0
	for h in Store.data["holdings"]:
		if str(h.get("price_key", "")).begins_with("av:"):
			n += 1
	return n


## Updates prices for every market holding (once a day each), plus exchange rates.
func refresh_all(force: bool = false) -> void:
	if busy:
		return
	busy = true
	last_error = ""
	var base: String = Store.setting("currency", "EUR")
	var p: Portfolio = Store.portfolio
	var done := {}
	var currencies := {}
	var errors := []
	var fetched := 0
	var todo := []
	for h in Store.data["holdings"]:
		var key: String = h.get("price_key", "")
		if key == "" or done.has(key):
			continue
		done[key] = true
		todo.append(h)
	var i := 0
	for h in todo:
		i += 1
		var key: String = h["price_key"]
		var entry: Dictionary = Store.data["prices"].get(key, {})
		var have: Dictionary = entry.get("points", {})
		var movs := p.movements(h["id"])
		var need_from := Dates.add_days(movs[0]["date"], -7) if not movs.is_empty() else Dates.add_days(Dates.today(), -30)
		var up_to_date: bool = str(entry.get("updated", "")).substr(0, 10) == Dates.today() and (have.is_empty() or have.keys().min() <= need_from or key.begins_with("cg:"))
		if up_to_date and not force:
			_note_currency(h, base, need_from, currencies)
			continue
		status_changed.emit("Updating prices %d/%d…" % [i, todo.size()])
		var r := {}
		var cur: String = h.get("currency", base)
		if key.begins_with("av:"):
			if not has_key():
				continue
			if calls_left() <= RESERVED_FOR_SEARCH and not force:
				errors.append("Daily limit of the free price key almost reached — the rest will update tomorrow.")
				break
			r = await fetch_alpha_vantage(key.substr(3), h.get("quote_currency", cur), need_from, have)
			if r.get("ok", false):
				r["currency"] = cur
		elif key.begins_with("cg:"):
			r = await fetch_coingecko(key.substr(3), base)
		else:
			continue
		if r.get("ok", false):
			fetched += 1
			Store.merge_prices(key, r["currency"], r["points"], "alphavantage" if key.begins_with("av:") else "coingecko")
			_note_currency(h, base, need_from, currencies)
		else:
			errors.append("%s: %s" % [h.get("name", key), r.get("error", "unknown error")])
			if str(r.get("error", "")).contains("limit"):
				break
	for c in currencies:
		var fx_from := _incremental_from(Store.data["fx"].get(c, {}).get("points", {}), currencies[c])
		var updated: String = str(Store.data["fx"].get(c, {}).get("updated", "")).substr(0, 10)
		if updated == Dates.today() and fx_from != currencies[c] and not force:
			continue
		var fr := await fetch_fx(c, base, fx_from)
		if fr["ok"]:
			fetched += 1
			Store.merge_fx(c, fr["points"])
		else:
			errors.append("Exchange rate %s: %s" % [c, fr["error"]])
	Store.data["settings"]["prices_updated"] = Store.now_iso()
	Store.commit()
	busy = false
	last_error = "\n".join(errors)
	if not errors.is_empty():
		status_changed.emit("Some prices could not be updated")
	elif fetched > 0 or force:
		status_changed.emit("Prices updated")
	refreshed.emit()


func _note_currency(h: Dictionary, base: String, need_from: String, currencies: Dictionary) -> void:
	var c: String = h.get("currency", base)
	if c != "" and c != base:
		if not currencies.has(c) or need_from < currencies[c]:
			currencies[c] = need_from


## If we already have data covering `needed_from`, only fetch the last few days.
static func _incremental_from(existing: Dictionary, needed_from: String) -> String:
	if existing.is_empty():
		return needed_from
	var keys := existing.keys()
	keys.sort()
	if keys[0] <= Dates.add_days(needed_from, 7):
		return Dates.add_days(keys[keys.size() - 1], -5)
	return needed_from
