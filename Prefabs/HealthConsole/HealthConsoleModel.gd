extends Spatial


func set_indicator(percentage : float):
	$Cylinder.get_surface_material(0).set_shader_param("percentage", percentage)
	$Cylinder001.get_surface_material(0).set_shader_param("percentage", percentage)
	
	if percentage <= 0.0:
		$Plane004.get_surface_material(0).set_shader_param("force_off_color", true)
