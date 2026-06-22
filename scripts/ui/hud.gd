# hud.gd
# Controla y actualiza los elementos visuales de la interfaz de usuario en tiempo real.
extends CanvasLayer

@onready var speed_label: Label = $HUDContainer/BottomRight/SpeedValue
@onready var lap_label: Label = $HUDContainer/TopLeft/LapValue
@onready var time_label: Label = $HUDContainer/TopRight/TimeValue
@onready var pos_label: Label = $HUDContainer/TopLeft/PositionValue

@onready var countdown_panel: Control = $CountdownContainer
@onready var countdown_label: Label = $CountdownContainer/CountdownText

@onready var notification_panel: Control = $NotificationContainer
@onready var notification_label: Label = $NotificationContainer/NotificationText

@onready var results_panel: Control = $ResultsContainer
@onready var results_title: Label = $ResultsContainer/Panel/VBoxContainer/Title
@onready var results_pos: Label = $ResultsContainer/Panel/VBoxContainer/PositionText
@onready var results_time: Label = $ResultsContainer/Panel/VBoxContainer/TimeText
@onready var results_rewards: Label = $ResultsContainer/Panel/VBoxContainer/RewardsText

func _ready() -> void:
	# Asegurarse de ocultar los paneles de resultados y notificaciones al iniciar
	if results_panel:
		results_panel.visible = false
	if notification_panel:
		notification_panel.visible = false
	if countdown_panel:
		countdown_panel.visible = true

## Actualiza el velocímetro en pantalla.
func update_speed(speed: float) -> void:
	if speed_label:
		speed_label.text = str(round(speed))

## Actualiza el texto de vueltas (ej. "VUELTA 1 / 3").
func update_lap(current: int, total: int) -> void:
	if lap_label:
		lap_label.text = "VUELTA: %d / %d" % [current, total]

## Actualiza la posición de carrera (ej. "POS: 1 / 3").
func update_position(pos: int, total: int) -> void:
	if pos_label:
		pos_label.text = "POS: %d / %d" % [pos, total]

## Formatea y actualiza el cronómetro (formato MM:SS.CC).
func update_timer(seconds: float) -> void:
	if not time_label:
		return
		
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	var centis = int((seconds - int(seconds)) * 100)
	time_label.text = "%02d:%02d.%02d" % [mins, secs, centis]

## Muestra y actualiza el contador de salida.
func update_countdown(text: String) -> void:
	if countdown_panel and countdown_label:
		countdown_panel.visible = true
		countdown_label.text = text
		
		# Crear un pequeño efecto de escala con Tween para que sea dinámico
		var tween = create_tween()
		countdown_label.scale = Vector2(1.5, 1.5)
		tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Oculta el panel de cuenta atrás.
func hide_countdown() -> void:
	if countdown_panel:
		# Hacer un fundido de salida (fade-out)
		var tween = create_tween()
		tween.tween_property(countdown_panel, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): countdown_panel.visible = false)

## Muestra un cartel flotante que avisa del fin de vuelta.
func show_lap_notification(lap_num: int) -> void:
	if not notification_panel or not notification_label:
		return
		
	notification_label.text = "¡VUELTA %d COMPLETADA!" % lap_num
	notification_panel.visible = true
	notification_panel.modulate.a = 0.0
	
	# Animación premium de entrada y salida
	var tween = create_tween()
	tween.tween_property(notification_panel, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.5)
	tween.tween_property(notification_panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): notification_panel.visible = false)

## Muestra la pantalla final de resultados con los créditos ganados.
func show_results(position: int, time: float, data: EventData) -> void:
	if not results_panel:
		return
		
	var mins = int(time) / 60
	var secs = int(time) % 60
	var centis = int((time - int(time)) * 100)
	var formatted_time = "%02d:%02d.%02d" % [mins, secs, centis]
	
	# Configurar textos
	if results_title:
		results_title.text = "¡CARRERA FINALIZADA!"
	
	if results_pos:
		var suffix = "º"
		results_pos.text = "Posición Final: %d%s" % [position, suffix]
		
	if results_time:
		results_time.text = "Tiempo Total: %s" % formatted_time
		
	if results_rewards and data:
		results_rewards.text = "Recompensas:\n+ %d Créditos\n+ %d Fans" % [data.reward_credits, data.reward_fans]
		
	results_panel.visible = true
	results_panel.modulate.a = 0.0
	
	# Animación de entrada de resultados
	var tween = create_tween()
	tween.tween_property(results_panel, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
