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
	if "--store" in OS.get_cmdline_user_args():
		d["settings"]["sample"] = false
		d["settings"]["last_backup"] = Dates.today()
		d["settings"]["prices_updated"] = Dates.today() + "T07:00:00Z"
		for h in d["holdings"]:
			h["name"] = str(h["name"]).replace(" (sample)", "")
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
	main.switch_tab("spending")
	await _settle()
	await shot("09_spending")
	main.scroll.scroll_vertical = 700
	await _settle()
	await shot("10_spending_list")
	var csv := "Date;Libellé;Montant\n17/11/2026;CB MONOPRIX PARIS 15;-32,80\n16/11/2026;CB SNCF INTERNET;-45,00\n15/11/2026;PRLV SEPA SPOTIFY;-11,99\n"
	main.push(preload("res://src/ui/screens/spending_import_screen.gd").new(Spending.parse(csv), "export-boursorama.csv"))
	await _settle()
	await shot("11_import_preview")
	main.pop_to_root()
	main.switch_tab("settings")
	await _settle()
	await shot("07_settings")
	main.push(preload("res://src/ui/screens/price_setup_screen.gd").new())
	await _settle()
	await shot("12_price_setup")
	main.pop_to_root()
	Store.data["settings"]["pin_salt"] = "x"
	Store.data["settings"]["pin_hash"] = PinPad.hash_pin("1234", "x")
	main.lock_if_needed()
	await _settle()
	await shot("13_lock")
	main.unlock()
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


func sample_data() -> Dictionary:
	return SampleData.build("2026-11-18")
