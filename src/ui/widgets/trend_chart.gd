class_name TrendChart
extends Control
## Income vs expenses per month: two slim bars per month (income grey, expenses accent).

var items: Array = []  # [{month, income, expenses (negative)}]
var currency := "EUR"
var _hover := -1


func _init() -> void:
	custom_minimum_size = Vector2(0, 150)
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_items(it: Array, cur: String) -> void:
	items = it
	currency = cur
	_hover = -1
	queue_redraw()


func _draw() -> void:
	if items.is_empty():
		return
	var f := AppTheme.font(500)
	var top := 28.0
	var bottom := 20.0
	var h := size.y - top - bottom
	var hi := 1
	for it in items:
		hi = maxi(hi, maxi(it["income"], -it["expenses"]))
	var n := items.size()
	var slot := size.x / n
	var bw := minf(slot * 0.28, 14.0)
	for i in n:
		var x := slot * i + slot / 2.0
		var inc := h * float(items[i]["income"]) / hi
		var out_h := h * float(-items[i]["expenses"]) / hi
		var dim := _hover >= 0 and i != _hover
		_bar(Rect2(x - bw - 1, top + h - inc, bw, inc), Color(AppTheme.c("faint"), 0.35 if dim else 0.8))
		_bar(Rect2(x + 1, top + h - out_h, bw, out_h), Color(AppTheme.c("accent"), 0.35 if dim else 1.0))
		var m: String = Dates.MONTHS_SHORT[int(items[i]["month"].substr(5, 2)) - 1]
		draw_string(f, Vector2(slot * i, size.y - 4), m, HORIZONTAL_ALIGNMENT_CENTER, slot, 11, AppTheme.c("faint"))
	draw_line(Vector2(0, top + h), Vector2(size.x, top + h), AppTheme.c("border"), 1.0)
	var it2: Dictionary = items[_hover if _hover >= 0 else n - 1]
	var txt := "%s  ·  in %s  ·  out %s" % [Dates.month_label(it2["month"]), Money.fmt(it2["income"], currency, false, 0), Money.fmt(-it2["expenses"], currency, false, 0)]
	draw_string(AppTheme.font(600), Vector2(0, 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AppTheme.c("text"))


func _bar(r: Rect2, col: Color) -> void:
	if r.size.y <= 0.5:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(3)
	draw_style_box(sb, r)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventScreenDrag or event is InputEventScreenTouch:
		if items.is_empty():
			return
		var i := clampi(int(event.position.x / size.x * items.size()), 0, items.size() - 1)
		if i != _hover:
			_hover = i
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		queue_redraw()
