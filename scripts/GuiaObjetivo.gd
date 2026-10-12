extends Node2D
# Guía de objetivo (hijo del jugador). Una flecha orbita al jugador y apunta a lo
# siguiente que conviene hacer: a quién entregar lo que llevas, el siguiente paso
# de una cadena, la bodega, etc. Si el destino está en otro piso, apunta a las
# escaleras y marca el piso. Además muestra un panel "Objetivo" en el HUD.
# Tecla G: mostrar / ocultar.

const NPC_SCRIPT = preload("res://scripts/NPC.gd")

const CENTRO := Vector2(0, -22)    # centro del cuerpo (los pies están en el origen)
const RADIO := Vector2(36, 38)     # órbita elíptica: libra la cabeza y los pies
const DIST_LLEGADA := 70.0         # más cerca que esto, la flecha se esconde

const ZONAS = {
	"bodega":      { "piso": 1, "lugar": "Bodega (Piso 1)" },
	"farmacia":    { "piso": 1, "lugar": "Farmacia (Piso 1)" },
	"laboratorio": { "piso": 2, "lugar": "Laboratorio (Piso 2)" },
}

var activa := true
var _destinatarios := {}   # ítem → NPC que lo recibe
var _piso_npc := {}        # NPC → piso (el de su archivo de diálogos)
var _ofrecidas := {}       # misiones que algún NPC ofrece hablando con él
var _obj := {}             # { texto, mision, lugar, piso, y "npc" o "zona" }
var _dir := Vector2.ZERO
var _mostrar_flecha := false
var _t := 0.0

var _panel: PanelContainer = null
var _texto: RichTextLabel = null
var _texto_actual := ""

func _ready():
	z_index = 10   # por encima de los personajes
	_leer_dialogos()
	_crear_panel()

# Los JSON de diálogos ya dicen quién recibe cada ítem y qué misión ofrece cada
# NPC; y cada archivo corresponde a un piso.
func _leer_dialogos():
	for piso in [1, 2, 3]:
		var f = FileAccess.open("res://data/dialogos_piso%d.json" % piso, FileAccess.READ)
		if f == null:
			continue
		var datos = JSON.parse_string(f.get_as_text())
		if typeof(datos) != TYPE_DICTIONARY:
			continue
		for clave in datos:
			var e = datos[clave]
			var npc = e.get("nombre", "")
			if npc == "":
				continue
			_piso_npc[npc] = piso
			if e.has("item_acepta"):
				_destinatarios[e.item_acepta] = npc
			for it in e.get("items_entrega", {}):
				_destinatarios[it] = npc
			for d in e.get("dialogos", []):
				for op in d.get("opciones", []):
					if op.has("mision"):
						_ofrecidas[op.mision] = true

func _crear_panel():
	var hud = GameManager.hud
	if hud == null:
		return
	_panel = PanelContainer.new()
	_panel.name = "PanelObjetivo"
	_panel.position = Vector2(1064, 160)
	_panel.custom_minimum_size = Vector2(210, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.18, 0.92)
	sb.set_corner_radius_all(10)
	sb.border_width_left = 4
	sb.border_color = Color(1.0, 0.80, 0.25)
	sb.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", sb)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vb)

	var titulo = Label.new()
	titulo.text = "🎯 OBJETIVO      [G] ocultar"
	titulo.add_theme_font_size_override("font_size", 12)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	vb.add_child(titulo)

	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.scroll_active = false
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(190, 0)
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.add_theme_font_size_override("normal_font_size", 14)
	vb.add_child(_texto)

	_panel.visible = false
	hud.add_child(_panel)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		activa = not activa
		if GameManager.hud:
			GameManager.hud.mostrar_aviso("🧭 Guía %s. Pulsa G para %s." % [
				"activada" if activa else "oculta", "ocultarla" if activa else "mostrarla"])

func _process(delta):
	_t += delta
	_obj = _calcular_objetivo() if activa and TiempoLaboral.activo else {}
	_actualizar_panel()
	_actualizar_flecha()
	queue_redraw()

# ─── ¿Qué toca hacer ahora? ──────────────────────────────────

func _calcular_objetivo() -> Dictionary:
	# 1. Lo que llevas en las manos manda
	if PlayerInventory.tiene():
		var item = PlayerInventory.get_nombre()
		var datos = PlayerInventory.get_datos()
		var npc = datos.get("destino", _destinatarios.get(item, ""))
		var faltan = SistemaMisiones.insumos_faltantes(datos.get("misiones", []))
		if not faltan.is_empty():
			return _a_zona("bodega", "Completa el paquete: falta %s" % faltan[0], item)
		# Aún en el piso de la bodega y hay otro encargo para la misma persona: juntarlo
		if datos.has("misiones") and FloorManager.piso_actual == ZONAS.bodega.piso:
			var extra = _encargo_pendiente_para(npc, datos.misiones)
			if extra != "":
				return _a_zona("bodega", "Añade al paquete %s: también es para %s" % [extra, npc], item)
		if npc != "":
			return _a_npc(npc, "Entrega %s a %s" % [item, npc], "")
	# 2. Misiones de hoy, de la más urgente a la menos urgente
	var hoy = TiempoLaboral.dia_semana
	var lista = []
	for id in SistemaMisiones.misiones:
		var m = SistemaMisiones.misiones[id]
		if m.estado == SistemaMisiones.Estado.ACTIVA or \
				(m.estado == SistemaMisiones.Estado.PENDIENTE and m.dia_disponible == hoy):
			lista.append(m)
	lista.sort_custom(_mas_urgente)
	for m in lista:
		var o = _objetivo_de(m)
		if not o.is_empty():
			return o
	return {}

# Primer insumo sin preparar de otra entrega activa para 'npc' que no va en el paquete
func _encargo_pendiente_para(npc: String, en_paquete: Array) -> String:
	for id in SistemaMisiones.misiones_activas:
		var m = SistemaMisiones.misiones[id]
		if m.npc_origen != npc or not m.get("requiere_entrega", false) or en_paquete.has(id):
			continue
		for obj in m.objetivos:
			if obj.tipo == "conseguir_insumo" and not obj.completado:
				return "%d × %s" % [obj.cantidad, obj.target]
	return ""

func _mas_urgente(a: Dictionary, b: Dictionary) -> bool:
	if a.critica != b.critica:
		return a.critica
	if a.hora_limite != b.hora_limite:
		return a.hora_limite < b.hora_limite
	return a.estado == SistemaMisiones.Estado.ACTIVA and b.estado != SistemaMisiones.Estado.ACTIVA

func _objetivo_de(m: Dictionary) -> Dictionary:
	# Sin aceptar, y se acepta hablando con quien la ofrece
	if m.estado == SistemaMisiones.Estado.PENDIENTE and _ofrecidas.has(m.id) \
			and _piso_npc.has(m.npc_origen):
		return _a_npc(m.npc_origen, "Habla con %s: tiene una misión para ti" % m.npc_origen, m.titulo)
	# El primer objetivo sin cumplir (las cadenas van en orden)
	for obj in m.objetivos:
		if obj.completado:
			continue
		match obj.tipo:
			"hablar_cadena", "hablar_npc":
				var t = obj.get("target", "")
				if _piso_npc.has(t):
					return _a_npc(t, "Habla con %s" % t, m.titulo)
			"conseguir_insumo":
				return _a_zona("bodega", "Prepara %d × %s en la bodega" % [obj.cantidad, obj.target], m.titulo)
			"revisar_caducidades":
				return _a_zona("bodega", "Retira los insumos caducados en la bodega", m.titulo)
			"revisar_inventario":
				return _a_zona("bodega", "Genera el informe de inventario en la bodega", m.titulo)
			"dispensar_medicamento":
				return _a_zona("farmacia", "Dispensa la receta en la farmacia", m.titulo)
			"llevar_muestras":
				return _a_zona("laboratorio", "Lleva las muestras al laboratorio", m.titulo)
		return {}
	return {}

func _a_npc(npc: String, texto: String, mision: String) -> Dictionary:
	return { "npc": npc, "texto": texto, "mision": mision, "piso": _piso_npc.get(npc, FloorManager.piso_actual),
		"lugar": NPC_SCRIPT.UBICACIONES.get(npc, "Piso %d" % _piso_npc.get(npc, 1)) }

func _a_zona(zona: String, texto: String, mision: String) -> Dictionary:
	return { "zona": zona, "texto": texto, "mision": mision,
		"piso": ZONAS[zona].piso, "lugar": ZONAS[zona].lugar }

# ─── Dónde está el destino en este piso ──────────────────────

func _posicion_destino() -> Variant:
	var piso = FloorManager.piso_actual
	var zona: Node2D = null
	if _obj.piso != piso:
		zona = _buscar_zona("escaleras_subir" if _obj.piso > piso else "escaleras_bajar")
	elif _obj.has("npc"):
		for n in get_tree().get_nodes_in_group("npc"):
			if is_instance_valid(n) and not n.is_queued_for_deletion() and n.get("npc_name") == _obj.npc:
				return n.global_position
		return null
	else:
		zona = _buscar_zona(_obj.zona)
	if zona == null:
		return null
	return zona.global_position

func _buscar_zona(tipo: String) -> Node2D:
	var cont = FloorManager.floor_container
	if cont == null:
		return null
	for piso in cont.get_children():
		if piso.is_queued_for_deletion():
			continue
		var zonas = piso.get_node_or_null("Zonas")
		if zonas == null:
			continue
		for z in zonas.get_children():
			if z.get("tipo") == tipo:
				return z
	return null

# ─── Dibujo ──────────────────────────────────────────────────

func _actualizar_flecha():
	_mostrar_flecha = false
	if _obj.is_empty():
		return
	var destino = _posicion_destino()
	if destino == null:
		return
	var v: Vector2 = destino - global_position
	if v.length() < DIST_LLEGADA:
		return
	_dir = v.normalized()
	_mostrar_flecha = true

func _draw():
	if not _mostrar_flecha:
		return
	var oscuro = Color(0.15, 0.10, 0.02, 0.9)
	var base = CENTRO + Vector2(_dir.x * RADIO.x, _dir.y * RADIO.y) + _dir * 2.5 * sin(_t * 6.0)
	# Flecha con punta y tallo (un triángulo solo no se lee bien en diagonal)
	var punta = base + _dir * 14.0
	var p = _dir.orthogonal()
	var cola = base - _dir * 9.0
	var forma = PackedVector2Array([punta, base + p * 7.0, base + p * 2.5, cola + p * 2.5,
		cola - p * 2.5, base - p * 2.5, base - p * 7.0])
	draw_colored_polygon(forma, Color(1.0, 0.82, 0.25))
	forma.append(punta)
	draw_polyline(forma, oscuro, 1.5)
	# Destino en otro piso: etiqueta "▲ P3" junto a la punta
	var piso = FloorManager.piso_actual
	if _obj.piso != piso:
		var tag = ("▲ P%d" if _obj.piso > piso else "▼ P%d") % _obj.piso
		var pos = punta + _dir * 14.0 + Vector2(-20, 5)
		var font = ThemeDB.fallback_font
		draw_string_outline(font, pos, tag, HORIZONTAL_ALIGNMENT_CENTER, 40, 12, 4, oscuro)
		draw_string(font, pos, tag, HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color(1.0, 0.92, 0.55))

func _actualizar_panel():
	if _panel == null:
		return
	var hud = GameManager.hud
	var tapado = hud != null and (hud.panel_inv.visible or hud.panel_mis.visible)
	_panel.visible = not _obj.is_empty() and not tapado
	if _obj.is_empty():
		return
	# Nombres e ítems resaltados en dorado
	var txt = SistemaMisiones.resaltar_bbcode(_obj.texto) \
		.replace("[b]", "[color=#ffd36b]").replace("[/b]", "[/color]")
	txt += "\n[font_size=12][color=#9fb3c8]📍 %s[/color][/font_size]" % _obj.lugar
	var piso = FloorManager.piso_actual
	if _obj.piso > piso:
		txt += "\n[color=#ffe08a]▲ Sube al Piso %d[/color]" % _obj.piso
	elif _obj.piso < piso:
		txt += "\n[color=#ffe08a]▼ Baja al Piso %d[/color]" % _obj.piso
	if _obj.mision != "":
		txt += "\n[font_size=11][color=#7f93a8]%s[/color][/font_size]" % _obj.mision
	if txt != _texto_actual:
		_texto_actual = txt
		_texto.text = txt
