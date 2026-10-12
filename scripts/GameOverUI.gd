extends CanvasLayer

@onready var panel        = $Panel
@onready var lbl_titulo   = $Panel/VBox/LblTitulo
@onready var lbl_mensaje  = $Panel/VBox/LblMensaje
@onready var lbl_stats    = $Panel/VBox/LblStats
@onready var btn_reiniciar = $Panel/VBox/BtnReiniciar

func _ready():
	# BUGFIX: sin esto, al pausar el árbol en el Game Over el botón
	# "Reiniciar" quedaba congelado y era imposible reiniciar la partida.
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	GameOverManager.game_over_activado.connect(_on_game_over)
	GameOverManager.semana_superada.connect(_on_semana_superada)
	btn_reiniciar.pressed.connect(_reiniciar)

func _on_game_over(_tipo, mensaje: String, detalle: String):
	lbl_titulo.text  = mensaje
	lbl_titulo.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2))
	lbl_mensaje.text = detalle
	_mostrar_stats()
	panel.visible = true
	get_tree().paused = true

func _on_semana_superada(resumen: Dictionary):
	lbl_titulo.text  = resumen.titulo
	lbl_titulo.add_theme_color_override("font_color",
		Color(0.2, 0.85, 0.3) if resumen.tipo == GameOverManager.TipoFin.VICTORIA_PLENA
		else Color(0.9, 0.85, 0.2))
	lbl_mensaje.text = resumen.mensaje
	_mostrar_stats()
	panel.visible = true

func _mostrar_stats():
	var completadas = SistemaMisiones.misiones_completadas.size()
	var fallidas    = SistemaMisiones.misiones_fallidas.size()
	var rep         = ReputacionGlobal.get_reputacion_global()
	var nivel_xp    = GameManager.nivel

	lbl_stats.text = (
		"── Resumen de la semana ──\n" +
		"Misiones completadas: %d\n" % completadas +
		"Misiones fallidas:    %d\n" % fallidas +
		"Reputación global:    %d/100 (%s)\n" % [rep, ReputacionGlobal.get_nivel_texto()] +
		"Nivel alcanzado:      %d\n" % nivel_xp
	)

func _reiniciar():
	get_tree().paused = false
	# BUGFIX: reiniciar también los autoloads (misiones, reputación, tiempo...),
	# si no, la "nueva partida" heredaba todo el estado de la anterior.
	GameManager.reiniciar_juego()
	get_tree().reload_current_scene()
