extends CSGSphere
class_name NavigationNode
tool

enum Type {
	NONE = 0,
	COVER = 1,
	PATROL = 2,
	PATROL_AREA = 3
}

const _colors = [
	Color(1.0, 0.0, 0.0),
	Color(0.0, 0.5529, 1.0),
	Color(0.5, 0.0, 1.0)
]

export(Type) var type : int = Type.COVER setget _set_type, _get_type
export var wait_time := 1.0
export var wait_time_random := 0.5
export var is_loop := false
export var start_reversed := false
export var is_visible := false

export(String, FILE, "*.tres") var node_material := ""
onready var base_material = load(node_material)

func get_point_away_from(pos : Vector3) -> Vector3:
	var direction := global_transform.origin - pos
	direction = direction.normalized()
	var point = global_transform.origin + direction * radius
	return point

func get_random_point() -> Vector3:
	var random := Vector3.ZERO
	var angle := randf() * 2.0 * PI
	random.x = cos(angle) * radius
	random.z = sin(angle) * radius
	random = global_transform.origin + random
	return random

func _ready():
	material = base_material.duplicate(true)
	if (not Engine.editor_hint) and (not is_visible):
		visible = false
	
	_set_type(type)

func _set_type(t : int):
	type = t
	if t == 0:
		return
	
	var mat : SpatialMaterial = material
	mat.albedo_color = _colors[t - 1]
	mat.albedo_color.a = 0.3058
	
func _get_type() -> int:
	return type
