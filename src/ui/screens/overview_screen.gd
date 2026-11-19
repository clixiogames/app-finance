extends Screen
## Global status: total wealth, gain/loss, value over time, allocation, monthly savings.

const RANGES := [["6M", 6], ["1Y", 12], ["3Y", 36], ["All", 0]]
static var range_idx := 1
static var alloc_mode := 0


func title() -> String:
	return "Overview"


func header_actions() -> Array:
	var b := Ui.button("Add", "Ghost", func(): app.push(preload("res://src/ui/screens/movement_edit_screen.gd").new()))
	return [b] if not Store.data["holdings"].is_empty() else []


func refresh() -> void:
	Ui.clear(self)
	var p: Portfolio = Store.portfolio
	var cur: String = Store.setting("currency", "EUR")
	if Store.data["holdings"].is_empty():
		_empty_state()
		return
	var t := p.totals()

	if Store.setting("sample", false):
		var sc := Ui.card(8)
		var sb := Ui.body(sc)
		sb.add_child(Ui.label("You're exploring sample data", "Strong"))
		sb.add_child(Ui.label("Nothing here is real and the prices are made up. Look around, then start with your own money.", "Muted", true))
		sb.add_child(Ui.button("Start with my own data", "Primary", func():
			app.confirm("Remove the sample data?", "The example accounts, holdings and spending will be deleted.", "Start fresh", func():
				var theme_mode: String = Store.setting("theme", "system")
				Store.reset_all()
				Store.set_setting("theme", theme_mode)
				app.reload_theme())))
		add_child(sc)

	# Live prices not connected yet
	var waiting := PriceService.waiting_for_key()
	if waiting > 0:
		var pc := Ui.card(8)
		var pb := Ui.body(pc)
		pb.add_child(Ui.label("Turn on live prices", "Strong"))
		pb.add_child(Ui.label("%d holding%s shown at the amount you put in. Connect free price data to see real values — it takes about a minute." % [waiting, "s are" if waiting > 1 else " is"], "Muted", true))
		pb.add_child(Ui.button("Set up live prices", "Primary", func(): app.push(preload("res://src/ui/screens/price_setup_screen.gd").new())))
		add_child(pc)

	# Backup reminder (data lives only on this device)
	var last_bk: String = Store.setting("last_backup", "")
	if not Store.data["movements"].is_empty() and not Store.setting("sample", false) and (last_bk == "" or last_bk < Dates.add_days(Dates.today(), -30)):
		var bc := Ui.card(8)
		var bb := Ui.body(bc)
		bb.add_child(Ui.label("Back up your data", "Strong"))
		bb.add_child(Ui.label("Everything is stored only on this device. Save a backup file now and then (for example to Google Drive).", "Muted", true))
		bb.add_child(Ui.button("Save a backup", "", func():
			Files.save_text(Store.export_json(), "app-finance-backup-%s.json" % Dates.today(), func(ok: bool, msg: String):
				if ok:
					Store.mark_backup_done()
					refresh()
				app.toast(msg))))
		add_child(bc)

	# Hero
	var hero := Ui.card(4)
	var hb := Ui.body(hero)
	hb.add_child(Ui.label("Total wealth", "Muted"))
	var big := Ui.label(Money.fmt(t["value"], cur), "Big")
	hb.add_child(big)
	var row := Ui.hbox(10)
	var g := Ui.label("%s  (%s)" % [Money.fmt(t["gain"], cur, true), Money.pct(t["gain"], t["invested"])], Ui.gain_variation(t["gain"]))
	row.add_child(g)
	row.add_child(Ui.label("total gain", "Muted"))
	hb.add_child(row)
	hb.add_child(Ui.spacer(6))
	hb.add_child(Ui.kv("Money invested", Money.fmt(t["invested"], cur)))
	var ar := p.annual_return()
	if ar["ok"]:
		hb.add_child(Ui.kv("Annual return since %s" % Dates.month_label(Dates.month_key(ar["since"])), Money.pct(ar["bps"], 10000) + " / yr", Ui.gain_variation(ar["bps"])))
	if t["debts"] < 0:
		hb.add_child(Ui.kv("Assets", Money.fmt(t["assets"], cur)))
		hb.add_child(Ui.kv("Debts", Money.fmt(t["debts"], cur)))
	add_child(hero)

	# History
	var hist := Ui.card(10)
	var hib := Ui.body(hist)
	var hh := Ui.hbox()
	hh.add_child(Ui.expand(Ui.label("Value over time", "Strong")))
	var labels := []
	for r in RANGES:
		labels.append(r[0])
	var chart := LineChart.new()
	hh.add_child(Ui.segmented(labels, range_idx, func(i):
		range_idx = i
		chart.set_points(p.series(RANGES[i][1]), cur)))
	hib.add_child(hh)
	chart.set_points(p.series(RANGES[range_idx][1]), cur)
	hib.add_child(chart)
	var legend := Ui.hbox(16)
	legend.add_child(_legend_dot("Value", AppTheme.c("accent"), false))
	legend.add_child(_legend_dot("Money invested", AppTheme.c("faint"), true))
	hib.add_child(legend)
	add_child(hist)

	# Allocation
	var al := Ui.card(12)
	var alb := Ui.body(al)
	var ah := Ui.hbox()
	ah.add_child(Ui.expand(Ui.label("Allocation", "Strong")))
	ah.add_child(Ui.segmented(["Type", "Account"], alloc_mode, func(i):
		alloc_mode = i
		refresh()))
	alb.add_child(ah)
	var groups: Dictionary = t["by_type"] if alloc_mode == 0 else t["by_account"]
	var names := groups.keys()
	names.sort_custom(func(a, b): return groups[a] > groups[b])
	var vals := []
	var cols := []
	for i in names.size():
		vals.append(groups[names[i]])
		cols.append(Ui.shade(i, names.size()))
	var bar := AllocBar.new()
	bar.set_values(vals, cols)
	alb.add_child(bar)
	for i in names.size():
		var r := Ui.hbox(10)
		var dot := ColorRect.new()
		dot.color = cols[i]
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(dot)
		r.add_child(Ui.expand(Ui.label(names[i])))
		r.add_child(Ui.label(Money.pct(vals[i], t["assets"], false), "Muted"))
		var v := Ui.label(Money.fmt(vals[i], cur, false, 0), "Strong")
		v.custom_minimum_size = Vector2(96, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_child(v)
		alb.add_child(r)
	add_child(al)

	# Savings
	var sv := Ui.card(10)
	var svb := Ui.body(sv)
	var sh := Ui.hbox()
	sh.add_child(Ui.expand(Ui.label("Monthly savings", "Strong")))
	sh.add_child(Ui.button("Income", "Ghost", func(): app.push(preload("res://src/ui/screens/income_screen.gd").new())))
	svb.add_child(sh)
	var months := p.monthly_savings(12)
	var this_m: Dictionary = months[-1]
	var tot_saved := 0
	var tot_income := 0
	for m in months:
		if m["income"] > 0:
			tot_saved += m["saved"]
			tot_income += m["income"]
	var stats := Ui.hbox(12)
	stats.add_child(_stat("This month", Money.fmt(this_m["saved"], cur, false, 0)))
	stats.add_child(_stat("Savings rate", Money.pct(this_m["saved"], this_m["income"], false, 0)))
	stats.add_child(_stat("12-month avg", Money.pct(tot_saved, tot_income, false, 0)))
	svb.add_child(stats)
	var bc := BarChart.new()
	bc.set_items(months, cur)
	svb.add_child(bc)
	if this_m["income"] == 0:
		svb.add_child(Ui.label("Add your monthly income to see your savings rate.", "Faint", true))
	add_child(sv)

	# Footer: price freshness
	var foot := Ui.vbox(4)
	var upd: String = Store.setting("prices_updated", "")
	var fh := Ui.hbox()
	var txt := "Prices: never updated"
	if upd != "":
		txt = "Prices updated %s" % Dates.pretty(upd.substr(0, 10))
		if t["oldest_price"] != "":
			txt += " · latest close %s" % Dates.pretty(t["oldest_price"])
	fh.add_child(Ui.expand(Ui.label(txt, "Faint", true)))
	var rb := Ui.button("Refresh", "Ghost", func(): PriceService.refresh_all())
	rb.disabled = PriceService.busy
	fh.add_child(rb)
	foot.add_child(fh)
	if t["stale"] > 0:
		foot.add_child(Ui.label("%d price(s) are more than a week old." % t["stale"], "Faint", true))
	if t["missing"] > 0:
		foot.add_child(Ui.label("%d holding(s) have no price yet — shown at the amount invested." % t["missing"], "Faint", true))
	if PriceService.last_error != "":
		foot.add_child(Ui.label(PriceService.last_error, "Faint", true))
	if t["estimated"]:
		foot.add_child(Ui.label("Savings-account interest is estimated from official rates.", "Faint", true))
	foot.add_child(Ui.label("For information only — not financial advice.", "Faint", true))
	add_child(foot)


func _stat(t: String, v: String) -> VBoxContainer:
	var b := Ui.vbox(0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_child(Ui.label(t, "Muted"))
	var l := Ui.label(v, "Strong")
	l.add_theme_font_size_override("font_size", 18)
	b.add_child(l)
	return b


func _legend_dot(text: String, col: Color, dashed: bool) -> HBoxContainer:
	var h := Ui.hbox(6)
	var d := ColorRect.new()
	d.color = col
	d.custom_minimum_size = Vector2(14, 2 if dashed else 3)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(d)
	h.add_child(Ui.label(text, "Muted"))
	return h


func _empty_state() -> void:
	var c := Ui.card(12)
	var b := Ui.body(c)
	b.add_child(Ui.label("Welcome", "Title"))
	b.add_child(Ui.label("Add where your money is — a PEA, a Livret A, a crypto wallet… then record your deposits. The app tracks the rest with real prices.", "Muted", true))
	b.add_child(Ui.spacer(4))
	b.add_child(Ui.button("Add your first account", "Primary", func(): app.push(preload("res://src/ui/screens/account_edit_screen.gd").new())))
	add_child(c)
