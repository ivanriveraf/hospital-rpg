extends CanvasLayer

signal cerrado

@onready var panel      = $Panel
@onready var titulo_lbl = $Panel/VBox/Titulo
@onready var contenido  = $Panel/VBox/Contenido
@onready var btn_cerrar = $Panel/VBox/BtnCerrar

# ─── Navegación por teclado (igual que la bodega) ────────────
var _botones_nav: Array = []
var _foco: int = 0

# Recetas del día (se reinician al nuevo día)
var recetas: Array = [
	{ "id": "rx001", "paciente": "Don Roberto",     "medicamento": "Paracetamol 500mg", "dosis": 3,
	  "mision_id": "medicacion_roberto", "item_entrega": "Medicación de Don Roberto",
	  "npc_destino": "Don Roberto (Piso 3, Hab. 105)", "dispensada": false },

	{ "id": "rx002", "paciente": "Sra. Carmen",     "medicamento": "Ibuprofeno 400mg",  "dosis": 2,
	  "mision_id": "receta_urgente",  "item_entrega": "Medicación de Sra. Carmen",
	  "npc_destino": "Sra. Carmen (Piso 3, Hab. 112)", "dispensada": false },

	{ "id": "rx003", "paciente": "Niño Martínez",   "medicamento": "Paracetamol 500mg", "dosis": 5,
	  "mision_id": "", "item_entrega": "",
	  "npc_destino": "", "dispensada": false },

	{ "id": "rx004", "paciente": "Dr. Vargas (UCI)","medicamento": "Suero IV 500ml",    "dosis": 4,
	  "mision_id": "", "item_entrega": "",
	  "npc_destino": "", "dispensada": false },
]

func _ready():
	panel.visible = false
	btn_cerrar.pressed.connect(cerrar)
	btn_cerrar.focus_mode = Control.FOCUS_NONE
	_envolver_contenido_en_scroll()
	# BUGFIX: el comentario decía "se reinician al nuevo día" pero nunca se
	# reiniciaban. Las recetas no dispensadas vuelven a estar disponibles
	# (importante para la medicación de Don Roberto, que es del jueves).
	TiempoLaboral.dia_iniciado.connect(_on_nuevo_dia)

func _on_nuevo_dia(_dia: int, _nombre: String):
	for receta in recetas:
		# Solo se restauran las que tienen misión asociada y aún no se entregaron
		if receta.mision_id != "" and SistemaMisiones.misiones.has(receta.mision_id):
			var m = SistemaMisiones.misiones[receta.mision_id]
			if m.estado != SistemaMisiones.Estado.COMPLETADA:
				receta.dispensada = false

# Mete 'contenido' dentro de un ScrollContainer para que la lista no se salga
func _envolver_contenido_en_scroll():
	var vbox = contenido.get_parent()
	var idx = contenido.get_index()
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContenido"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	vbox.move_child(scroll, idx)
	vbox.remove_child(contenido)
	scroll.add_child(contenido)
	contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _input(event):
	if not panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		cerrar()
		get_viewport().set_input_as_handled()
		return
	if _botones_nav.is_empty():
		return
	if event.is_action_pressed("ui_up"):
		_mover_foco(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_mover_foco(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _foco < _botones_nav.size():
			var btn = _botones_nav[_foco]
			if is_instance_valid(btn) and not btn.disabled:
				btn.pressed.emit()
		get_viewport().set_input_as_handled()

func _mover_foco(delta: int):
	var n = _botones_nav.size()
	if n == 0:
		return
	var intentos = 0
	var nuevo = _foco
	while intentos < n:
		nuevo = (nuevo + delta + n) % n
		var b = _botones_nav[nuevo]
		if is_instance_valid(b) and not b.disabled:
			break
		intentos += 1
	_set_foco(nuevo)

func _set_foco(idx: int):
	_foco = idx
	for i in range(_botones_nav.size()):
		var btn = _botones_nav[i]
		if not is_instance_valid(btn):
			continue
		btn.modulate = Color(1.3, 1.3, 0.55) if i == idx else Color(1, 1, 1)

func _recoger_botones():
	_botones_nav = []
	_recoger_recursivo(contenido)
	_botones_nav.append(btn_cerrar)
	_foco = 0
	if not _botones_nav.is_empty():
		_set_foco(0)

func _recoger_recursivo(nodo: Node):
	for hijo in nodo.get_children():
		if hijo is Button:
			hijo.focus_mode = Control.FOCUS_NONE
			_botones_nav.append(hijo)
		else:
			_recoger_recursivo(hijo)

func abrir():
	panel.visible = true
	_verificar_misiones_ya_dispensadas()
	_refrescar()

# Si el jugador dispensó recetas antes de aceptar la misión, la completa retroactivamente
func _verificar_misiones_ya_dispensadas():
	for receta in recetas:
		if not receta.dispensada or receta.mision_id == "" or receta.item_entrega != "":
			continue
		var m_id = receta.mision_id
		if not SistemaMisiones.misiones.has(m_id):
			continue
		var m = SistemaMisiones.misiones[m_id]
		if m.estado == SistemaMisiones.Estado.PENDIENTE:
			SistemaMisiones.aceptar_mision(m_id)
		if m.estado == SistemaMisiones.Estado.ACTIVA:
			SistemaMisiones.completar_objetivo(m_id, "dispensar_medicamento")

func cerrar():
	panel.visible = false
	emit_signal("cerrado")

func _refrescar():
	# Vaciar la navegación antes de liberar los botones (evita usar referencias liberadas)
	_botones_nav = []
	_foco = 0
	for c in contenido.get_children():
		c.queue_free()

	titulo_lbl.text = "FARMACIA — Dispensación de Medicamentos"

	# ─── Stock disponible ─────────────────────────────────────
	var hdr = Label.new()
	hdr.text = "── STOCK DE MEDICAMENTOS ──"
	hdr.add_theme_color_override("font_color", Color(0.4, 0.85, 0.55))
	contenido.add_child(hdr)

	for nombre in GameManager.inventario.insumos:
		var item = GameManager.inventario.insumos[nombre]
		if item.categoria == "medicamentos" or item.categoria == "sueros":
			var nivel = GameManager.inventario.get_nivel_stock(nombre)
			var ic = {"normal":"🟢","bajo":"🟡","critico":"🔴","agotado":"⛔"}.get(nivel,"?")
			var lbl = Label.new()
			lbl.text = "%s %-28s %d uds." % [ic, nombre, item.cantidad]
			contenido.add_child(lbl)

	contenido.add_child(HSeparator.new())

	# ─── Recetas pendientes ───────────────────────────────────
	var hdr2 = Label.new()
	hdr2.text = "── RECETAS PENDIENTES ──"
	hdr2.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	contenido.add_child(hdr2)

	var hay_pendientes = false
	for receta in recetas:
		if not receta.dispensada:
			hay_pendientes = true
			_fila_receta(receta)

	if not hay_pendientes:
		var lbl = Label.new()
		lbl.text = "✅ No hay recetas pendientes."
		lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		contenido.add_child(lbl)

	contenido.add_child(HSeparator.new())

	# ─── Recetas dispensadas ──────────────────────────────────
	var hdr3 = Label.new()
	hdr3.text = "── DISPENSADAS HOY ──"
	hdr3.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	contenido.add_child(hdr3)

	for receta in recetas:
		if receta.dispensada:
			var lbl = Label.new()
			lbl.text = "✅ %s — %s ×%d" % [receta.paciente, receta.medicamento, receta.dosis]
			lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 0.45))
			contenido.add_child(lbl)

	# Reconstruir la lista de botones navegables con teclado
	await get_tree().process_frame
	_recoger_botones()

func _fila_receta(receta: Dictionary):
	var vbox = VBoxContainer.new()
	contenido.add_child(vbox)

	# Info de la receta
	var lbl = Label.new()
	lbl.text = "👤 %-20s  %s ×%d" % [receta.paciente, receta.medicamento, receta.dosis]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(lbl)

	# Destino de entrega si aplica
	if receta.npc_destino != "":
		var dest = Label.new()
		dest.text = "   📍 Llevar a: %s" % receta.npc_destino
		dest.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		vbox.add_child(dest)

	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)

	var tiene = GameManager.inventario.tiene_suficiente(receta.medicamento, receta.dosis)
	var btn = Button.new()
	btn.text = "💊 Dispensar" if tiene else "⚠️ Sin stock"
	btn.disabled = not tiene
	var rx_id = receta.id
	btn.pressed.connect(func(): _dispensar(rx_id))
	hbox.add_child(btn)

func _dispensar(rx_id: String):
	var receta = null
	for r in recetas:
		if r.id == rx_id:
			receta = r
			break
	if receta == null or receta.dispensada:
		return

	# Si la receta requiere LLEVAR el medicamento a alguien y ya llevas algo en las
	# manos, no la dispenses todavía (si no, se gastaría el stock y no podrías
	# recoger el ítem). Entrega primero lo que llevas.
	if receta.item_entrega != "" and PlayerInventory.tiene():
		GameManager.hud.mostrar_aviso(
			"⚠️ Ya llevas '%s'. Entrégalo primero y vuelve a dispensar." % PlayerInventory.get_nombre())
		return

	if not GameManager.inventario.usar_insumo(receta.medicamento, receta.dosis):
		GameManager.hud.mostrar_aviso("⚠️ Stock insuficiente para dispensar.")
		return

	receta.dispensada = true
	GameManager.ganar_experiencia(10)
	TiempoLaboral.descontar_tiempo(6, "Dispensando en farmacia")

	# Si la receta tiene misión, asegurar que quede ACTIVA. Si además requiere
	# entrega (item_entrega), la misión se COMPLETARÁ al entregar el medicamento
	# al paciente, no aquí al dispensar.
	if receta.mision_id != "" and SistemaMisiones.misiones.has(receta.mision_id) and \
	   SistemaMisiones.misiones[receta.mision_id].estado == SistemaMisiones.Estado.PENDIENTE:
		SistemaMisiones.aceptar_mision(receta.mision_id)

	# Completar objetivo de misión directa (sin entrega)
	if receta.mision_id != "" and receta.item_entrega == "":
		var m_id = receta.mision_id
		# Auto-aceptar si el jugador no habló antes con el NPC que la ofrece
		if SistemaMisiones.misiones.has(m_id) and \
		   SistemaMisiones.misiones[m_id].estado == SistemaMisiones.Estado.PENDIENTE:
			SistemaMisiones.aceptar_mision(m_id)
		SistemaMisiones.completar_objetivo(m_id, "dispensar_medicamento")
		GameManager.hud.mostrar_aviso("✅ Receta dispensada — misión completada.")

	# Crear ítem de entrega si hay NPC destino
	elif receta.item_entrega != "":
		if PlayerInventory.tiene():
			GameManager.hud.mostrar_aviso(
				"⚠️ Ya llevas '%s'. Entrega primero ese ítem." % PlayerInventory.get_nombre())
			# Aun así marcar como dispensada
		else:
			PlayerInventory.tomar(receta.item_entrega,
				"Llevar a: " + receta.npc_destino)
			GameManager.hud.mostrar_aviso(
				"💊 Tomaste: %s\n➡ Llévalo a %s" % [receta.item_entrega, receta.npc_destino])

	else:
		# Receta sin misión ni entrega (genérica)
		GameManager.hud.mostrar_aviso("✅ Receta dispensada correctamente.")

	_refrescar()
