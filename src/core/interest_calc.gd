class_name InterestCalc
## Estimates interest on French-style savings accounts using the "quinzaine" rules:
## - a deposit starts earning on the 1st or 16th FOLLOWING the deposit date;
## - a withdrawal stops earning from the 1st or 16th PRECEDING the withdrawal date;
## - interest for each half-month = balance × annual rate / 24;
## - interest is credited (added to the balance) on 31 December.
## Amounts are integer cents; rates in basis points. Result is an estimate.

## movements: Array of {date, kind, amount_cents} for ONE holding, any order.
## rate_fn: Callable(date: String) -> int (bps) giving the rate in force on that date.
## until: date (exclusive) up to which interest is counted.
## Returns {credited: int, accrued: int} in cents.
static func compute(movements: Array, rate_fn: Callable, until: String) -> Dictionary:
	var effects := {}  # quinzaine index -> balance change (cents)
	var first_q := -1
	for mv in movements:
		var kind: String = mv.get("kind", "")
		var amt: int = mv.get("amount_cents", 0)
		var q := Dates.quinzaine(mv["date"])
		var eff_q := 0
		var delta := 0
		if kind == "deposit":
			eff_q = q + 1
			delta = amt
		elif kind == "withdrawal" or kind == "fee":
			eff_q = q
			delta = -amt
		else:
			continue
		effects[eff_q] = effects.get(eff_q, 0) + delta
		if first_q < 0 or q < first_q:
			first_q = q
	if first_q < 0:
		return {"credited": 0, "accrued": 0}
	var end_q := Dates.quinzaine(until)
	var balance := 0
	var acc := 0  # cents × bps, divided by 240000 when credited
	var credited := 0
	for q in range(first_q, end_q):
		balance += effects.get(q, 0)
		var rate: int = rate_fn.call(Dates.quinzaine_start(q))
		if balance > 0 and rate > 0:
			acc += balance * rate
		if q % 24 == 23:  # end of December: credit the year's interest
			var year_interest := acc / 240000
			credited += year_interest
			balance += year_interest
			acc = 0
	return {"credited": credited, "accrued": acc / 240000}
