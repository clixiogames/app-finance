class_name Portfolio
extends RefCounted
## Read-only calculations over the saved data: values, gains, allocation, history, savings.
## Create a new Portfolio whenever the data changes (it builds lookup indexes once).

var data: Dictionary
var base: String
var _price_idx := {}
var _fx_idx := {}
var _movs := {}
var _holdings := {}
var _accounts := {}


func _init(d: Dictionary) -> void:
	data = d
	base = d.get("settings", {}).get("currency", "EUR")
	for key in d.get("prices", {}):
		_price_idx[key] = _index(d["prices"][key].get("points", {}))
	for cur in d.get("fx", {}):
		_fx_idx[cur] = _index(d["fx"][cur].get("points", {}))
	for a in d.get("accounts", []):
		_accounts[a["id"]] = a
	for h in d.get("holdings", []):
		_holdings[h["id"]] = h
		_movs[h["id"]] = []
	for m in d.get("movements", []):
		if _movs.has(m.get("holding_id", "")):
			_movs[m["holding_id"]].append(m)
	for hid in _movs:
		_movs[hid].sort_custom(func(a, b): return a["date"] < b["date"] or (a["date"] == b["date"] and str(a.get("created", "")) < str(b.get("created", ""))))


static func _index(points: Dictionary) -> Dictionary:
	var dates := PackedStringArray(points.keys())
	dates.sort()
	var values := PackedInt64Array()
	for dt in dates:
		values.append(int(points[dt]))
	return {"dates": dates, "values": values}


static func _lookup(idx: Dictionary, date: String) -> Dictionary:
	var dates: PackedStringArray = idx["dates"]
	if dates.is_empty():
		return {}
	var i := dates.bsearch(date, false) - 1
	if i < 0:
		return {}
	return {"value": idx["values"][i], "date": dates[i]}


func holding(hid: String) -> Dictionary:
	return _holdings.get(hid, {})


func account(aid: String) -> Dictionary:
	return _accounts.get(aid, {})


func movements(hid: String) -> Array:
	return _movs.get(hid, [])


func holdings_in(aid: String) -> Array:
	var out := []
	for h in data.get("holdings", []):
		if h.get("account_id", "") == aid:
			out.append(h)
	return out


## {price4, date} or {} if unknown.
func price_at(key: String, date: String) -> Dictionary:
	if key == "" or not _price_idx.has(key):
		return {}
	var r := _lookup(_price_idx[key], date)
	if r.is_empty():
		return {}
	return {"price4": r["value"], "date": r["date"]}


## Base-currency per 1 unit of `cur`, ×1e6. 0 if unknown.
func fx_at(cur: String, date: String) -> int:
	if cur == "" or cur == base:
		return Money.FX_SCALE
	if not _fx_idx.has(cur):
		return 0
	var r := _lookup(_fx_idx[cur], date)
	if r.is_empty():
		var dates: PackedStringArray = _fx_idx[cur]["dates"]
		if dates.is_empty():
			return 0
		return _fx_idx[cur]["values"][0]
	return r["value"]


## Units (×1e6) for a deposit/withdrawal on a market holding. -1 if the price is unknown.
func movement_units(h: Dictionary, mv: Dictionary) -> int:
	if mv.get("units_6") != null:
		return int(mv["units_6"])
	var p := price_at(h.get("price_key", ""), mv["date"])
	var fx := fx_at(h.get("currency", base), mv["date"])
	if p.is_empty() or fx == 0:
		return -1
	var net: int = mv.get("amount_cents", 0)
	if mv.get("kind", "") == "deposit":
		net -= int(mv.get("fee_cents", 0))
	return Money.units_for(Money.convert_back(net, fx), p["price4"])


## Price used for a movement (×1e4, instrument currency) or 0.
func movement_price(h: Dictionary, mv: Dictionary) -> int:
	if mv.get("price_4") != null:
		return int(mv["price_4"])
	var p := price_at(h.get("price_key", ""), mv["date"])
	return p.get("price4", 0)


func _rate_fn(h: Dictionary) -> Callable:
	var source: String = h.get("rate_source", "fixed")
	var fixed: int = h.get("fixed_rate_bps", 0)
	return func(date: String) -> int: return RegulatedRates.rate_bps(source, date, fixed)


## Full state of one holding on `date`.
func holding_state(h: Dictionary, date: String = "") -> Dictionary:
	if date == "":
		date = Dates.today()
	var t := Catalog.holding_type(h.get("type", "other"))
	var valuation: String = t["valuation"]
	var s := {
		"deposits": 0, "withdrawals": 0, "dividends": 0, "fees": 0, "interest": 0,
		"units": 0, "value": 0, "invested": 0, "gain": 0,
		"missing_price": false, "estimated": false, "price4": 0, "price_date": "",
		"currency": h.get("currency", base), "valuation": valuation,
	}
	var last_val := -1
	var after_val_net := 0
	var upto := []
	for mv in movements(h["id"]):
		if mv["date"] > date:
			break
		upto.append(mv)
		var amt: int = mv.get("amount_cents", 0)
		match mv.get("kind", ""):
			"deposit":
				s["deposits"] += amt
				after_val_net += amt
				if valuation == "market":
					var u := movement_units(h, mv)
					if u < 0:
						s["missing_price"] = true
					else:
						s["units"] += u
			"withdrawal":
				s["withdrawals"] += amt
				after_val_net -= amt
				if valuation == "market":
					var u2 := movement_units(h, mv)
					if u2 < 0:
						s["missing_price"] = true
					else:
						s["units"] -= u2
			"dividend":
				s["dividends"] += amt
			"fee":
				s["fees"] += amt
				if valuation != "market":
					after_val_net -= amt
			"interest":
				s["interest"] += amt
				after_val_net += amt
			"valuation":
				last_val = amt
				after_val_net = 0
	s["invested"] = s["deposits"] - s["withdrawals"]
	match valuation:
		"market":
			var p := price_at(h.get("price_key", ""), date)
			var fx := fx_at(h.get("currency", base), date)
			if s["units"] != 0 and (p.is_empty() or fx == 0):
				s["missing_price"] = true
			if s["missing_price"]:
				s["value"] = s["invested"]
			elif not p.is_empty():
				s["price4"] = p["price4"]
				s["price_date"] = p["date"]
				s["value"] = Money.convert(Money.value_cents(s["units"], p["price4"]), fx)
			s["gain"] = s["value"] - s["invested"] + s["dividends"] - s["fees"]
		"interest":
			var mode: String = h.get("interest_mode", "auto")
			var interest := 0
			if mode == "auto":
				var r := InterestCalc.compute(upto, _rate_fn(h), date)
				interest = r["credited"] + r["accrued"]
				s["estimated"] = true
			elif mode == "manual":
				interest = s["interest"]
			s["interest"] = interest
			s["value"] = s["invested"] - s["fees"] + interest
			s["gain"] = s["value"] - s["invested"] + s["dividends"]
		_:
			if h.get("type", "") == "loan":
				s["value"] = -last_val if last_val >= 0 else 0
				s["invested"] = 0
				s["gain"] = 0
			else:
				if last_val >= 0:
					s["value"] = last_val + after_val_net
				else:
					s["value"] = s["invested"] + s["interest"] - s["fees"]
				s["gain"] = s["value"] - s["invested"] + s["dividends"]
	return s


## Totals across all holdings on `date`.
func totals(date: String = "") -> Dictionary:
	if date == "":
		date = Dates.today()
	var out := {"value": 0, "invested": 0, "gain": 0, "assets": 0, "debts": 0,
		"by_type": {}, "by_account": {}, "missing": 0, "estimated": false, "oldest_price": ""}
	for h in data.get("holdings", []):
		var s := holding_state(h, date)
		out["value"] += s["value"]
		out["invested"] += s["invested"]
		out["gain"] += s["gain"]
		if s["value"] < 0:
			out["debts"] += s["value"]
		else:
			out["assets"] += s["value"]
			var group: String = Catalog.holding_type(h.get("type", "other"))["group"]
			out["by_type"][group] = out["by_type"].get(group, 0) + s["value"]
			var acc_name: String = account(h.get("account_id", "")).get("name", "Other")
			out["by_account"][acc_name] = out["by_account"].get(acc_name, 0) + s["value"]
		if s["missing_price"]:
			out["missing"] += 1
		if s["estimated"]:
			out["estimated"] = true
		if s["price_date"] != "" and (out["oldest_price"] == "" or s["price_date"] < out["oldest_price"]):
			out["oldest_price"] = s["price_date"]
	return out


func first_date() -> String:
	var first := ""
	for m in data.get("movements", []):
		if first == "" or m["date"] < first:
			first = m["date"]
	return first


## Value and money invested over time. months = 0 means since the first movement.
## Returns Array of {date, value, invested}.
func series(months: int = 12) -> Array:
	var today := Dates.today()
	var first := first_date()
	if first == "":
		return []
	var start := first
	if months > 0:
		var limit := Dates.add_days(today, -months * 30 - months / 2)
		if limit > start:
			start = limit
	var dates := []
	var span := Dates.to_days(today) - Dates.to_days(start)
	if span <= 400:
		var step := maxi(1, span / 60)
		var d := Dates.to_days(start)
		while d < Dates.to_days(today):
			dates.append(Dates.from_days(d))
			d += step
	else:
		var key := Dates.month_key(start)
		var end_key := Dates.month_key(today)
		dates.append(start)
		while key < end_key:
			dates.append(Dates.month_end(key))
			key = Dates.month_key_add(key, 1)
	dates.append(today)
	var out := []
	for dt in dates:
		var t := totals(dt)
		out.append({"date": dt, "value": t["value"], "invested": t["invested"]})
	return out


func income_for(key: String) -> int:
	var inc: Dictionary = data.get("income", {})
	if inc.has(key):
		return int(inc[key])
	return int(data.get("settings", {}).get("monthly_income_cents", 0))


## Money saved per month (deposits − withdrawals, all holdings except debts) for the last n months.
func monthly_savings(n: int = 12) -> Array:
	var this_key := Dates.month_key(Dates.today())
	var start_key := Dates.month_key_add(this_key, -(n - 1))
	var per := {}
	for h in data.get("holdings", []):
		if h.get("type", "") == "loan":
			continue
		for mv in movements(h["id"]):
			var key := Dates.month_key(mv["date"])
			if key < start_key or key > this_key:
				continue
			var k: String = mv.get("kind", "")
			if k == "deposit":
				per[key] = per.get(key, 0) + int(mv.get("amount_cents", 0))
			elif k == "withdrawal":
				per[key] = per.get(key, 0) - int(mv.get("amount_cents", 0))
	var out := []
	for i in n:
		var key := Dates.month_key_add(start_key, i)
		out.append({"month": key, "saved": per.get(key, 0), "income": income_for(key)})
	return out
