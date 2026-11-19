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
## Emitted after queued downstream updates were requested (see [method _flush_pending]).
signal updates_flushed(layers: Array[Layer])

var source_texture: Texture2D:
	set(value):
		if value == source_texture:
			return
		source_texture = value
		_rechain()

# Untyped on purpose: typed access to an externally freed layer raises engine errors.
var _layers: Array = []
var _solo: Variant
## Active links, each [upstream, downstream, callable].
var _wired: Array[Array] = []
var _last_final: Texture2D
var _pending := {}
var _stack_exiting := false


func _init() -> void:
	tree_exiting.connect(func() -> void: _stack_exiting = true)
	tree_entered.connect(func() -> void: _stack_exiting = false)
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)


## Appends [param layer] (or inserts it at [param index]) and takes ownership as a child.
## A layer owned by another stack is removed from it first.
func add_layer(layer: Layer, index := -1) -> void:
	if not layer or _layers.has(layer):
		return
	_reconcile()
	var parent := layer.get_parent()
	if parent is LayerStack and parent != self:
		parent.remove_layer(layer)
	elif parent and parent != self:
		parent.remove_child(layer)
	if index < 0 or index > _layers.size():
		index = _layers.size()
	_layers.insert(index, layer)
	if layer.get_parent() != self:
		add_child(layer)
	layer.tree_exiting.connect(_on_layer_tree_exiting.bind(layer))
	_rechain()


## Removes [param layer] from the stack without freeing it.
func remove_layer(layer: Layer) -> void:
	if not _layers.has(layer):
		return
	_forget(layer)
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
	_reconcile()
	var result: Array[Layer] = []
	result.assign(_layers)
	return result


func get_layer(index: int) -> Layer:
	_reconcile()
	if index < 0 or index >= _layers.size():
		return null
	return _layers[index]


## Shows [param layer]'s output as the final texture; null clears the solo.
## Layers downstream of the solo layer are not displayed, so they stop receiving updates;
## when they become visible again they are resized and re-rendered.
func set_solo(layer: Layer) -> void:
	_reconcile()
	if layer and not _layers.has(layer):
		return
	var old_boundary := _active_boundary()
	_solo = layer
	for i in range(old_boundary + 1, _active_boundary() + 1):
		_layers[i].refresh_size()
		_queue(_layers[i])
	_emit_final_if_changed()


func get_solo() -> Layer:
	_reconcile()
	return _solo


func clear_solo() -> void:
	set_solo(null)


func get_final_texture() -> Texture2D:
	if _solo:
		return _solo.get_output()
	if _layers.is_empty():
		return source_texture
	return _layers[-1].get_output()


## Requests the updates queued by upstream changes.
##
## Sibling SubViewports have no guaranteed render order, so a downstream layer requested in
## the same frame as its upstream may sample the upstream's previous frame. Instead, an
## upstream change only queues its downstream layer; the queue is flushed after the frame was
## drawn ([signal RenderingServer.frame_post_draw]), so the upstream is rendered by then and
## the downstream renders one frame later. Any number of changes in a frame is coalesced into
## one request per layer. Runs automatically; callable directly (e.g. from tests).
func _flush_pending() -> void:
	var queued := _pending.keys()
	_pending.clear()
	var flushed: Array[Layer] = []
	for layer: Layer in queued:
		if is_instance_valid(layer) and _layers.has(layer) and _is_active(layer):
			layer.request_update()
			flushed.append(layer)
	if not flushed.is_empty():
		updates_flushed.emit(flushed)


func _on_frame_post_draw() -> void:
	if not _pending.is_empty():
		_flush_pending()


func _queue(layer: Layer) -> void:
	if _is_active(layer):
		_pending[layer] = true


func _active_boundary() -> int:
	return _layers.size() - 1 if not _solo else _layers.find(_solo)


func _is_active(layer: Layer) -> bool:
	return _layers.find(layer) <= _active_boundary()


func _on_upstream_changed(downstream: Layer) -> void:
	if not is_instance_valid(downstream) or not _is_active(downstream):
		return
	downstream.refresh_size()
	_queue(downstream)


func _on_layer_tree_exiting(_layer: Layer) -> void:
	# Leaving the tree is ambiguous (layer removed or freed vs. the whole stack leaving), so
	# decide once the removal finished.
	_reconcile.call_deferred()


## Drops [param layer] from the bookkeeping (not from the scene tree).
func _forget(layer: Layer) -> void:
	_layers.erase(layer)
	_pending.erase(layer)
	if _solo == layer:
		_solo = null
	if layer.tree_exiting.is_connected(_on_layer_tree_exiting.bind(layer)):
		layer.tree_exiting.disconnect(_on_layer_tree_exiting.bind(layer))


## Drops layers that were freed or reparented behind the stack's back, then re-chains once.
func _reconcile() -> void:
	var dirty := false
	for i in range(_layers.size() - 1, -1, -1):
		var entry: Variant = _layers[i]
		if not is_instance_valid(entry):
			_layers.remove_at(i)
			dirty = true
		elif entry.get_parent() != self:
			_forget(entry)
			entry.input_tex = null
			dirty = true
	if not is_instance_valid(_solo):
		_solo = null
	if dirty:
		_pending.clear()
		_rechain()


func _unwire() -> void:
	for link in _wired:
		var upstream: Variant = link[0]
		if is_instance_valid(upstream) and upstream.output_changed.is_connected(link[2]):
			upstream.output_changed.disconnect(link[2])
	_wired.clear()


func _rechain() -> void:
	_unwire()
	var previous: Texture2D = source_texture
	var previous_layer: Layer
	for layer in _layers:
		layer.input_tex = previous
		if previous_layer:
			var callable := _on_upstream_changed.bind(layer)
			previous_layer.output_changed.connect(callable)
			_wired.append([previous_layer, layer, callable])
		previous = layer.get_output()
		previous_layer = layer
	# An unchanged input texture object makes the input_tex setter return early, so the
	# layer would never notice that the texture behind it changed size.
	for layer in _layers:
		layer.refresh_size()
	for layer in _layers:
		_queue(layer)
	_emit_final_if_changed()


func _emit_final_if_changed() -> void:
	var current := get_final_texture()
	if current == _last_final:
		return
	_last_final = current
	final_texture_changed.emit(current)
