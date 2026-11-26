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

## Account types shown when creating an account. "holding" = holding type suggested first.
## "hidden" kinds are kept only so older accounts still show a label; they are not offered for new accounts.
const ACCOUNT_KINDS := [
	{"id": "current", "label": "Current account (compte courant)", "holding": "cash"},
	{"id": "livret_a", "label": "Livret A", "holding": "livret_a"},
	{"id": "ldds", "label": "LDDS", "holding": "ldds"},
	{"id": "lep", "label": "LEP", "holding": "lep"},
	{"id": "livret_jeune", "label": "Livret Jeune", "holding": "savings"},
	{"id": "bank_savings", "label": "Bank savings account (livret bancaire)", "holding": "savings"},
	{"id": "cel", "label": "CEL (compte épargne logement)", "holding": "home_savings"},
	{"id": "pel", "label": "PEL (plan épargne logement)", "holding": "home_savings"},
	{"id": "term", "label": "Term deposit (compte à terme)", "holding": "term_deposit"},
	{"id": "pea", "label": "PEA", "holding": "etf"},
	{"id": "pea_pme", "label": "PEA-PME", "holding": "etf"},
	{"id": "cto", "label": "Brokerage account (CTO)", "holding": "etf"},
	{"id": "assurance_vie", "label": "Life insurance (assurance vie)", "holding": "euro_fund"},
	{"id": "capitalisation", "label": "Capitalisation contract (contrat de capitalisation)", "holding": "euro_fund"},
	{"id": "per", "label": "Individual retirement plan (PER individuel)", "holding": "retirement"},
	{"id": "per_company", "label": "Company retirement plan (PERCOL / PERCO / PERO)", "holding": "retirement"},
	{"id": "employee", "label": "Employee savings plan (PEE / PEG)", "holding": "retirement"},
	{"id": "crypto", "label": "Crypto exchange / wallet", "holding": "crypto"},
	{"id": "property", "label": "Property (home, rental)", "holding": "property"},
	{"id": "scpi", "label": "Real-estate funds (SCPI / OPCI)", "holding": "other"},
	{"id": "crowdfunding", "label": "Crowdfunding / crowdlending", "holding": "other"},
	{"id": "cash", "label": "Cash (wallet, at home)", "holding": "cash"},
	{"id": "loan", "label": "Loan / mortgage", "holding": "loan"},
	{"id": "other", "label": "Other", "holding": "etf", "hidden": true},
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
	return account_kind(id).get("label", "Other")


static func account_kind(id: String) -> Dictionary:
	for k in ACCOUNT_KINDS:
		if k["id"] == id:
			return k
	return {}


## Account types offered in the picker (plus the account's current type, if it is an old hidden one).
static func account_kind_choices(current: String = "") -> Array:
	var out := []
	for k in ACCOUNT_KINDS:
		if not k.get("hidden", false) or k["id"] == current:
			out.append([k["id"], k["label"]])
	return out


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
