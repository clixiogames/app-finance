class_name BarChart
extends Control
## Monthly savings bars. Positive = accent, negative (withdrew more than saved) = loss colour.

var items: Array = []  # [{month, saved, income}]
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
	var lo := 0
	for it in items:
		hi = maxi(hi, it["saved"])
		lo = mini(lo, it["saved"])
	var span := float(hi - lo)
	var zero_y := top + h * float(hi) / span
	var n := items.size()
	var slot := size.x / n
	var bw := minf(slot * 0.56, 22.0)
	for i in n:
		var v: int = items[i]["saved"]
		var x := slot * i + (slot - bw) / 2.0
		var bh := h * absf(float(v)) / span
		var col := AppTheme.c("accent") if v >= 0 else AppTheme.c("loss")
		if _hover >= 0 and i != _hover:
			col = Color(col, 0.35)
		elif _hover < 0 and i != n - 1:
			col = Color(col, 0.55)
		if v != 0:
			var rect := Rect2(x, zero_y - bh if v > 0 else zero_y, bw, maxf(bh, 2.0))
			var sb := StyleBoxFlat.new()
			sb.bg_color = col
			sb.set_corner_radius_all(int(minf(4.0, bw / 2.0)))
			draw_style_box(sb, rect)
		var m: String = Dates.MONTHS_SHORT[int(items[i]["month"].substr(5, 2)) - 1].substr(0, 1)
		draw_string(f, Vector2(slot * i, size.y - 4), m, HORIZONTAL_ALIGNMENT_CENTER, slot, 11, AppTheme.c("faint"))
	draw_line(Vector2(0, zero_y), Vector2(size.x, zero_y), AppTheme.c("border"), 1.0)
	var idx := _hover if _hover >= 0 else n - 1
	var it2: Dictionary = items[idx]
	var txt := "%s  ·  %s" % [Dates.month_label(it2["month"]), Money.fmt(it2["saved"], currency, true, 0)]
	if it2["income"] > 0:
		txt += "  ·  " + Money.pct(it2["saved"], it2["income"], false, 0) + " of income"
	draw_string(AppTheme.font(600), Vector2(0, 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AppTheme.c("text"))


func _gui_input(event: InputEvent) -> void:
	var x := -1.0
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventScreenDrag or event is InputEventScreenTouch:
		x = event.position.x
	if x >= 0 and not items.is_empty():
		var i := clampi(int(x / size.x * items.size()), 0, items.size() - 1)
		if i != _hover:
			_hover = i
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		queue_redraw()
