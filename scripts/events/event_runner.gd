# event_runner.gd
# Controla el ciclo de vida de una carrera (cuenta atrás, cronómetro, checkpoints, vueltas, posiciones y recompensas).
class_name EventRunner
extends Node

## Estado de la carrera.
enum RaceState { IDLE, COUNTDOWN, RACING, FINISHED }

@export_category("Configuración del Evento")
## Datos básicos del evento (nombre, vueltas, recompensas).
@export var event_data: EventData
## Nodo contenedor que tiene todos los Checkpoints ordenados secuencialmente.
@export var checkpoints_container: Node3D

@export_category("Competidores")
## Nodo del vehículo del jugador.
@export var player_vehicle: Node3D
## Controlador de entrada del jugador (para bloquearlo durante la cuenta atrás).
@export var player_controller: Node
## Lista de vehículos controlados por la IA (definidos como NodePath).
@export var ai_vehicles: Array[NodePath] = []
## Lista de controladores de IA correspondientes (definidos como NodePath).
@export var ai_controllers: Array[NodePath] = []

# Nodos de IA resueltos dinámicamente en _ready()
var ai_vehicle_nodes: Array[Node3D] = []
var ai_controller_nodes: Array[Node] = []

@export_category("Interfaz")
## Referencia al HUD del juego.
@export var hud: CanvasLayer

# Estado interno
var state: RaceState = RaceState.IDLE
var checkpoints: Array[Checkpoint] = []
var race_time: float = 0.0
var countdown_time: float = 3.0

# Estructuras de datos para el seguimiento de los competidores
var player_state = {
	"next_checkpoint_idx": 0,
	"lap": 0,
	"finished": false,
	"finish_time": 0.0,
	"has_started": false
}

var ai_states = {} # Map: ai_node -> state_dict
var player_position: int = 1
var total_competitors: int = 1

func _ready() -> void:
	# Resolver NodePaths de vehículos y controladores de IA
	for path in ai_vehicles:
		var node = get_node_or_null(path) as Node3D
		if node:
			ai_vehicle_nodes.append(node)
			
	for path in ai_controllers:
		var node = get_node_or_null(path)
		if node:
			ai_controller_nodes.append(node)
			
	# Inicializar competidores
	total_competitors = 1 + ai_vehicle_nodes.size()
	
	# Inicializar checkpoints del contenedor
	if checkpoints_container:
		for child in checkpoints_container.get_children():
			if child is Checkpoint:
				checkpoints.append(child)
				child.vehicle_passed.connect(_on_checkpoint_passed)
	
	# Asignar identificadores numéricos ordenados
	for i in range(checkpoints.size()):
		checkpoints[i].checkpoint_id = i
	
	# Establecer el primer checkpoint como activo para el jugador
	if checkpoints.size() > 0:
		checkpoints[0].is_active = true
	
	# Configurar estados iniciales de IA
	for ai in ai_vehicle_nodes:
		ai_states[ai] = {
			"next_checkpoint_idx": 0,
			"lap": 0,
			"finished": false,
			"finish_time": 0.0,
			"has_started": false
		}
	
	# Iniciar el evento
	start_event()

func start_event() -> void:
	state = RaceState.COUNTDOWN
	race_time = 0.0
	countdown_time = 3.0
	
	# Congelar físicamente los vehículos de la parrilla
	if player_vehicle:
		player_vehicle.process_mode = Node.PROCESS_MODE_DISABLED
	for ai in ai_vehicle_nodes:
		if ai:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
			
	# Bloquear controles
	_set_controls_enabled(false)
	
	# Actualizar HUD inicial
	if hud:
		hud.update_lap(1, event_data.laps if event_data else 3)
		hud.update_position(total_competitors, total_competitors)
		hud.update_timer(0.0)

func _process(delta: float) -> void:
	match state:
		RaceState.COUNTDOWN:
			countdown_time -= delta
			if hud:
				if countdown_time > 0:
					hud.update_countdown(str(ceil(countdown_time)))
				else:
					hud.update_countdown("¡YA!")
					
			if countdown_time <= -1.0: # Mantener el "¡YA!" por un segundo
				_on_countdown_finished()
				
		RaceState.RACING:
			race_time += delta
			if hud:
				hud.update_timer(race_time)
				# Actualizar la velocidad del jugador
				if player_vehicle and player_vehicle.has_method("get_speed_kmh"):
					hud.update_speed(player_vehicle.get_speed_kmh())
				elif player_vehicle and "linear_velocity" in player_vehicle:
					hud.update_speed(player_vehicle.linear_velocity.length() * 3.6)
			
			# Actualizar las posiciones relativas de los competidores
			_update_positions()

func _on_countdown_finished() -> void:
	state = RaceState.RACING
	if hud:
		hud.hide_countdown()
		
	# Descongelar vehículos
	if player_vehicle:
		player_vehicle.process_mode = Node.PROCESS_MODE_INHERIT
	for ai in ai_vehicle_nodes:
		if ai:
			ai.process_mode = Node.PROCESS_MODE_INHERIT
			
	_set_controls_enabled(true)

# Activa o desactiva la ejecución física de los controladores para bloquear la entrada de mandos
func _set_controls_enabled(enabled: bool) -> void:
	if player_controller:
		player_controller.set_physics_process(enabled)
		if player_controller.has_method("set_process"):
			player_controller.set_process(enabled)
			
	for ai_ctrl in ai_controller_nodes:
		if ai_ctrl:
			ai_ctrl.set_physics_process(enabled)
			if ai_ctrl.has_method("set_process"):
				ai_ctrl.set_process(enabled)

# Escucha cuando cualquier vehículo entra en cualquier checkpoint
func _on_checkpoint_passed(vehicle: Node3D, checkpoint: Checkpoint) -> void:
	if state != RaceState.RACING:
		return
		
	var is_player = (vehicle == player_vehicle)
	var current_state = player_state if is_player else ai_states.get(vehicle)
	
	if not current_state or current_state.finished:
		return
		
	# Comprobar si el checkpoint cruzado es el esperado secuencialmente
	if checkpoint.checkpoint_id == current_state.next_checkpoint_idx:
		# Si es el primer checkpoint (salida) y el coche aún no ha comenzado oficialmente la carrera
		if checkpoint.checkpoint_id == 0 and not current_state.has_started:
			current_state.has_started = true
			current_state.next_checkpoint_idx = 1
		else:
			# Avanzar el índice del siguiente checkpoint esperado de forma circular
			var total_chks = checkpoints.size()
			current_state.next_checkpoint_idx = (current_state.next_checkpoint_idx + 1) % total_chks
			
			# Si vuelve al checkpoint 1 (es decir, ha pasado el 0 completando una vuelta)
			if current_state.next_checkpoint_idx == 1:
				current_state.lap += 1
				
				if is_player:
					var total_laps = event_data.laps if event_data else 3
					hud.update_lap(mini(current_state.lap + 1, total_laps), total_laps)
					# Efecto visual en HUD al completar vuelta
					hud.show_lap_notification(current_state.lap)
				
				# Comprobar si ha terminado la carrera
				var target_laps = event_data.laps if event_data else 3
				if current_state.lap >= target_laps:
					_finish_competitor(vehicle, is_player)
		
		# Si es la IA, actualizar su posición de seguridad en su controlador para la prevención de atascos
		if not is_player:
			for ai_ctrl in ai_controller_nodes:
				if ai_ctrl and "vehicle_node" in ai_ctrl and ai_ctrl.vehicle_node == vehicle:
					if ai_ctrl.has_method("update_safe_position"):
						ai_ctrl.update_safe_position(checkpoint.global_position, checkpoint.global_transform.basis)
		
		# Si es el jugador, actualizar visualmente qué checkpoint está activo
		if is_player and not player_state.finished:
			# Apagar todos los checkpoints
			for chk in checkpoints:
				chk.is_active = false
			# Encender el siguiente objetivo
			checkpoints[player_state.next_checkpoint_idx].is_active = true


func _finish_competitor(vehicle: Node3D, is_player: bool) -> void:
	if is_player:
		player_state.finished = true
		player_state.finish_time = race_time
		
		# Apagar checkpoints activos para el jugador
		for chk in checkpoints:
			chk.is_active = false
			
		# Detener controles
		_set_controls_enabled(false)
		
		# Entregar recompensas al perfil
		if event_data:
			PlayerProfile.add_credits(event_data.reward_credits)
			PlayerProfile.add_fans(event_data.reward_fans)
			
		# Mostrar pantalla de resultados en HUD
		if hud:
			hud.show_results(player_position, race_time, event_data)
			
		state = RaceState.FINISHED
	else:
		var state_dict = ai_states.get(vehicle)
		if state_dict:
			state_dict.finished = true
			state_dict.finish_time = race_time

# Determina las posiciones de la carrera en tiempo real
func _update_positions() -> void:
	var list = []
	
	# Añadir al jugador
	list.append({
		"node": player_vehicle,
		"is_player": true,
		"lap": player_state.lap,
		"next_chk": player_state.next_checkpoint_idx,
		"finished": player_state.finished,
		"finish_time": player_state.finish_time,
		"dist": _get_distance_to_checkpoint(player_vehicle, player_state.next_checkpoint_idx)
	})
	
	# Añadir competidores de IA
	for ai in ai_vehicle_nodes:
		var s = ai_states[ai]
		list.append({
			"node": ai,
			"is_player": false,
			"lap": s.lap,
			"next_chk": s.next_checkpoint_idx,
			"finished": s.finished,
			"finish_time": s.finish_time,
			"dist": _get_distance_to_checkpoint(ai, s.next_checkpoint_idx)
		})
	
	# Ordenar competidores:
	# 1. Finalizados primero (menor tiempo primero)
	# 2. Mayor número de vueltas
	# 3. Siguiente checkpoint más lejano (significa que está más adelantado en el circuito)
	# 4. Menor distancia al siguiente checkpoint (desempate de sector)
	list.sort_custom(func(a, b):
		if a.finished != b.finished:
			return a.finished # El terminado va delante
		if a.finished and b.finished:
			return a.finish_time < b.finish_time
			
		if a.lap != b.lap:
			return a.lap > b.lap
			
		if a.next_chk != b.next_chk:
			return a.next_chk > b.next_chk
			
		return a.dist < b.dist
	)
	
	# Encontrar la posición del jugador en la lista
	for i in range(list.size()):
		if list[i].is_player:
			player_position = i + 1
			break
			
	if hud:
		hud.update_position(player_position, total_competitors)

func _get_distance_to_checkpoint(vehicle: Node3D, chk_idx: int) -> float:
	if chk_idx >= checkpoints.size() or not is_instance_valid(checkpoints[chk_idx]):
		return 9999.0
	return vehicle.global_position.distance_to(checkpoints[chk_idx].global_position)
