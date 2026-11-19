extends Screen
## Preferences, backup (export / import), price relay and about.

func title() -> String:
	return "Settings"


func refresh() -> void:
	Ui.clear(self)
	var cur: String = Store.setting("currency", "EUR")

	# Preferences
	var pref := Ui.card(12)
	var pb := Ui.body(pref)
	pb.add_child(Ui.label("Preferences", "Strong"))
	var theme_opt := Ui.option([["system", "Same as phone"], ["light", "Light"], ["dark", "Dark"]], Store.setting("theme", "system"))
	theme_opt.item_selected.connect(func(_i):
		Store.set_setting("theme", Ui.option_value(theme_opt))
		app.reload_theme())
	pb.add_child(Ui.field("Appearance", theme_opt))
	var modes := []
	for k in Catalog.INTEREST_MODES:
		modes.append([k, Catalog.INTEREST_MODES[k]])
	var mode_opt := Ui.option(modes, Store.setting("interest_mode", "auto"))
	mode_opt.item_selected.connect(func(_i): Store.set_setting("interest_mode", Ui.option_value(mode_opt)))
	pb.add_child(Ui.field("Default for new savings accounts", mode_opt, "Each account can have its own setting (Edit holding)."))
	var inc_row := Ui.hbox()
	inc_row.add_child(Ui.expand(Ui.label("Monthly income: " + Money.fmt(Store.setting("monthly_income_cents", 0), cur, false, 0))))
	inc_row.add_child(Ui.button("Change", "Ghost", func(): app.push(preload("res://src/ui/screens/income_screen.gd").new())))
	pb.add_child(inc_row)
	pb.add_child(Ui.kv("Currency", cur))
	add_child(pref)

	# Backup
	var bk := Ui.card(10)
	var bb := Ui.body(bk)
	bb.add_child(Ui.label("Backup", "Strong"))
	var last: String = Store.setting("last_backup", "")
	bb.add_child(Ui.label("Your data is stored only on this device%s. Save a backup file regularly (e.g. to Google Drive) so you never lose it." % (" and in this browser" if OS.has_feature("web") else ""), "Muted", true))
	bb.add_child(Ui.label("Last backup: " + (Dates.pretty(last) if last != "" else "never"), "Faint"))
	var row := Ui.hbox()
	row.add_child(Ui.expand(Ui.button("Save backup file", "Primary", _export)))
	row.add_child(Ui.expand(Ui.button("Restore from file", "", _import)))
	bb.add_child(row)
	var row2 := Ui.hbox()
	row2.add_child(Ui.expand(Ui.button("Copy as text", "Ghost", func():
		DisplayServer.clipboard_set(Store.export_json())
		Store.mark_backup_done()
		app.toast("Backup copied — paste it somewhere safe"))))
	row2.add_child(Ui.expand(Ui.button("Paste backup", "Ghost", _paste_import)))
	bb.add_child(row2)
	add_child(bk)

	# Prices
	var pr := Ui.card(10)
	var prb := Ui.body(pr)
	prb.add_child(Ui.label("Prices", "Strong"))
	prb.add_child(Ui.label("Funds, ETFs & stocks: Yahoo Finance public data. Crypto: CoinGecko. Exchange rates: European Central Bank. Prices are end-of-day and may be delayed.", "Muted", true))
	var upd: String = Store.setting("prices_updated", "")
	prb.add_child(Ui.label("Last update: " + (Dates.pretty(upd.substr(0, 10)) if upd != "" else "never"), "Faint"))
	prb.add_child(Ui.button("Update prices now", "", func(): PriceService.refresh_all()))
	if OS.has_feature("web") or Store.setting("relay_url", "") != "":
		var relay := Ui.line_edit("https://…workers.dev", Store.setting("relay_url", ""))
		relay.text_submitted.connect(func(t):
			Store.set_setting("relay_url", t.strip_edges())
			app.toast("Relay saved"))
		prb.add_child(Ui.field("Price relay (website only)", relay, "Browsers block finance sites; the relay passes price requests through. Press Enter to save."))
	add_child(pr)

	# About
	var ab := Ui.card(8)
	var abb := Ui.body(ab)
	abb.add_child(Ui.label("About", "Strong"))
	abb.add_child(Ui.kv("Version", str(ProjectSettings.get_setting("application/config/version", "0.1.0"))))
	abb.add_child(Ui.label("APP FINANCE shows and organises your own data. It does not give investment advice and never moves money. Interest on savings accounts is an estimate.", "Muted", true))
	abb.add_child(Ui.button("Delete all my data", "Danger", func():
		app.confirm("Delete everything?", "All accounts, holdings and history on this device will be erased. Save a backup first if you may need it. This cannot be undone.", "Delete everything", func():
			Store.reset_all()
			app.reload_theme(), true)))
	add_child(ab)


func _backup_name() -> String:
	return "app-finance-backup-%s.json" % Dates.today()


func _export() -> void:
	Files.save_text(Store.export_json(), _backup_name(), func(ok: bool, msg: String):
		if ok:
			Store.mark_backup_done()
		app.toast(msg))


func _import() -> void:
	Files.open_bytes(PackedStringArray(["*.json"]), func(bytes: PackedByteArray, _name: String):
		_restore_text(bytes.get_string_from_utf8()), func(err: String): app.toast(err))


func _paste_import() -> void:
	_restore_text(DisplayServer.clipboard_get())


func _restore_text(text: String) -> void:
	app.confirm("Restore this backup?", "It will replace all data currently on this device.", "Restore", func():
		var err := Store.import_json(text)
		if err != "":
			app.toast(err, 4.0)
		else:
			app.toast("Backup restored")
			app.reload_theme())
