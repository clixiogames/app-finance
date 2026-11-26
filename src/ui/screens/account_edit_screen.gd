extends Screen
## Create or edit an account (PEA, Livret, crypto exchange…).

var account_id := ""
var _name: LineEdit
var _kind: OptionButton
var _inst: LineEdit
var _built := false


func _init(aid: String = "") -> void:
	super()
	account_id = aid


func title() -> String:
	return "New account" if account_id == "" else "Edit account"


func auto_refresh() -> bool:
	return false


func refresh() -> void:
	if _built:
		return
	_built = true
	var a: Dictionary = Store.portfolio.account(account_id) if account_id != "" else {}
	_kind = Ui.option(Catalog.account_kind_choices(a.get("kind", "")), a.get("kind", "pea"))
	add_child(Ui.field("Type", _kind))
	_name = Ui.line_edit("e.g. PEA Boursorama", a.get("name", ""))
	add_child(Ui.field("Name", _name))
	_inst = Ui.line_edit("e.g. Boursorama, Crédit Agricole…", a.get("institution", ""))
	add_child(Ui.field("Bank / provider (optional)", _inst))
	_kind.item_selected.connect(func(_i):
		if _name.text == "":
			_name.placeholder_text = _kind.get_item_text(_kind.selected))
	add_child(Ui.spacer(6))
	add_child(Ui.button("Save", "Primary", _save))
	if account_id != "":
		add_child(Ui.button("Delete account", "Danger", func():
			app.confirm("Delete this account?", "Its holdings and all their history will be deleted. This cannot be undone.", "Delete", func():
				Store.delete_account(account_id)
				app.pop_to_root(), true)))


func _save() -> void:
	var nm := _name.text.strip_edges()
	if nm == "":
		nm = _kind.get_item_text(_kind.selected)
	var fields := {"name": nm, "kind": Ui.option_value(_kind), "institution": _inst.text.strip_edges()}
	if account_id == "":
		var aid := Store.add_account(fields)
		app.pop()
		app.push(preload("res://src/ui/screens/holding_edit_screen.gd").new("", aid))
		app.toast("Account added — now add what it holds")
	else:
		Store.update_account(account_id, fields)
		app.pop()
