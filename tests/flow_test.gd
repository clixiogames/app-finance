extends Node
## End-to-end check of the main user flow through the real screens (no network):
## onboarding -> add account -> add Livret A -> deposit -> overview totals -> backup round-trip.
## Run: godot --headless --path . res://tests/flow_test.tscn

var failures := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)


func _ready() -> void:
	Dates.fixed_today = "2026-11-18"
	Store.persist = false
	Store.set_data(Store.default_data(), false)
	var main = load("res://src/ui/main.tscn").instantiate()
	add_child(main)
	await _frames()

	# Onboarding
	var ob = main.current()
	check(ob.get_script().resource_path.ends_with("onboarding_screen.gd"), "starts on onboarding")
	ob._income.text = "2 500"
	ob._start()
	await _frames()
	check(Store.setting("onboarded"), "onboarded saved")
	check(Store.setting("monthly_income_cents") == 250000, "income saved")

	# Add account
	main.push(preload("res://src/ui/screens/account_edit_screen.gd").new())
	await _frames()
	var ae = main.current()
	ae._name.text = "Livrets"
	ae._kind.select(_index_of(ae._kind, "bank_savings"))
	ae._save()
	await _frames()
	check(Store.data["accounts"].size() == 1, "account created")
	var he = main.current()
	check(he.get_script().resource_path.ends_with("holding_edit_screen.gd"), "goes to new holding")
	check(Ui.option_value(he._type) == "livret_a", "bank savings defaults to Livret A")
	he._save()
	await _frames()
	check(Store.data["holdings"].size() == 1, "holding created")
	check(Store.data["holdings"][0]["interest_mode"] == "auto", "default interest mode")

	# Deposit
	var me = main.current()
	check(me.get_script().resource_path.ends_with("movement_edit_screen.gd"), "goes to deposit")
	me._amount.text = "1 000,50"
	me._save()
	await _frames()
	check(Store.data["movements"].size() == 1, "deposit created")
	check(Store.data["movements"][0]["amount_cents"] == 100050, "amount parsed exactly")
	var t: Dictionary = Store.portfolio.totals()
	check(t["invested"] == 100050, "invested total")

	# Market holding without a price: shows invested amount, flagged
	var hid := Store.add_holding({"account_id": Store.data["accounts"][0]["id"], "type": "etf", "name": "World", "price_key": "y:TEST", "currency": ""})
	Store.add_movement({"holding_id": hid, "kind": "deposit", "date": "2026-11-02", "amount_cents": 50000, "fee_cents": 0, "units_6": null, "price_4": null})
	t = Store.portfolio.totals()
	check(t["missing"] == 1, "missing price flagged")
	check(t["value"] == 150050, "value falls back to invested")

	# Every tab renders
	for tab in ["overview", "accounts", "spending", "settings"]:
		main.switch_tab(tab)
		await _frames()
	main.push(preload("res://src/ui/screens/holding_screen.gd").new(hid))
	await _frames()
	main.push(preload("res://src/ui/screens/income_screen.gd").new())
	await _frames()

	# Spending: import, re-import (no duplicates), learn a category
	var csv := "Date;Libellé;Montant\n03/11/2026;CB CHEZ MARIE;-4,50\n04/11/2026;CB CHEZ MARIE;-3,20\n05/11/2026;PRLV SEPA NETFLIX.COM;-13,49\n"
	var parsed := Spending.parse(csv)
	var imp := Store.import_transactions(parsed["rows"], "Test bank")
	check(imp["added"] == 3, "spending import adds 3")
	check(Store.import_transactions(parsed["rows"], "Test bank")["added"] == 0, "re-import adds nothing")
	var bread: Dictionary = Store.transactions()[0]
	check(bread["category"] == "other", "unknown bakery starts as other")
	var updated := Store.update_transaction(bread["id"], {"category": "groceries"}, true)
	check(updated == 1, "learning updates the similar transaction")
	check(Store.transactions()[1]["category"] == "groceries", "similar transaction recategorised")
	check(Store.transactions()[2]["category"] == "subscriptions", "netflix auto-categorised")
	check(Store.portfolio.totals()["value"] == 150050, "spending does not touch wealth")
	main.switch_tab("spending")
	await _frames()
	main.push(preload("res://src/ui/screens/transaction_edit_screen.gd").new(bread["id"]))
	await _frames()
	main.push(preload("res://src/ui/screens/spending_import_screen.gd").new(parsed, "bourso.csv"))
	await _frames()

	# Backup round trip
	var json := Store.export_json()
	Store.reset_all()
	check(Store.data["movements"].is_empty(), "reset clears data")
	check(Store.import_json(json) == "", "import ok")
	check(Store.data["movements"].size() == 2, "import restores movements")
	check(Store.transactions().size() == 3, "import restores spending")
	check(Store.import_json("{\"x\":1}") != "", "rejects foreign file")

	# Monthly repeat: one entry dated in the past fills in the months up to today
	var hid2: String = Store.data["holdings"][0]["id"]
	var before: int = Store.data["movements"].size()
	Store.add_movement({"holding_id": hid2, "kind": "deposit", "date": "2026-06-10", "amount_cents": 10000})
	Store.add_recurring({"holding_id": hid2, "kind": "deposit", "amount_cents": 10000, "day": 10, "start": "2026-06-10", "last": "2026-06-10"})
	check(Store.data["movements"].size() - before == 6, "June entry + July..Nov repeats (got %d)" % (Store.data["movements"].size() - before))
	check(Store.apply_recurring() == 0, "nothing more due today")
	main.push(preload("res://src/ui/screens/holding_screen.gd").new(hid2))
	await _frames()
	Store.delete_recurring(Store.data["recurring"][0]["id"])
	check(Store.data["recurring"].is_empty(), "repeat stopped")

	# Device-only settings never go into backups
	Store.data["settings"]["av_key"] = "ABCDEF1234567890"
	var exported := Store.export_json()
	check(not exported.contains("ABCDEF1234567890"), "price key not in backup")
	check(Store.import_json(exported) == "", "re-import ok")
	check(Store.setting("av_key") == "ABCDEF1234567890", "price key kept on device after restore")

	# App lock
	main.push(preload("res://src/ui/screens/pin_setup_screen.gd").new())
	await _frames()
	var ps = main.current()
	ps._on_pin("1234")
	ps._on_pin("1234")
	await _frames()
	check(str(Store.setting("pin_hash")) != "" and not str(Store.setting("pin_hash")).contains("1234"), "PIN stored as hash")
	check(not Store.export_json().contains(str(Store.setting("pin_hash"))), "PIN hash not in backup")
	main.lock_if_needed()
	await _frames()
	check(main.lock_layer != null, "app locked")
	main.lock_layer._check("0000")
	check(main.lock_layer != null, "wrong PIN keeps it locked")
	main.lock_layer._check("1234")
	await _frames()
	check(main.lock_layer == null, "right PIN unlocks")
	Store.set_settings({"pin_hash": "", "pin_salt": ""})

	# Sample data mode
	Store.set_data(SampleData.build("2026-11-18"), false)
	main.reload_theme()
	await _frames()
	var st: Dictionary = Store.portfolio.totals()
	check(Store.setting("sample", false), "sample flag set")
	check(st["value"] > 0 and st["missing"] == 0, "sample has values and prices")
	check(PriceService.waiting_for_key() == 0, "sample needs no price key")
	var ar: Dictionary = Store.portfolio.annual_return()
	check(ar["ok"], "sample annual return")
	for tab in ["overview", "accounts", "spending", "settings"]:
		main.switch_tab(tab)
		await _frames()
	main.push(preload("res://src/ui/screens/price_setup_screen.gd").new())
	await _frames()
	main.pop_to_root()
	main.push(preload("res://src/ui/screens/report_screen.gd").new())
	await _frames()
	var rep: Dictionary = Store.portfolio.income_report(2026)
	check(rep["interest"] > 0, "sample savings earn interest in report")

	print("Flow test: ", "OK" if failures == 0 else "%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _index_of(o: OptionButton, id: String) -> int:
	for i in o.item_count:
		if o.get_item_metadata(i) == id:
			return i
	return 0


func _frames() -> void:
	for i in 4:
		await get_tree().process_frame
