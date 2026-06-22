# vehicle_controller.gd
# Este script controla las físicas del vehículo, el derrape y el seguimiento suave de la cámara.
# Extiende VehicleBody3D para utilizar las físicas nativas de ruedas y chasis de Godot 4.
extends VehicleBody3D

## Señal emitida al cambiar el estado de derrape.
signal on_drift(is_drifting: bool)

@export_category("Motor & Físicas")
## Fuerza máxima del motor aplicada al acelerar.
# Se usa max_engine_force para evitar conflictos de nombres con la propiedad engine_force nativa de VehicleBody3D.
@export var max_engine_force: float = 300.0
## Fuerza máxima de frenado.
@export var max_brake_force: float = 80.0
## Ángulo máximo de dirección en radianes (aprox. 23 grados).
@export var max_steer_angle: float = 0.4
## Velocidad máxima del vehículo en km/h.
@export var max_speed_kmh: float = 250.0

@export_category("Asistencias de Conducción")
## Control de tracción (TCS) para evitar el deslizamiento excesivo de las ruedas.
@export var tcs_enabled: bool = true
## Sistema antibloqueo de frenos (ABS) para evitar la pérdida de control al frenar.
@export var abs_enabled: bool = true

@export_category("Cámara de Seguimiento")
## Referencia al nodo SpringArm3D de la cámara.
@export var spring_arm: SpringArm3D
## Velocidad de interpolación de la posición de la cámara.
@export var camera_follow_speed: float = 10.0
## Velocidad de interpolación de la rotación de la cámara.
@export var camera_rotation_speed: float = 5.0

# Estado interno
var current_speed_kmh: float = 0.0
var drift_active: bool = false
var was_drifting: bool = false

func _ready() -> void:
	# Configurar el SpringArm3D para que no herede rígidamente la transformación del vehículo.
	# Esto permite interpolar su posición y rotación de forma suave en coordenadas globales.
	if spring_arm:
		spring_arm.top_level = true

func _physics_process(delta: float) -> void:
	# Calcular velocidad actual en km/h
	current_speed_kmh = linear_velocity.length() * 3.6
	
	# Procesar las entradas del jugador
	_handle_input()
	
	# Comprobar si el vehículo está derrapando
	_check_drift()
	
	# Actualizar la cámara de seguimiento
	_update_camera(delta)

func _handle_input() -> void:
	# Leer los ejes del Input Map de Godot
	var throttle = Input.get_axis("brake", "accelerate")
	var steer = Input.get_axis("steer_right", "steer_left")
	
	# Dirección
	steering = steer * max_steer_angle
	
	# Lógica del motor (Aceleración / Freno / Marcha atrás)
	if throttle > 0:
		# Aceleración hacia adelante
		if current_speed_kmh < max_speed_kmh:
			var applied_force = throttle * max_engine_force
			
			# Aplicar Control de Tracción (TCS) si está habilitado
			if tcs_enabled:
				applied_force = _apply_tcs(applied_force)
				
			engine_force = applied_force
		else:
			engine_force = 0.0
		brake = 0.0
	elif throttle < 0:
		# Frenado o marcha atrás
		# Comprobamos si nos movemos hacia adelante localmente
		var local_velocity = global_transform.basis.inverse() * linear_velocity
		if local_velocity.z < -0.5: # Z negativo es hacia adelante en Godot
			var applied_brake = abs(throttle) * max_brake_force
			
			# Aplicar ABS si está habilitado
			if abs_enabled:
				applied_brake = _apply_abs(applied_brake)
				
			brake = applied_brake
			engine_force = 0.0
		else:
			# Marcha atrás
			if current_speed_kmh < 50.0: # Limitar velocidad de marcha atrás
				engine_force = throttle * (max_engine_force * 0.5) # Menor potencia marcha atrás
			else:
				engine_force = 0.0
			brake = 0.0
	else:
		# Sin aceleración ni freno
		engine_force = 0.0
		brake = 0.0

## Retorna la velocidad actual en kilómetros por hora.
func get_speed_kmh() -> float:
	return current_speed_kmh

## Comprueba si el coche está derrapando y emite señales.
func _check_drift() -> void:
	# El derrape se calcula por el ángulo entre la dirección del coche y su velocidad.
	# Z negativo (-global_transform.basis.z) es la dirección hacia adelante del coche.
	var car_forward = -global_transform.basis.z
	
	if current_speed_kmh > 30.0:
		var velocity_dir = linear_velocity.normalized()
		var dot = car_forward.dot(velocity_dir)
		
		# Si el dot product es menor a 0.85, hay un deslizamiento lateral (derrape)
		drift_active = dot < 0.85
	else:
		drift_active = false
		
	# Emitir señal on_drift solo al cambiar de estado
	if drift_active != was_drifting:
		was_drifting = drift_active
		on_drift.emit(drift_active)

## Actualiza la posición y rotación de la cámara suavemente.
func _update_camera(delta: float) -> void:
	if not spring_arm:
		return
		
	# Interpolar la posición global del brazo de cámara hacia la posición del vehículo
	spring_arm.global_position = spring_arm.global_position.lerp(global_position, delta * camera_follow_speed)
	
	# Interpolar la rotación usando Quaternions para evitar rotaciones bruscas o bloqueos de cardán (gimbal lock)
	var target_rotation = global_transform.basis.get_rotation_quaternion()
	var current_rotation = spring_arm.global_transform.basis.get_rotation_quaternion()
	var next_rotation = current_rotation.slerp(target_rotation, delta * camera_rotation_speed)
	spring_arm.global_transform.basis = Basis(next_rotation)

## Simulación básica de Control de Tracción (TCS)
func _apply_tcs(force: float) -> float:
	# Si detectamos un deslizamiento excesivo o pérdida de tracción lateral,
	# reducimos la fuerza del motor aplicada a las ruedas tractoras.
	if drift_active:
		# Reducir fuerza a la mitad si está derrapando por exceso de gas
		return force * 0.5
	return force

## Simulación básica de ABS
func _apply_abs(brake_force_input: float) -> float:
	# Si estamos frenando fuertemente y el coche empieza a derrapar lateralmente,
	# reducimos la fuerza de frenado para recuperar tracción.
	if drift_active:
		# Pulsar los frenos (reducir a un 40%) para recuperar agarre
		return brake_force_input * 0.4
	return brake_force_input
