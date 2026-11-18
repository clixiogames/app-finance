class_name Catalog
## Lists of holding types, account kinds and movement kinds shown in the app.

## valuation: "market" (real price online), "interest" (deposits + interest), "manual" (you update the value)
## source: price source for market types ("yahoo" or "coingecko")
## rate: default rate source for interest types
const HOLDING_TYPES := [
	{"id": "etf", "label": "ETF", "group": "Funds & ETFs", "valuation": "market", "source": "yahoo"},
	{"id": "fund", "label": "Investment fund", "group": "Funds & ETFs", "valuation": "market", "source": "yahoo"},
	{"id": "stock", "label": "Stock", "group": "Stocks", "valuation": "market", "source": "yahoo"},
	{"id": "crypto", "label": "Crypto", "group": "Crypto", "valuation": "market", "source": "coingecko"},
	{"id": "livret_a", "label": "Livret A", "group": "Savings accounts", "valuation": "interest", "rate": "livret_a"},
	{"id": "ldds", "label": "LDDS", "group": "Savings accounts", "valuation": "interest", "rate": "ldds"},
	{"id": "lep", "label": "LEP", "group": "Savings accounts", "valuation": "interest", "rate": "lep"},
	{"id": "savings", "label": "Other savings account", "group": "Savings accounts", "valuation": "interest", "rate": "fixed"},
	{"id": "term_deposit", "label": "Term deposit", "group": "Savings accounts", "valuation": "interest", "rate": "fixed"},
	{"id": "home_savings", "label": "PEL / CEL", "group": "Savings accounts", "valuation": "interest", "rate": "fixed"},
	{"id": "euro_fund", "label": "Euro fund (assurance vie)", "group": "Life insurance", "valuation": "manual"},
	{"id": "retirement", "label": "Retirement / employee savings", "group": "Retirement", "valuation": "manual"},
	{"id": "cash", "label": "Cash", "group": "Cash", "valuation": "manual"},
	{"id": "property", "label": "Property", "group": "Property & other", "valuation": "manual"},
	{"id": "other", "label": "Other asset", "group": "Property & other", "valuation": "manual"},
	{"id": "loan", "label": "Loan / debt", "group": "Debts", "valuation": "manual"},
]

const ACCOUNT_KINDS := [
	{"id": "pea", "label": "PEA"},
	{"id": "cto", "label": "Brokerage account (CTO)"},
	{"id": "assurance_vie", "label": "Life insurance (assurance vie)"},
	{"id": "per", "label": "Retirement plan (PER)"},
	{"id": "employee", "label": "Employee savings (PEE / PERCO)"},
	{"id": "bank_savings", "label": "Bank savings"},
	{"id": "crypto", "label": "Crypto exchange / wallet"},
	{"id": "property", "label": "Property"},
	{"id": "other", "label": "Other"},
]

const MOVEMENT_KINDS := {
	"deposit": "Deposit",
	"withdrawal": "Withdrawal",
	"interest": "Interest received",
	"dividend": "Dividend paid out",
	"fee": "Fee",
	"valuation": "Value update",
}

const INTEREST_MODES := {
	"auto": "Automatic (estimated)",
	"manual": "I enter it when paid",
	"none": "Don't track interest",
}


static func holding_type(id: String) -> Dictionary:
	for t in HOLDING_TYPES:
		if t["id"] == id:
			return t
	return HOLDING_TYPES[HOLDING_TYPES.size() - 2]


static func account_kind_label(id: String) -> String:
	for k in ACCOUNT_KINDS:
		if k["id"] == id:
			return k["label"]
	return "Other"


## Movement kinds that make sense for a holding.
static func movement_kinds_for(holding: Dictionary) -> Array:
	var t := holding_type(holding.get("type", "other"))
	match t["valuation"]:
		"market":
			return ["deposit", "withdrawal", "dividend", "fee"]
		"interest":
			var kinds := ["deposit", "withdrawal", "fee"]
			if holding.get("interest_mode", "auto") == "manual":
				kinds.insert(2, "interest")
			return kinds
		_:
			if holding.get("type", "") == "loan":
				return ["valuation"]
			return ["deposit", "withdrawal", "valuation", "interest", "dividend", "fee"]
