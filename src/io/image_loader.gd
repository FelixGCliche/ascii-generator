class_name ImageLoader
extends Node
## Lets the user pick an image file and turns it into an [ImageTexture].
##
## Web uses a hidden HTML file input through [JavaScriptBridge]; desktop uses a [FileDialog].
## Both paths end in [method load_bytes].

## Emitted with the decoded (and size-limited) texture.
signal image_loaded(texture: ImageTexture, filename: String)
## Emitted when the chosen file could not be read or decoded.
signal load_failed(reason: String)

const _FILTERS: Array[String] = ["*.png, *.jpg, *.jpeg, *.webp, *.bmp ; Images"]

# Kept referenced: JavaScriptBridge callbacks are freed when garbage collected.
var _js_callback: JavaScriptObject
var _dialog: FileDialog


## Opens the platform file picker. Must be called from a user gesture on web.
func open_picker() -> void:
	if OS.has_feature("web"):
		_open_web_picker()
	else:
		_open_desktop_picker()


## Decodes [param bytes] and emits [signal image_loaded] or [signal load_failed].
func load_bytes(bytes: PackedByteArray, filename := "") -> void:
	var image := ImageDecoder.decode(bytes, filename)
	if image == null:
		load_failed.emit("Could not read '%s' as an image" % filename)
		return
	image = ImageDecoder.limit_size(image)
	image_loaded.emit(ImageDecoder.to_texture(image), filename)


# The platform pickers are verified manually (they need a real browser or window).
func _open_desktop_picker() -> void:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.filters = PackedStringArray(_FILTERS)
		_dialog.use_native_dialog = true
		_dialog.file_selected.connect(_on_file_selected)
		add_child(_dialog)
	_dialog.popup_centered_ratio(0.6)


func _on_file_selected(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		load_failed.emit("Could not read '%s'" % path)
		return
	load_bytes(bytes, path.get_file())


func _open_web_picker() -> void:
	if _js_callback == null:
		_js_callback = JavaScriptBridge.create_callback(_on_js_file)
	var window := JavaScriptBridge.get_interface("window")
	window.asciiOnFile = _js_callback
	# The file is read as a data URL: its base64 payload is a plain string, which crosses the
	# bridge reliably (unlike typed arrays) and is decoded with Marshalls on the Godot side.
	(
		JavaScriptBridge
		. eval(
			"""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = 'image/*';
			input.style.display = 'none';
			input.onchange = function () {
				var file = input.files[0];
				if (!file) { return; }
				var reader = new FileReader();
				reader.onload = function () { window.asciiOnFile(file.name, String(reader.result)); };
				reader.onerror = function () { window.asciiOnFile(file.name, ''); };
				reader.readAsDataURL(file);
			};
			document.body.appendChild(input);
			input.click();
			input.remove();
		})();
	"""
		)
	)


func _on_js_file(args: Array) -> void:
	var filename := str(args[0])
	var data_url := str(args[1])
	var comma := data_url.find(",")
	if comma < 0:
		load_failed.emit("Could not read '%s'" % filename)
		return
	load_bytes(Marshalls.base64_to_raw(data_url.substr(comma + 1)), filename)
