class_name LayerStack
extends Node
## An ordered chain of [Layer]s.
##
## The first layer reads [member source_texture]; every other layer reads the output of the
## layer before it. The stack owns the wiring: it re-chains whenever layers, order or source
## change, and forwards each upstream [signal Layer.output_changed] to the next layer's
## [method Layer.refresh_size] so downstream layers resize and re-render.
##
## [method get_final_texture] is the last layer's output, or the solo layer's output while a
## solo is set.

## Emitted whenever the texture returned by [method get_final_texture] changes.
signal final_texture_changed(texture: Texture2D)

var source_texture: Texture2D:
	set(value):
		if value == source_texture:
			return
		source_texture = value
		_rechain()

var _layers: Array[Layer] = []
var _solo: Layer
var _wired: Array[Array] = []
var _last_final: Texture2D


## Appends [param layer] (or inserts it at [param index]) and takes ownership as a child.
func add_layer(layer: Layer, index := -1) -> void:
	if not layer or _layers.has(layer):
		return
	if index < 0 or index > _layers.size():
		index = _layers.size()
	_layers.insert(index, layer)
	if layer.get_parent() != self:
		if layer.get_parent():
			layer.get_parent().remove_child(layer)
		add_child(layer)
	_rechain()


## Removes [param layer] from the stack without freeing it.
func remove_layer(layer: Layer) -> void:
	if not _layers.has(layer):
		return
	_layers.erase(layer)
	if _solo == layer:
		_solo = null
	if layer.get_parent() == self:
		remove_child(layer)
	layer.input_tex = null
	_rechain()


## Moves [param layer] to [param index] (clamped to the valid range).
func move_layer(layer: Layer, index: int) -> void:
	if not _layers.has(layer):
		return
	_layers.erase(layer)
	_layers.insert(clampi(index, 0, _layers.size()), layer)
	_rechain()


func get_layers() -> Array[Layer]:
	return _layers.duplicate()


func get_layer(index: int) -> Layer:
	if index < 0 or index >= _layers.size():
		return null
	return _layers[index]


## Shows [param layer]'s output as the final texture; null clears the solo.
func set_solo(layer: Layer) -> void:
	if layer and not _layers.has(layer):
		return
	_solo = layer
	_emit_final_if_changed()


func get_solo() -> Layer:
	return _solo


func clear_solo() -> void:
	set_solo(null)


func get_final_texture() -> Texture2D:
	if _solo:
		return _solo.get_output()
	if _layers.is_empty():
		return source_texture
	return _layers[-1].get_output()


func _rechain() -> void:
	for pair in _wired:
		var upstream: Layer = pair[0]
		var downstream: Layer = pair[1]
		if is_instance_valid(upstream) and is_instance_valid(downstream):
			if upstream.output_changed.is_connected(downstream.refresh_size):
				upstream.output_changed.disconnect(downstream.refresh_size)
	_wired.clear()
	var previous: Texture2D = source_texture
	var previous_layer: Layer
	for layer in _layers:
		layer.input_tex = previous
		if previous_layer:
			previous_layer.output_changed.connect(layer.refresh_size)
			_wired.append([previous_layer, layer])
		previous = layer.get_output()
		previous_layer = layer
	_emit_final_if_changed()


func _emit_final_if_changed() -> void:
	var current := get_final_texture()
	if current == _last_final:
		return
	_last_final = current
	final_texture_changed.emit(current)
