class_name AllocBar
extends Control
## One horizontal stacked bar showing shares of the total.

var values: Array = []  # ints
var colors: Array = []


func _init() -> void:
	custom_minimum_size = Vector2(0, 12)


func set_values(v: Array, c: Array) -> void:
	values = v
	colors = c
	queue_redraw()


func _draw() -> void:
	var total := 0
	for v in values:
		total += maxi(v, 0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = AppTheme.c("surface2")
	bg.set_corner_radius_all(6)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	if total <= 0:
		return
	var x := 0.0
	var gap := 2.0
	for i in values.size():
		var w := size.x * float(maxi(values[i], 0)) / float(total)
		if w <= 0:
			continue
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[i]
		sb.set_corner_radius_all(6 if values.size() == 1 else 3)
		if i == 0:
			sb.corner_radius_top_left = 6
			sb.corner_radius_bottom_left = 6
		if i == values.size() - 1:
			sb.corner_radius_top_right = 6
			sb.corner_radius_bottom_right = 6
		draw_style_box(sb, Rect2(x, 0, maxf(w - gap, 1.0), size.y))
		x += w
