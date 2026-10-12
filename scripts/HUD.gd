extends CanvasLayer

@onready var lbl_dia       = $TopBar/LblDia
@onready var lbl_hora      = $TopBar/LblHora
@onready var lbl_nivel     = $TopBar/LblNivel
@onready var lbl_piso      = $TopBar/LblPiso
@onready var barra_xp      = $TopBar/BarraXP
@onready var barra_dia     = $TopBar/BarraDia
@onready var barra_rep     = $TopBar/BarraRep

@onready var btn_inventario = $BotonesLaterales/BtnInventario
@onready var btn_misiones   = $BotonesLaterales/BtnMisiones
@onready var panel_inv      = $PanelInventario
@onready var lista_inv      = $PanelInventario/VBox/ListaInventario
@onready var panel_mis      = $PanelMisiones
@onready var lista_mis      = $PanelMisiones/VBox/ListaMisiones

@onready var banner_aviso   = $BannerAviso
@onready var lbl_aviso      = $BannerAviso/LblAviso

func _ready():
	panel_inv.visible = false
	panel_mis.visible = false
	banner_aviso.visible = false
	_estilizar_topbar()

	# Señales de tiempo
	TiempoLaboral.hora_actualizada.connect(_on_hora)
	TiempoLaboral.dia_iniciado.connect(_on_dia_iniciado)
	TiempoLaboral.hora_critica.connect(_on_hora_critica)

	# Señales de progresión
	GameManager.experiencia_ganada.connect(_on_xp)
	GameManager.nivel_subido.connect(_on_nivel)

	# Señales de reputación
	ReputacionGlobal.reputacion_global_cambiada.connect(_on_rep_global)
	ReputacionGlobal.advertencia_global.connect(mostrar_aviso)
	ReputacionGlobal.npc_bloqueado.connect(func(npc, _r): mostrar_aviso("⛔ %s ya no quiere hablar contigo." % npc))

	# Señales de misiones
	SistemaMisiones.mision_desbloqueada.connect(func(m): mostrar_aviso("🔵 Nueva misión: %s" % m.titulo))
	SistemaMisiones.mision_completada.connect(func(m): mostrar_aviso("🟢 ¡Misión completada! +%d XP" % m.recompensa_exp))
	SistemaMisiones.mision_fallida.connect(func(m): mostrar_aviso("🔴 Misión fallida: %s" % m.titulo))
	SistemaMisiones.mision_critica_fallida.connect(func(m): mostrar_aviso("❌ INCIDENTE GRAVE: %s" % m.titulo))
	SistemaMisiones.mision_por_vencer.connect(func(m, mins): mostrar_aviso("⏳ ¡'%s' vence en %d min!" % [m.titulo, mins]))

	# Piso (con animación de pop al cambiar)
	FloorManager.piso_cambiado.connect(func(n, nombre):
		lbl_piso.text = "🏢 P%d · %s" % [n, nombre]
		_pop(lbl_piso))

	# Inventario: avisar cuando un insumo caduca (la misión del martes lo usa)
	Inventario.insumo_caducado.connect(func(n): mostrar_aviso("⚠️ Insumo caducado: %s — retíralo en bodega." % n))
	Inventario.insumo_agotado.connect(func(n): mostrar_aviso("⛔ Stock agotado: %s." % n))

	btn_inventario.pressed.connect(_toggle_inv)
	btn_misiones.pressed.connect(_toggle_mis)

	# Quitar el foco de los botones para que las flechas/WASD no los activen
	btn_inventario.focus_mode = Control.FOCUS_NONE
	btn_misiones.focus_mode   = Control.FOCUS_NONE

	# Actualizar texto de los botones con atajo visible
	btn_inventario.text = "📦 Stock  [I]"
	btn_misiones.text   = "📋 Misiones  [M]"

	# Botón de pausa
	var btn_pausa = Button.new()
	btn_pausa.text = "⏸ Pausa  [P]"
	btn_pausa.focus_mode = Control.FOCUS_NONE
	btn_pausa.pressed.connect(func(): Pausa.alternar_pausa())
	$BotonesLaterales.add_child(btn_pausa)

	# Listas largas → scroll (rueda del ratón) para que no se salgan de pantalla
	_envolver_en_scroll(lista_inv)
	_envolver_en_scroll(lista_mis)

# ─── Estilo del TopBar ───────────────────────────────────────
# Antes los textos (Lunes, hora, nivel, reputación, piso) eran labels planos.
# Ahora cada uno vive en una "píldora" de color con icono, letra más grande
# y animaciones (pop al cambiar de día/piso/nivel, parpadeo en la última hora).

func _estilizar_topbar():
	var barra = $TopBar
	barra.offset_left = 10.0
	barra.offset_right = 1270.0
	barra.offset_bottom = 46.0
	barra.add_theme_constant_override("separation", 14)

	_pill(lbl_dia,   Color(0.16, 0.32, 0.55), Color(0.72, 0.86, 1.0))
	_pill(lbl_hora,  Color(0.08, 0.10, 0.15), Color(0.98, 0.92, 0.60))
	_pill(lbl_nivel, Color(0.33, 0.22, 0.52), Color(0.88, 0.78, 1.0))
	_pill(lbl_piso,  Color(0.10, 0.36, 0.38), Color(0.70, 0.96, 0.94))

	var lbl_rep = get_node_or_null("TopBar/LblRep")
	if lbl_rep:
		lbl_rep.text = "❤ Rep"
		lbl_rep.custom_minimum_size = Vector2(55, 0)
		lbl_rep.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_rep.add_theme_font_size_override("font_size", 15)
		lbl_rep.add_theme_color_override("font_color", Color(0.95, 0.65, 0.70))

	# Las barras de progreso, centradas verticalmente
	for b in [barra_dia, barra_xp, barra_rep]:
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	lbl_dia.text  = "📅 Lunes"
	lbl_piso.text = "🏢 P1 · Planta Baja"
	lbl_nivel.text = "⭐ Nv.1"

func _pill(lbl: Label, fondo: Color, letra: Color):
	var sb = StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(1)
	sb.border_color = Color(fondo.r + 0.22, fondo.g + 0.22, fondo.b + 0.25, 0.9)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	lbl.add_theme_stylebox_override("normal", sb)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", letra)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# Pequeño "pop" de escala para llamar la atención cuando un dato cambia
func _pop(ctrl: Control):
	ctrl.pivot_offset = ctrl.size / 2.0
	ctrl.scale = Vector2(1.35, 1.35)
	var tw = create_tween()
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _envolver_en_scroll(lista: Control):
	var padre = lista.get_parent()
	var idx = lista.get_index()
	var scroll = ScrollContainer.new()
	scroll.name = lista.name + "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padre.add_child(scroll)
	padre.move_child(scroll, idx)
	padre.remove_child(lista)
	scroll.add_child(lista)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _input(event):
	if event.is_action_pressed("ui_inventario"):
		_toggle_inv()
	elif event.is_action_pressed("ui_misiones"):
		_toggle_mis()
	elif event.is_action_pressed("ui_cancel"):
		if panel_inv.visible or panel_mis.visible:
			panel_inv.visible = false
			panel_mis.visible = false
			get_viewport().set_input_as_handled()

func _process(_delta):
	lbl_hora.text   = "🕒 " + TiempoLaboral.get_hora_texto()
	barra_dia.value = TiempoLaboral.get_progreso_dia() * 100.0
	# Última hora del turno: la hora parpadea en rojo para avisar la urgencia
	if TiempoLaboral.activo and TiempoLaboral.hora_actual >= TiempoLaboral.HORA_FIN - 1.0:
		var t = Time.get_ticks_msec() / 1000.0
		var pulso = 0.5 + 0.5 * sin(t * 6.0)
		lbl_hora.add_theme_color_override("font_color",
			Color(0.98, 0.92, 0.60).lerp(Color(1.0, 0.30, 0.25), pulso))
	else:
		lbl_hora.add_theme_color_override("font_color", Color(0.98, 0.92, 0.60))

func _on_hora(_texto, _prog):
	pass  # Actualizado en _process

func _on_dia_iniciado(_dia: int, nombre: String):
	lbl_dia.text = "📅 %s" % nombre
	_pop(lbl_dia)
	mostrar_aviso("📅 ¡Bienvenido al %s! Turno: 08:00 – 17:00" % nombre)
	if panel_mis.visible:
		_actualizar_misiones()

func _on_hora_critica(hora: float):
	if hora == 12.0:
		mostrar_aviso("🕛 Mediodía. Ya pasó media mañana — revisa tus misiones [M].")
	elif hora == 14.0:
		mostrar_aviso("🕑 Las 14:00. Quedan 3 horas de turno.")
	elif hora == 16.0:
		mostrar_aviso("⏰ Solo queda 1 hora de turno. Prioriza tus misiones activas.")
	elif hora == 16.5:
		mostrar_aviso("⏰ 30 minutos para el cierre. Última oportunidad.")
	elif hora == 16.833:
		mostrar_aviso("⏰ ¡10 minutos! Las misiones activas fallarán al cierre.")

func _on_xp(_cantidad):
	# BUGFIX: hay que asignar max_value ANTES que value; en el orden anterior,
	# si la XP superaba el máximo antiguo, la barra se quedaba recortada.
	barra_xp.max_value = GameManager.xp_para_nivel
	barra_xp.value     = GameManager.experiencia

func _on_nivel(nivel: int):
	lbl_nivel.text = "⭐ Nv.%d" % nivel
	_pop(lbl_nivel)
	mostrar_aviso("⭐ ¡Subiste al nivel %d!" % nivel)

func _on_rep_global(valor: int):
	barra_rep.value    = valor
	barra_rep.modulate = ReputacionGlobal.get_color_reputacion(valor)

# ─── Paneles ─────────────────────────────────────────────────

func _toggle_inv():
	panel_inv.visible = not panel_inv.visible
	if panel_inv.visible:
		_actualizar_inventario()
		panel_mis.visible = false

func _toggle_mis():
	panel_mis.visible = not panel_mis.visible
	if panel_mis.visible:
		_actualizar_misiones()
		panel_inv.visible = false

func _actualizar_inventario():
	for c in lista_inv.get_children(): c.queue_free()
	var insumos = GameManager.inventario.insumos
	var prev_cat = ""
	for nombre in insumos:
		var item = insumos[nombre]
		if item.categoria != prev_cat:
			prev_cat = item.categoria
			var sep = Label.new()
			sep.text = "─ " + item.categoria.to_upper()
			sep.add_theme_color_override("font_color", Color(0.8, 0.7, 0.2))
			lista_inv.add_child(sep)
		var nivel = GameManager.inventario.get_nivel_stock(nombre)
		var icono = {"normal":"🟢","bajo":"🟡","critico":"🔴","agotado":"⛔"}.get(nivel,"?")
		var lbl = Label.new()
		lbl.text = "%s %-26s %3d uds." % [icono, nombre, item.cantidad]
		lista_inv.add_child(lbl)

func _actualizar_misiones():
	for c in lista_mis.get_children(): c.queue_free()

	var orden = [
		SistemaMisiones.Estado.ACTIVA,
		SistemaMisiones.Estado.PENDIENTE,
		SistemaMisiones.Estado.COMPLETADA,
		SistemaMisiones.Estado.FALLIDA,
	]

	for estado in orden:
		var lista = SistemaMisiones.get_misiones_por_estado(estado)
		if lista.is_empty(): continue
		var header = Label.new()
		header.text = SistemaMisiones.get_icono_estado(estado) + " " + _nombre_estado(estado)
		header.add_theme_color_override("font_color", SistemaMisiones.get_color_estado(estado))
		lista_mis.add_child(header)

		for m in lista:
			# RichTextLabel: los nombres de NPC y objetos van en NEGRITA para
			# ayudar a recordar qué pide cada misión.
			var lbl = RichTextLabel.new()
			lbl.bbcode_enabled = true
			lbl.fit_content = true
			lbl.scroll_active = false
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var prog = ""
			if estado == SistemaMisiones.Estado.ACTIVA:
				var p = int(SistemaMisiones.get_progreso_objetivo(m.id) * 100)
				if p >= 100 and m.get("requiere_entrega", false) and not m.get("entregado", false):
					prog = " [📦 falta entregar]"
				else:
					prog = " [%d%%]" % p
			# Mostrar la hora límite si vence antes del fin del turno
			var limite_tag = ""
			if estado in [SistemaMisiones.Estado.ACTIVA, SistemaMisiones.Estado.PENDIENTE] \
					and m.hora_limite < TiempoLaboral.HORA_FIN:
				limite_tag = "  ⏰%02d:%02d" % [int(m.hora_limite), int((m.hora_limite - int(m.hora_limite)) * 60)]
			var critica_tag = " ⚠️" if m.critica else ""
			lbl.text = "  · %s%s%s%s" % [SistemaMisiones.resaltar_bbcode(m.titulo), critica_tag, prog, limite_tag]
			lbl.add_theme_color_override("default_color", SistemaMisiones.get_color_estado(estado))
			# Tooltip con descripción (Godot 4: tooltip_text)
			lbl.tooltip_text = m.descripcion
			lista_mis.add_child(lbl)
			var fv = FontVariation.new()
			fv.base_font = lbl.get_theme_font("normal_font")
			fv.variation_embolden = 0.85
			lbl.add_theme_font_override("bold_font", fv)

func _nombre_estado(estado) -> String:
	match estado:
		SistemaMisiones.Estado.ACTIVA:     return "EN PROGRESO"
		SistemaMisiones.Estado.PENDIENTE:  return "DISPONIBLES"
		SistemaMisiones.Estado.COMPLETADA: return "COMPLETADAS"
		SistemaMisiones.Estado.FALLIDA:    return "FALLIDAS"
	return ""

# ─── Avisos flotantes ────────────────────────────────────────

var cola_avisos: Array = []
var aviso_activo: bool = false

func mostrar_aviso(texto: String):
	cola_avisos.append(texto)
	if not aviso_activo:
		_mostrar_siguiente_aviso()

func _mostrar_siguiente_aviso():
	if cola_avisos.is_empty():
		aviso_activo = false
		banner_aviso.visible = false
		return
	aviso_activo = true
	lbl_aviso.text = cola_avisos.pop_front()
	banner_aviso.visible = true
	await get_tree().create_timer(3.5).timeout
	_mostrar_siguiente_aviso()
