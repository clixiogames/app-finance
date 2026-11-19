class_name Files
## Open and save files on every platform: browser file picker on the web,
## system file picker on Android, plain files on desktop.

static var _js_cb: JavaScriptObject


## Lets the user pick a file; cb(bytes: PackedByteArray, name: String) is called with its content.
static func open_bytes(filters: PackedStringArray, cb: Callable, on_error: Callable = Callable()) -> void:
	if OS.has_feature("web"):
		_js_cb = JavaScriptBridge.create_callback(func(args):
			var data_url := str(args[0])
			var fname := str(args[1]) if args.size() > 1 else ""
			var comma := data_url.find(",")
			cb.call(Marshalls.base64_to_raw(data_url.substr(comma + 1)), fname))
		var window := JavaScriptBridge.get_interface("window")
		window.appFinanceOnFile = _js_cb
		var accept := ",".join(Array(filters).map(func(f): return f.replace("*", "")))
		JavaScriptBridge.eval("""(function(){var i=document.createElement('input');i.type='file';i.accept='%s';
			i.onchange=function(e){var f=e.target.files[0];if(!f)return;var r=new FileReader();
			r.onload=function(){window.appFinanceOnFile(r.result, f.name);};r.readAsDataURL(f);};
			i.click();})()""" % accept, true)
		return
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Choose a file", OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters,
			func(ok: bool, paths: PackedStringArray, _f: int):
				if not ok or paths.is_empty():
					return
				var bytes := FileAccess.get_file_as_bytes(paths[0])
				if bytes.is_empty() and on_error.is_valid():
					on_error.call("Could not open the file")
					return
				cb.call(bytes, paths[0].get_file()))
	elif on_error.is_valid():
		on_error.call("Opening files is not available on this device")


## Saves text to a file the user chooses (download on the web). cb(ok: bool, message: String)
static func save_text(text: String, file_name: String, cb: Callable) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, "application/json")
		cb.call(true, "Downloaded " + file_name)
		return
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Save", OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), file_name, false,
			DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.json"]),
			func(ok: bool, paths: PackedStringArray, _f: int):
				if not ok or paths.is_empty():
					return
				var f := FileAccess.open(paths[0], FileAccess.WRITE)
				if f == null:
					cb.call(false, "Could not save the file")
					return
				f.store_string(text)
				f.close()
				cb.call(true, "Saved"))
		return
	var path := OS.get_user_data_dir().path_join(file_name)
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	if f2 == null:
		cb.call(false, "Could not save the file")
		return
	f2.store_string(text)
	f2.close()
	cb.call(true, "Saved to " + path)
