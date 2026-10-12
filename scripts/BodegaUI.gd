extends CanvasLayer

signal cerrado

# ─── Navegación por teclado ──────────────────────────────────
var _botones_nav: Array = []   # todos los Button visibles
var _foco: int = 0

@onready var panel     = $Panel
@onready var titulo    = $Panel/VBox/Titulo
@onready var contenido = $Panel/VBox/Contenido
@onready var btn_cerrar = $Panel/VBox/BtnCerrar

# Nombre del paquete de las entregas que tienen texto propio en los diálogos
# (JSON). El resto de paquetes se nombran "Insumo ×cantidad". La bodega decide
# por MISIÓN, no por insumo: antes dos misiones con el mismo insumo (sueros del
# miércoles, guantes del kit) se pisaban la configuración.
const NOMBRE_PAQUETE = {
	"conseguir_jeringas": "Paquete Jeringas 5ml ×20",
	"sueros_uci_urgente": "Sueros IV ×6 (UCI)",
	"kit_quirurgico":     "Kit Quirúrgico",
	"stock_analgesicos":  "Caja Paracetamol ×30",
	"gasas_laboratorio":  "Paquete Gasas estériles ×25",
}

const NPC_SCRIPT = preload("res://scripts/NPC.gd")   # para NPC_SCRIPT.UBICACIONES

func _ready():
	panel.visible = false
	btn_cerrar.pressed.connect(cerrar)
	btn_cerrar.focus_mode = Control.FOCUS_ALL
	_envolver_contenido_en_scroll()

# Mete 'contenido' dentro de un ScrollContainer para que la lista larga se
# desplace en vez de salirse de la pantalla (y el botón Cerrar quede siempre visible).
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
	# Escape cierra
	if event.is_action_pressed("ui_cancel"):
		cerrar()
		get_viewport().set_input_as_handled()
		return
	if _botones_nav.is_empty():
		return
	# Arriba / abajo navegan entre botones habilitados
	if event.is_action_pressed("ui_up"):
		_mover_foco(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_mover_foco(1)
		get_viewport().set_input_as_handled()
	# Enter activa el botón enfocado
	elif event.is_action_pressed("ui_accept"):
		if _foco < _botones_nav.size():
			var btn = _botones_nav[_foco]
			# El botón pudo ser liberado por un refresco previo: validar antes de usar
			if is_instance_valid(btn) and not btn.disabled:
				btn.pressed.emit()
		get_viewport().set_input_as_handled()

func _mover_foco(delta: int):
	var n = _botones_nav.size()
	if n == 0:
		return
	# Buscar siguiente botón válido y habilitado en la dirección dada
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
		if i == idx:
			btn.modulate = Color(1.3, 1.3, 0.55)
			# Hacer scroll al botón si está en un ScrollContainer
			var sc = _find_scroll_container(btn)
			if sc:
				await get_tree().process_frame
				sc.ensure_control_visible(btn)
		else:
			btn.modulate = Color(1, 1, 1)

func _find_scroll_container(node: Node) -> ScrollContainer:
	var p = node.get_parent()
	while p:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null

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
			hijo.focus_mode = Control.FOCUS_NONE  # teclado via _input, no Tab
			_botones_nav.append(hijo)
		else:
			_recoger_recursivo(hijo)

func abrir():
	panel.visible = true
	_refrescar()

func cerrar():
	panel.visible = false
	emit_signal("cerrado")

func _refrescar():
	# Vaciar la lista de navegación ANTES de liberar los botones: así, mientras se
	# reconstruye la interfaz, ninguna pulsación de tecla accede a botones liberados.
	_botones_nav = []
	_foco = 0
	for c in contenido.get_children():
		c.queue_free()

	titulo.text = "BODEGA — Gestión de Insumos"

	# ─── Sección 1: Misiones activas que necesitan insumos ────────
	var misiones_activas = _get_misiones_con_insumos()
	if not misiones_activas.is_empty():
		_sep("🎯  MISIONES ACTIVAS — PREPARAR ENTREGA", Color(0.95, 0.75, 0.15))
		for datos in misiones_activas:
			_fila_mision(datos)
		contenido.add_child(HSeparator.new())

	# ─── Sección 2: Inventario completo ───────────────────────────
	_sep("📦  STOCK ACTUAL", Color(0.6, 0.8, 0.6))
	var insumos = GameManager.inventario.insumos
	var prev_cat = ""
	for nombre in insumos:
		var item = insumos[nombre]
		if item.categoria != prev_cat:
			prev_cat = item.categoria
			var sub = Label.new()
			sub.text = "── " + item.categoria.to_upper()
			sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			contenido.add_child(sub)

		var hbox = HBoxContainer.new()
		contenido.add_child(hbox)

		var nivel = GameManager.inventario.get_nivel_stock(nombre)
		var ic = {"normal":"🟢","bajo":"🟡","critico":"🔴","agotado":"⛔"}.get(nivel,"?")
		var lbl = Label.new()
		lbl.text = "%s %-26s %3d uds.  Cal:%d%%" % [ic, nombre, item.cantidad, item.calidad]
		lbl.custom_minimum_size = Vector2(420, 0)
		hbox.add_child(lbl)

		# Botón "Reponer" solo para stock bajo/crítico
		if nivel in ["bajo", "critico", "agotado"]:
			var btn = Button.new()
			btn.text = "Reponer +20"
			btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
			var n = nombre
			btn.pressed.connect(func(): _reponer(n))
			hbox.add_child(btn)

	# ─── Sección 3: Caducados e informes ─────────────────────────
	contenido.add_child(HSeparator.new())
	var btn_cad = Button.new()
	btn_cad.text = "🗑  Retirar todos los insumos caducados"
	btn_cad.pressed.connect(_retirar_caducados)
	contenido.add_child(btn_cad)

	var btn_inf = Button.new()
	btn_inf.text = "📋  Generar informe de inventario"
	btn_inf.pressed.connect(_generar_informe)
	contenido.add_child(btn_inf)

	# Reconstruir lista de botones navegables
	await get_tree().process_frame
	_recoger_botones()

# ─── Helpers ────────────────────────────────────────────────────

func _get_misiones_con_insumos() -> Array:
	var resultado = []
	if not GameManager.misiones:
		return resultado
	for id in GameManager.misiones.misiones_activas:
		var m = GameManager.misiones.misiones[id]
		for obj in m.objetivos:
			if obj.tipo == "conseguir_insumo" and not obj.completado:
				resultado.append({ "mision": m, "objetivo": obj })
	return resultado

func _fila_mision(datos: Dictionary):
	var m        = datos.mision
	var obj      = datos.objetivo
	var nombre   = obj.target
	var cantidad = obj.cantidad
	var entrega  = m.get("requiere_entrega", false)
	var destino  = m.npc_origen

	var vbox = VBoxContainer.new()
	contenido.add_child(vbox)

	var lbl_titulo = Label.new()
	lbl_titulo.text = "📋 %s" % m.titulo
	if entrega:
		lbl_titulo.text += "   ➡ para %s" % destino
	lbl_titulo.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
	vbox.add_child(lbl_titulo)

	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)

	var tiene_stock = GameManager.inventario.tiene_suficiente(nombre, cantidad)
	var cant_actual = GameManager.inventario.insumos.get(nombre, {}).get("cantidad", 0)
	var lbl = Label.new()
	if tiene_stock:
		lbl.text = "   ✅ %s  ×%d  — suficiente en bodega" % [nombre, cantidad]
		lbl.add_theme_color_override("font_color", Color(0.5, 0.95, 0.5))
	else:
		lbl.text = "   ⚠️ %s  ×%d  — solo hay %d en bodega" % [nombre, cantidad, cant_actual]
		lbl.add_theme_color_override("font_color", Color(0.95, 0.5, 0.3))
	lbl.custom_minimum_size = Vector2(380, 0)
	hbox.add_child(lbl)

	var btn = Button.new()
	if not entrega:
		btn.text = "✅ Completar pedido"
	elif PlayerInventory.get_datos().get("destino", "") == destino:
		btn.text = "➕ Añadir al paquete"
		btn.tooltip_text = "Ya llevas un paquete para %s: se junta todo en un solo viaje." % destino
	else:
		btn.text = "📦 Preparar para entregar"
		btn.tooltip_text = "Lleva el paquete a: %s (%s)" % [destino, NPC_SCRIPT.UBICACIONES.get(destino, "?")]

	btn.disabled = not tiene_stock
	if not tiene_stock:
		btn.tooltip_text = "Necesitas %d %s pero solo hay %d" % [cantidad, nombre, cant_actual]
		# Mostrar botón de reponer urgente
		var btn_rep = Button.new()
		btn_rep.text = "⬆️ Reponer stock"
		btn_rep.pressed.connect(func(): _reponer(nombre))
		hbox.add_child(btn_rep)

	var m_id = m.id
	btn.pressed.connect(func(): _preparar_mision(m_id, nombre, cantidad))
	hbox.add_child(btn)

func _preparar_mision(m_id: String, nombre_insumo: String, cantidad: int):
	var m = SistemaMisiones.misiones.get(m_id)
	if m == null or m.estado != SistemaMisiones.Estado.ACTIVA:
		_refrescar()
		return
	if not GameManager.inventario.tiene_suficiente(nombre_insumo, cantidad):
		GameManager.hud.mostrar_aviso("⚠️ Stock insuficiente para preparar el pedido.")
		return

	# Manos: se puede seguir llenando un paquete para la MISMA persona, pero no
	# llevar dos encargos para personas distintas. Se comprueba ANTES de gastar tiempo.
	var entrega = m.get("requiere_entrega", false)
	if entrega and PlayerInventory.tiene() \
			and PlayerInventory.get_datos().get("destino", "") != m.npc_origen:
		GameManager.hud.mostrar_aviso(
			"⚠️ Ya llevas '%s'. Entrégalo primero." % PlayerInventory.get_nombre())
		return

	# Preparar insumos cuesta tiempo (contar, empacar, etiquetar)
	TiempoLaboral.descontar_tiempo(11, "Preparando insumos en bodega")
	if m.estado != SistemaMisiones.Estado.ACTIVA:
		# Esos 11 minutos hicieron vencer la misión: no se gasta stock
		GameManager.hud.mostrar_aviso("⏰ Se acabó el plazo de '%s' mientras preparabas el pedido." % m.titulo)
		_refrescar()
		return
	GameManager.inventario.usar_insumo(nombre_insumo, cantidad)
	SistemaMisiones.completar_objetivo_insumo_de_mision(m_id, nombre_insumo)

	if entrega:
		_empaquetar(m)
	else:
		GameManager.hud.mostrar_aviso("✅ Pedido completado en bodega.")
	_refrescar()

# Mete el encargo en el paquete que lleva el jugador (o crea uno nuevo).
func _empaquetar(m: Dictionary):
	var destino = m.npc_origen
	var misiones: Array = []
	if PlayerInventory.tiene():
		misiones = PlayerInventory.get_datos().get("misiones", []).duplicate()
	var nuevo = misiones.is_empty()
	if not misiones.has(m.id):
		misiones.append(m.id)
	var nombre = _nombre_paquete(misiones)
	PlayerInventory.tomar(nombre, "Llevar a: %s (%s)" % [destino, NPC_SCRIPT.UBICACIONES.get(destino, "?")],
		{ "destino": destino, "misiones": misiones })
	var faltan = SistemaMisiones.insumos_faltantes(misiones)
	if not faltan.is_empty():
		GameManager.hud.mostrar_aviso("📦 %s — aún falta: %s" % [nombre, ", ".join(PackedStringArray(faltan))])
	elif nuevo:
		GameManager.hud.mostrar_aviso("📦 Tomaste: %s\n➡ Llévalo a %s" % [nombre, destino])
	else:
		GameManager.hud.mostrar_aviso("➕ Añadido al paquete: %s\n➡ Llévalo a %s" % [nombre, destino])

func _nombre_paquete(misiones: Array) -> String:
	if misiones.size() > 1:
		return "Pedido (%d encargos)" % misiones.size()
	var m = SistemaMisiones.misiones[misiones[0]]
	var base = NOMBRE_PAQUETE.get(m.id, "")
	if base == "":
		var obj = m.objetivos[0]
		base = "%s ×%d" % [obj.target, obj.cantidad]
	# Misiones de varios insumos (el kit): mostrar cuánto lleva preparado
	var total = m.objetivos.size()
	if total > 1:
		var hechos = m.objetivos.filter(func(o): return o.completado).size()
		if hechos < total:
			base += " (%d/%d)" % [hechos, total]
	return base

func _reponer(nombre: String):
	if not GameManager.inventario.insumos.has(nombre):
		return
	var item = GameManager.inventario.insumos[nombre]
	GameManager.inventario.agregar_insumo(nombre, item.categoria, 20, 100, item.caducidad_dias)
	TiempoLaboral.descontar_tiempo(7, "Reponiendo stock en bodega")
	GameManager.hud.mostrar_aviso("📦 +20 %s añadidos a bodega." % nombre)
	_refrescar()

func _retirar_caducados():
	var retirados = 0
	var caducados = []
	for nombre in GameManager.inventario.insumos:
		if GameManager.inventario.insumos[nombre].calidad <= 0:
			caducados.append(nombre)
	for nombre in caducados:
		GameManager.inventario.retirar_insumo(nombre)  # Se elimina del listado
		retirados += 1
	# Esta acción ES la misión: auto-aceptarla aunque ningún NPC la haya ofrecido
	# (la misión de caducados tiene origen "Sistema", que no es un personaje real).
	_auto_aceptar_si_pendiente("insumos_caducados")
	_auto_aceptar_si_pendiente("auditoria_inventario")
	TiempoLaboral.descontar_tiempo(8, "Retirando insumos caducados")
	SistemaMisiones.completar_objetivo("insumos_caducados", "revisar_caducidades")
	# BUGFIX: antes completaba TODA la auditoría del director aquí, con lo que
	# el paso de "generar informe" se regalaba. Solo se completa el objetivo
	# de caducidades; el informe sigue siendo el otro paso de la auditoría.
	SistemaMisiones.completar_objetivo("auditoria_inventario", "revisar_caducidades")
	GameManager.hud.mostrar_aviso("🗑 %d tipos de insumos caducados retirados." % retirados)
	_refrescar()

func _generar_informe():
	# Genera el informe de inventario: completa las misiones de revisión de stock.
	_auto_aceptar_si_pendiente("informe_semanal")
	_auto_aceptar_si_pendiente("auditoria_inventario")
	TiempoLaboral.descontar_tiempo(9, "Generando informe de inventario")
	SistemaMisiones.completar_objetivo("informe_semanal", "revisar_inventario")
	SistemaMisiones.completar_todos_objetivos("informe_semanal")
	SistemaMisiones.completar_objetivo("auditoria_inventario", "revisar_inventario")
	GameManager.hud.mostrar_aviso("📋 Informe de inventario generado.")
	_refrescar()

func _auto_aceptar_si_pendiente(m_id: String):
	if SistemaMisiones.misiones.has(m_id) and \
	   SistemaMisiones.misiones[m_id].estado == SistemaMisiones.Estado.PENDIENTE:
		SistemaMisiones.aceptar_mision(m_id)

func _sep(texto: String, color: Color = Color.GRAY):
	var lbl = Label.new()
	lbl.text = texto
	lbl.add_theme_color_override("font_color", color)
	contenido.add_child(lbl)
