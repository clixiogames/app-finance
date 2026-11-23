class_name SampleData
## Example data to explore the app ("Explore with sample data"). All prices here are made up.


## Made-up price path: steady yearly growth `drift` with gentle waves and small daily noise.
static func _walk(start: String, end: String, p0: float, drift: float, vol: float, seed_v: int, weekdays_only: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pts := {}
	var d0 := Dates.to_days(start)
	var d := d0
	while d <= Dates.to_days(end):
		var wd := (d + 4) % 7  # 0 = Sunday
		if not weekdays_only or (wd != 0 and wd != 6):
			var t := float(d - d0)
			var p := p0 * exp(drift * t / 365.0) * (1.0 + vol * 4.0 * sin(t / 47.0 + seed_v)) * (1.0 + rng.randfn(0.0, vol * 0.6))
			pts[Dates.from_days(d)] = Money.from_float(p, Money.PRICE_SCALE)
		d += 1
	return pts


## Builds a complete example data set ending on `today`. Prices are made up (clearly labelled).
static func build(today: String = "") -> Dictionary:
	if today == "":
		today = Dates.today()
	var d := StoreScript.default_data()
	d["settings"]["sample"] = true
	d["settings"]["onboarded"] = true
	d["settings"]["monthly_income_cents"] = 280000
	d["accounts"] = [
		{"id": "a_pea", "name": "PEA", "kind": "pea", "institution": "My online broker"},
		{"id": "a_bank", "name": "Savings accounts", "kind": "bank_savings", "institution": "My bank"},
		{"id": "a_av", "name": "Life insurance", "kind": "assurance_vie", "institution": "My insurer"},
		{"id": "a_crypto", "name": "Crypto", "kind": "crypto", "institution": "My exchange"},
	]
	d["holdings"] = [
		{"id": "h_world", "account_id": "a_pea", "name": "World stocks ETF (sample)", "type": "etf", "price_key": "sample:world", "currency": "EUR"},
		{"id": "h_em", "account_id": "a_pea", "name": "Emerging markets ETF (sample)", "type": "etf", "price_key": "sample:em", "currency": "EUR"},
		{"id": "h_la", "account_id": "a_bank", "name": "Livret A", "type": "livret_a", "rate_source": "livret_a", "interest_mode": "auto", "price_key": ""},
		{"id": "h_ldds", "account_id": "a_bank", "name": "LDDS", "type": "ldds", "rate_source": "ldds", "interest_mode": "auto", "price_key": ""},
		{"id": "h_euro", "account_id": "a_av", "name": "Fonds euros", "type": "euro_fund", "price_key": ""},
		{"id": "h_btc", "account_id": "a_crypto", "name": "Bitcoin (sample)", "type": "crypto", "price_key": "sample:btc", "currency": "EUR"},
	]
	d["prices"]["sample:world"] = {"currency": "EUR", "points": _walk("2023-12-20", "2026-11-17", 420.0, 0.09, 0.012, 7, true)}
	d["prices"]["sample:em"] = {"currency": "EUR", "points": _walk("2023-12-20", "2026-11-17", 21.0, 0.05, 0.015, 11, true)}
	d["prices"]["sample:btc"] = {"currency": "EUR", "points": _walk("2025-11-18", "2026-11-18", 82000.0, 0.22, 0.03, 3, false)}
	var mv := []
	var key := "2024-01"
	var i := 0
	while key <= "2026-11":
		mv.append({"id": "w%d" % i, "holding_id": "h_world", "date": key + "-05", "kind": "deposit", "amount_cents": 40000, "fee_cents": 0, "units_6": null, "price_4": null})
		if i % 3 == 0:
			mv.append({"id": "e%d" % i, "holding_id": "h_em", "date": key + "-06", "kind": "deposit", "amount_cents": 15000, "fee_cents": 0, "units_6": null, "price_4": null})
		if i % 2 == 0:
			mv.append({"id": "l%d" % i, "holding_id": "h_la", "date": key + "-02", "kind": "deposit", "amount_cents": 20000})
		key = Dates.month_key_add(key, 1)
		i += 1
	mv.append({"id": "dv1", "holding_id": "h_em", "date": "2024-07-10", "kind": "dividend", "amount_cents": 1840})
	mv.append({"id": "dv2", "holding_id": "h_em", "date": "2025-07-09", "kind": "dividend", "amount_cents": 2615})
	mv.append({"id": "dv3", "holding_id": "h_em", "date": "2026-07-08", "kind": "dividend", "amount_cents": 3120})
	mv.append({"id": "fe1", "holding_id": "h_euro", "date": "2025-12-31", "kind": "fee", "amount_cents": 650})
	mv.append({"id": "la0", "holding_id": "h_la", "date": "2023-12-28", "kind": "deposit", "amount_cents": 500000})
	mv.append({"id": "la1", "holding_id": "h_la", "date": "2025-07-20", "kind": "withdrawal", "amount_cents": 150000})
	mv.append({"id": "ld0", "holding_id": "h_ldds", "date": "2024-03-10", "kind": "deposit", "amount_cents": 600000})
	mv.append({"id": "av0", "holding_id": "h_euro", "date": "2024-02-15", "kind": "deposit", "amount_cents": 1000000})
	mv.append({"id": "av1", "holding_id": "h_euro", "date": "2024-12-31", "kind": "valuation", "amount_cents": 1025000})
	mv.append({"id": "av2", "holding_id": "h_euro", "date": "2025-12-31", "kind": "valuation", "amount_cents": 1052000})
	mv.append({"id": "b0", "holding_id": "h_btc", "date": "2025-12-10", "kind": "deposit", "amount_cents": 100000, "fee_cents": 0, "units_6": null, "price_4": null})
	mv.append({"id": "b1", "holding_id": "h_btc", "date": "2026-04-10", "kind": "deposit", "amount_cents": 50000, "fee_cents": 0, "units_6": null, "price_4": null})
	mv.append({"id": "w_sell", "holding_id": "h_world", "date": "2026-09-14", "kind": "withdrawal", "amount_cents": 200000, "fee_cents": 0, "units_6": null, "price_4": null})
	for m in mv:
		m["created"] = m["id"]
	d["movements"] = mv
	d["income"] = {"2026-09": 310000}
	var lines := ["Date;Libellé;Montant"]
	var spend := [
		["01", "VIR SEPA RECU SALAIRE ACME SAS", "2800,00"], ["02", "PRLV SEPA LOYER FONCIA", "-850,00"],
		["03", "CB CARREFOUR CITY 03/%s", "-46,20"], ["04", "CB UBER EATS PARIS", "-23,90"],
		["05", "PRLV SEPA EDF", "-62,00"], ["06", "CB NAVIGO", "-86,40"], ["07", "PRLV SEPA NETFLIX.COM", "-13,49"],
		["08", "CB PHARMACIE DU CENTRE", "-18,30"], ["10", "CB LECLERC DRIVE", "-112,75"], ["12", "CB FNAC", "-59,99"],
		["13", "RETRAIT DAB PARIS", "-40,00"], ["14", "CB RESTAURANT LE PETIT ZINC", "-38,00"],
		["15", "VIR SEPA VERS LIVRET A", "-200,00"], ["16", "PRLV SEPA FREE MOBILE", "-19,99"], ["17", "CB DECATHLON", "-34,99"],
	]
	for m in ["09", "10", "11"]:
		for t in spend:
			if m == "11" and int(t[0]) > 17:
				continue
			var amt: String = t[2]
			lines.append("%s/%s/2026;%s;%s" % [t[0], m, t[1].replace("%s", m), amt])
	var rows: Array = Spending.parse("\n".join(lines))["rows"]
	var txs := []
	var n := 0
	for r in Spending.keyed(rows):
		txs.append({"id": "t%d" % n, "date": r["date"], "amount_cents": r["amount_cents"], "label": r["label"], "bank": "My bank", "key": r["key"], "category": Spending.guess_category(r["label"], r["amount_cents"], {})})
		n += 1
	d["spending"] = {"transactions": txs, "rules": {}}
	return d
	return _shift(d, today)


## Moves every date so the sample ends today (it was written as if today were 2026-11-18).
static func _shift(d: Dictionary, today: String) -> Dictionary:
	var off := Dates.to_days(today) - Dates.to_days(BASE_DAY)
	if off == 0:
		return d
	var mdelta := Dates.months_between(Dates.month_key(BASE_DAY), Dates.month_key(today))
	for m in d["movements"]:
		m["date"] = Dates.add_days(m["date"], off)
	for t in d["spending"]["transactions"]:
		t["date"] = Dates.add_days(t["date"], off)
	for key in d["prices"]:
		var pts := {}
		var old: Dictionary = d["prices"][key]["points"]
		for dt in old:
			pts[Dates.add_days(dt, off)] = old[dt]
		d["prices"][key]["points"] = pts
	var inc := {}
	for k in d["income"]:
		inc[Dates.month_key_add(k, mdelta)] = d["income"][k]
	d["income"] = inc
	return d


const BASE_DAY := "2026-11-18"
const StoreScript = preload("res://src/core/store.gd")

