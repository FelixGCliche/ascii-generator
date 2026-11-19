extends Control
## Temporary glue: opens an image and feeds it to the layer stack.

@onready var _stack: LayerStack = $LayerStack
@onready var _loader: ImageLoader = $ImageLoader


func _ready() -> void:
	_loader.image_loaded.connect(_on_image_loaded)
	$OpenButton.pressed.connect(_loader.open_picker)


func _on_image_loaded(texture: ImageTexture, _filename: String) -> void:
	_stack.source_texture = texture
