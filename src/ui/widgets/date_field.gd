class_name DateField
extends HBoxContainer
## Day / month / year pickers. value is "YYYY-MM-DD".

var _d: OptionButton
var _m: OptionButton
var _y: OptionButton


func _init(initial: String = "") -> void:
	add_theme_constant_override("separation", 6)
	if not Dates.is_valid(initial):
		initial = Dates.today()
	var days := []
	for i in range(1, 32):
		days.append([i, str(i)])
	var months := []
	for i in 12:
		months.append([i + 1, Dates.MONTHS_SHORT[i]])
	var years := []
	var this_year := Dates.year(Dates.today())
	for y in range(this_year, 1989, -1):
		years.append([y, str(y)])
	_d = Ui.option(days, Dates.day(initial))
	_m = Ui.option(months, Dates.month(initial))
	_y = Ui.option(years, Dates.year(initial))
	_d.size_flags_stretch_ratio = 0.8
	_m.size_flags_stretch_ratio = 1.0
	_y.size_flags_stretch_ratio = 1.2
	for o in [_d, _m, _y]:
		add_child(o)


## Returns a valid date (clamps day to month length).
func value() -> String:
	var y: int = Ui.option_value(_y)
	var m: int = Ui.option_value(_m)
	var d: int = mini(Ui.option_value(_d), Dates.days_in_month(y, m))
	return Dates.make(y, m, d)
