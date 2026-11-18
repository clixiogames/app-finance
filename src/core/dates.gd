class_name Dates
## Date helpers. All dates are ISO strings "YYYY-MM-DD" (calendar dates, UTC).

const MONTHS_SHORT := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

## Overridable "today" for tests and screenshots.
static var fixed_today := ""


static func today() -> String:
	if fixed_today != "":
		return fixed_today
	return Time.get_date_string_from_system(true)


static func is_valid(s: String) -> bool:
	if s.length() != 10 or s[4] != "-" or s[7] != "-":
		return false
	var p := s.split("-")
	if not (p[0].is_valid_int() and p[1].is_valid_int() and p[2].is_valid_int()):
		return false
	var y := int(p[0])
	var m := int(p[1])
	var d := int(p[2])
	return y >= 1900 and y <= 2200 and m >= 1 and m <= 12 and d >= 1 and d <= days_in_month(y, m)


static func make(y: int, m: int, d: int) -> String:
	return "%04d-%02d-%02d" % [y, m, d]


static func year(s: String) -> int:
	return int(s.substr(0, 4))


static func month(s: String) -> int:
	return int(s.substr(5, 2))


static func day(s: String) -> int:
	return int(s.substr(8, 2))


static func is_leap(y: int) -> bool:
	return (y % 4 == 0 and y % 100 != 0) or y % 400 == 0


static func days_in_month(y: int, m: int) -> int:
	if m == 2:
		return 29 if is_leap(y) else 28
	if m in [4, 6, 9, 11]:
		return 30
	return 31


## Days since 1970-01-01.
static func to_days(s: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(s + "T00:00:00")) / 86400


static func from_days(d: int) -> String:
	return Time.get_date_string_from_unix_time(d * 86400)


static func from_unix(t: int) -> String:
	return Time.get_date_string_from_unix_time(t)


static func add_days(s: String, n: int) -> String:
	return from_days(to_days(s) + n)


## "2026-11"
static func month_key(s: String) -> String:
	return s.substr(0, 7)


static func month_key_add(key: String, n: int) -> String:
	var y := int(key.substr(0, 4))
	var m := int(key.substr(5, 2)) - 1 + n
	y += floori(m / 12.0)
	m = posmod(m, 12)
	return "%04d-%02d" % [y, m + 1]


static func month_end(key: String) -> String:
	var y := int(key.substr(0, 4))
	var m := int(key.substr(5, 2))
	return make(y, m, days_in_month(y, m))


## Number of months from key a to key b (b - a).
static func months_between(a: String, b: String) -> int:
	return (int(b.substr(0, 4)) - int(a.substr(0, 4))) * 12 + int(b.substr(5, 2)) - int(a.substr(5, 2))


## "Nov 2026"
static func month_label(key: String, with_year: bool = true) -> String:
	var m := int(key.substr(5, 2))
	return MONTHS_SHORT[m - 1] + ((" " + key.substr(0, 4)) if with_year else "")


## "18 Nov 2026"
static func pretty(s: String) -> String:
	if not is_valid(s):
		return s
	return "%d %s %d" % [day(s), MONTHS_SHORT[month(s) - 1], year(s)]


## French "quinzaine" index: two half-months per month (1st–15th, 16th–end).
static func quinzaine(s: String) -> int:
	return year(s) * 24 + (month(s) - 1) * 2 + (1 if day(s) >= 16 else 0)


static func quinzaine_start(q: int) -> String:
	var y := q / 24
	var r := q % 24
	return make(y, r / 2 + 1, 16 if r % 2 == 1 else 1)
