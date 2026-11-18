extends Node
## Takes screenshots of the main screens with SAMPLE data (fake prices) for visual review.
## Run: xvfb-run godot --path . res://tests/shots.tscn -- --out=/tmp/shots [--dark]
## Not part of the shipped app.

var out_dir := "/tmp/shots"
var main: Control


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	OS.low_processor_usage_mode = false
	Dates.fixed_today = "2026-11-18"
	Store.persist = false
	var d := sample_data()
	if "--dark" in OS.get_cmdline_user_args():
		d["settings"]["theme"] = "dark"
	else:
		d["settings"]["theme"] = "light"
	Store.set_data(d, false)
	main = load("res://src/ui/main.tscn").instantiate()
	add_child(main)
	await _settle()
	await shot("01_overview")
	main.scroll.scroll_vertical = 520
	await _settle()
	await shot("02_overview_scrolled")
	main.switch_tab("accounts")
	await _settle()
	await shot("03_wealth")
	var etf: Dictionary = Store.data["holdings"][0]
	main.push(preload("res://src/ui/screens/holding_screen.gd").new(etf["id"]))
	await _settle()
	await shot("04_holding")
	main.push(preload("res://src/ui/screens/movement_edit_screen.gd").new(etf["id"], "deposit"))
	await _settle()
	var form = main.current()
	form._amount.text = "500"
	form._update_preview()
	await _settle()
	await shot("05_add_deposit")
	main.pop_to_root()
	main.push(preload("res://src/ui/screens/holding_edit_screen.gd").new("", Store.data["accounts"][1]["id"]))
	await _settle()
	await shot("06_new_holding_livret")
	main.switch_tab("settings")
	await _settle()
	await shot("07_settings")
	Store.data["settings"]["onboarded"] = false
	main._set_root(preload("res://src/ui/screens/onboarding_screen.gd").new())
	await _settle()
	await shot("08_onboarding")
	get_tree().quit()


func _settle() -> void:
	for i in 6:
		await get_tree().process_frame
	await get_tree().process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


# ---------- sample data (fake prices, for screenshots only) ----------

func _walk(start: String, end: String, p0: float, drift: float, vol: float, seed_v: int, weekdays_only: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pts := {}
	var p := p0
	var d := Dates.to_days(start)
	while d <= Dates.to_days(end):
		var wd := (d + 4) % 7  # 0 = Sunday
		if not weekdays_only or (wd != 0 and wd != 6):
			p *= 1.0 + drift + rng.randfn(0.0, vol)
			pts[Dates.from_days(d)] = Money.from_float(p, Money.PRICE_SCALE)
		d += 1
	return pts


func sample_data() -> Dictionary:
	var d := StoreScript.default_data()
	d["settings"]["onboarded"] = true
	d["settings"]["monthly_income_cents"] = 280000
	d["settings"]["prices_updated"] = "2026-11-18T07:30:00Z"
	d["accounts"] = [
		{"id": "a_pea", "name": "PEA Boursorama", "kind": "pea", "institution": "Boursorama"},
		{"id": "a_bank", "name": "Livrets", "kind": "bank_savings", "institution": "La Banque Postale"},
		{"id": "a_av", "name": "Assurance vie Linxea", "kind": "assurance_vie", "institution": "Linxea"},
		{"id": "a_crypto", "name": "Crypto", "kind": "crypto", "institution": "Kraken"},
	]
	d["holdings"] = [
		{"id": "h_world", "account_id": "a_pea", "name": "Amundi MSCI World", "type": "etf", "price_key": "y:CW8.PA", "currency": "EUR"},
		{"id": "h_em", "account_id": "a_pea", "name": "Amundi MSCI Emerging", "type": "etf", "price_key": "y:PAEEM.PA", "currency": "EUR"},
		{"id": "h_la", "account_id": "a_bank", "name": "Livret A", "type": "livret_a", "rate_source": "livret_a", "interest_mode": "auto", "price_key": ""},
		{"id": "h_ldds", "account_id": "a_bank", "name": "LDDS", "type": "ldds", "rate_source": "ldds", "interest_mode": "auto", "price_key": ""},
		{"id": "h_euro", "account_id": "a_av", "name": "Fonds euros", "type": "euro_fund", "price_key": ""},
		{"id": "h_btc", "account_id": "a_crypto", "name": "Bitcoin", "type": "crypto", "price_key": "cg:bitcoin", "currency": "EUR"},
	]
	d["prices"]["y:CW8.PA"] = {"currency": "EUR", "points": _walk("2023-12-20", "2026-11-17", 420.0, 0.0005, 0.009, 7, true)}
	d["prices"]["y:PAEEM.PA"] = {"currency": "EUR", "points": _walk("2023-12-20", "2026-11-17", 21.0, 0.0003, 0.011, 11, true)}
	d["prices"]["cg:bitcoin"] = {"currency": "EUR", "points": _walk("2025-11-18", "2026-11-18", 82000.0, 0.0004, 0.025, 3, false)}
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
	return d


const StoreScript = preload("res://src/core/store.gd")
