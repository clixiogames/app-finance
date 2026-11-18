class_name LineChart
extends Control
## Value over time (solid accent line + soft fill) vs money invested (dashed grey line).
## Touch or hover to read a point.

var points: Array = []  # [{date, value, invested}]
var currency := "EUR"
var _hover := -1
const PAD_TOP := 34.0
const PAD_BOTTOM := 22.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 210)
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_points(p: Array, cur: String) -> void:
	points = p
	currency = cur
	_hover = -1
	queue_redraw()


func _range() -> Vector2:
	var lo := 9223372036854775807
	var hi := -9223372036854775807
	for p in points:
		lo = mini(lo, mini(p["value"], p["invested"]))
		hi = maxi(hi, maxi(p["value"], p["invested"]))
	if hi == lo:
		hi += 100
		lo -= 100
	var pad := (hi - lo) / 10
	return Vector2(lo - pad, hi + pad)


func _xy(i: int, v: int, r: Vector2) -> Vector2:
	var w := size.x
	var h := size.y - PAD_TOP - PAD_BOTTOM
	var x := 0.0 if points.size() < 2 else w * float(i) / float(points.size() - 1)
	var y := PAD_TOP + h * (1.0 - (float(v) - r.x) / (r.y - r.x))
	return Vector2(x, y)


func _draw() -> void:
	var f := AppTheme.font(500)
	if points.size() < 2:
		draw_string(f, Vector2(0, size.y / 2), "Add a deposit to see your history", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, AppTheme.c("faint"))
		return
	var r := _range()
	var val := PackedVector2Array()
	var inv := PackedVector2Array()
	for i in points.size():
		val.append(_xy(i, points[i]["value"], r))
		inv.append(_xy(i, points[i]["invested"], r))
	# soft fill under value line
	var fill := val.duplicate()
	fill.append(Vector2(size.x, size.y - PAD_BOTTOM))
	fill.append(Vector2(0, size.y - PAD_BOTTOM))
	var acc := AppTheme.c("accent")
	var cols := PackedColorArray()
	for i in fill.size():
		var t := clampf((fill[i].y - PAD_TOP) / (size.y - PAD_TOP - PAD_BOTTOM), 0, 1)
		cols.append(Color(acc, 0.16 * (1.0 - t)))
	if Geometry2D.triangulate_polygon(fill).size() > 0:
		draw_polygon(fill, cols)
	# baseline
	draw_line(Vector2(0, size.y - PAD_BOTTOM), Vector2(size.x, size.y - PAD_BOTTOM), AppTheme.c("border"), 1.0)
	# invested dashed
	for i in inv.size() - 1:
		draw_dashed_line(inv[i], inv[i + 1], AppTheme.c("faint"), 1.5, 5.0)
	draw_polyline(val, acc, 2.5, true)
	# axis labels
	draw_string(f, Vector2(0, size.y - 4), Dates.pretty(points[0]["date"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, AppTheme.c("faint"))
	draw_string(f, Vector2(0, size.y - 4), Dates.pretty(points[-1]["date"]), HORIZONTAL_ALIGNMENT_RIGHT, size.x, 11, AppTheme.c("faint"))
	# readout
	var i := _hover if _hover >= 0 else points.size() - 1
	var p: Dictionary = points[i]
	var pos := val[i]
	if _hover >= 0:
		draw_line(Vector2(pos.x, PAD_TOP - 4), Vector2(pos.x, size.y - PAD_BOTTOM), AppTheme.c("border"), 1.0)
	draw_circle(pos, 4.5, AppTheme.c("surface"))
	draw_circle(pos, 3.5, acc)
	var txt := "%s  ·  %s" % [Dates.pretty(p["date"]), Money.fmt(p["value"], currency, false, 0)]
	draw_string(AppTheme.font(600), Vector2(0, 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AppTheme.c("text"))
	var sub := "Invested %s" % Money.fmt(p["invested"], currency, false, 0)
	draw_string(f, Vector2(0, 28), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, AppTheme.c("muted"))


func _gui_input(event: InputEvent) -> void:
	var x := -1.0
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		x = event.position.x
	elif event is InputEventScreenDrag or event is InputEventScreenTouch:
		x = event.position.x
	if x >= 0 and points.size() >= 2:
		var i := clampi(roundi(x / size.x * (points.size() - 1)), 0, points.size() - 1)
		if i != _hover:
			_hover = i
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		queue_redraw()
