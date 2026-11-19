class_name PresetIO
extends Node
## Saves and loads layer presets as JSON files.
##
## Web uses [JavaScriptBridge] (a download, and a hidden file input); desktop uses a
## [FileDialog]. Every load path ends in [method load_text].

## Emitted after a preset was applied; [param report] is [method PresetSerializer.apply]'s.
signal preset_loaded(report: Dictionary)
## Emitted when a preset could not be read or parsed.
signal preset_failed(reason: String)

const DEFAULT_FILENAME := "ascii-preset.json"
const _FILTERS: Array[String] = ["*.json ; Presets"]

# Kept referenced: JavaScriptBridge callbacks are freed when garbage collected.
var _js_callback: JavaScriptObject
var _dialog: FileDialog
var _stack: LayerStack


## Writes [param stack] to a user-chosen file (a download on web).
func save(stack: LayerStack) -> void:
	var text := PresetSerializer.to_json(stack)
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(
			text.to_utf8_buffer(), DEFAULT_FILENAME, "application/json"
		)
	else:
		_stack = stack
		_show_dialog(FileDialog.FILE_MODE_SAVE_FILE).current_file = DEFAULT_FILENAME


## Opens the platform file picker and applies the chosen preset to [param stack]. Must be
## called from a user gesture on web.
func open_picker(stack: LayerStack) -> void:
	_stack = stack
	if OS.has_feature("web"):
		_open_web_picker()
	else:
		_show_dialog(FileDialog.FILE_MODE_OPEN_FILE)


## Parses [param text] and applies it to [param stack]; emits [signal preset_loaded] or
## [signal preset_failed].
func load_text(stack: LayerStack, text: String) -> void:
	var data := PresetSerializer.from_json(text)
	if data.is_empty():
		preset_failed.emit("Not a valid preset file")
		return
	preset_loaded.emit(PresetSerializer.apply(stack, data))


# The platform pickers are verified manually (they need a real browser or window).
func _show_dialog(mode: FileDialog.FileMode) -> FileDialog:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.filters = PackedStringArray(_FILTERS)
		_dialog.use_native_dialog = true
		_dialog.file_selected.connect(_on_file_selected)
		add_child(_dialog)
	_dialog.file_mode = mode
	_dialog.popup_centered_ratio(0.6)
	return _dialog


func _on_file_selected(path: String) -> void:
	if _dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			preset_failed.emit("Could not write '%s'" % path)
			return
		file.store_string(PresetSerializer.to_json(_stack))
		return
	if not FileAccess.file_exists(path):
		preset_failed.emit("Could not read '%s'" % path)
		return
	load_text(_stack, FileAccess.get_file_as_string(path))


func _open_web_picker() -> void:
	if _js_callback == null:
		_js_callback = JavaScriptBridge.create_callback(_on_js_file)
	var window := JavaScriptBridge.get_interface("window")
	window.asciiOnPreset = _js_callback
	(
		JavaScriptBridge
		. eval(
			"""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.json,application/json';
			input.style.display = 'none';
			// The input must stay in the DOM until the user picks or cancels: Safari and
			// Firefox drop `change` events on detached inputs.
			input.onchange = function () {
				var file = input.files[0];
				input.remove();
				if (!file) { return; }
				var reader = new FileReader();
				reader.onload = function () { window.asciiOnPreset(file.name, String(reader.result)); };
				reader.onerror = function () { window.asciiOnPreset(file.name, ''); };
				reader.readAsText(file);
			};
			input.oncancel = function () { input.remove(); };
			document.body.appendChild(input);
			input.click();
		})();
	"""
		)
	)


func _on_js_file(args: Array) -> void:
	var text := str(args[1])
	if text.is_empty():
		preset_failed.emit("Could not read '%s'" % str(args[0]))
		return
	load_text(_stack, text)
