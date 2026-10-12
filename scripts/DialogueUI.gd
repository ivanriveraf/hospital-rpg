extends CanvasLayer

@onready var panel           = $Panel
@onready var label_nombre    = $Panel/VBox/LabelNombre
@onready var label_texto     = $Panel/VBox/LabelTexto
@onready var container_opc   = $Panel/VBox/ContainerOpciones

var npc_actual = null
var zona_actual = null   # Para diálogos de transporte
var modo_transporte: bool = false
var _tiempo_bloqueado: bool = false   # Para pausar el reloj sólo una vez

func esta_visible() -> bool:
	return panel.visible

func _bloquear_tiempo():
	if not _tiempo_bloqueado:
		_tiempo_bloqueado = true
		TiempoLaboral.bloquear_tiempo()

# Navegación por teclado
var _opciones_actuales: Array = []
var _opcion_sel: int = 0

var _rtexto: RichTextLabel = null   # sustituye a label_texto (permite negritas)

func _ready():
	panel.visible = false
	_estilizar()

# Nombre del NPC grande y dorado + texto con soporte de negritas.
func _estilizar():
	label_nombre.add_theme_font_size_override("font_size", 24)
	label_nombre.add_theme_color_override("font_color", Color(1.0, 0.80, 0.30))
	label_nombre.add_theme_color_override("font_outline_color", Color(0.18, 0.10, 0.02))
	label_nombre.add_theme_constant_override("outline_size", 4)

	_rtexto = RichTextLabel.new()
	_rtexto.bbcode_enabled = true
	_rtexto.scroll_active = false
	_rtexto.custom_minimum_size = Vector2(0, 70)
	_rtexto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rtexto.add_theme_font_size_override("normal_font_size", 17)
	_rtexto.add_theme_font_size_override("bold_font_size", 17)
	var vbox = label_texto.get_parent()
	vbox.add_child(_rtexto)
	vbox.move_child(_rtexto, label_texto.get_index())
	label_texto.visible = false
	var fv = FontVariation.new()
	fv.base_font = _rtexto.get_theme_font("normal_font")
	fv.variation_embolden = 0.85
	_rtexto.add_theme_font_override("bold_font", fv)

# ─── Diálogo normal de NPC ───────────────────────────────────

func mostrar(npc, datos: Dictionary):
	_bloquear_tiempo()
	npc_actual       = npc
	zona_actual      = null
	modo_transporte  = false
	# Solo el nombre — antes se mostraba "Nombre (rol)" y quedaba recargado
	_renderizar(npc.npc_name, datos)

# ─── Diálogo de transporte (escaleras/ascensor) ───────────────

func mostrar_transporte(datos: Dictionary, zona: Area2D):
	_bloquear_tiempo()
	zona_actual     = zona
	npc_actual      = null
	modo_transporte = true
	_renderizar("🏢 Cambio de Piso", datos)

# ─── Renderizado común ───────────────────────────────────────

func _renderizar(titulo: String, datos: Dictionary):
	label_nombre.text = titulo
	_rtexto.text = SistemaMisiones.resaltar_bbcode(datos.get("texto", "..."))
	_opcion_sel = 0

	for btn in container_opc.get_children():
		btn.queue_free()

	_opciones_actuales = datos.get("opciones", [])

	if not _opciones_actuales.is_empty():
		for i in range(_opciones_actuales.size()):
			var opcion = _opciones_actuales[i]
			var btn = Button.new()
			# Prefijo numérico para indicar atajo de teclado
			var prefijo = "[%d] " % (i + 1) if i < 9 else ""
			btn.text = prefijo + _texto_opcion_limpio(opcion.get("texto", "..."))
			btn.custom_minimum_size = Vector2(0, 38)
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD
			btn.focus_mode = Control.FOCUS_NONE
			# NOTA: las opciones ya NO se colorean según reputación ni muestran
			# sus efectos (−min / +rep / recibe ítem). El jugador debe decidir
			# sin saber de antemano cuál es la opción "correcta".

			var idx = i
			btn.pressed.connect(func(): _elegir(idx))
			container_opc.add_child(btn)

		_resaltar(0)
	else:
		var btn = Button.new()
		btn.text = "[Enter] Continuar"
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(ocultar)
		container_opc.add_child(btn)

	var estaba_visible = panel.visible
	panel.visible = true
	if not estaba_visible:
		_animar_aparicion()

# Limpia las marcas internas del texto de una opción para no delatar cuál
# conviene elegir: quita los emojis de "correcta/incorrecta" del inicio
# (✅ ❌ 🤷 ...) y la etiqueta de efectos del final ("[−5 min, +8 rep, ...]").
func _texto_opcion_limpio(txt: String) -> String:
	var res = txt.strip_edges()
	for pre in ["✅", "❌", "🤷", "🤔", "❓", "⚠️"]:
		if res.begins_with(pre):
			res = res.trim_prefix(pre).strip_edges()
	var regex = RegEx.new()
	regex.compile("\\s*\\[[^\\]]*\\]\\s*$")
	var m = regex.search(res)
	if m != null:
		var tag = m.get_string().to_lower()
		if "min" in tag or "rep" in tag or "ítem" in tag or "item" in tag:
			res = res.substr(0, m.get_start()).strip_edges()
	return res

# Pequeña animación de aparición (pop-in)
func _animar_aparicion():
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.95, 0.95)
	panel.modulate.a = 0.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.16)

func _resaltar(idx: int):
	var botones = container_opc.get_children()
	for i in range(botones.size()):
		var btn = botones[i]
		if i == idx:
			btn.modulate = Color(1.3, 1.3, 0.6)   # dorado = seleccionado
		else:
			btn.modulate = Color(1, 1, 1)

func _input(event):
	if not panel.visible:
		return

	var botones = container_opc.get_children()

	# Sin opciones: Enter o Escape cierra
	if _opciones_actuales.is_empty():
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			ocultar()
			get_viewport().set_input_as_handled()
		return

	# Teclas numéricas 1-9: elegir directamente
	if event is InputEventKey and event.pressed and not event.echo:
		var kc = event.keycode
		if kc >= KEY_1 and kc <= KEY_9:
			var i = kc - KEY_1
			if i < _opciones_actuales.size():
				_elegir(i)
				get_viewport().set_input_as_handled()
				return

	# Flecha arriba/abajo para mover selección
	if event.is_action_pressed("ui_up"):
		_opcion_sel = max(0, _opcion_sel - 1)
		_resaltar(_opcion_sel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_opcion_sel = min(_opciones_actuales.size() - 1, _opcion_sel + 1)
		_resaltar(_opcion_sel)
		get_viewport().set_input_as_handled()
	# Enter confirma la opción seleccionada
	elif event.is_action_pressed("ui_accept"):
		_elegir(_opcion_sel)
		get_viewport().set_input_as_handled()
	# Escape cierra el diálogo sin elegir nada (antes elegía la última opción,
	# que en los diálogos de NPC suele ser la grosera con penalización de
	# reputación — era una trampa para el jugador).
	elif event.is_action_pressed("ui_cancel"):
		ocultar()
		get_viewport().set_input_as_handled()

func _elegir(index: int):
	if index >= _opciones_actuales.size():
		return
	var opcion = _opciones_actuales[index]

	if modo_transporte:
		# Cerrar SIEMPRE el diálogo, aunque la zona ya no sea válida (evita que
		# el menú de transporte se quede pegado en pantalla).
		var zona_ref = zona_actual
		ocultar()
		if is_instance_valid(zona_ref):
			zona_ref.usar_transporte(opcion.get("accion", "cancelar"))
		return

	if npc_actual != null:
		npc_actual.procesar_opcion(opcion)

func ocultar():
	panel.visible = false
	npc_actual   = null
	zona_actual  = null
	modo_transporte = false
	_opciones_actuales = []
	# Reanudar el reloj si este diálogo lo había pausado
	if _tiempo_bloqueado:
		_tiempo_bloqueado = false
		TiempoLaboral.desbloquear_tiempo()
