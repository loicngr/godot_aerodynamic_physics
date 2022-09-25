extends Node

#http://www.braeunig.us/space/atmos.htm

var altitude_values : Dictionary = {
	0: {"temperature": 288.0, "pressure": 101325.0, "density": 1.225, "viscosity": 0.00001812},
	2000: {"temperature": 275.0, "pressure": 79495.2, "density": 1.0065, "viscosity": 0.00001746},
	5000: {"temperature": 255.0, "pressure": 54019.9, "density": 0.7361, "viscosity": 0.00001645},
	10000: {"temperature": 223.0, "pressure": 26436.3, "density": 0.4127, "viscosity": 0.00001645},
	15000: {"temperature": 216.0, "pressure": 12044.6, "density": 0.1937, "viscosity": 0.00001432},
	20000: {"temperature": 216.0, "pressure": 5474.8, "density": 0.08803, "viscosity": 0.00001645},
	30000: {"temperature": 226.0, "pressure": 1171.8, "density": 0.01803, "viscosity": 0.00001432},
	40000: {"temperature": 251.0, "pressure": 277.5, "density": 0.003851, "viscosity": 0.00001621},
	50000: {"temperature": 270.0, "pressure": 75.9, "density": .0009775, "viscosity": 0.00001723},
	60000: {"temperature": 245.0, "pressure": 20.3, "density": .0002883, "viscosity": 0.00001591},
	70000: {"temperature": 217.0, "pressure": 4.6, "density": .00007424, "viscosity": 0.000014367},
	80000: {"temperature": 196.0, "pressure": 0.89, "density": .0000157, "viscosity": 0.000013168},
}

@export var min_altitude : float = 0.0
@export var max_altitude : float = 80000.0

@export var min_mach : float = 0.0
@export var max_mach : float = 10.0

@export var min_density : float = 0.0:
	set(x):
		min_density = x
		update_density_curve()
@export var max_density : float = 100.0:
	set(x):
		max_density = x
		update_density_curve()
@onready var density_at_altitude_curve := Curve.new()
func update_density_curve() -> void:
	density_at_altitude_curve.min_value = min_density
	density_at_altitude_curve.max_value = max_density
func get_density_at_altitude(altitude : float) -> float:
	var lerp : float = altitude_to_lerp(altitude)
	return density_at_altitude_curve.sample(lerp)

@export var min_machspeed : float = 0.0:
	set(x):
		min_machspeed = x
		update_machspeed_curve()
@export var max_machspeed : float = 700.0:
	set(x):
		max_machspeed = x
		update_machspeed_curve()
@onready var mach_at_altitude_curve := Curve.new()
func update_machspeed_curve() -> void:
	mach_at_altitude_curve.min_value = min_machspeed
	mach_at_altitude_curve.max_value = max_machspeed
func get_mach_at_altitude(altitude : float) -> float:
	var lerp : float = altitude_to_lerp(altitude)
	return mach_at_altitude_curve.sample(altitude)


@export var min_pressure : float = 0.0:
	set(x):
		min_pressure = x
		update_pressure_curve()
@export var max_pressure : float = 1000000.0:
	set(x):
		max_pressure = x
		update_pressure_curve()
@onready var pressure_at_altitude_curve := Curve.new()
func update_pressure_curve() -> void:
	pressure_at_altitude_curve.min_value = min_pressure
	pressure_at_altitude_curve.max_value = max_pressure
func get_pressure_at_altitude(altitude : float) -> float:
	var lerp : float = altitude_to_lerp(altitude)
	return pressure_at_altitude_curve.sample(altitude)


@export var min_temperature : float = 100.0:
	set(x):
		min_temperature = x
		update_temperature_curve()
@export var max_temperature : float = 400.0:
	set(x):
		max_temperature = x
		update_temperature_curve()
@onready var temperature_at_altitude_curve := Curve.new()
func update_temperature_curve() -> void:
	temperature_at_altitude_curve.min_value = min_temperature
	temperature_at_altitude_curve.max_value = max_temperature
func get_temp_at_altitude(altitude : float) -> float:
	var lerp : float = altitude_to_lerp(altitude)
	return temperature_at_altitude_curve.sample(altitude)


@export var min_drag_multiplier : float = 0.0:
	set(x):
		min_drag_multiplier = x
		update_drag_curve()
@export var max_drag_multiplier : float = 50.0:
	set(x):
		max_drag_multiplier = x
		update_drag_curve()
@onready var drag_at_mach_multiplier_curve := Curve.new()
func update_drag_curve() -> void:
	drag_at_mach_multiplier_curve.min_value = min_drag_multiplier
	drag_at_mach_multiplier_curve.max_value = max_drag_multiplier
func get_drag_multiplier_at_mach(mach : float) -> float:
	var lerp : float = range_to_lerp(mach, min_mach, max_mach)
	return drag_at_mach_multiplier_curve.sample(lerp)




func _ready() -> void:
	for key in altitude_values.keys():
		var entry : Dictionary = altitude_values[key]
		var altitude_lerp : float = altitude_to_lerp(key)
		
		temperature_at_altitude_curve.add_point(Vector2(altitude_lerp, entry["temperature"]))
		
		var speed_of_sound : float = get_speed_of_sound_at_pressure_and_density(entry["pressure"], entry["density"])
		mach_at_altitude_curve.add_point(Vector2(altitude_lerp, speed_of_sound))
		
		


func altitude_to_lerp(altitude : float) -> float:
	return remap(altitude, min_altitude, max_altitude, 0.0, 1.0)

func lerp_to_altitude(lerp : float) -> float:
	return remap(lerp, 0.0, 1.0, min_altitude, max_altitude)

static func range_to_lerp(value : float, min : float, max : float) -> float:
	return remap(value, min, max, 0.0, 1.0)

func lerp_to_range(lerp : float, min : float, max : float) -> float:
	return remap(lerp, 0.0, 1.0, min, max)

#http://www.sengpielaudio.com/calculator-speedsound.htm
#kelvin
static func get_speed_of_sound_at_pressure_and_density(pressure : float, density : float) -> float:
	return sqrt(1.402 * (pressure / density))

##heavy
#static func get_dynamic_viscosity(sutherland : float, temp : float, reference_temp : float, reference_viscosity : float) -> float:
#	var temp_rankine : float = kelvin_to_rankine(temp)
#	var reference_temp_rankine = kelvin_to_rankine(reference_temp)
#	var reference_viscosity_centipoise : float = reference_viscosity * 1000
#
#	var viscosity_centipoise : float = (reference_viscosity_centipoise * pow(temp_rankine / reference_temp_rankine, 3/2) * (reference_temp_rankine + sutherland)) / (sutherland + temp_rankine)
#	return 1.0

#static func kelvin_to_rankine(kelvin : float) -> float:
#	return kelvin * (9.0/5.0)
