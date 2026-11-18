extends Control
## App shell: background, header, scrolling body, bottom tabs, navigation stack, toasts and dialogs.

const OverviewScreen = preload("res://src/ui/screens/overview_screen.gd")
const AccountsScreen = preload("res://src/ui/screens/accounts_screen.gd")
const SpendingScreen = preload("res://src/ui/screens/spending_screen.gd")
const SettingsScreen = preload("res://src/ui/screens/settings_screen.gd")
const OnboardingScreen = preload("res://src/ui/screens/onboarding_screen.gd")

const MAX_WIDTH := 560.0
const TABS := [["overview", "Overview"], ["accounts", "Wealth"], ["spending", "Spending"], ["settings", "Settings"]]

var bg: ColorRect
var column: VBoxContainer
var header: HBoxContainer
var back_btn: Button
var title_lbl: Label
var actions: HBoxContainer
var scroll: ScrollContainer
var body_margin: MarginContainer
var tabbar: PanelContainer
var tab_buttons := {}
var overlay: Control
var toast_lbl: Label

var stack: Array = []
var current_tab := "overview"
var _top_inset := 0.0
var _bottom_inset := 0.0
var _refresh_queued := false


func _ready() -> void:
	get_tree().quit_on_go_back = false
	_apply_theme()
	_build_shell()
	Store.changed.connect(_on_data_changed)
	PriceService.status_changed.connect(func(t): toast(t))
	get_viewport().size_changed.connect(_layout)
	_layout()
	if not Store.setting("onboarded", false):
		_set_root(OnboardingScreen.new())
	else:
		switch_tab("overview")
		_auto_refresh_prices()


func _apply_theme() -> void:
	var mode: String = Store.setting("theme", "system")
	var is_dark := mode == "dark" or (mode == "system" and DisplayServer.is_dark_mode_supported() and DisplayServer.is_dark_mode())
	theme = AppTheme.build(is_dark)
	RenderingServer.set_default_clear_color(AppTheme.c("bg"))
	if bg:
		bg.color = AppTheme.c("bg")


func reload_theme() -> void:
	_apply_theme()
	for ch in get_children():
		ch.queue_free()
	tab_buttons.clear()
	_build_shell()
	_layout()
	var root_tab := current_tab
	stack.clear()
	switch_tab(root_tab)


func _build_shell() -> void:
	bg = ColorRect.new()
	bg.color = AppTheme.c("bg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	column = Ui.vbox(0)
	add_child(column)

	var head_margin := MarginContainer.new()
	head_margin.name = "HeadMargin"
	for side in ["left", "right"]:
		head_margin.add_theme_constant_override("margin_" + side, 16)
	head_margin.add_theme_constant_override("margin_bottom", 6)
	column.add_child(head_margin)
	header = Ui.hbox(4)
	header.custom_minimum_size = Vector2(0, 48)
	head_margin.add_child(header)
	back_btn = Ui.button("‹", "Ghost", pop)
	back_btn.add_theme_font_size_override("font_size", 30)
	back_btn.custom_minimum_size = Vector2(40, 40)
	header.add_child(back_btn)
	title_lbl = Ui.label("", "Title")
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.clip_text = true
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title_lbl)
	actions = Ui.hbox(4)
	header.add_child(actions)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	column.add_child(scroll)
	body_margin = MarginContainer.new()
	body_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		body_margin.add_theme_constant_override("margin_" + side, 16)
	body_margin.add_theme_constant_override("margin_top", 6)
	body_margin.add_theme_constant_override("margin_bottom", 28)
	scroll.add_child(body_margin)

	tabbar = PanelContainer.new()
	tabbar.theme_type_variation = "Bar"
	column.add_child(tabbar)
	var tabs := Ui.hbox(0)
	tabbar.add_child(tabs)
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Ui.button(t[1], "Tab")
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 52)
		var id: String = t[0]
		b.pressed.connect(func(): switch_tab(id))
		tabs.add_child(b)
		tab_buttons[id] = b

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	toast_lbl = Ui.label("", "")
	var tp := PanelContainer.new()
	tp.name = "Toast"
	var sb := AppTheme.box(AppTheme.c("text"), 999, Color.TRANSPARENT, 16, 10)
	tp.add_theme_stylebox_override("panel", sb)
	toast_lbl.add_theme_color_override("font_color", AppTheme.c("bg"))
	toast_lbl.add_theme_font_size_override("font_size", 14)
	tp.add_child(toast_lbl)
	tp.visible = false
	tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tp)


func _layout() -> void:
	var vp := get_viewport_rect().size
	var cw := minf(vp.x, MAX_WIDTH)
	_compute_insets(vp)
	column.position = Vector2((vp.x - cw) / 2.0, 0)
	column.size = Vector2(cw, vp.y)
	var hm: MarginContainer = column.get_node("HeadMargin")
	hm.add_theme_constant_override("margin_top", int(_top_inset) + 10)
	tabbar.add_theme_constant_override("margin_bottom", int(_bottom_inset))
	var bar_sb: StyleBoxFlat = tabbar.get_theme_stylebox("panel", "Bar").duplicate()
	bar_sb.content_margin_bottom = 6 + _bottom_inset
	tabbar.add_theme_stylebox_override("panel", bar_sb)


func _compute_insets(vp: Vector2) -> void:
	_top_inset = 0.0
	_bottom_inset = 0.0
	if not OS.has_feature("mobile"):
		return
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0 or win.y <= 0:
		return
	var safe := DisplayServer.get_display_safe_area()
	var k := vp.y / win.y
	_top_inset = maxf(0.0, safe.position.y) * k
	_bottom_inset = maxf(0.0, win.y - safe.end.y) * k


# ---------------- navigation ----------------

func current() -> Screen:
	return stack[-1] if not stack.is_empty() else null


func _root_for(tab: String) -> Screen:
	match tab:
		"accounts":
			return AccountsScreen.new()
		"spending":
			return SpendingScreen.new()
		"settings":
			return SettingsScreen.new()
		_:
			return OverviewScreen.new()


func switch_tab(tab: String) -> void:
	current_tab = tab
	if tab_buttons.has(tab):
		tab_buttons[tab].button_pressed = true
	_set_root(_root_for(tab))


func _set_root(s: Screen) -> void:
	for old in stack:
		if is_instance_valid(old):
			old.queue_free()
	stack = []
	push(s)


func push(s: Screen) -> void:
	s.app = self
	if not stack.is_empty() and stack[-1].get_parent() == body_margin:
		var prev: Screen = stack[-1]
		prev.set_meta("scroll", scroll.scroll_vertical)
		body_margin.remove_child(prev)
	stack.append(s)
	_show(s, 0)


func pop() -> void:
	if stack.size() <= 1:
		return
	var s: Screen = stack.pop_back()
	if s.get_parent():
		s.get_parent().remove_child(s)
	s.queue_free()
	var top: Screen = stack[-1]
	_show(top, top.get_meta("scroll", 0))


## Close forms and go back to the tab root.
func pop_to_root() -> void:
	while stack.size() > 1:
		pop()


func _show(s: Screen, scroll_to: int) -> void:
	for ch in body_margin.get_children():
		body_margin.remove_child(ch)
	body_margin.add_child(s)
	s.refresh()
	_update_header()
	await get_tree().process_frame
	scroll.scroll_vertical = scroll_to


func _update_header() -> void:
	var s := current()
	if s == null:
		return
	back_btn.visible = stack.size() > 1
	title_lbl.text = s.title()
	Ui.clear(actions)
	for a in s.header_actions():
		actions.add_child(a)
	var onboarding := s is OnboardingScreen
	tabbar.visible = stack.size() == 1 and not onboarding
	column.get_node("HeadMargin").visible = not (onboarding and s.title() == "")


func _on_data_changed() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	await get_tree().process_frame
	_refresh_queued = false
	var s := current()
	if s and s.auto_refresh():
		var y := scroll.scroll_vertical
		s.refresh()
		_update_header()
		await get_tree().process_frame
		scroll.scroll_vertical = y


func finish_onboarding() -> void:
	switch_tab("overview")
	_auto_refresh_prices()


func _auto_refresh_prices() -> void:
	var last: String = Store.setting("prices_updated", "")
	var has_market := false
	for h in Store.data["holdings"]:
		if h.get("price_key", "") != "":
			has_market = true
	if has_market and (last == "" or last.substr(0, 10) < Dates.today()):
		PriceService.refresh_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not overlay.get_children().is_empty():
			_close_overlay()
		elif stack.size() > 1:
			pop()
		elif current_tab != "overview" and Store.setting("onboarded", false):
			switch_tab("overview")
		else:
			get_tree().quit()


# ---------------- toasts & dialogs ----------------

func toast(text: String, seconds: float = 2.4) -> void:
	var tp: PanelContainer = get_node("Toast")
	toast_lbl.text = text
	tp.visible = true
	tp.modulate.a = 1.0
	tp.reset_size()
	var vp := get_viewport_rect().size
	tp.position = Vector2((vp.x - tp.size.x) / 2.0, vp.y - tp.size.y - 84 - _bottom_inset)
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(tp, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): tp.visible = false)


## Shows a modal card. content is any Control; buttons: [[text, variation, callable]].
func show_dialog(title: String, content: Control, buttons: Array) -> void:
	_close_overlay()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = AppTheme.c("scrim")
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_close_overlay())
	overlay.add_child(scrim)
	var sheet := PanelContainer.new()
	sheet.theme_type_variation = "Sheet"
	var v := Ui.vbox(14)
	sheet.add_child(v)
	if title != "":
		v.add_child(Ui.label(title, "Title"))
	if content:
		v.add_child(content)
	var row := Ui.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_END
	for b in buttons:
		var cb: Callable = b[2]
		var btn := Ui.button(b[0], b[1], func():
			_close_overlay()
			if cb.is_valid():
				cb.call())
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn)
	v.add_child(row)
	overlay.add_child(sheet)
	var vp := get_viewport_rect().size
	var w := minf(vp.x - 32, 440)
	sheet.custom_minimum_size = Vector2(w, 0)
	sheet.size = Vector2(w, 0)
	await get_tree().process_frame
	sheet.position = Vector2((vp.x - w) / 2.0, maxf(24, (vp.y - sheet.size.y) / 2.0))


func confirm(title: String, text: String, ok_text: String, cb: Callable, danger: bool = false) -> void:
	show_dialog(title, Ui.label(text, "", true), [["Cancel", "", Callable()], [ok_text, "Danger" if danger else "Primary", cb]])


func _close_overlay() -> void:
	Ui.clear(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
