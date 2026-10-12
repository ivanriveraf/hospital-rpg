extends CanvasLayer
# Pantalla que aparece al inicio y al fin de cada día laboral.
# Al inicio → muestra briefing de misiones del día.
# Al fin    → muestra resultados y botón para continuar.

@onready var panel         = $Panel
@onready var lbl_titulo    = $Panel/VBox/LblTitulo
@onready var lbl_subtitulo = $Panel/VBox/LblSubtitulo
@onready var contenido     = $Panel/VBox/Contenido
@onready var btn_accion    = $Panel/VBox/BtnAccion

enum Modo { BRIEFING, RESULTADOS, FIN_SEMANA }
var modo_actual: Modo = Modo.BRIEFING

func _ready():
	panel.visible = false
	TiempoLaboral.dia_terminado.connect(_on_dia_terminado)
	TiempoLaboral.semana_terminada.connect(_on_semana_terminada)
	btn_accion.pressed.connect(_on_btn_accion)
	_aplicar_estilo()
	# Mostrar briefing del primer día al iniciar
	call_deferred("_mostrar_briefing_dia", 1)

# Tipografía grande y centrada: esta pantalla se veía con letras muy
# pequeñas y desaprovechaba el espacio del panel.
func _aplicar_estilo():
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo.add_theme_font_size_override("font_size", 40)
	lbl_titulo.add_theme_constant_override("outline_size", 6)
	lbl_titulo.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.14))

	lbl_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_subtitulo.add_theme_font_size_override("font_size", 19)
	lbl_subtitulo.add_theme_color_override("font_color", Color(0.66, 0.76, 0.90))

	btn_accion.add_theme_font_size_override("font_size", 22)
	btn_accion.custom_minimum_size = Vector2(0, 56)

	var vbox = lbl_titulo.get_parent()
	if vbox is VBoxContainer:
		vbox.add_theme_constant_override("separation", 10)
	if contenido is VBoxContainer:
		contenido.add_theme_constant_override("separation", 6)

# ─── Briefing de inicio de día ───────────────────────────────

func _mostrar_briefing_dia(dia: int):
	modo_actual = Modo.BRIEFING
	_limpiar()

	var nombre = TiempoLaboral.DIAS[dia]
	lbl_titulo.text    = "📅  %s" % nombre
	lbl_titulo.add_theme_color_override("font_color", Color(0.3, 0.6, 0.95))
	lbl_subtitulo.text = "Turno: 08:00 – 17:00  •  Piso 1 — Planta Baja"

	# Misiones disponibles hoy
	var misiones_hoy = []
	for id in SistemaMisiones.misiones:
		var m = SistemaMisiones.misiones[id]
		if m.dia_disponible == dia:
			misiones_hoy.append(m)

	_separador("MISIONES DE HOY")

	if misiones_hoy.is_empty():
		_linea("No hay misiones asignadas para hoy.", Color.GRAY)
	else:
		for m in misiones_hoy:
			var urgencia = " ⚠️ CRÍTICA" if m.critica else ""
			_linea("🔵 %s%s" % [m.titulo, urgencia],
				Color(0.9, 0.4, 0.2) if m.critica else Color(0.85, 0.85, 0.85))
			_linea("        📍 %s   •   Límite: %s" % [
				m.npc_origen, _hora_a_texto(m.hora_limite)],
				Color(0.68, 0.72, 0.78), 15)

	_separador("ESTADO ACTUAL")
	var rep = ReputacionGlobal.get_reputacion_global()
	_linea("Reputación global: %d/100 — %s" % [rep, ReputacionGlobal.get_nivel_texto()],
		ReputacionGlobal.get_color_reputacion(rep))
	_linea("Nivel: %d  •  XP: %d/%d" % [
		GameManager.nivel, GameManager.experiencia, GameManager.xp_para_nivel],
		Color(0.7, 0.85, 1.0))

	btn_accion.text = "▶  Empezar el %s" % nombre
	panel.visible = true

# ─── Resultados al fin del día ───────────────────────────────

func _on_dia_terminado(dia: int, resumen: Dictionary):
	# Seguridad: si terminó el día con un diálogo abierto, ciérralo para que no
	# quede pegado encima de la pantalla de resultados.
	GameManager.hide_dialogue()
	modo_actual = Modo.RESULTADOS
	_limpiar()

	var nombre = TiempoLaboral.DIAS[dia]
	lbl_titulo.text    = "🏁  Fin del %s" % nombre
	lbl_titulo.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	lbl_subtitulo.text = "Turno terminado. Revisa tu desempeño del día."

	# Misiones completadas
	if not resumen.completadas.is_empty():
		_separador("MISIONES COMPLETADAS")
		for m in resumen.completadas:
			_linea("🟢  %s  (+%d XP, +%d rep)" % [
				m.titulo, m.recompensa_exp, m.recompensa_reputacion],
				Color(0.3, 0.9, 0.45))

	# Misiones fallidas (aceptadas pero no completadas)
	if not resumen.fallidas.is_empty():
		_separador("MISIONES FALLIDAS")
		for m in resumen.fallidas:
			# BUGFIX: el texto mostraba "−rep/2" pero la penalización real solo
			# se aplica a misiones críticas (y es rep/4). Ahora coincide.
			var critica = " ⚠️ CRÍTICA" if m.critica else ""
			var pena = "(−%d rep)" % (m.recompensa_reputacion / 4) if m.critica else "(sin penalización)"
			_linea("🔴  %s%s  %s" % [m.titulo, critica, pena],
				Color(0.95, 0.35, 0.35))

	# Misiones no atendidas (disponibles pero nunca aceptadas)
	var no_atendidas = resumen.get("no_atendidas", [])
	if not no_atendidas.is_empty():
		_separador("NO ATENDIDAS (disponibles hoy)")
		for m in no_atendidas:
			_linea("⚪  %s  — sin aceptar" % m.titulo, Color(0.60, 0.60, 0.62), 15)

	# Resumen numérico
	_separador("BALANCE DEL DÍA")
	var rep_cambio = resumen.rep_cambio
	var rep_signo  = "+" if rep_cambio >= 0 else ""
	var rep_color  = Color(0.3, 0.9, 0.3) if rep_cambio >= 0 else Color(0.95, 0.35, 0.35)

	_linea("Misiones completadas: %d    Fallidas: %d" % [
		resumen.completadas.size(), resumen.fallidas.size()],
		Color(0.85, 0.85, 0.85))
	_linea("Reputación: %s%d  (total: %d/100 — %s)" % [
		rep_signo, rep_cambio, resumen.rep_actual,
		ReputacionGlobal.get_nivel_texto()], rep_color)
	_linea("XP ganada hoy: +%d  (nivel %d)" % [
		resumen.xp_ganada, GameManager.nivel], Color(0.7, 0.85, 1.0))

	if resumen.ultimo_dia:
		btn_accion.text = "📊  Ver evaluación final de la semana"
	else:
		var sig = TiempoLaboral.DIAS[dia + 1]
		btn_accion.text = "➡  Continuar al %s" % sig

	panel.visible = true

func _on_semana_terminada(resumen: Dictionary):
	modo_actual = Modo.FIN_SEMANA
	_limpiar()

	var rep = resumen.reputacion_final
	var victoria = rep >= 70 and resumen.completadas_total >= 8
	lbl_titulo.text = "🏆  Semana completada" if victoria else "📋  Evaluación semanal"
	lbl_titulo.add_theme_color_override("font_color",
		Color(0.95, 0.8, 0.1) if victoria else Color(0.85, 0.85, 0.85))
	lbl_subtitulo.text = "Reputación: %s" % resumen.nivel_final

	_separador("RESULTADO FINAL")
	_linea("Misiones completadas: %d" % resumen.completadas_total, Color(0.3, 0.9, 0.45))
	_linea("Misiones fallidas:    %d" % resumen.fallidas_total,    Color(0.95, 0.35, 0.35))
	_linea("Reputación final:     %d/100" % rep, ReputacionGlobal.get_color_reputacion(rep))
	_linea("Nivel alcanzado:      %d" % GameManager.nivel, Color(0.7, 0.85, 1.0))

	if victoria:
		_separador("¡EXCELENTE DESEMPEÑO!")
		_linea("Has demostrado ser un técnico ejemplar.", Color(0.95, 0.8, 0.1))
	else:
		_separador("ÁREAS A MEJORAR")
		_linea("Hay aspectos de tu gestión que puedes mejorar.", Color(0.8, 0.8, 0.8))

	btn_accion.text = "🔄  Nueva semana"
	panel.visible = true

# ─── Botón de acción ─────────────────────────────────────────

func _on_btn_accion():
	match modo_actual:
		Modo.BRIEFING:
			panel.visible = false
			TiempoLaboral.iniciar_dia()
		Modo.RESULTADOS:
			panel.visible = false
			var era_ultimo_dia = TiempoLaboral.dia_semana >= 5
			TiempoLaboral.avanzar_al_siguiente_dia()
			# Si era el último día, avanzar_al_siguiente_dia() ya emitió semana_terminada
			# y _on_semana_terminada() habrá tomado el control — no sobrescribir con briefing
			if not era_ultimo_dia and TiempoLaboral.dia_semana <= 5:
				_mostrar_briefing_dia(TiempoLaboral.dia_semana)
		Modo.FIN_SEMANA:
			# BUGFIX: resetear los autoloads antes de recargar, o la nueva
			# semana empezaba con las misiones/reputación de la anterior.
			GameManager.reiniciar_juego()
			get_tree().reload_current_scene()

# ─── Helpers visuales ────────────────────────────────────────

func _limpiar():
	for c in contenido.get_children():
		c.queue_free()

func _separador(texto: String):
	var lbl = Label.new()
	lbl.text = "──────  %s  ──────" % texto
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.55, 0.68, 0.85))
	lbl.add_theme_font_size_override("font_size", 16)
	contenido.add_child(lbl)

# Las líneas ahora usan RichTextLabel: letra más grande y los nombres de
# NPC / objetos aparecen automáticamente en NEGRITA (ver SistemaMisiones).
func _linea(texto: String, color: Color, size: int = 18):
	var lbl = RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = SistemaMisiones.resaltar_bbcode(texto)
	lbl.add_theme_color_override("default_color", color)
	lbl.add_theme_font_size_override("normal_font_size", size)
	lbl.add_theme_font_size_override("bold_font_size", size)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenido.add_child(lbl)
	# Negrita real basada en la misma fuente del tema (embolden)
	var fv = FontVariation.new()
	fv.base_font = lbl.get_theme_font("normal_font")
	fv.variation_embolden = 0.85
	lbl.add_theme_font_override("bold_font", fv)

func _hora_a_texto(hora: float) -> String:
	var h = int(hora)
	var m = int((hora - h) * 60.0)
	return "%02d:%02d" % [h, m]
