class_name Money
## Exact money maths. Never uses floats for stored amounts.
## - Amounts: integer cents (minor units).
## - Units (shares/coins): integer, scale 1e6 (6 decimals).
## - Prices: integer, scale 1e4 (4 decimals) in the instrument's currency.
## - FX rates: integer, scale 1e6 = base-currency per 1 unit of foreign currency.

const UNIT_SCALE := 1000000
const PRICE_SCALE := 10000
const FX_SCALE := 1000000

const SYMBOLS := {"EUR": "€", "USD": "$", "GBP": "£", "CHF": "CHF", "JPY": "¥"}


## Computes round(a * b / d) without overflowing for realistic values.
static func mul_div(a: int, b: int, d: int) -> int:
	if d == 0:
		return 0
	var neg := (a < 0) != (b < 0)
	if d < 0:
		neg = not neg
		d = -d
	a = absi(a)
	b = absi(b)
	var q := a / d
	var r := a % d
	var res := q * b + (r * b + d / 2) / d
	return -res if neg else res


## Value in cents of `units6` units at `price4`.
static func value_cents(units6: int, price4: int) -> int:
	return mul_div(units6, price4, 100000000)


## Units (×1e6) bought with `amount_cents` at `price4`.
static func units_for(amount_cents: int, price4: int) -> int:
	if price4 <= 0:
		return 0
	return mul_div(amount_cents, 100000000, price4)


## Price (×1e4) implied by paying `amount_cents` for `units6`.
static func price_for(amount_cents: int, units6: int) -> int:
	if units6 <= 0:
		return 0
	return mul_div(amount_cents, 100000000, units6)


## Converts cents in a foreign currency to base-currency cents.
static func convert(cents: int, fx6: int) -> int:
	return mul_div(cents, fx6, FX_SCALE)


## Converts base-currency cents to a foreign currency.
static func convert_back(cents: int, fx6: int) -> int:
	if fx6 <= 0:
		return 0
	return mul_div(cents, FX_SCALE, fx6)


## Turns a float from an external source (JSON) into a scaled integer.
static func from_float(v: float, scale: int) -> int:
	return roundi(v * scale)


## Parses user text like "1 234,56", "1,234.56", "1234.5", "€ 20" into a scaled int.
## Returns null when the text is not a valid number.
static func parse_decimal(text: String, scale: int) -> Variant:
	var t := text.strip_edges()
	for junk in ["€", "$", "£", "CHF", "¥", " ", " ", " ", "'", "_"]:
		t = t.replace(junk, "")
	if t.is_empty():
		return null
	var neg := false
	if t.begins_with("-"):
		neg = true
		t = t.substr(1)
	elif t.begins_with("+"):
		t = t.substr(1)
	var last_dot := t.rfind(".")
	var last_comma := t.rfind(",")
	var dec_pos := maxi(last_dot, last_comma)
	var int_part := t
	var frac_part := ""
	if dec_pos >= 0:
		var sep := t[dec_pos]
		var other := "," if sep == "." else "."
		# A single separator followed by exactly 3 digits with no other separator
		# is ambiguous ("1,234"); treat as thousands only if it repeats or the other sep exists.
		var occurrences := t.count(sep)
		if occurrences > 1:
			# e.g. "1.234.567" -> all thousands separators
			int_part = t.replace(sep, "").replace(other, "")
			frac_part = ""
		else:
			int_part = t.substr(0, dec_pos).replace(other, "")
			frac_part = t.substr(dec_pos + 1)
	if int_part.is_empty():
		int_part = "0"
	if not int_part.is_valid_int() or (frac_part != "" and not frac_part.is_valid_int()):
		return null
	if frac_part.begins_with("-") or frac_part.begins_with("+") or int_part.begins_with("-") or int_part.begins_with("+"):
		return null
	var digits := 0
	var s := scale
	while s > 1:
		s /= 10
		digits += 1
	var frac := frac_part
	var round_up := false
	if frac.length() > digits:
		round_up = int(frac[digits]) >= 5
		frac = frac.substr(0, digits)
	while frac.length() < digits:
		frac += "0"
	var value := int(int_part) * scale + (int(frac) if digits > 0 else 0)
	if round_up:
		value += 1
	return -value if neg else value


static func parse_cents(text: String) -> Variant:
	return parse_decimal(text, 100)


static func _group(int_str: String, sep: String) -> String:
	var out := ""
	var count := 0
	for i in range(int_str.length() - 1, -1, -1):
		out = int_str[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = sep + out
	return out


## Formats a scaled integer with `decimals` decimals, French-style grouping.
static func format_scaled(v: int, scale: int, decimals: int, trim: bool = false) -> String:
	var neg := v < 0
	v = absi(v)
	var digits := 0
	var s := scale
	while s > 1:
		s /= 10
		digits += 1
	decimals = mini(decimals, digits)
	var factor := 1
	for i in digits - decimals:
		factor *= 10
	var p10 := 1
	for i in decimals:
		p10 *= 10
	var r := (v + factor / 2) / factor
	var whole := r / p10
	var frac_str := str(r % p10).pad_zeros(decimals) if decimals > 0 else ""
	if whole == 0 and r == 0:
		neg = false
	if trim:
		frac_str = frac_str.rstrip("0")
	var out := _group(str(whole), " ")
	if frac_str != "":
		out += "," + frac_str
	return ("-" if neg else "") + out


static func symbol(currency: String) -> String:
	return SYMBOLS.get(currency, currency)


## "12 345,67 €"
static func fmt(cents: int, currency: String = "EUR", signed: bool = false, decimals: int = 2) -> String:
	var body := format_scaled(absi(cents), 100, decimals)
	var sign := ""
	if cents < 0:
		sign = "−"
	elif signed and cents > 0:
		sign = "+"
	return sign + body + " " + symbol(currency)


## Short form for chart axes: "12,3 k€"
static func fmt_short(cents: int, currency: String = "EUR") -> String:
	var a := absi(cents)
	var sign := "−" if cents < 0 else ""
	var sym := symbol(currency)
	if a >= 100000000:
		return sign + format_scaled(a / 10000000, 10, 1, true) + " M" + sym
	if a >= 100000:
		return sign + format_scaled(a / 10000, 10, 1, true) + " k" + sym
	return sign + format_scaled(a, 100, 0) + " " + sym


static func fmt_units(units6: int) -> String:
	return format_scaled(units6, UNIT_SCALE, 6, true)


static func fmt_price(price4: int, currency: String) -> String:
	return format_scaled(price4, PRICE_SCALE, 2 if price4 >= 100000 else 4, price4 < 100000) + " " + symbol(currency)


## Percentage num/den as text, e.g. "+12,34 %". Returns "—" if den is 0.
static func pct(num: int, den: int, signed: bool = true, decimals: int = 1) -> String:
	if den == 0:
		return "—"
	var bps := mul_div(num, 10000, den)
	var body := format_scaled(absi(bps), 100, decimals)
	var sign := ""
	if bps < 0:
		sign = "−"
	elif signed and bps > 0:
		sign = "+"
	return sign + body + " %"


## Basis points (1 % = 100) as "1,70 %".
static func fmt_bps(bps: int) -> String:
	return format_scaled(bps, 100, 2) + " %"
