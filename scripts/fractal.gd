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
var tile_size: int = 128
var infinite_math = InfiniteMath.new()
var div_precision: = 100
var snapshot_rect: TextureRect
var rendering_snapshot := false
var fractal_material: ShaderMaterial
var current_render_id := 0
var where_am_i = false
var about = false
var goto = false

@onready var viewport_container := $SubViewportContainer
@onready var subviewport := $SubViewportContainer/SubViewport
@onready var canvas := $SubViewportContainer/SubViewport/ColorRect


func _ready() -> void:
	await _change_resolution()
	tile_size = screen_size[0]
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
	await _store_frame(current_render_id)
	
	tile_size = 128

func _input(event: InputEvent) -> void:
	var hovered = get_viewport().gui_get_hovered_control()

	if hovered != null and hovered != viewport_container:
		return
		
	if where_am_i or about:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		current_render_id += 1
		var my_render_id = current_render_id
		rendering_snapshot = true
		var mouse_position = event.position
		var mouse_position_array = _mouse_position_to_box_coordinates(mouse_position)
		await zoom_animation(mouse_position)
		
		if my_render_id != current_render_id:
			return
			
		update_vertex(mouse_position_array)
		subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await _store_frame(my_render_id)
		
		if my_render_id == current_render_id:
			rendering_snapshot = false
			
func _change_resolution() -> void:
	var res := Vector2(Manager.resolution, Manager.resolution)    
	await get_tree().process_frame
	subviewport.size = res
	canvas.size = res    
	screen_size = get_viewport_rect().size    # always 1024 x 1024

func zoom_animation(mouse_position: Vector2):
	var zoom_position = screen_size/2.0 - zoom_int * mouse_position
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(snapshot_rect, "scale", zoom_int * snapshot_rect.scale, 1.0)
	tween.tween_property(snapshot_rect, "position", zoom_position, 1.0)
	await tween.finished

func _build_preview_image(render_size: Vector2i) -> Image:
	var frame_image := Image.create(render_size.x, render_size.y, false, Image.FORMAT_RGBA8)
	frame_image.fill(Color.BLACK)

	if snapshot_rect.texture == null:
		return frame_image

	var source_image := snapshot_rect.texture.get_image()

	var src_w := source_image.get_width()
	var src_h := source_image.get_height()

	var scale := snapshot_rect.scale
	var position := snapshot_rect.position

	for y in render_size.y:
		for x in render_size.x:
			var screen_pos := Vector2(x, y)

			# Inverte a transformação aplicada pelo tween
			var coord_scale := float(render_size.x) / float(screen_size.x)
			var uv := (screen_pos - position * coord_scale) / scale
			var sx := int(uv.x)
			var sy := int(uv.y)
 
			if sx >= 0 and sx < src_w and sy >= 0 and sy < src_h:
				frame_image.set_pixel(x, y, source_image.get_pixel(sx, sy))

	return frame_image

func _store_frame(render_id: int) -> void:
	var render_size: Vector2i = subviewport.size
	var frame_image := _build_preview_image(render_size)

	snapshot_rect.scale = Vector2.ONE
	snapshot_rect.position = Vector2.ZERO
	snapshot_rect.texture = ImageTexture.create_from_image(frame_image)
	snapshot_rect.show()
	
	viewport_container.show()
	
	canvas.show()
	canvas.material = fractal_material
	
	fractal_material.set_shader_parameter("viewport_size", Vector2(subviewport.size))

	for tile_y in range(0, render_size.y, tile_size):
		for tile_x in range(0, render_size.x, tile_size):
			if render_id != current_render_id:
				return
			var tile_width = min(tile_size, render_size.x - tile_x)
			var tile_height = min(tile_size, render_size.y - tile_y)
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
	fractal_material.set_shader_parameter("digits_precision", digits_precision)
	fractal_material.set_shader_parameter("max_iter", max_iter)
	fractal_material.set_shader_parameter("colors", colors)
	fractal_material.set_shader_parameter("viewport_size", Vector2(subviewport.size))

func update_vertex(mouse_position_array):
	box_size = infinite_math.float_repr_sub(bx, ax)
	center_box_x = mouse_position_array[0]
	center_box_y = mouse_position_array[1]
	box_size = infinite_math.float_repr_div(box_size, zoom, div_precision)
	var half_box_size = infinite_math.float_repr_div(box_size, [1, 2, 0], div_precision)

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
		tile_size = 128
		fractal_material.shader = load("res://resources/materials/fractal_8.gdshader")
	elif index == 1:
		digits_precision = 28
		tile_size = 64
		fractal_material.shader = load("res://resources/materials/fractal_16.gdshader")
	elif index == 2:
		digits_precision = 44
		tile_size = 32
		fractal_material.shader = load("res://resources/materials/fractal_25.gdshader")

	_set_fractal_shader_parameters()
	await _store_frame(my_render_id)

func _on_zoom_item_selected(index: int) -> void:
	var value = (
		1 if index == 0
		else 2 if index == 1
		else 5 if index == 2
		else 10 if index == 3
		else 20 if index == 4
		else 100
	)
	zoom = [1, value, 0]
	zoom_int = zoom[1]

func _on_max_iter_item_selected(index: int) -> void:
	max_iter = (
		10 if index == 0
		else 100 if index == 1
		else 500 if index == 2
		else 1000 if index == 3
		else 1500
	)
	
	current_render_id += 1
	var my_render_id = current_render_id
	
	_set_fractal_shader_parameters()
	await _store_frame(my_render_id)

func _on_where_am_i_pressed() -> void:
	if not about and not goto:
		if not where_am_i:
			where_am_i = true
			snapshot_rect.modulate = Color(0.05, 0.05, 0.05)
			$HUD/WhereAmI/Sprite2D.show()
			$HUD/WhereAmI/Sprite2D/X.text = str(infinite_math.array2string(ax))
			$HUD/WhereAmI/Sprite2D/Y.text = str(infinite_math.array2string(ay))
			$HUD/WhereAmI/Sprite2D/L.text = str(infinite_math.array2string(box_size))
		else:
			where_am_i = false
			snapshot_rect.modulate = Color(1.0, 1.0, 1.0)
			$HUD/WhereAmI/Sprite2D.hide()

func _on_about_pressed() -> void:
	if not where_am_i and not goto:
		if not about:
			about = true
			snapshot_rect.modulate = Color(0.3, 0.3, 0.3)
			$HUD/About/RichTextLabel.show()
			$HUD/About/Sprite2D.show()
		else:
			about = false
			snapshot_rect.modulate = Color(1.0, 1.0, 1.0)
			$HUD/About/RichTextLabel.hide()
			$HUD/About/Sprite2D.hide()

func _on_go_to_pressed() -> void:
	if not where_am_i and not about:
		if not goto:
			goto = true
			snapshot_rect.modulate = Color(0.3, 0.3, 0.3)
			$HUD/GoTo/LineEditX.show()
			$HUD/GoTo/LineEditY.show()
			$HUD/GoTo/LineEditL.show()
			$HUD/GoTo/Submit.show()
		else:
			goto = false
			snapshot_rect.modulate = Color(1.0, 1.0, 1.0)
			$HUD/GoTo/LineEditX.hide()
			$HUD/GoTo/LineEditY.hide()
			$HUD/GoTo/LineEditL.hide()
			$HUD/GoTo/Submit.hide()
	
func _on_submit_pressed() -> void:
	var x_value = infinite_math.string2array($HUD/GoTo/LineEditX.text)
	var y_value = infinite_math.string2array($HUD/GoTo/LineEditY.text)
	var l_value = infinite_math.string2array($HUD/GoTo/LineEditL.text)
	var half_l = infinite_math.float_repr_div(l_value, [1, 2, 0], div_precision)

	center_box_x = infinite_math.float_repr_add(x_value, half_l)
	center_box_y = infinite_math.float_repr_sub(y_value, half_l)
	box_size = l_value

	ax = x_value
	ay = y_value
	bx = infinite_math.float_repr_add(x_value, l_value)
	#by = y_value
	#cx = x_value
	#cy = infinite_math.float_repr_sub(y_value, l_value)
	#dx = infinite_math.float_repr_add(x_value, l_value)
	#dy = infinite_math.float_repr_sub(y_value, l_value)

	_set_fractal_shader_parameters()

	current_render_id += 1
	var my_render_id = current_render_id
	rendering_snapshot = true

	if my_render_id == current_render_id:
		rendering_snapshot = false
		goto = false
		snapshot_rect.modulate = Color(1.0, 1.0, 1.0)
		$HUD/GoTo/LineEditX.hide()
		$HUD/GoTo/LineEditY.hide()
		$HUD/GoTo/LineEditL.hide()
		$HUD/GoTo/Submit.hide()
	
		await _store_frame(my_render_id)
