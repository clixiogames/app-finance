class_name RegulatedRates
## Official French regulated savings rates (net, in basis points: 1,70 % = 170).
## Each entry: [date the rate starts, bps]. Update when the government announces a change
## (usually 1 February and 1 August). Last checked: 2026-11-18.

const TABLE := {
	"livret_a": [
		["2015-08-01", 75], ["2020-02-01", 50], ["2022-02-01", 100], ["2022-08-01", 200],
		["2023-02-01", 300], ["2025-02-01", 240], ["2025-08-01", 170], ["2026-02-01", 150],
		["2026-08-01", 170],
	],
	"ldds": [
		["2015-08-01", 75], ["2020-02-01", 50], ["2022-02-01", 100], ["2022-08-01", 200],
		["2023-02-01", 300], ["2025-02-01", 240], ["2025-08-01", 170], ["2026-02-01", 150],
		["2026-08-01", 170],
	],
	"lep": [
		["2015-08-01", 125], ["2020-02-01", 100], ["2022-02-01", 220], ["2022-08-01", 460],
		["2023-02-01", 610], ["2023-08-01", 600], ["2024-02-01", 500], ["2024-08-01", 400],
		["2025-02-01", 350], ["2025-08-01", 270], ["2026-02-01", 250], ["2026-08-01", 250],
	],
}

const LABELS := {
	"livret_a": "Livret A",
	"ldds": "LDDS",
	"lep": "LEP",
	"fixed": "Custom rate",
}


static func rate_bps(source: String, date: String, fixed_bps: int = 0) -> int:
	if not TABLE.has(source):
		return fixed_bps
	var result := 0
	for entry in TABLE[source]:
		if entry[0] <= date:
			result = entry[1]
		else:
			break
	return result


static func current_bps(source: String, fixed_bps: int = 0) -> int:
	return rate_bps(source, Dates.today(), fixed_bps)
