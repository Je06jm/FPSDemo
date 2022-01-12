extends Spatial


func _ready():
	var mat : Material = $Cylinder.get_surface_material(0)
	$Cylinder.set_surface_material(0, mat.duplicate(true))
	
	mat = $Cylinder001.get_surface_material(0)
	$Cylinder001.set_surface_material(0, mat.duplicate(true))
	
	mat = $Plane004.get_surface_material(0)
	$Plane004.set_surface_material(0, mat.duplicate(true))

func set_indicator(percentage : float):
	$Cylinder.get_surface_material(0).set_shader_param("percentage", percentage)
	$Cylinder001.get_surface_material(0).set_shader_param("percentage", percentage)
	
	if percentage <= 0.0:
		$Plane004.get_surface_material(0).set_shader_param("force_off_color", true)
