extends Node
## Holds all user data, saves it on the device, and handles backups.
## Data never leaves the device (except anonymous price lookups done by PriceService).

signal changed

const SCHEMA := 3
## Settings that stay on this device (never in backups): price key, usage counter, PIN.
const DEVICE_ONLY := ["av_key", "av_calls", "pin_hash", "pin_salt", "pin_len"]
const SAVE_PATH := "user://finance_data.json"
const TMP_PATH := "user://finance_data.tmp"
const BACKUP_PATH := "user://finance_data.prev.json"

var data: Dictionary = {}
var portfolio: Portfolio
## Set to false in tests to avoid touching the disk.
var persist := true


func _ready() -> void:
	load_data()


static func default_data() -> Dictionary:
	return {
		"app": "app-finance",
		"schema": SCHEMA,
		"settings": {
			"currency": "EUR",
			"monthly_income_cents": 0,
			"interest_mode": "auto",
			"onboarded": false,
			"theme": "system",
			"av_key": "",
			"av_calls": {},
			"pin_hash": "",
			"pin_salt": "",
			"sample": false,
			"last_backup": "",
			"prices_updated": "",
		},
		"accounts": [],
		"holdings": [],
		"movements": [],
		"income": {},
		"prices": {},
		"fx": {},
		"spending": {"transactions": [], "rules": {}},
	}


func load_data() -> void:
	var loaded := {}
	if persist and FileAccess.file_exists(SAVE_PATH):
		loaded = _read_json(SAVE_PATH)
		if loaded.is_empty() and FileAccess.file_exists(BACKUP_PATH):
			loaded = _read_json(BACKUP_PATH)
	set_data(loaded if not loaded.is_empty() else default_data(), false)


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## Replaces all data (after migration) and notifies the UI.
func set_data(d: Dictionary, save_now: bool = true) -> void:
	data = migrate(d)
	_rebuild()
	if save_now:
		save()


## Brings old saved files up to the current schema and fills in missing fields.
static func migrate(d: Dictionary) -> Dictionary:
	var out := default_data()
	for key in out:
		if d.has(key):
			if out[key] is Dictionary and d[key] is Dictionary and key == "settings":
				for sk in d[key]:
					out[key][sk] = d[key][sk]
			else:
				out[key] = d[key]
	# Numbers from JSON come back as floats: turn amounts into ints.
	for m in out["movements"]:
		for k in ["amount_cents", "fee_cents"]:
			m[k] = int(m.get(k, 0))
		for k in ["units_6", "price_4"]:
			if m.get(k) != null:
				m[k] = int(m[k])
	for h in out["holdings"]:
		h["fixed_rate_bps"] = int(h.get("fixed_rate_bps", 0))
	for k in out["income"]:
		out["income"][k] = int(out["income"][k])
	out["settings"]["monthly_income_cents"] = int(out["settings"].get("monthly_income_cents", 0))
	for store_key in ["prices", "fx"]:
		for key in out[store_key]:
			var pts: Dictionary = out[store_key][key].get("points", {})
			for dt in pts:
				pts[dt] = int(pts[dt])
	if not out["spending"] is Dictionary:
		out["spending"] = {"transactions": [], "rules": {}}
	for k in ["transactions", "rules"]:
		if not out["spending"].has(k):
			out["spending"][k] = [] if k == "transactions" else {}
	for t in out["spending"]["transactions"]:
		t["amount_cents"] = int(t.get("amount_cents", 0))
	# v3: Yahoo symbols -> Alpha Vantage symbols; relay removed.
	out["settings"].erase("relay_url")
	for h in out["holdings"]:
		var key: String = str(h.get("price_key", ""))
		if key.begins_with("y:"):
			var sym := PriceParsers.yahoo_to_av(key.substr(2))
			h["price_key"] = "av:" + sym
			if out["prices"].has(key):
				out["prices"]["av:" + sym] = out["prices"][key]
				out["prices"].erase(key)
	for key in out["prices"].keys():
		if str(key).begins_with("y:"):
			out["prices"].erase(key)
	out["schema"] = SCHEMA
	return out


func _rebuild() -> void:
	portfolio = Portfolio.new(data)
	changed.emit()


## Saves atomically: write to a temp file, keep the previous copy, then swap.
func save() -> void:
	if not persist:
		return
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not save data: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))
	f.close()
	var dir := DirAccess.open("user://")
	if dir.file_exists("finance_data.json"):
		if dir.file_exists("finance_data.prev.json"):
			dir.remove("finance_data.prev.json")
		dir.rename("finance_data.json", "finance_data.prev.json")
	dir.rename("finance_data.tmp", "finance_data.json")


func commit() -> void:
	_rebuild()
	save()


static func new_id() -> String:
	return "%x%04x" % [int(Time.get_unix_time_from_system() * 1000), randi() % 0xffff]


static func now_iso() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


# ---------- settings ----------

func setting(key: String, default: Variant = null) -> Variant:
	return data["settings"].get(key, default)


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	commit()


func set_settings(values: Dictionary) -> void:
	for k in values:
		data["settings"][k] = values[k]
	commit()


func set_income(month_key: String, cents: int) -> void:
	data["income"][month_key] = cents
	commit()


func clear_income(month_key: String) -> void:
	data["income"].erase(month_key)
	commit()


# ---------- accounts ----------

func add_account(fields: Dictionary) -> String:
	var a := fields.duplicate()
	a["id"] = new_id()
	a["created"] = now_iso()
	data["accounts"].append(a)
	commit()
	return a["id"]


func update_account(aid: String, fields: Dictionary) -> void:
	for a in data["accounts"]:
		if a["id"] == aid:
			for k in fields:
				a[k] = fields[k]
	commit()


func delete_account(aid: String) -> void:
	var hids := []
	for h in data["holdings"]:
		if h["account_id"] == aid:
			hids.append(h["id"])
	for hid in hids:
		_delete_holding_no_commit(hid)
	data["accounts"] = data["accounts"].filter(func(a): return a["id"] != aid)
	commit()


# ---------- holdings ----------

func add_holding(fields: Dictionary) -> String:
	var h := fields.duplicate()
	h["id"] = new_id()
	h["created"] = now_iso()
	data["holdings"].append(h)
	commit()
	return h["id"]


func update_holding(hid: String, fields: Dictionary) -> void:
	for h in data["holdings"]:
		if h["id"] == hid:
			for k in fields:
				h[k] = fields[k]
	commit()


func _delete_holding_no_commit(hid: String) -> void:
	data["movements"] = data["movements"].filter(func(m): return m["holding_id"] != hid)
	data["holdings"] = data["holdings"].filter(func(h): return h["id"] != hid)


func delete_holding(hid: String) -> void:
	_delete_holding_no_commit(hid)
	commit()


# ---------- movements ----------

func add_movement(fields: Dictionary) -> String:
	var m := fields.duplicate()
	m["id"] = new_id()
	m["created"] = now_iso()
	data["movements"].append(m)
	commit()
	return m["id"]


func update_movement(mid: String, fields: Dictionary) -> void:
	for m in data["movements"]:
		if m["id"] == mid:
			for k in fields:
				m[k] = fields[k]
	commit()


func delete_movement(mid: String) -> void:
	data["movements"] = data["movements"].filter(func(m): return m["id"] != mid)
	commit()


# ---------- prices ----------

func merge_prices(key: String, currency: String, points: Dictionary, source: String) -> void:
	if not data["prices"].has(key):
		data["prices"][key] = {"currency": currency, "points": {}, "source": source}
	var entry: Dictionary = data["prices"][key]
	entry["currency"] = currency
	entry["source"] = source
	entry["updated"] = now_iso()
	for dt in points:
		entry["points"][dt] = int(points[dt])


func merge_fx(currency: String, points: Dictionary) -> void:
	if not data["fx"].has(currency):
		data["fx"][currency] = {"points": {}, "source": "ECB via Frankfurter"}
	data["fx"][currency]["updated"] = now_iso()
	for dt in points:
		data["fx"][currency]["points"][dt] = int(points[dt])


# ---------- spending (separate from wealth) ----------

func transactions() -> Array:
	return data["spending"]["transactions"]


## rows: [{date, label, amount_cents}] from Spending.parse(). Skips ones already imported.
func import_transactions(rows: Array, bank: String) -> Dictionary:
	var existing := {}
	for t in transactions():
		existing[t.get("key", "")] = true
	var rules: Dictionary = data["spending"]["rules"]
	var added := 0
	var dupes := 0
	for r in Spending.keyed(rows):
		if existing.has(r["key"]):
			dupes += 1
			continue
		existing[r["key"]] = true
		transactions().append({
			"id": new_id() + str(added), "date": r["date"], "amount_cents": int(r["amount_cents"]),
			"label": r["label"], "bank": bank, "key": r["key"],
			"category": Spending.guess_category(r["label"], r["amount_cents"], rules),
		})
		added += 1
	commit()
	return {"added": added, "duplicates": dupes}


func add_transaction(fields: Dictionary) -> String:
	var t := fields.duplicate()
	t["id"] = new_id()
	t["key"] = "manual|" + t["id"]
	transactions().append(t)
	commit()
	return t["id"]


## Changes a transaction. With learn=true, the new category is remembered for this payee
## and applied to its other transactions too. Returns how many others were updated.
func update_transaction(tid: String, fields: Dictionary, learn: bool = false) -> int:
	var changed := 0
	var target := {}
	for t in transactions():
		if t["id"] == tid:
			for k in fields:
				t[k] = fields[k]
			target = t
	if learn and fields.has("category") and not target.is_empty():
		var key := Spending.merchant_key(target["label"])
		data["spending"]["rules"][key] = fields["category"]
		for t in transactions():
			if t["id"] != tid and Spending.merchant_key(t["label"]) == key and t.get("category", "") != fields["category"]:
				t["category"] = fields["category"]
				changed += 1
	commit()
	return changed


func delete_transaction(tid: String) -> void:
	data["spending"]["transactions"] = transactions().filter(func(t): return t["id"] != tid)
	commit()


func clear_spending() -> void:
	data["spending"]["transactions"] = []
	commit()


# ---------- backup ----------

func export_json() -> String:
	var copy := data.duplicate(true)
	copy["exported"] = now_iso()
	# Device-only settings are not put in backup files.
	for k in DEVICE_ONLY:
		copy["settings"].erase(k)
	return JSON.stringify(copy, "  ")


## Returns "" on success, or an error message.
func import_json(text: String) -> String:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return "This file is not a valid backup."
	if parsed.get("app", "") != "app-finance":
		return "This file is not an APP FINANCE backup."
	if int(parsed.get("schema", 0)) > SCHEMA:
		return "This backup comes from a newer version of the app. Please update the app first."
	var keep := {}
	for k in DEVICE_ONLY:
		keep[k] = data["settings"].get(k)
	var restored := migrate(parsed)
	for k in keep:
		if keep[k] != null:
			restored["settings"][k] = keep[k]
	set_data(restored)
	return ""


func mark_backup_done() -> void:
	data["settings"]["last_backup"] = Dates.today()
	save()


func reset_all() -> void:
	set_data(default_data())
