extends Control
## Temporary glue: opens an image and feeds it to the layer stack.

@onready var _stack: LayerStack = $LayerStack
@onready var _loader: ImageLoader = $ImageLoader
@onready var _status: Label = $StatusLabel


func _ready() -> void:
	_loader.image_loaded.connect(_on_image_loaded)
	_loader.load_failed.connect(_on_load_failed)
	$OpenButton.pressed.connect(_on_open_pressed)


func _on_open_pressed() -> void:
	_status.text = ""
	_loader.open_picker()


func _on_load_failed(reason: String) -> void:
	_status.text = reason


func _on_image_loaded(texture: ImageTexture, _filename: String) -> void:
	_status.text = ""
	_stack.source_texture = texture
