# player_profile.gd
# Autoload (Singleton) para gestionar el perfil del jugador, su economía y guardado de datos.
extends Node

const SAVE_PATH = "user://save_data.cfg"

# Señales para notificar al HUD u otros componentes de cambios en el estado
signal credits_changed(new_credits: int)
signal fans_changed(new_fans: int)
signal stage_up(new_stage: int)

# Variables principales con setters para emitir señales y autoguardado
var credits: int = 0:
	set(value):
		credits = value
		credits_changed.emit(credits)
		save_data()

var fans: int = 0:
	set(value):
		fans = value
		fans_changed.emit(fans)
		_check_stage_up()
		save_data()

var festival_stage: int = 1:
	set(value):
		if value != festival_stage:
			festival_stage = value
			stage_up.emit(festival_stage)
			save_data()

var owned_cars: Array[String] = ["seat_ibiza"]
var current_car: String = "seat_ibiza"
var accolades_completed: Array[String] = []
var unlocked_zones: Array[String] = ["Zone_Palma"]

func _ready() -> void:
	load_data()

## Añade créditos a la cuenta del jugador.
func add_credits(amount: int) -> void:
	credits += amount

## Añade fans e incrementa el prestigio.
func add_fans(amount: int) -> void:
	fans += amount

# Comprueba si el jugador ha subido de nivel de Festival
func _check_stage_up() -> void:
	# Límites de fans para cada nivel de festival
	var thresholds = [0, 5000, 15000, 35000, 70000, 120000]
	var target_stage = 1
	for i in range(thresholds.size()):
		if fans >= thresholds[i]:
			target_stage = i + 1
	
	if target_stage > festival_stage:
		festival_stage = target_stage

## Guarda el estado del jugador en un archivo de configuración local.
func save_data() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("player", "credits", credits)
	cfg.set_value("player", "fans", fans)
	cfg.set_value("player", "festival_stage", festival_stage)
	cfg.set_value("player", "owned_cars", owned_cars)
	cfg.set_value("player", "current_car", current_car)
	cfg.set_value("player", "accolades_completed", accolades_completed)
	cfg.set_value("player", "unlocked_zones", unlocked_zones)
	cfg.save(SAVE_PATH)

## Carga el estado del jugador desde el almacenamiento local.
func load_data() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		credits = cfg.get_value("player", "credits", 0)
		fans = cfg.get_value("player", "fans", 0)
		festival_stage = cfg.get_value("player", "festival_stage", 1)
		owned_cars = cfg.get_value("player", "owned_cars", ["seat_ibiza"])
		current_car = cfg.get_value("player", "current_car", "seat_ibiza")
		accolades_completed = cfg.get_value("player", "accolades_completed", [])
		unlocked_zones = cfg.get_value("player", "unlocked_zones", ["Zone_Palma"])
