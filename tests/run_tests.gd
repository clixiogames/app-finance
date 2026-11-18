extends SceneTree
## Automated checks for the money maths, interest engine and portfolio calculations.
## Run: godot --headless --path . --script res://tests/run_tests.gd

var passed := 0
var failed := 0


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: ", name)


func eq(a: Variant, b: Variant, name: String) -> void:
	if typeof(a) == typeof(b) and a == b:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: %s — got %s, expected %s" % [name, str(a), str(b)])


func _init() -> void:
	Dates.fixed_today = "2026-11-18"
	test_money()
	test_dates()
	test_rates()
	test_interest()
	test_portfolio_market()
	test_portfolio_interest_and_manual()
	test_savings()
	test_parsers()
	test_migration()
	print("Tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func test_money() -> void:
	eq(Money.parse_cents("1 234,56"), 123456, "parse fr")
	eq(Money.parse_cents("1,234.56"), 123456, "parse en")
	eq(Money.parse_cents("500"), 50000, "parse int")
	eq(Money.parse_cents("12,5"), 1250, "parse one decimal")
	eq(Money.parse_cents("0,005"), 1, "parse rounds")
	eq(Money.parse_cents("€ 20"), 2000, "parse symbol")
	eq(Money.parse_cents("-3.10"), -310, "parse negative")
	eq(Money.parse_cents("abc"), null, "parse invalid")
	eq(Money.parse_cents(""), null, "parse empty")
	eq(Money.parse_decimal("1.5", 10000), 15000, "parse rate")
	eq(Money.fmt(123456), "1 234,56 €", "format")
	eq(Money.fmt(-5), "−0,05 €", "format negative")
	eq(Money.fmt(1000, "EUR", true), "+10,00 €", "format signed")
	eq(Money.fmt(199999, "EUR", false, 0), "2 000 €", "format rounded")
	eq(Money.fmt_short(1234567), "12,3 k€", "short k")
	eq(Money.fmt_short(250000000), "2,5 M€", "short M")
	eq(Money.pct(1234, 10000), "+12,3 %", "pct")
	eq(Money.pct(1, 0), "—", "pct zero")
	# 500 € at 98,1234 € -> 5.095648 units
	eq(Money.units_for(50000, 981234), 5095624, "units")
	eq(Money.value_cents(5095648, 1000000), 50956, "value")
	eq(Money.convert(10000, 920000), 9200, "fx convert")
	eq(Money.mul_div(-7, 3, 2), -11, "mul_div rounding negative")
	eq(Money.fmt_units(1500000), "1,5", "units format")


func test_dates() -> void:
	eq(Dates.quinzaine("2026-03-15"), 2026 * 24 + 4, "quinzaine first half")
	eq(Dates.quinzaine("2026-03-16"), 2026 * 24 + 5, "quinzaine second half")
	eq(Dates.quinzaine_start(2026 * 24 + 5), "2026-03-16", "quinzaine start")
	eq(Dates.month_key_add("2026-11", 3), "2027-02", "month add")
	eq(Dates.month_key_add("2026-01", -1), "2025-12", "month sub")
	eq(Dates.month_end("2024-02"), "2024-02-29", "leap month end")
	eq(Dates.add_days("2026-12-31", 1), "2027-01-01", "add days")
	check(Dates.is_valid("2026-02-28"), "valid date")
	check(not Dates.is_valid("2026-02-30"), "invalid date")
	eq(Dates.months_between("2025-11", "2026-11"), 12, "months between")


func test_rates() -> void:
	eq(RegulatedRates.rate_bps("livret_a", "2024-06-01"), 300, "livret A 2024")
	eq(RegulatedRates.rate_bps("livret_a", "2026-08-01"), 170, "livret A Aug 2026")
	eq(RegulatedRates.rate_bps("livret_a", "2026-07-31"), 150, "livret A Jul 2026")
	eq(RegulatedRates.rate_bps("lep", "2026-11-18"), 250, "LEP now")
	eq(RegulatedRates.rate_bps("fixed", "2026-11-18", 325), 325, "fixed rate")


func test_interest() -> void:
	var rate3 := func(_d: String) -> int: return 300
	# 10 000 € deposited 1 Jan: earns from 16 Jan -> 23 quinzaines in the year.
	var mv := [{"date": "2024-01-01", "kind": "deposit", "amount_cents": 1000000}]
	var r := InterestCalc.compute(mv, rate3, "2025-01-01")
	eq(r["credited"], 1000000 * 300 * 23 / 240000, "interest year 1 credited")
	eq(r["accrued"], 0, "nothing accrued after credit")
	# Deposit on 31 Dec: first quinzaine starts 1 Jan next year.
	var mv2 := [{"date": "2023-12-31", "kind": "deposit", "amount_cents": 1000000}]
	var r2 := InterestCalc.compute(mv2, rate3, "2025-01-01")
	eq(r2["credited"], 1000000 * 300 * 24 / 240000, "full year from 1 Jan")
	# Withdrawal on 20 March removes balance from 16 March.
	var mv3 := [
		{"date": "2023-12-31", "kind": "deposit", "amount_cents": 1000000},
		{"date": "2024-03-20", "kind": "withdrawal", "amount_cents": 1000000},
	]
	var r3 := InterestCalc.compute(mv3, rate3, "2025-01-01")
	eq(r3["credited"], 1000000 * 300 * 5 / 240000, "withdrawal quinzaine rule")
	# Interest is capitalised: 2nd year earns on balance + year-1 interest.
	var r4 := InterestCalc.compute(mv2, rate3, "2026-01-01")
	var y1 := 30000
	eq(r4["credited"], y1 + (1000000 + y1) * 300 * 24 / 240000, "capitalisation")
	# Mid-year accrual.
	var r5 := InterestCalc.compute(mv2, rate3, "2024-07-01")
	eq(r5["accrued"], 1000000 * 300 * 12 / 240000, "accrued half year")


func _base_data() -> Dictionary:
	var d := {
		"settings": {"currency": "EUR", "monthly_income_cents": 300000},
		"accounts": [{"id": "a1", "name": "PEA", "kind": "pea"}],
		"holdings": [], "movements": [], "income": {}, "prices": {}, "fx": {},
	}
	return d


func test_portfolio_market() -> void:
	var d := _base_data()
	d["holdings"].append({"id": "h1", "account_id": "a1", "name": "World ETF", "type": "etf", "price_key": "y:CW8.PA", "currency": "EUR"})
	d["movements"].append({"id": "m1", "holding_id": "h1", "date": "2026-01-05", "kind": "deposit", "amount_cents": 100000, "fee_cents": 0, "units_6": null, "price_4": null})
	d["movements"].append({"id": "m2", "holding_id": "h1", "date": "2026-06-03", "kind": "deposit", "amount_cents": 50000, "fee_cents": 0, "units_6": null, "price_4": null})
	d["prices"]["y:CW8.PA"] = {"currency": "EUR", "points": {"2026-01-02": 5000000, "2026-06-02": 5500000, "2026-11-17": 6000000}}
	var p := Portfolio.new(d)
	var s := p.holding_state(d["holdings"][0])
	# 1000 € @ 500 -> 2 units; 500 € @ 550 -> 0.909091 units
	eq(s["units"], 2000000 + 909091, "market units")
	eq(s["value"], Money.value_cents(2909091, 6000000), "market value")
	eq(s["invested"], 150000, "market invested")
	eq(s["gain"], s["value"] - 150000, "market gain")
	eq(s["price_date"], "2026-11-17", "price date shown")
	# Manual override of units/price.
	d["movements"][0]["units_6"] = 2100000
	d["movements"][0]["price_4"] = 4761905
	var p2 := Portfolio.new(d)
	eq(p2.holding_state(d["holdings"][0])["units"], 2100000 + 909091, "manual units override")
	# Missing price -> falls back to invested, flagged.
	d["holdings"].append({"id": "h2", "account_id": "a1", "name": "No price", "type": "etf", "price_key": "y:NONE", "currency": "EUR"})
	d["movements"].append({"id": "m3", "holding_id": "h2", "date": "2026-02-01", "kind": "deposit", "amount_cents": 20000, "fee_cents": 0, "units_6": null, "price_4": null})
	var p3 := Portfolio.new(d)
	var s3 := p3.holding_state(d["holdings"][1])
	check(s3["missing_price"], "missing price flagged")
	eq(s3["value"], 20000, "missing price uses invested")
	eq(p3.totals()["missing"], 1, "totals count missing")
	# Foreign currency: USD instrument, 1 USD = 0.90 €
	var d2 := _base_data()
	d2["holdings"].append({"id": "u", "account_id": "a1", "name": "US stock", "type": "stock", "price_key": "y:AAPL", "currency": "USD"})
	d2["movements"].append({"id": "mu", "holding_id": "u", "date": "2026-03-02", "kind": "deposit", "amount_cents": 90000, "fee_cents": 0, "units_6": null, "price_4": null})
	d2["prices"]["y:AAPL"] = {"currency": "USD", "points": {"2026-03-02": 2000000, "2026-11-17": 2500000}}
	d2["fx"]["USD"] = {"points": {"2026-03-02": 900000, "2026-11-17": 900000}}
	var su := Portfolio.new(d2).holding_state(d2["holdings"][0])
	eq(su["units"], 5000000, "usd units: 900€ -> 1000$ -> 5 shares")
	eq(su["value"], 112500, "usd value: 5 × 250$ × 0.9")


func test_portfolio_interest_and_manual() -> void:
	var d := _base_data()
	d["holdings"].append({"id": "la", "account_id": "a1", "name": "Livret A", "type": "livret_a", "rate_source": "livret_a", "interest_mode": "auto"})
	d["movements"].append({"id": "m1", "holding_id": "la", "date": "2025-12-31", "kind": "deposit", "amount_cents": 1000000})
	var p := Portfolio.new(d)
	var s := p.holding_state(d["holdings"][0], "2026-02-01")
	# Jan 2026 at 1.70 % (rate from Aug 2025): 2 quinzaines
	eq(s["interest"], 1000000 * 170 * 2 / 240000, "livret auto interest")
	check(s["estimated"], "auto interest is estimated")
	d["holdings"][0]["interest_mode"] = "none"
	eq(Portfolio.new(d).holding_state(d["holdings"][0], "2026-02-01")["value"], 1000000, "interest ignored")
	d["holdings"][0]["interest_mode"] = "manual"
	d["movements"].append({"id": "m2", "holding_id": "la", "date": "2026-12-31", "kind": "interest", "amount_cents": 15000})
	eq(Portfolio.new(d).holding_state(d["holdings"][0], "2027-01-01")["value"], 1015000, "manual interest")
	# Manual valuation
	var d2 := _base_data()
	d2["holdings"].append({"id": "av", "account_id": "a1", "name": "Fonds euros", "type": "euro_fund"})
	d2["movements"].append({"id": "x1", "holding_id": "av", "date": "2025-01-10", "kind": "deposit", "amount_cents": 500000})
	d2["movements"].append({"id": "x2", "holding_id": "av", "date": "2025-12-31", "kind": "valuation", "amount_cents": 512000})
	d2["movements"].append({"id": "x3", "holding_id": "av", "date": "2026-03-01", "kind": "deposit", "amount_cents": 100000})
	var s2 := Portfolio.new(d2).holding_state(d2["holdings"][0])
	eq(s2["value"], 612000, "valuation + later deposit")
	eq(s2["gain"], 12000, "valuation gain")
	# Loan
	d2["holdings"].append({"id": "ln", "account_id": "a1", "name": "Mortgage", "type": "loan"})
	d2["movements"].append({"id": "x4", "holding_id": "ln", "date": "2026-01-01", "kind": "valuation", "amount_cents": 10000000})
	var t := Portfolio.new(d2).totals()
	eq(t["value"], 612000 - 10000000, "net worth with debt")
	eq(t["debts"], -10000000, "debts total")


func test_savings() -> void:
	var d := _base_data()
	d["holdings"].append({"id": "la", "account_id": "a1", "name": "Livret A", "type": "livret_a", "rate_source": "livret_a", "interest_mode": "none"})
	d["movements"].append({"id": "1", "holding_id": "la", "date": "2026-11-02", "kind": "deposit", "amount_cents": 60000})
	d["movements"].append({"id": "2", "holding_id": "la", "date": "2026-11-10", "kind": "withdrawal", "amount_cents": 10000})
	d["movements"].append({"id": "3", "holding_id": "la", "date": "2026-10-02", "kind": "deposit", "amount_cents": 30000})
	d["income"]["2026-10"] = 250000
	var ms := Portfolio.new(d).monthly_savings(12)
	eq(ms.size(), 12, "12 months")
	eq(ms[11]["month"], "2026-11", "last month is current")
	eq(ms[11]["saved"], 50000, "saved this month")
	eq(ms[11]["income"], 300000, "default income")
	eq(ms[10]["income"], 250000, "income override")
	var ser := Portfolio.new(d).series(12)
	check(ser.size() > 10, "series has points")
	eq(ser[ser.size() - 1]["value"], 80000, "series ends at current value")


func test_parsers() -> void:
	var yahoo := {"chart": {"result": [{
		"meta": {"currency": "GBp", "gmtoffset": 0, "regularMarketPrice": 812.5, "regularMarketTime": 1763424000},
		"timestamp": [1763337600],
		"indicators": {"quote": [{"close": [800.0]}]},
	}]}}
	var py := PriceParsers.parse_yahoo_chart(yahoo)
	check(py["ok"], "yahoo parse ok")
	eq(py["currency"], "GBP", "pence converted")
	eq(py["points"]["2025-11-17"], 80000, "pence price /100")
	var cg := PriceParsers.parse_coingecko({"prices": [[1763337600000, 81234.5]]}, "eur")
	eq(cg["points"]["2025-11-17"], 812345000, "coingecko parse")
	var fx := PriceParsers.parse_frankfurter({"rates": {"2026-01-02": {"EUR": 0.9123}}}, "EUR")
	eq(fx["points"]["2026-01-02"], 912300, "frankfurter parse")
	check(not PriceParsers.parse_yahoo_chart({"chart": {"result": null}})["ok"], "yahoo empty")


func test_migration() -> void:
	var raw := {"app": "app-finance", "schema": 1, "settings": {"currency": "EUR", "monthly_income_cents": 250000.0},
		"movements": [{"amount_cents": 100.0, "units_6": 5.0, "price_4": null}], "prices": {"k": {"points": {"2026-01-01": 12.0}}}}
	var m := StoreScript.migrate(raw)
	eq(m["movements"][0]["amount_cents"], 100, "float to int amount")
	eq(m["movements"][0]["units_6"], 5, "float to int units")
	eq(m["settings"]["monthly_income_cents"], 250000, "income int")
	eq(m["settings"]["interest_mode"], "auto", "default filled")
	eq(m["prices"]["k"]["points"]["2026-01-01"], 12, "price int")
	check(m["holdings"] is Array, "missing lists created")


const StoreScript = preload("res://src/core/store.gd")
