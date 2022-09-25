@tool
extends Node3D
class_name AeroSurface3D

enum {Pitch, Yaw, Roll, Flap}

var config : AeroSurfaceConfig = AeroSurfaceConfig.new(6.28, 0.02, -3.0, 15.0, -15.0, 1.57, 0.2, 2.1, 0, 7)
func update_config() -> void:
	config = AeroSurfaceConfig.new(lift_slope, skin_friction, zero_lift_aoa, stall_angle_high, stall_angle_low, chord, flap_fraction, span, auto_aspect_ratio, aspect_ratio)
	update_gizmos()
var is_control_surface : bool = false
@export_group("Wing Properties")
@export var auto_aspect_ratio : bool = true :
	set(value):
		auto_aspect_ratio = value
		update_config()
@export var aspect_ratio : float = 2.0 :
	set(value):
		aspect_ratio = value
		update_config()
@export var chord : float = 1.0 : 
	set(value):
		chord = max(value, 0.001)
		update_config()
@export var flap_angle : float = 0.0 :
	set(value):
		flap_angle = clamp(value, -deg_to_rad(50.0), deg_to_rad(50.0))
		update_config()
@export var flap_fraction : float = 0.0 :
	set(value):
		flap_fraction = clamp(value, 0.0, 0.4)
		update_config()
@export var lift_slope : float = 6.28 :
	set(value):
		lift_slope = value
		update_config()
@export var skin_friction : float = 0.02 :
	set(value):
		skin_friction = value
		update_config()
@export var span : float = 1.0 :
	set(value):
		span = value
		update_config()
@export var stall_angle_high : float = 15.0 :
	set(value):
		stall_angle_high = max(value, 0.0)
		update_config()
@export var stall_angle_low : float = -15.0 :
	set(value):
		stall_angle_low = min(value, 0.0)
		update_config()
@export var zero_lift_aoa : float = 0.0 :
	set(value):
		zero_lift_aoa = value
		update_config()

@export_group("Curves")

@export var use_curves : bool = false
@export var lift_curve : Curve
@export var drag_curve : Curve
@export var buffet_curve : Curve

@export_group("")

var _current_lift : Vector3
var _current_drag : Vector3
var _current_torque : Vector3

func calculate_forces(world_air_velocity : Vector3, air_density : float, relative_position : Vector3) -> PackedVector3Array:
	var force := Vector3.ZERO
	var torque := Vector3.ZERO
	
	var corrected_lift_slope = config.lift_slope * config.aspect_ratio / (config.aspect_ratio + 2.0 * (config.aspect_ratio + 4.0) / (config.aspect_ratio + 2.0))
	var theta : float = acos(2.0 * config.flap_fraction - 1.0)
	var flap_effectiveness : float = 1.0 - (theta - sin(theta)) / PI
	var delta_lift : float = corrected_lift_slope * flap_effectiveness * flap_effectiveness_correction(flap_angle) * flap_angle
	var zero_lift_aoa_base : float = deg_to_rad(config.zero_lift_aoa)
	var zero_lift_aoa : float = zero_lift_aoa_base - delta_lift / corrected_lift_slope
	var stall_angle_high_base : float = deg_to_rad(config.stall_angle_high)
	var stall_angle_low_base : float = deg_to_rad(config.stall_angle_low)
	var cl_max_high : float = corrected_lift_slope * (stall_angle_high_base - zero_lift_aoa_base) + delta_lift * lift_coefficient_max_friction(config.flap_fraction)
	var cl_max_low : float = corrected_lift_slope * (stall_angle_low_base - zero_lift_aoa_base) + delta_lift * lift_coefficient_max_friction(config.flap_fraction)
	var stall_angle_high = zero_lift_aoa + cl_max_high / corrected_lift_slope
	var stall_angle_low = zero_lift_aoa + cl_max_low / corrected_lift_slope
	
	#Calculating air velocity relative to the surface's coordinate system.
	var air_velocity : Vector3 = global_transform.basis.inverse() * world_air_velocity
	
	air_velocity = Vector3(0.0, air_velocity.y, air_velocity.z)
	var drag_direction : Vector3 = global_transform.basis * (air_velocity.normalized())
	var lift_direction : Vector3 = drag_direction.cross(-global_transform.basis.x)
	
	var area : float = config.chord * config.span
	var dynamic_pressure : float = 0.5 * air_density * air_velocity.length_squared()
	
	var angle_of_attack : float = atan2(air_velocity.y, -air_velocity.z)
	
	var aerodynamic_coefficients : Vector3 = calculate_coefficients(angle_of_attack, corrected_lift_slope, zero_lift_aoa, stall_angle_high, stall_angle_low)
	
	var lift : Vector3 = lift_direction * aerodynamic_coefficients.x * dynamic_pressure * area
	var drag : Vector3 = drag_direction * aerodynamic_coefficients.y * dynamic_pressure * area
	var _torque : Vector3 = global_transform.basis.x * aerodynamic_coefficients.z * dynamic_pressure * area * config.chord
	
	force = lift + drag
	torque += relative_position.cross(force)
	torque += _torque
	
	_current_lift = lift
	_current_drag = drag
	_current_torque = torque
	
	return PackedVector3Array([force, torque])

func flap_effectiveness_correction(flap_angle : float = 0.0) -> float:
	return lerp(0.8, 0.4, (rad_to_deg(abs(flap_angle)) - 10.0) / 50.0)

func lift_coefficient_max_friction(fraction : float = 0.0) -> float:
	return clamp(1.0 - 0.5 * (fraction - 0.1) / 0.3, 0, 1)

func calculate_coefficients(angle_of_attack : float, corrected_lift_slope : float, zero_lift_aoa : float, stall_angle_high : float, stall_angle_low : float) -> Vector3:
	var aerodynamic_coefficients : Vector3
	
	var padding_angle_high : float = deg_to_rad(lerp(15.0, 5.0, rad_to_deg(flap_angle + 50.0) / 100.0))
	var padding_angle_low : float = deg_to_rad(lerp(15.0, 5.0, -rad_to_deg(flap_angle + 50.0) / 100.0))
	var padded_stall_angle_high : float = stall_angle_high + padding_angle_high
	var padded_stall_angle_low : float = stall_angle_low + padding_angle_low
	
	if angle_of_attack < stall_angle_high and angle_of_attack > stall_angle_low:
		#low angle of attack mode
		aerodynamic_coefficients = calculate_coefficients_at_low_aoa(angle_of_attack, corrected_lift_slope, zero_lift_aoa)
	else:
		if angle_of_attack > padded_stall_angle_high or angle_of_attack < padded_stall_angle_low:
			#stall mode
			aerodynamic_coefficients = calculate_coefficients_at_stall(angle_of_attack, corrected_lift_slope, zero_lift_aoa, stall_angle_high, stall_angle_low)
		else:
			#Linear stitching in-between stall and low angles of attack modes.
			var aerodynamic_coefficients_low : Vector3
			var aerodynamic_coefficients_stall : Vector3
			var lerp_param : float
			
			if angle_of_attack > stall_angle_high:
				aerodynamic_coefficients_low = calculate_coefficients_at_low_aoa(stall_angle_high, corrected_lift_slope, zero_lift_aoa)
				aerodynamic_coefficients_stall = calculate_coefficients_at_stall(padded_stall_angle_high, corrected_lift_slope, zero_lift_aoa, stall_angle_high, stall_angle_low)
				lerp_param = (angle_of_attack - stall_angle_high) / (padded_stall_angle_high - stall_angle_high)
			else:
				aerodynamic_coefficients_low = calculate_coefficients_at_low_aoa(stall_angle_low, corrected_lift_slope, zero_lift_aoa)
				aerodynamic_coefficients_stall = calculate_coefficients_at_stall(padded_stall_angle_low, corrected_lift_slope, zero_lift_aoa, stall_angle_high, stall_angle_low)
				lerp_param = (angle_of_attack - stall_angle_low) / (padded_stall_angle_low - stall_angle_low)
			
			aerodynamic_coefficients = aerodynamic_coefficients_low.lerp(aerodynamic_coefficients_stall, lerp_param)
	
	return aerodynamic_coefficients

func calculate_coefficients_at_low_aoa(angle_of_attack : float, corrected_lift_slope : float, zero_lift_aoa : float) -> Vector3:
	var lift_coefficient : float = corrected_lift_slope * (angle_of_attack - zero_lift_aoa)
	var induced_angle : float = lift_coefficient / (PI * config.aspect_ratio)
	var effective_angle : float = angle_of_attack - zero_lift_aoa - induced_angle
	
	var sin_effective : float = sin(effective_angle)
	var cos_effective : float = cos(effective_angle)
	
	var tangential_coefficient : float = config.skin_friction * cos_effective
	var normal_coefficient : float = (lift_coefficient + sin_effective * tangential_coefficient) / cos_effective
	
	var drag_coefficient : float = normal_coefficient * sin_effective + tangential_coefficient * cos_effective
	var torque_coefficient : float = -normal_coefficient * torque_coefficient_proportion(effective_angle)
	
	return Vector3(lift_coefficient, drag_coefficient, torque_coefficient)

func calculate_coefficients_at_stall(angle_of_attack : float, corrected_lift_slope : float, zero_lift_aoa : float, stall_angle_high : float, stall_angle_low : float) -> Vector3:
	var lift_coefficient_low_aoa : float
	
	if angle_of_attack > stall_angle_high:
		lift_coefficient_low_aoa = corrected_lift_slope * (stall_angle_high - zero_lift_aoa)
	else:
		lift_coefficient_low_aoa = corrected_lift_slope * (stall_angle_low - zero_lift_aoa)
	
	var induced_angle : float = lift_coefficient_low_aoa / (PI * config.aspect_ratio)
	
	var lerp_param : float
	var half_pi : float = PI / 2.0
	if angle_of_attack > stall_angle_high:
		lerp_param = (half_pi - clamp(angle_of_attack, -half_pi, half_pi)) / (half_pi - stall_angle_high)
	else:
		lerp_param = (-half_pi - clamp(angle_of_attack, -half_pi, half_pi)) / (-half_pi - stall_angle_low)
	
	induced_angle = lerp(0.0, induced_angle, lerp_param)
	
	var effective_angle : float = angle_of_attack - zero_lift_aoa - induced_angle
	
	var sin_effective : float = sin(effective_angle)
	var cos_effective : float = cos(effective_angle)
	
	var normal_coefficient : float = friction_at_90_degrees(flap_angle) * sin_effective * (1.0 / (0.56 + 0.44 * abs(sin_effective)) - 0.41 * (1.0 - exp(-17.0 / config.aspect_ratio)))
	var tangential_coefficient : float = 0.5 * config.skin_friction * cos_effective
	
	var lift_coefficient : float = normal_coefficient * cos_effective - tangential_coefficient * sin_effective
	var drag_coefficient : float = normal_coefficient * sin_effective + tangential_coefficient * cos_effective
	var torque_coefficient : float = -normal_coefficient * torque_coefficient_proportion(effective_angle)
	
	return Vector3(lift_coefficient, drag_coefficient, torque_coefficient)

func friction_at_90_degrees(flap_angle : float) -> float:
	return 1.98 - 0.0426 * flap_angle * flap_angle + 0.21 * flap_angle

func torque_coefficient_proportion(effective_angle : float) -> float:
	return 0.25 - 0.175 * (1.0 - 2.0 * abs(effective_angle) / PI)

func update_debug_vectors() -> void:
	pass
