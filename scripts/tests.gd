extends Node2D


var ax := [1, -2, 0]
var ay := [1, 2, 0]
var bx := [1, 2, 0]
var by := [1, 2, 0]
var cx := [1, -2, 0]
var cy := [1, -2, 0]
var dx := [1, 2, 0]
var dy := [1, -2, 0]
var zoom := [1, 2, 0]
var zoom_int = zoom[1]
var screen_size: Vector2
var box_size: float
var infinite_math = InfiniteMath.new()

const TWO := [1, 2, 0]

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	screen_size = get_viewport_rect().size
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_position = get_global_mouse_position()
		zoom_animation(mouse_position)
		update_vertex(mouse_position)
	
func zoom_animation(mouse_position: Vector2):
	var position = screen_size/2.0 - mouse_position
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", zoom_int * sprite.scale, 1.0)
	tween.tween_property(sprite, "position", sprite.position + zoom_int * position, 1.0)
	
func update_vertex(mouse_position: Vector2):
	# Box translation.
	box_size = infinite_math.array2float(infinite_math.float_repr_sub(bx, ax))
	mouse_position = _mouse_position_to_box_coordinates(mouse_position)
	var mouse_position_x = infinite_math.float2array(mouse_position.x)
	var mouse_position_y = infinite_math.float2array(mouse_position.y)
	var center_box_x = infinite_math.float_repr_div(infinite_math.float_repr_add(ax, bx), TWO)
	var center_box_y = infinite_math.float_repr_div(infinite_math.float_repr_add(ay, cy), TWO)
	var delta_x = infinite_math.float_repr_sub(mouse_position_x, center_box_x)
	var delta_y = infinite_math.float_repr_sub(mouse_position_y, center_box_y)
	
	ax = infinite_math.float_repr_add(ax, delta_x)
	ay = infinite_math.float_repr_add(ay, delta_y)
	bx = infinite_math.float_repr_add(bx, delta_x)
	by = infinite_math.float_repr_add(by, delta_y)
	cx = infinite_math.float_repr_add(cx, delta_x)
	cy = infinite_math.float_repr_add(cy, delta_y)
	dx = infinite_math.float_repr_add(dx, delta_x)
	dy = infinite_math.float_repr_add(dy, delta_y)
	
	# Box zoom.
	ax = infinite_math.float_repr_div(ax, zoom)
	ay = infinite_math.float_repr_div(ay, zoom)
	bx = infinite_math.float_repr_div(bx, zoom)
	by = infinite_math.float_repr_div(by, zoom)
	cx = infinite_math.float_repr_div(cx, zoom)
	cy = infinite_math.float_repr_div(cy, zoom)
	dx = infinite_math.float_repr_div(dx, zoom)
	dy = infinite_math.float_repr_div(dy, zoom)
	box_size = infinite_math.array2float(infinite_math.float_repr_sub(bx, ax))
	
	print("box size: ", box_size)
	print("a: ", [infinite_math.array2float(ax),  infinite_math.array2float(ay)])
	print("b: ", [infinite_math.array2float(bx), infinite_math.array2float(by)])
	print("c: ", [infinite_math.array2float(cx), infinite_math.array2float(cy)])
	print("d: ", [infinite_math.array2float(dx), infinite_math.array2float(dy)])
	
func _mouse_position_to_box_coordinates(mouse_position: Vector2) -> Vector2:
	mouse_position.y = screen_size.y - mouse_position.y
	mouse_position.x = box_size * (mouse_position.x/screen_size.x - 0.5)
	mouse_position.y = box_size * (mouse_position.y/screen_size.y - 0.5)
	
	return mouse_position
	
