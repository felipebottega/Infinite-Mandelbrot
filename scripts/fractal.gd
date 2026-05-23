extends Node2D


var ax := [1, -2, 0]
var ay := [1, 2, 0]
var bx := [1, 2, 0]
var by := [1, 2, 0]
var cx := [1, -2, 0]
var cy := [1, -2, 0]
var dx := [1, 2, 0]
var dy := [1, -2, 0]
var center_box_x := [1, 0, 0]
var center_box_y := [1, 0, 0]
var box_size := [1, 4, 0]
var zoom := [1, 10, 0]
var zoom_int = zoom[1]
var screen_size: Vector2
var digits_precision: int = 8
var max_iter: int = 100
var colors: float = 0.5
var infinite_math = InfiniteMath.new()
var div_precision: = 100
var snapshot_rect: TextureRect
var rendering_snapshot := false
var fractal_material: ShaderMaterial
var current_render_id := 0
var where_am_i = false
var about = false

const TILE_SIZE := 50

@onready var viewport_container := $SubViewportContainer
@onready var subviewport := $SubViewportContainer/SubViewport
@onready var canvas := $SubViewportContainer/SubViewport/ColorRect


func _ready() -> void:
	$HUD/Version.text ="v" + ProjectSettings.get_setting("application/config/version")
	screen_size = get_viewport_rect().size
	canvas.show()
	fractal_material = canvas.material

	snapshot_rect = TextureRect.new()
	snapshot_rect.size = screen_size
	snapshot_rect.stretch_mode = TextureRect.STRETCH_SCALE
	snapshot_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	snapshot_rect.z_index = 100
	add_child(snapshot_rect)
	subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	_set_fractal_shader_parameters()
	fractal_material.set_shader_parameter("digits_precision", digits_precision)
	fractal_material.set_shader_parameter("max_iter", max_iter)
	fractal_material.set_shader_parameter("colors", colors)
	fractal_material.set_shader_parameter("viewport_size", Vector2(subviewport.size))
	await _store_frame(current_render_id)

func _input(event: InputEvent) -> void:
	var hovered = get_viewport().gui_get_hovered_control()

	if hovered != null and hovered != viewport_container:
		return
		
	if where_am_i or about:
		return
		
	if event is InputEventMouseButton and event.pressed:
		current_render_id += 1
		var my_render_id = current_render_id
		rendering_snapshot = true
		var mouse_position = event.position
		var mouse_position_array = _mouse_position_to_box_coordinates(mouse_position)
		await zoom_animation(mouse_position)
		
		if my_render_id != current_render_id:
			return
			
		update_vertex(mouse_position_array)
		await _store_frame(my_render_id)
		
		if my_render_id == current_render_id:
			rendering_snapshot = false

func zoom_animation(mouse_position: Vector2):
	var zoom_position = screen_size/2.0 - zoom_int * mouse_position
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(snapshot_rect, "scale", zoom_int * snapshot_rect.scale, 1.0)
	tween.tween_property(snapshot_rect, "position", zoom_position, 1.0)
	await tween.finished

func _build_preview_image(render_size: Vector2i) -> Image:
	var frame_image := Image.create(render_size.x, render_size.y, false, Image.FORMAT_RGBA8)
	frame_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	
	if snapshot_rect.texture == null:
		return frame_image
		
	var source_image := snapshot_rect.texture.get_image()
	var source_size: Vector2i = source_image.get_size()
	
	for y in range(render_size.y):
		for x in range(render_size.x):
			var source_x := int(floor((float(x) - snapshot_rect.position.x) / snapshot_rect.scale.x))
			var source_y := int(floor((float(y) - snapshot_rect.position.y) / snapshot_rect.scale.y))
			if source_x >= 0 and source_x < source_size.x and source_y >= 0 and source_y < source_size.y:
				frame_image.set_pixel(x, y, source_image.get_pixel(source_x, source_y))
				
	return frame_image

func _shader_repr(value: Array) -> Array:
	var decimal_pos := int(value[0])
	var digits := []
	var number_sign := 1

	for i in range(1, value.size()):
		var d := int(value[i])
		if d < 0:
			number_sign = -1
			d = -d
		digits.append(d)

	if digits.is_empty():
		return [1, 0]

	while digits.size() < decimal_pos:
		digits.append(0)

	var int_digits := digits.slice(0, decimal_pos)
	var frac_digits := digits.slice(decimal_pos)

	if int_digits.is_empty():
		int_digits = [0]

	while int_digits.size() % 4 != 0:
		int_digits.push_front(0)

	var int_limbs := []

	for i in range(0, int_digits.size(), 4):
		int_limbs.append(int_digits[i] * 1000 + int_digits[i + 1] * 100 + int_digits[i + 2] * 10 + int_digits[i + 3])

	while int_limbs.size() > 1 and int_limbs[0] == 0:
		int_limbs.remove_at(0)

	while frac_digits.size() > 0 and frac_digits.size() % 4 != 0:
		frac_digits.append(0)

	var frac_limbs := []

	for i in range(0, frac_digits.size(), 4):
		frac_limbs.append(frac_digits[i] * 1000 + frac_digits[i + 1] * 100 + frac_digits[i + 2] * 10 + frac_digits[i + 3])

	while frac_limbs.size() > 0 and frac_limbs[frac_limbs.size() - 1] == 0:
		frac_limbs.pop_back()

	var limbs := int_limbs + frac_limbs
	var all_zero := true

	for i in range(limbs.size()):
		if limbs[i] != 0:
			all_zero = false
			break

	if all_zero:
		return [1, 0]

	if number_sign < 0:
		for i in range(limbs.size()):
			if limbs[i] != 0:
				limbs[i] = -limbs[i]
				break

	var repr := [int_limbs.size()]
	repr.append_array(limbs)

	return repr

func _set_fractal_shader_parameters() -> void:
	var ex_repr := _shader_repr(center_box_x)
	var ey_repr := _shader_repr(center_box_y)
	var box_size_repr := _shader_repr(box_size)
	
	fractal_material.set_shader_parameter("ex", PackedInt32Array(ex_repr))
	fractal_material.set_shader_parameter("ey", PackedInt32Array(ey_repr))
	fractal_material.set_shader_parameter("box_size", PackedInt32Array(box_size_repr))
	fractal_material.set_shader_parameter("ex_size", ex_repr.size())
	fractal_material.set_shader_parameter("ey_size", ey_repr.size())
	fractal_material.set_shader_parameter("box_size_size", box_size_repr.size())

func _store_frame(render_id: int) -> void:
	var render_size: Vector2i = subviewport.size
	var frame_image := _build_preview_image(render_size)

	snapshot_rect.scale = Vector2.ONE
	snapshot_rect.position = Vector2.ZERO
	viewport_container.show()
	canvas.show()
	canvas.material = fractal_material
	fractal_material.set_shader_parameter("viewport_size", Vector2(subviewport.size))
	snapshot_rect.texture = ImageTexture.create_from_image(frame_image)
	snapshot_rect.show()

	for tile_y in range(0, render_size.y, TILE_SIZE):
		for tile_x in range(0, render_size.x, TILE_SIZE):
			if render_id != current_render_id:
				return
			var tile_width = min(TILE_SIZE, render_size.x - tile_x)
			var tile_height = min(TILE_SIZE, render_size.y - tile_y)
			fractal_material.set_shader_parameter("tile_origin", Vector2(tile_x, tile_y))
			fractal_material.set_shader_parameter("tile_size", Vector2(tile_width, tile_height))
			subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			
			if render_id != current_render_id:
				return
			
			var tile_image = subviewport.get_texture().get_image()
			var tile_rect := Rect2i(tile_x, tile_y, tile_width, tile_height)
			frame_image.blit_rect(tile_image, tile_rect, Vector2i(tile_x, tile_y))
			snapshot_rect.texture = ImageTexture.create_from_image(frame_image)
			await get_tree().process_frame

	if render_id == current_render_id:
		subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		canvas.material = null
		viewport_container.hide()

func update_vertex(mouse_position_array):
	box_size = infinite_math.float_repr_sub(bx, ax)
	center_box_x = mouse_position_array[0]
	center_box_y = mouse_position_array[1]

	box_size = infinite_math.float_repr_div(box_size, zoom, div_precision)
	var half_box_size = infinite_math.float_repr_div(box_size, [1, 2, 0], div_precision)
	print(str(infinite_math.array2string(box_size)), ': ', box_size)

	ax = infinite_math.float_repr_sub(center_box_x, half_box_size)
	ay = infinite_math.float_repr_add(center_box_y, half_box_size)
	bx = infinite_math.float_repr_add(center_box_x, half_box_size)
	#by = infinite_math.float_repr_add(center_box_y, half_box_size)
	#cx = infinite_math.float_repr_sub(center_box_x, half_box_size)
	#cy = infinite_math.float_repr_sub(center_box_y, half_box_size)
	#dx = infinite_math.float_repr_add(center_box_x, half_box_size)
	#dy = infinite_math.float_repr_sub(center_box_y, half_box_size)

	_set_fractal_shader_parameters()

func _mouse_position_to_box_coordinates(mouse_position: Vector2):
	var mouse_local = snapshot_rect.get_global_transform_with_canvas().affine_inverse() * mouse_position
	var uv = (mouse_local + Vector2(0.5, 0.5)) / snapshot_rect.size
	var mouse_position_x = infinite_math.float_repr_add(center_box_x, infinite_math.float_repr_mul(box_size, infinite_math.float2array(uv.x - 0.5)))
	var mouse_position_y = infinite_math.float_repr_add(center_box_y, infinite_math.float_repr_mul(box_size, infinite_math.float2array((1.0 - uv.y) - 0.5)))

	return [mouse_position_x, mouse_position_y]

func _on_precision_item_selected(index: int) -> void:
	current_render_id += 1
	var my_render_id = current_render_id
	
	if index == 0:
		digits_precision = 8
		fractal_material.shader = load("res://resources/materials/fractal_8.gdshader")
	elif index == 1:
		digits_precision = 28
		fractal_material.shader = load("res://resources/materials/fractal_16.gdshader")
	elif index == 2:
		digits_precision = 44
		fractal_material.shader = load("res://resources/materials/fractal_25.gdshader")

	fractal_material.set_shader_parameter("digits_precision", digits_precision)
	fractal_material.set_shader_parameter("max_iter", max_iter)
	fractal_material.set_shader_parameter("colors", colors)
	_set_fractal_shader_parameters()
	await _store_frame(my_render_id)

func _on_zoom_item_selected(index: int) -> void:
	var value = (
		2 if index == 0
		else 5 if index == 1
		else 10 if index == 2
		else 20 if index == 3
		else 100
	)
	zoom = [1, value, 0]
	zoom_int = zoom[1]

func _on_max_iter_value_changed(value: float) -> void:
	max_iter = int(value)
	$HUD/MaxIter/Label.text = "Max Iter = " + str(max_iter)
	current_render_id += 1
	var my_render_id = current_render_id
	
	fractal_material.set_shader_parameter("max_iter", max_iter)
	_set_fractal_shader_parameters()
	await _store_frame(my_render_id)

func _on_where_am_i_pressed() -> void:
	if not about:
		if not where_am_i:
			where_am_i = true
			snapshot_rect.modulate = Color(0.3, 0.3, 0.3)
			$HUD/WhereAmI/Sprite2D.show()
			$HUD/WhereAmI/Sprite2D/X.text = str(infinite_math.array2string(ax))
			$HUD/WhereAmI/Sprite2D/Y.text = str(infinite_math.array2string(ay))
			$HUD/WhereAmI/Sprite2D/L.text = str(infinite_math.array2string(box_size))
		else:
			where_am_i = false
			snapshot_rect.modulate = Color(1.0, 1.0, 1.0)
			$HUD/WhereAmI/Sprite2D.hide()

func _on_about_pressed() -> void:
	if not where_am_i:
		if not about:
			about = true
			snapshot_rect.modulate = Color(0.2, 0.2, 0.2)
			$HUD/About/RichTextLabel.show()
		else:
			about = false
			snapshot_rect.modulate = Color(1.0, 1.0, 1.0)
			$HUD/About/RichTextLabel.hide()
