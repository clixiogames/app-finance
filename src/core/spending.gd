class_name Spending
## Daily income & expenses from bank statements. Completely separate from Wealth.
## - Parses bank exports (CSV from most French banks, OFX).
## - Guesses a category from the label (built-in keywords + rules learned from your corrections).
## - Monthly summaries.
## Transactions: {id, date, amount_cents (+ in / − out), label, category, bank, key}

const CATEGORIES := [
	{"id": "salary", "label": "Salary", "kind": "income"},
	{"id": "other_income", "label": "Other income", "kind": "income"},
	{"id": "refund", "label": "Refunds", "kind": "income"},
	{"id": "housing", "label": "Housing", "kind": "expense"},
	{"id": "utilities", "label": "Energy & internet", "kind": "expense"},
	{"id": "groceries", "label": "Groceries", "kind": "expense"},
	{"id": "restaurants", "label": "Restaurants & cafés", "kind": "expense"},
	{"id": "transport", "label": "Transport", "kind": "expense"},
	{"id": "shopping", "label": "Shopping", "kind": "expense"},
	{"id": "health", "label": "Health", "kind": "expense"},
	{"id": "leisure", "label": "Leisure", "kind": "expense"},
	{"id": "subscriptions", "label": "Subscriptions", "kind": "expense"},
	{"id": "insurance", "label": "Insurance", "kind": "expense"},
	{"id": "taxes", "label": "Taxes", "kind": "expense"},
	{"id": "travel", "label": "Travel", "kind": "expense"},
	{"id": "fees", "label": "Bank fees", "kind": "expense"},
	{"id": "cash", "label": "Cash withdrawals", "kind": "expense"},
	{"id": "other", "label": "Other", "kind": "expense"},
	{"id": "transfer", "label": "Transfers (not counted)", "kind": "transfer"},
]

## Built-in keyword hints (checked against the cleaned label, upper case).
const KEYWORDS := {
	"salary": ["SALAIRE", "PAIE ", "REMUNERATION", "PAYROLL", "SALARY"],
	"refund": ["REMBOURSEMENT", "REMB ", "AVOIR", "CPAM", "MUTUELLE REMB"],
	"housing": ["LOYER", "FONCIA", "NEXITY", "SYNDIC", "CREDIT IMMO", "ECHEANCE PRET"],
	"utilities": ["EDF", "ENGIE", "TOTALENERGIES ELEC", "VEOLIA", "SUEZ", "ORANGE", "FREE MOBILE", "FREE TELECOM", "SFR", "BOUYGUES TEL", "SOSH", "RED BY SFR"],
	"groceries": ["CARREFOUR", "LECLERC", "AUCHAN", "INTERMARCHE", "LIDL", "ALDI", "MONOPRIX", "FRANPRIX", "CASINO", "SUPER U", "HYPER U", "U EXPRESS", "PICARD", "BIOCOOP", "NATURALIA", "GRAND FRAIS", "NETTO", "COCCINELLE", "SPAR"],
	"restaurants": ["RESTAURANT", "RESTO", "MCDONALD", "MC DONALD", "BURGER KING", "KFC", "STARBUCKS", "DELIVEROO", "UBER EATS", "UBER *EATS", "JUST EAT", "BOULANGERIE", "CAFE ", "BRASSERIE", "PAUL ", "SUBWAY", "DOMINO"],
	"transport": ["SNCF", "RATP", "NAVIGO", "UBER", "BOLT", "BLABLACAR", "TOTAL ", "ESSO", "SHELL", "BP ", "AVIA", "STATION", "PEAGE", "VINCI AUTOROUTE", "SANEF", "APRR", "PARKING", "INDIGO", "TCL", "TISSEO", "LIME"],
	"shopping": ["AMAZON", "FNAC", "DARTY", "BOULANGER", "DECATHLON", "IKEA", "ZARA", "H&M", "H ET M", "UNIQLO", "LEROY MERLIN", "CASTORAMA", "CDISCOUNT", "VINTED", "ACTION ", "SEPHORA", "KIABI", "ALIEXPRESS", "APPLE.COM/BILL", "ZALANDO"],
	"health": ["PHARMACIE", "DOCTOLIB", "MEDECIN", "DR ", "DENTISTE", "OPTIC", "LABORATOIRE", "KINE", "HOPITAL", "CLINIQUE"],
	"leisure": ["CINEMA", "UGC", "PATHE", "GAUMONT", "FNAC SPECTACLE", "TICKETMASTER", "STEAM", "PLAYSTATION", "NINTENDO", "BASIC FIT", "FITNESS", "SALLE DE SPORT"],
	"subscriptions": ["NETFLIX", "SPOTIFY", "DEEZER", "DISNEY", "CANAL+", "CANAL +", "PRIME VIDEO", "AMAZON PRIME", "YOUTUBE", "APPLE.COM", "ICLOUD", "GOOGLE ", "OPENAI", "ANTHROPIC", "ADOBE", "MICROSOFT"],
	"insurance": ["ASSURANCE", "MAIF", "MACIF", "MATMUT", "AXA", "ALLIANZ", "GROUPAMA", "MAAF", "GMF", "MUTUELLE", "HARMONIE"],
	"taxes": ["DGFIP", "IMPOT", "TRESOR PUBLIC", "TAXE", "URSSAF", "AMENDE"],
	"travel": ["AIRBNB", "BOOKING", "HOTEL", "AIR FRANCE", "EASYJET", "RYANAIR", "VUELING", "TRANSAVIA", "EXPEDIA", "OUIGO", "TRAINLINE"],
	"fees": ["FRAIS", "COMMISSION", "COTISATION", "AGIOS", "INTERETS DEBITEURS"],
	"cash": ["RETRAIT", "DAB", "ATM", "WITHDRAWAL"],
	"transfer": ["VIR SEPA VERS", "VIREMENT VERS", "VIR VERS", "VIREMENT INTERNE", "VIR INTERNE", "LIVRET", "EPARGNE", "VIR PERMANENT"],
}

const NOISE := ["PAIEMENT PAR CARTE", "PAIEMENT CARTE", "CARTE X", "CB ", "PRLV SEPA", "PRELEVEMENT", "PRLV", "VIR SEPA RECU", "VIR SEPA", "VIREMENT RECU", "VIREMENT", "ACHAT CB", "FACTURE CARTE", "DU ", "PAYPAL *", "SUMUP *", "ZETTLE_*", "SQ *"]


static func category(id: String) -> Dictionary:
	for c in CATEGORIES:
		if c["id"] == id:
			return c
	return CATEGORIES[CATEGORIES.size() - 2]


static func category_label(id: String) -> String:
	return category(id)["label"]


# ---------------- labels & categories ----------------

## Upper-case, accents removed, single spaces.
static func clean(label: String) -> String:
	var t := label.to_upper()
	var from := "ÀÂÄÁÃÉÈÊËÍÎÏÌÓÔÖÒÕÚÙÛÜÇÑ"
	var to := "AAAAAEEEEIIIIOOOOOUUUUCN"
	for i in from.length():
		t = t.replace(from[i], to[i])
	t = t.replace("\t", " ").replace("\n", " ")
	while t.contains("  "):
		t = t.replace("  ", " ")
	return t.strip_edges()


## A short key identifying the merchant/payee, used to learn your categories.
## "PAIEMENT PAR CARTE X1234 CARREFOUR CITY 12/11" -> "CARREFOUR CITY"
static func merchant_key(label: String) -> String:
	var t := clean(label)
	for n in NOISE:
		t = t.replace(n, " ")
	var words := []
	for w in t.split(" ", false):
		var digits := 0
		for ch in w:
			if ch >= "0" and ch <= "9":
				digits += 1
		if digits * 2 >= w.length():
			continue  # dates, card numbers, references
		if w.begins_with("X") and w.length() >= 4 and w.substr(1).is_valid_int():
			continue
		words.append(w)
		if words.size() == 3:
			break
	return " ".join(words) if not words.is_empty() else clean(label).substr(0, 24)


## rules: {merchant_key: category_id} learned from your corrections.
static func guess_category(label: String, amount_cents: int, rules: Dictionary) -> String:
	var key := merchant_key(label)
	if rules.has(key):
		return rules[key]
	var t := clean(label)
	for cat in ["transfer", "salary", "refund", "cash", "fees", "taxes"]:
		if _matches(t, cat, amount_cents):
			return cat
	for cat in KEYWORDS:
		if _matches(t, cat, amount_cents):
			return cat
	return "other_income" if amount_cents > 0 else "other"


static func _matches(t: String, cat: String, amount_cents: int) -> bool:
	var kind: String = category(cat)["kind"]
	if kind == "income" and amount_cents < 0:
		return false
	if kind == "expense" and amount_cents > 0:
		return false
	for kw in KEYWORDS[cat]:
		if t.contains(kw):
			return true
	return false


# ---------------- file parsing ----------------

## Decodes bank files that may be UTF-8 or Latin-1 (common in French bank exports).
static func decode(bytes: PackedByteArray) -> String:
	var s := bytes.get_string_from_utf8()
	if s.length() > 0 and not s.contains("�"):
		if s.begins_with("﻿"):
			s = s.substr(1)
		return s
	var out := PackedStringArray()
	for b in bytes:
		out.append(String.chr(b))
	return "".join(out)


## Parses a bank export (CSV or OFX). Returns {ok, rows: [{date, label, amount_cents}], error, info}
static func parse(text: String) -> Dictionary:
	var t := text.strip_edges()
	if t.contains("<STMTTRN>") or t.contains("<OFX>"):
		return parse_ofx(t)
	return parse_csv(t)


static func parse_ofx(text: String) -> Dictionary:
	var rows := []
	var blocks := text.split("<STMTTRN>")
	for i in range(1, blocks.size()):
		var b: String = blocks[i].split("</STMTTRN>")[0]
		var dt := _ofx_tag(b, "DTPOSTED")
		var amt := _ofx_tag(b, "TRNAMT")
		var label := _ofx_tag(b, "NAME")
		var memo := _ofx_tag(b, "MEMO")
		if memo != "" and not label.contains(memo):
			label = (label + " " + memo).strip_edges()
		if dt.length() < 8:
			continue
		var date := "%s-%s-%s" % [dt.substr(0, 4), dt.substr(4, 2), dt.substr(6, 2)]
		var cents: Variant = Money.parse_cents(amt)
		if not Dates.is_valid(date) or cents == null:
			continue
		rows.append({"date": date, "label": label, "amount_cents": cents})
	if rows.is_empty():
		return {"ok": false, "rows": [], "error": "No transactions found in this OFX file.", "info": ""}
	return {"ok": true, "rows": rows, "error": "", "info": "OFX file"}


static func _ofx_tag(block: String, tag: String) -> String:
	var i := block.find("<" + tag + ">")
	if i < 0:
		return ""
	var rest := block.substr(i + tag.length() + 2)
	var end := rest.find("<")
	var v := rest.substr(0, end if end >= 0 else rest.length())
	return v.strip_edges().replace("&amp;", "&")


static func _split_line(line: String, sep: String) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	var quoted := false
	var i := 0
	while i < line.length():
		var ch := line[i]
		if ch == "\"":
			if quoted and i + 1 < line.length() and line[i + 1] == "\"":
				cur += "\""
				i += 1
			else:
				quoted = not quoted
		elif ch == sep and not quoted:
			out.append(cur.strip_edges())
			cur = ""
		else:
			cur += ch
		i += 1
	out.append(cur.strip_edges())
	return out


static func _norm_header(h: String) -> String:
	return clean(h).replace("_", " ").replace(".", "").strip_edges()


## Finds which column holds what. Returns {} if this line is not a header.
static func _detect_columns(cells: PackedStringArray) -> Dictionary:
	var cols := {}
	for i in cells.size():
		var h := _norm_header(cells[i])
		if h == "":
			continue
		if not cols.has("date") and (h in ["DATE", "DATEOP", "DATE OP", "DATE OPERATION", "DATE D'OPERATION", "DATE DE L'OPERATION", "DATE COMPTABLE", "BOOKING DATE", "TRANSACTION DATE", "DATE TRANSACTION"] or h.begins_with("DATE OP")):
			cols["date"] = i
		elif not cols.has("date2") and (h.begins_with("DATE") or h == "DATEVAL" or h.contains("VALUE DATE")):
			cols["date2"] = i
		elif not cols.has("label") and (h in ["LIBELLE", "LABEL", "LIBELLE OPERATION", "LIBELLE SIMPLIFIE", "DESCRIPTION", "DETAIL", "DETAILS", "OPERATION", "NATURE DE L'OPERATION", "LIBELLE COURT", "MERCHANT", "PAYEE", "NAME"] or h.begins_with("LIBELLE")):
			cols["label"] = i
		elif not cols.has("label2") and (h in ["INFORMATIONS COMPLEMENTAIRES", "LIBELLE OPERATION DETAILLE", "MEMO", "REFERENCE", "COMMENTAIRE"]):
			cols["label2"] = i
		elif not cols.has("amount") and (h in ["MONTANT", "AMOUNT", "MONTANT(EUROS)", "MONTANT (EUR)", "MONTANT EUR", "MONTANT EN EUROS", "VALEUR", "SOMME"] or h.begins_with("MONTANT")):
			cols["amount"] = i
		elif not cols.has("debit") and (h.begins_with("DEBIT") or h == "DEBIT EUROS" or h == "WITHDRAWAL" or h == "OUT"):
			cols["debit"] = i
		elif not cols.has("credit") and (h.begins_with("CREDIT") or h == "DEPOSIT" or h == "IN"):
			cols["credit"] = i
	if not cols.has("date") and cols.has("date2"):
		cols["date"] = cols["date2"]
	if cols.has("date") and cols.has("label") and (cols.has("amount") or cols.has("debit") or cols.has("credit")):
		return cols
	return {}


static func parse_date(s: String) -> String:
	var t := s.strip_edges().replace(".", "/").replace("-", "/")
	if t.length() >= 10 and t[4] == "/":
		var d := "%s-%s-%s" % [t.substr(0, 4), t.substr(5, 2), t.substr(8, 2)]
		return d if Dates.is_valid(d) else ""
	var p := t.split("/")
	if p.size() < 3:
		return ""
	var y := p[2].substr(0, 4).strip_edges()
	if y.length() == 2:
		y = "20" + y
	if not (p[0].is_valid_int() and p[1].is_valid_int() and y.is_valid_int()):
		return ""
	var d2 := Dates.make(int(y), int(p[1]), int(p[0]))
	return d2 if Dates.is_valid(d2) else ""


static func parse_csv(text: String) -> Dictionary:
	var lines := text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var sep := ";"
	var best := 0
	for cand in [";", ",", "\t", "|"]:
		var n := 0
		for l in lines.slice(0, 30):
			n += l.count(cand)
		if n > best:
			best = n
			sep = cand
	var cols := {}
	var start := -1
	for i in mini(lines.size(), 40):
		var c := _detect_columns(_split_line(lines[i], sep))
		if not c.is_empty():
			cols = c
			start = i + 1
			break
	if start < 0:
		return {"ok": false, "rows": [], "error": "Couldn't find the date, label and amount columns. Export your statement as CSV from your bank's website.", "info": ""}
	var rows := []
	var skipped := 0
	for i in range(start, lines.size()):
		var line: String = lines[i]
		if line.strip_edges() == "":
			continue
		var cells := _split_line(line, sep)
		var need: int = cols.values().max()
		if cells.size() <= need and cells.size() < 2:
			skipped += 1
			continue
		var date := parse_date(cells[cols["date"]] if cols["date"] < cells.size() else "")
		var label: String = cells[cols["label"]] if cols["label"] < cells.size() else ""
		if cols.has("label2") and cols["label2"] < cells.size() and cells[cols["label2"]] != "":
			label = (label + " " + cells[cols["label2"]]).strip_edges()
		var cents: Variant = null
		if cols.has("amount") and cols["amount"] < cells.size():
			cents = Money.parse_cents(cells[cols["amount"]])
		else:
			var deb: Variant = Money.parse_cents(cells[cols["debit"]]) if cols.has("debit") and cols["debit"] < cells.size() else null
			var cre: Variant = Money.parse_cents(cells[cols["credit"]]) if cols.has("credit") and cols["credit"] < cells.size() else null
			if deb != null and deb != 0:
				cents = -absi(deb)
			elif cre != null:
				cents = absi(cre)
		if date == "" or cents == null:
			skipped += 1
			continue
		rows.append({"date": date, "label": label.replace("\"", "").strip_edges(), "amount_cents": cents})
	if rows.is_empty():
		return {"ok": false, "rows": [], "error": "No transactions could be read from this file.", "info": ""}
	return {"ok": true, "rows": rows, "error": "", "info": "%d lines skipped" % skipped if skipped > 0 else ""}


# ---------------- duplicates ----------------

## Identity of a transaction, so importing the same statement twice adds nothing.
static func tx_key(date: String, amount_cents: int, label: String, occurrence: int) -> String:
	return "%s|%d|%s|%d" % [date, amount_cents, clean(label), occurrence]


## Adds `occurrence` numbers so two identical coffees on the same day both count.
static func keyed(rows: Array) -> Array:
	var seen := {}
	var out := []
	for r in rows:
		var base := "%s|%d|%s" % [r["date"], r["amount_cents"], clean(r["label"])]
		var n: int = seen.get(base, 0)
		seen[base] = n + 1
		var r2: Dictionary = r.duplicate()
		r2["key"] = tx_key(r["date"], r["amount_cents"], r["label"], n)
		out.append(r2)
	return out


# ---------------- summaries ----------------

## Totals for a month: {income, expenses (negative), net, by_category {id: cents}, count}
static func month_summary(transactions: Array, month_key: String) -> Dictionary:
	var out := {"income": 0, "expenses": 0, "net": 0, "by_category": {}, "count": 0, "transfers": 0}
	for t in transactions:
		if Dates.month_key(t["date"]) != month_key:
			continue
		out["count"] += 1
		var cat: String = t.get("category", "other")
		var kind: String = category(cat)["kind"]
		var amt: int = t["amount_cents"]
		if kind == "transfer":
			out["transfers"] += amt
			continue
		if amt >= 0:
			out["income"] += amt
		else:
			out["expenses"] += amt
		out["by_category"][cat] = out["by_category"].get(cat, 0) + amt
	out["net"] = out["income"] + out["expenses"]
	return out


## Last n months of {month, income, expenses}
static func trend(transactions: Array, n: int, end_key: String) -> Array:
	var out := []
	for i in n:
		var k := Dates.month_key_add(end_key, -(n - 1 - i))
		var s := month_summary(transactions, k)
		out.append({"month": k, "income": s["income"], "expenses": s["expenses"]})
	return out
