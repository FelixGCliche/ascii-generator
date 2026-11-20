extends Control
## Temporary glue: opens an image, feeds it to the layer stack and shows the result.

@onready var _stack: LayerStack = $LayerStack
@onready var _loader: ImageLoader = $ImageLoader
@onready var _status: Label = %StatusLabel
@onready var _panel: LayerPanel = %LayerPanel
@onready var _preview: TextureRect = %Preview


func _ready() -> void:
	_loader.image_loaded.connect(_on_image_loaded)
	_loader.load_failed.connect(_on_load_failed)
	_stack.final_texture_changed.connect(_on_final_texture_changed)
	%OpenButton.pressed.connect(_on_open_pressed)
	_panel.stack = _stack
	_preview.texture = _stack.get_final_texture()


func _on_open_pressed() -> void:
	_status.text = ""
	_loader.open_picker()


func _on_load_failed(reason: String) -> void:
	_status.text = reason


func _on_image_loaded(texture: ImageTexture, _filename: String) -> void:
	_status.text = ""
	_stack.source_texture = texture


func _on_final_texture_changed(texture: Texture2D) -> void:
	_preview.texture = texture
