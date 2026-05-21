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
var zoom := [1, 2, 0]
var zoom_int = zoom[1]
var screen_size: Vector2
var digits_precision: int = 6
var max_iter: int = 20
var colors: float = 0.5
var infinite_math = InfiniteMath.new()
var snapshot_rect: TextureRect
var rendering_snapshot := false
var fractal_material: ShaderMaterial

const TWO := [1, 2, 0]


@onready var viewport_container := $SubViewportContainer
@onready var subviewport := $SubViewportContainer/SubViewport
@onready var canvas := $SubViewportContainer/SubViewport/ColorRect


func _ready() -> void:
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

	fractal_material.set_shader_parameter("ex", PackedInt32Array(center_box_x))
	fractal_material.set_shader_parameter("ey", PackedInt32Array(center_box_y))
	fractal_material.set_shader_parameter("box_size", PackedInt32Array(box_size))
	fractal_material.set_shader_parameter("ex_size", center_box_x.size())
	fractal_material.set_shader_parameter("ey_size", center_box_y.size())
	fractal_material.set_shader_parameter("box_size_size", box_size.size())
	fractal_material.set_shader_parameter("digits_precision", digits_precision)
	fractal_material.set_shader_parameter("max_iter", max_iter)
	fractal_material.set_shader_parameter("colors", colors)
	await _store_frame()

func _input(event: InputEvent) -> void:
	if rendering_snapshot:
		return
	if event is InputEventMouseButton and event.pressed:
		rendering_snapshot = true
		var mouse_position = event.position
		var mouse_position_array = _mouse_position_to_box_coordinates(mouse_position)
		await zoom_animation(mouse_position)
		update_vertex(mouse_position_array)
		await _store_frame()
		rendering_snapshot = false

func zoom_animation(mouse_position: Vector2):
	var position = screen_size/2.0 - zoom_int * mouse_position
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(snapshot_rect, "scale", zoom_int * snapshot_rect.scale, 1.0)
	tween.tween_property(snapshot_rect, "position", position, 1.0)
	await tween.finished

func _store_frame() -> void:
	snapshot_rect.hide()
	snapshot_rect.scale = Vector2.ONE
	snapshot_rect.position = Vector2.ZERO
	viewport_container.show()
	canvas.show()
	canvas.material = fractal_material
	subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image = subviewport.get_texture().get_image()
	snapshot_rect.texture = ImageTexture.create_from_image(image)
	subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	canvas.material = null
	viewport_container.hide()
	snapshot_rect.show()

func update_vertex(mouse_position_array):
	box_size = infinite_math.float_repr_sub(bx, ax)
	center_box_x = mouse_position_array[0]
	center_box_y = mouse_position_array[1]

	box_size = infinite_math.float_repr_div(box_size, zoom)
	var half_box_size = infinite_math.float_repr_div(box_size, TWO)

	ax = infinite_math.float_repr_sub(center_box_x, half_box_size)
	ay = infinite_math.float_repr_add(center_box_y, half_box_size)
	bx = infinite_math.float_repr_add(center_box_x, half_box_size)
	by = infinite_math.float_repr_add(center_box_y, half_box_size)
	cx = infinite_math.float_repr_sub(center_box_x, half_box_size)
	cy = infinite_math.float_repr_sub(center_box_y, half_box_size)
	dx = infinite_math.float_repr_add(center_box_x, half_box_size)
	dy = infinite_math.float_repr_sub(center_box_y, half_box_size)

	print("box size: ", box_size)
	print("a: ", [infinite_math.array2float(ax),  infinite_math.array2float(ay)])
	print("b: ", [infinite_math.array2float(bx), infinite_math.array2float(by)])
	print("c: ", [infinite_math.array2float(cx), infinite_math.array2float(cy)])
	print("d: ", [infinite_math.array2float(dx), infinite_math.array2float(dy)])
	print("e: ", [infinite_math.array2float(center_box_x), infinite_math.array2float(center_box_y)])

	fractal_material.set_shader_parameter("ex", PackedInt32Array(center_box_x))
	fractal_material.set_shader_parameter("ey", PackedInt32Array(center_box_y))
	fractal_material.set_shader_parameter("box_size", PackedInt32Array(box_size))
	fractal_material.set_shader_parameter("ex_size", center_box_x.size())
	fractal_material.set_shader_parameter("ey_size", center_box_y.size())
	fractal_material.set_shader_parameter("box_size_size", box_size.size())

func _mouse_position_to_box_coordinates(mouse_position: Vector2):
	var mouse_local = snapshot_rect.get_global_transform_with_canvas().affine_inverse() * mouse_position
	var uv := Vector2(mouse_local.x/snapshot_rect.size.x, mouse_local.y/snapshot_rect.size.y)
	var mouse_position_x = infinite_math.float_repr_add(center_box_x, infinite_math.float_repr_mul(box_size, infinite_math.float2array(uv.x - 0.5)))
	var mouse_position_y = infinite_math.float_repr_add(center_box_y, infinite_math.float_repr_mul(box_size, infinite_math.float2array((1.0 - uv.y) - 0.5)))

	return [mouse_position_x, mouse_position_y]
