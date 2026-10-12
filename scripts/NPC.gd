extends CharacterBody2D

signal dialogue_started(npc)
signal dialogue_ended(npc)
signal reputation_changed(npc_name, new_value)

@export var npc_name: String = "Personaje"
@export var npc_role: String = "Médico"
@export var initial_reputation: int = 50
@export var npc_color: Color = Color(0.9, 0.4, 0.4)
@export var dialogo_archivo: String = "res://data/dialogos_piso1.json"
@export var item_necesario: String = ""   # ítem que acepta; también se carga del JSON
@export var usar_sprites: bool = true     # si existe res://assets/sprites/npc/<rol>.png lo usa; si no, dibuja la figura por código
@export var escala_sprite: int = 1        # pixel art: solo escalas enteras

# Las figuras de este script se dibujan con los pies en y = PIE_Y. En _draw se
# suben PIE_Y para que el origen del nodo sea el punto de apoyo (orden por Y).
const PIE_Y := 18.0

# Estado (persiste en GameManager al cambiar piso)
var mision_ya_ofrecida: bool = false
var mision_completada_flag: bool = false

# Datos del JSON
var dialogue_data: Array = []
var texto_recibe_item: String = ""
var mision_entrega_id: String = ""
var texto_completado: String = ""   # Frase al detectar que la misión fue completada
var texto_fallido: String = ""      # Frase si la misión de HOY de este NPC falló

# Sistema multi-entrega: { nombre_item → { "texto", "mision", "texto_completado" } }
var items_entrega: Dictionary = {}
var items_ya_entregados: Array = []  # para saber cuándo están todas completadas

# Lista de ítems alternativos que acepta este NPC (asignada desde el piso)
var items_aceptados: Array = []

# Referencias a hijos
var label_name: Label = null
var interact_hint: Label = null
var reputation_bar: ProgressBar = null

var reputation: int = 50
var current_dialogue_index: int = 0

# ─── Ciclo de vida ────────────────────────────────────────────

func _ready():
	add_to_group("npc")
	# La reputación real vive en ReputacionGlobal (antes se tomaba la inicial y
	# la barra volvía a ese valor cada vez que se recargaba el piso)
	if ReputacionGlobal.reputaciones.has(npc_name):
		reputation = ReputacionGlobal.get_reputacion(npc_name)
	else:
		reputation = initial_reputation
	ReputacionGlobal.reputacion_npc_cambiada.connect(_on_rep_cambiada)
	PlayerInventory.item_entregado.connect(_on_item_entregado)
	_fase = randf() * TAU

	label_name     = get_node_or_null("LabelName")
	interact_hint  = get_node_or_null("InteractHint")
	reputation_bar = get_node_or_null("ReputationBar")

	# El nombre y la reputación ahora se dibujan en _draw() con un estilo propio,
	# así que ocultamos los nodos Label/ProgressBar para no duplicar.
	if label_name:     label_name.visible = false
	if interact_hint:  interact_hint.visible = false
	if reputation_bar:
		reputation_bar.visible = false
		reputation_bar.max_value = 100.0
		reputation_bar.value = float(reputation)

	_cargar_dialogos()

	# Restaurar estado persistente desde GameManager
	var estado = GameManager.get_estado_npc(npc_name)
	mision_ya_ofrecida    = estado.ofrecida
	mision_completada_flag = estado.completada
	if estado.has("entregados"):
		items_ya_entregados = estado.entregados.duplicate()

func _cargar_dialogos():
	var archivo = FileAccess.open(dialogo_archivo, FileAccess.READ)
	if archivo == null: return
	var datos = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if datos == null: return
	for clave in datos:
		var entrada = datos[clave]
		if entrada.get("nombre", "") == npc_name:
			dialogue_data    = entrada.get("dialogos", [])
			if entrada.has("item_acepta"):
				item_necesario   = entrada.item_acepta
			if entrada.has("texto_recibe_item"):
				texto_recibe_item = entrada.texto_recibe_item
			if entrada.has("mision_entrega"):
				mision_entrega_id = entrada.mision_entrega
			if entrada.has("texto_completado"):
				texto_completado = entrada.texto_completado
			if entrada.has("texto_fallido"):
				texto_fallido = entrada.texto_fallido
			# Sistema multi-entrega: cada ítem tiene su propio texto y misión
			if entrada.has("items_entrega"):
				items_entrega = entrada.items_entrega
				for nombre_item in items_entrega:
					if not items_aceptados.has(nombre_item):
						items_aceptados.append(nombre_item)
			return

# ─── Visual ───────────────────────────────────────────────────
# Los NPCs se dibujan como personajes con cuerpo, cabeza, cabello y un
# atuendo que cambia según su rol (médico, enfermera, recepción, etc.).
# Los rasgos (piel, cabello, estilo) se derivan del nombre para dar variedad.

var _fase: float = 0.0

var _skin: Color
var _hair: Color
var _hair_style: int = 0
var _cat: String = ""
var _vis_listo: bool = false
var _npc_sprite: Sprite2D = null   # sprite pixel-art opcional
var _sprite_base_y: float = 0.0
var _y_placa: float = -50.0        # altura de la placa de nombre (se ajusta al sprite)
var _alto: float = 50.0            # alto de la figura en píxeles
var _salto: float = 0.0            # saltito de alegría (lo anima un tween)
var _rep_pendiente: int = 0        # cambios de reputación que se agrupan en un solo texto
var _rep_timer_activo: bool = false

const _SKINS = [
	Color(0.98, 0.82, 0.69), Color(0.91, 0.72, 0.55),
	Color(0.78, 0.58, 0.42), Color(0.58, 0.42, 0.30)
]
const _HAIRS = [
	Color(0.13, 0.10, 0.09), Color(0.33, 0.20, 0.10),
	Color(0.55, 0.38, 0.18), Color(0.20, 0.20, 0.22)
]

func _init_visual():
	var h = abs(int(npc_name.hash()))
	_cat = _categoria_rol()
	_skin = _SKINS[h % _SKINS.size()]
	_hair = _HAIRS[(h / 4) % _HAIRS.size()]
	_hair_style = (h / 16) % 3
	if _cat == "paciente":
		_hair = Color(0.80, 0.80, 0.82)   # pacientes mayores → canas
	_cargar_sprite_npc()
	_vis_listo = true

# Carga un sprite pixel-art para este rol si existe el archivo. Si no, se usará
# la figura dibujada por código (_dibujar_personaje).
func _cargar_sprite_npc():
	if not usar_sprites or _npc_sprite != null:
		return
	var ruta = "res://assets/sprites/npc/%s.png" % _cat
	if not ResourceLoader.exists(ruta):
		return
	var tex = load(ruta)
	_npc_sprite = Sprite2D.new()
	_npc_sprite.texture = tex
	_npc_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_npc_sprite.scale = Vector2.ONE * escala_sprite
	# Zona visible de la textura (sin el margen transparente)
	var img = tex.get_image()
	var zona = img.get_used_rect() if img else Rect2i(0, 0, tex.get_width(), tex.get_height())
	# Pies (última fila visible) en el origen del nodo
	_sprite_base_y = -(zona.end.y - tex.get_height() / 2.0) * escala_sprite
	_npc_sprite.position = Vector2(0, _sprite_base_y)
	# Placa de nombre 18 px sobre la cabeza
	_alto = zona.size.y * escala_sprite
	_y_placa = PIE_Y - _alto - 18.0
	add_child(_npc_sprite)

func _categoria_rol() -> String:
	var r = npc_role.to_lower()
	if "enfermer" in r: return "enfermera"
	if "paciente" in r: return "paciente"
	if "recepcion" in r or "administr" in r: return "admin"
	if "farmac" in r or "técnic" in r or "tecnic" in r or "labor" in r: return "lab"
	if "bodega" in r or "encargado" in r or "almac" in r: return "bodega"
	if "conserje" in r or "mantenim" in r: return "bodega"   # overol de trabajo
	return "doctor"

func _color_uniforme() -> Color:
	match _cat:
		"doctor":    return Color(0.95, 0.96, 0.99)   # bata blanca
		"enfermera": return Color(0.24, 0.62, 0.74)   # uniforme turquesa
		"lab":       return Color(0.92, 0.94, 0.97)   # bata clara
		"admin":     return Color(0.40, 0.33, 0.54)   # blazer
		"bodega":    return Color(0.80, 0.55, 0.20)   # overol naranja
		"paciente":  return Color(0.86, 0.90, 0.94)   # bata de paciente
	return npc_color

# Helpers de dibujo con desplazamiento de "respiración" (off)
func _r(off: Vector2, x: float, y: float, w: float, h: float, c: Color):
	draw_rect(Rect2(Vector2(x, y) + off, Vector2(w, h)), c)

func _c(off: Vector2, x: float, y: float, rad: float, c: Color):
	draw_circle(Vector2(x, y) + off, rad, c)

func _process(delta):
	_fase += delta
	queue_redraw()  # animación de respiración / pulso del cartel

func _draw():
	if not _vis_listo:
		_init_visual()

	var bloqueado = ReputacionGlobal.esta_bloqueado(npc_name)
	var bob = sin(_fase * 2.0) * 1.2 - _salto
	var off = Vector2(0, bob)

	# Sombra ovalada en el suelo (en el origen = los pies)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.40))
	draw_circle(Vector2.ZERO, 16, Color(0, 0, 0, 0.20))
	draw_set_transform(Vector2(0, -PIE_Y))

	if _npc_sprite != null:
		# Sprite pixel-art: animar el "bob" (en píxeles enteros) y atenuar si está bloqueado
		_npc_sprite.position.y = _sprite_base_y + roundf(bob)
		_npc_sprite.modulate = Color(0.55, 0.55, 0.60) if bloqueado else Color.WHITE
	else:
		_dibujar_personaje(off, bloqueado)

	if bloqueado:
		draw_string(ThemeDB.fallback_font, Vector2(-7, -24) + off, "✕",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.92, 0.22, 0.22))

	_dibujar_placa()

	# De cerca se ven los carteles Hablar/Entregar; de lejos, el indicador de misión
	if interact_hint != null and interact_hint.visible:
		_dibujar_hints()
	elif not bloqueado:
		_dibujar_indicador(_estado_indicador(), _y_placa - 12.0)

# ─── Indicador de misión sobre la cabeza ─────────────────────
# "?" celeste: aquí puedes avanzar YA (llevas su encargo o es el siguiente paso
# de una cadena). "!" dorado: tiene una misión nueva hoy. "✓": hoy ya no
# necesita nada de ti.
func _estado_indicador() -> String:
	var paquete_listo = SistemaMisiones.insumos_faltantes(
		PlayerInventory.get_datos().get("misiones", [])).is_empty()
	if (_item_que_lleva_jugador() != "" and paquete_listo) \
			or SistemaMisiones.es_siguiente_paso_cadena(npc_name):
		return "?"
	var hoy = TiempoLaboral.dia_semana
	var nueva = false
	var en_curso = false
	var cumplida = false
	for id in SistemaMisiones.misiones:
		var m = SistemaMisiones.misiones[id]
		if m.npc_origen != npc_name or m.dia_disponible != hoy:
			continue
		match m.estado:
			SistemaMisiones.Estado.PENDIENTE:  nueva = true
			SistemaMisiones.Estado.ACTIVA:     en_curso = true
			SistemaMisiones.Estado.COMPLETADA: cumplida = true
	if nueva:
		return "!"
	if cumplida and not en_curso:
		return "✓"
	return ""

func _dibujar_indicador(estado: String, tope: float):
	if estado == "":
		return
	if estado == "✓":
		var cv = Vector2(0, tope - 10.0)
		draw_circle(cv, 7.0, Color(0.10, 0.26, 0.15, 0.85))
		draw_polyline(PackedVector2Array([cv + Vector2(-3.5, 0), cv + Vector2(-1, 2.5),
			cv + Vector2(3.5, -2.5)]), Color(0.55, 1.0, 0.60), 2.0)
		return
	var c = Vector2(0, tope - 15.0 - absf(sin(_fase * 3.2)) * 3.0)
	var fondo = Color(1.0, 0.80, 0.18) if estado == "!" else Color(0.35, 0.88, 1.0)
	var oscuro = Color(0.12, 0.10, 0.06)
	if estado == "?":
		draw_circle(c, 12.0 + 2.0 * sin(_fase * 6.0), Color(fondo.r, fondo.g, fondo.b, 0.30))
	draw_circle(c, 10.0, oscuro)
	draw_circle(c, 8.5, fondo)
	var font = ThemeDB.fallback_font
	draw_string_outline(font, Vector2(c.x - 10, c.y + 5), estado,
		HORIZONTAL_ALIGNMENT_CENTER, 20, 15, 1, oscuro)
	draw_string(font, Vector2(c.x - 10, c.y + 5), estado,
		HORIZONTAL_ALIGNMENT_CENTER, 20, 15, oscuro)

func _dibujar_personaje(off: Vector2, bloqueado: bool):
	var skin = _skin if not bloqueado else _skin.darkened(0.45)
	var hair = _hair if not bloqueado else _hair.darkened(0.4)
	var uni  = _color_uniforme()
	if bloqueado: uni = uni.darkened(0.45)
	var uni_b = uni.darkened(0.26)
	var pant = uni.darkened(0.45)
	if _cat == "doctor" or _cat == "lab":
		pant = Color(0.30, 0.40, 0.53)   # pantalón azul bajo la bata
	if bloqueado: pant = pant.darkened(0.4)

	# Piernas y zapatos (fijos al suelo, sin "bob")
	draw_rect(Rect2(-7, 4, 6, 12), pant)
	draw_rect(Rect2(1, 4, 6, 12), pant)
	draw_rect(Rect2(-8, 14, 7, 4), Color(0.16, 0.16, 0.18))
	draw_rect(Rect2(1, 14, 7, 4), Color(0.16, 0.16, 0.18))

	# Brazos
	_r(off, -16, -14, 5, 19, uni_b)
	_r(off, 11, -14, 5, 19, uni_b)
	# Manos
	_c(off, -13.5, 6, 2.6, skin)
	_c(off, 13.5, 6, 2.6, skin)

	# Torso
	_r(off, -12, -16, 24, 22, uni)

	# Detalles del atuendo según el rol
	_atuendo(off, uni, uni_b, skin)

	# Cuello
	_r(off, -3, -20, 6, 5, skin)

	# Cabeza: cabello detrás, cara delante, flequillo, ojos
	_c(off, 0, -30, 10, hair)
	if _hair_style == 2:
		_r(off, -10, -29, 20, 9, hair)        # melena a los lados
	_c(off, 0, -27, 9, skin)                   # cara
	if _hair_style == 0:
		_r(off, -9, -34, 18, 5, hair)          # flequillo recto
	elif _hair_style == 1:
		_r(off, -9, -34, 11, 5, hair)          # raya al costado
	# Ojos y boca
	_c(off, -3.2, -27, 1.3, Color(0.15, 0.12, 0.10))
	_c(off, 3.2, -27, 1.3, Color(0.15, 0.12, 0.10))
	draw_line(Vector2(-2.5, -22) + off, Vector2(2.5, -22) + off, _skin.darkened(0.35), 1.0)

	# Accesorios de cabeza (cofia, gafas)
	_accesorios_cabeza(off)

func _atuendo(off: Vector2, uni: Color, uni_b: Color, skin: Color):
	match _cat:
		"doctor", "lab":
			# Escote en V con camisa azul bajo la bata
			draw_colored_polygon(PackedVector2Array([
				Vector2(-5, -16) + off, Vector2(5, -16) + off, Vector2(0, -4) + off]),
				Color(0.30, 0.45, 0.62))
			_c(off, 0, -2, 0.9, Color(0.65, 0.65, 0.70))   # botón
			# Estetoscopio
			draw_polyline(PackedVector2Array([
				Vector2(-4, -15) + off, Vector2(-6, -8) + off, Vector2(-3, -1) + off]),
				Color(0.14, 0.15, 0.19), 1.5)
			draw_polyline(PackedVector2Array([
				Vector2(4, -15) + off, Vector2(6, -8) + off, Vector2(3, -1) + off]),
				Color(0.14, 0.15, 0.19), 1.5)
			_c(off, 3, 0, 1.8, Color(0.72, 0.74, 0.80))
		"enfermera":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-5, -16) + off, Vector2(5, -16) + off, Vector2(0, -7) + off]),
				uni.darkened(0.22))
			_r(off, 3, -3, 6, 5, uni.darkened(0.16))       # bolsillo
		"admin":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-5, -16) + off, Vector2(5, -16) + off, Vector2(0, -2) + off]),
				Color(0.95, 0.95, 0.97))                   # camisa
			_r(off, -1.5, -15, 3, 11, Color(0.70, 0.20, 0.25))   # corbata
		"bodega":
			_r(off, -8, -9, 16, 15, uni.darkened(0.12))    # peto del overol
			_r(off, -8, -16, 3, 8, uni.darkened(0.30))     # tirantes
			_r(off, 5, -16, 3, 8, uni.darkened(0.30))
		"paciente":
			draw_line(Vector2(0, -15) + off, Vector2(0, 5) + off, uni.darkened(0.2), 1.0)
			_c(off, 0, -8, 1.0, uni.darkened(0.3))
			# Bastón en la mano derecha
			draw_line(Vector2(15, -10) + off, Vector2(17, 16), Color(0.50, 0.33, 0.18), 2.0)

func _accesorios_cabeza(off: Vector2):
	match _cat:
		"enfermera":
			# Cofia blanca con cruz roja
			_r(off, -8, -38, 16, 5, Color(0.98, 0.98, 1.0))
			draw_rect(Rect2(Vector2(-1.5, -37.5) + off, Vector2(3, 4)), Color(0.85, 0.20, 0.20))
			draw_rect(Rect2(Vector2(-2.5, -36.5) + off, Vector2(5, 2)), Color(0.85, 0.20, 0.20))
		"lab":
			# Gafas
			draw_rect(Rect2(Vector2(-6.5, -29) + off, Vector2(5, 4)), Color(0.12, 0.12, 0.15), false, 1.0)
			draw_rect(Rect2(Vector2(1.5, -29) + off, Vector2(5, 4)), Color(0.12, 0.12, 0.15), false, 1.0)
			draw_line(Vector2(-1.5, -27) + off, Vector2(1.5, -27) + off, Color(0.12, 0.12, 0.15), 1.0)
		"paciente":
			# Gafas de lectura
			draw_rect(Rect2(Vector2(-6.5, -29) + off, Vector2(5, 4)), Color(0.35, 0.28, 0.22), false, 1.0)
			draw_rect(Rect2(Vector2(1.5, -29) + off, Vector2(5, 4)), Color(0.35, 0.28, 0.22), false, 1.0)

func _dibujar_placa():
	var font = ThemeDB.fallback_font
	var y = _y_placa
	# Nombre con fondo redondeado
	var ancho = npc_name.length() * 6.2 + 14.0
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.18, 0.82)
	sb.set_corner_radius_all(5)
	draw_style_box(sb, Rect2(-ancho / 2.0, y - 12, ancho, 15))
	draw_string(font, Vector2(-ancho / 2.0 + 7, y - 1), npc_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.96, 1.0))
	# Mini-barra de reputación
	var rep = clampf(float(reputation), 0.0, 100.0)
	var bw = 34.0
	draw_rect(Rect2(-bw / 2.0, y + 5, bw, 4), Color(0.20, 0.20, 0.24, 0.85))
	var col_rep = Color(0.30, 0.80, 0.40)
	if rep < 35.0:   col_rep = Color(0.90, 0.35, 0.35)
	elif rep < 60.0: col_rep = Color(0.95, 0.80, 0.30)
	draw_rect(Rect2(-bw / 2.0, y + 5, bw * rep / 100.0, 4), col_rep)

func _dibujar_hints():
	var item_detectado = _item_que_lleva_jugador()
	var pulso = 0.65 + 0.35 * sin(_fase * 5.0)
	var y = _y_placa   # los carteles se apilan sobre la placa de nombre
	# Cartel "Hablar" (baja un puesto si no hay cartel de "Entregar")
	var yh = y - 62 if item_detectado != "" else y - 38
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.16, 0.85)
	sb.set_corner_radius_all(6)
	draw_style_box(sb, Rect2(-48, yh, 96, 20))
	draw_string(ThemeDB.fallback_font, Vector2(-40, yh + 14),
		"⏎ Hablar", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 0.65, pulso))
	# Cartel "Entregar" (solo si llevas algo para este NPC)
	if item_detectado != "":
		var txt = "F · Entregar: " + item_detectado
		var ancho = ThemeDB.fallback_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 14.0
		var sb2 = StyleBoxFlat.new()
		sb2.bg_color = Color(0.12, 0.09, 0.02, 0.9)
		sb2.set_corner_radius_all(6)
		draw_style_box(sb2, Rect2(-ancho / 2.0, y - 38, ancho, 20))
		draw_string(ThemeDB.fallback_font, Vector2(-ancho / 2.0 + 7, y - 24),
			txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.88, 0.4))

func show_interact_hint(show: bool):
	if interact_hint: interact_hint.visible = show
	queue_redraw()

# Llamado con tecla F — entrega directa sin abrir el árbol de diálogo
func try_deliver_item():
	# No bloquear por mision_completada_flag: el NPC puede tener varias misiones
	var item_detectado = _item_que_lleva_jugador()
	if item_detectado != "":
		_dialogo_entrega(item_detectado)
	# Si no lleva nada relevante, no hace nada

# ─── Diálogos ─────────────────────────────────────────────────

func start_dialogue():
	if ReputacionGlobal.esta_bloqueado(npc_name):
		GameManager.show_dialogue(self, {
			"texto": "No tengo nada que hablar contigo. Tu actitud pasada fue inaceptable.",
			"opciones": [{ "texto": "(Retirarse)", "siguiente": -1 }]
		})
		return

	# 1. Siempre verificar si el jugador lleva algo para este NPC — prioridad total
	var item_detectado = _item_que_lleva_jugador()
	if item_detectado != "":
		_dialogo_entrega(item_detectado)
		return

	# 2. Paso de una misión EN CADENA (si este NPC es el siguiente eslabón)
	var paso = SistemaMisiones.completar_paso_cadena(npc_name)
	if not paso.is_empty():
		GameManager.show_dialogue(self, {
			"texto": paso.get("texto", "Gracias. Continúa con la siguiente parte de la tarea."),
			"opciones": [{ "texto": "(Continuar)", "siguiente": -1 }]
		})
		return

	# 3. Verificar si la misión de entrega fue completada (para cambiar el diálogo)
	if mision_ya_ofrecida and not mision_completada_flag:
		if mision_entrega_id != "" and _is_mision_completada(mision_entrega_id):
			mision_completada_flag = true
			_guardar_estado()

	# ¿Este NPC ofrece una misión disponible HOY?
	var hay_mision_hoy = _tiene_mision_hoy()

	# 3b. ¿Su misión de HOY falló? → reproche (texto propio o genérico)
	if _tiene_mision_fallida_hoy():
		GameManager.show_dialogue(self, _get_dialogo_fallido())
		return

	# 4. Misión completada (y era de hoy) → frase de agradecimiento
	if mision_completada_flag and hay_mision_hoy:
		GameManager.show_dialogue(self, _get_dialogo_completado())
		return

	# 5. Misión ya aceptada y disponible hoy → recordatorio
	if mision_ya_ofrecida and hay_mision_hoy and not dialogue_data.is_empty():
		GameManager.show_dialogue(self, _get_dialogo_seguimiento())
		return

	# 6. Hay una misión disponible HOY → ofrecer el diálogo de misión
	if hay_mision_hoy and not dialogue_data.is_empty():
		current_dialogue_index = 0
		emit_signal("dialogue_started", self)
		GameManager.show_dialogue(self, dialogue_data[0])
		return

	# 6b. ¿Forma parte de una cadena activa pero aún no es su turno? → dar pista
	var sig = SistemaMisiones.pista_cadena_para(npc_name)
	if sig != "":
		var donde = UBICACIONES.get(sig, "")
		var txt = "Para esa tarea primero tienes que hablar con %s" % sig
		if donde != "":
			txt += " — está en %s" % donde
		txt += "."
		GameManager.show_dialogue(self, {
			"texto": txt,
			"opciones": [{ "texto": "(De acuerdo)", "siguiente": -1 }]
		})
		return

	# 7. Sin tarea hoy → saludo genérico (la misión es de otro día)
	GameManager.show_dialogue(self, _dialogo_generico())

# Ubicación de cada NPC, para las pistas de las misiones en cadena
const UBICACIONES = {
	"Dr. Ramírez": "Urgencias (Piso 1)",
	"Recepcionista Ana": "Recepción (Piso 1)",
	"Farmacéutico Luis": "Farmacia (Piso 1)",
	"Bodeguero Pedro": "Bodega (Piso 1)",
	"Dr. Vargas": "Quirófano (Piso 2)",
	"Enf. Sofía": "UCI (Piso 2)",
	"Técnico Carlos": "Laboratorio (Piso 2)",
	"Enf. Jefa García": "Enfermería (Piso 2)",
	"Don Roberto": "Habitación 105 (Piso 3)",
	"Sra. Carmen": "Habitación 112 (Piso 3)",
	"Director Dr. Mendoza": "Dirección (Piso 3)",
	"Administradora Torres": "Administración (Piso 3)",
}

# ¿Este NPC ofrece una misión "de diálogo" (no automática) disponible hoy?
func _tiene_mision_hoy() -> bool:
	var hoy = TiempoLaboral.dia_semana
	for id in SistemaMisiones.misiones:
		var m = SistemaMisiones.misiones[id]
		if m.npc_origen == npc_name and m.dia_disponible == hoy and not m.get("auto_activa", false):
			return true
	return false

# ¿Alguna misión de este NPC, disponible HOY, terminó FALLIDA?
func _tiene_mision_fallida_hoy() -> bool:
	var hoy = TiempoLaboral.dia_semana
	for id in SistemaMisiones.misiones:
		var m = SistemaMisiones.misiones[id]
		if m.npc_origen == npc_name and m.dia_disponible == hoy \
				and m.estado == SistemaMisiones.Estado.FALLIDA:
			return true
	return false

# Diálogo de reproche cuando la misión falló: 1) texto del JSON,
# 2) nodo del árbol marcado "fallido", 3) frase genérica según el personaje.
func _get_dialogo_fallido() -> Dictionary:
	if texto_fallido != "":
		return { "texto": texto_fallido,
			"opciones": [{ "texto": "(Disculparse y prometer hacerlo mejor)", "siguiente": -1 }] }
	for d in dialogue_data:
		if d.get("fallido", false):
			return d
	var frases = [
		"Te esperé con lo que te pedí... y nada. En este hospital los milagros existen, pero la puntualidad claramente no.",
		"La tarea que te encargué quedó sin hacer. No estoy enojado... estoy 'documentando el incidente', que es peor.",
		"¿Sabes qué duele más que una inyección sin avisar? Un encargo olvidado. Espero que mañana sea distinto.",
		"Lo que te pedí nunca llegó. Lo anoté en mi libreta. La libreta de las cosas que NO se olvidan.",
	]
	var idx = abs(npc_name.hash() + TiempoLaboral.dia_semana) % frases.size()
	return { "texto": frases[idx],
		"opciones": [{ "texto": "(Disculparse y prometer hacerlo mejor)", "siguiente": -1 }] }

# Saludo cuando este NPC no tiene tarea para hoy.
# Mezcla frases genéricas con frases con la personalidad de cada NPC.
func _dialogo_generico() -> Dictionary:
	var frases = [
		"Buenos días. Hoy hace algo de frío en el hospital, ¿eh? Aunque siempre hace frío. Creo que el termostato lo maneja un pingüino.",
		"Todo tranquilo por mi parte. Tan tranquilo que da sospecha. En este hospital la calma nunca dura más de diez minutos.",
		"Hola. Por ahora no necesito nada... lo cual es un milagro digno de estudio clínico.",
		"Hoy estamos con calma. No lo digas en voz alta o se rompe el hechizo.",
		"Sin novedades por aquí. El café de la máquina sigue sabiendo a castigo, eso sí.",
		"Gracias por la ronda. Hoy no tengo nada para ti. Disfruta el momento: mañana seguro te persigo por el pasillo.",
		"¿Sabías que las escaleras de este hospital cuentan como gimnasio? Lo digo por experiencia. Y por las rodillas.",
		"Todo en orden. Si ves al del ascensor, dile que lo arregle ANTES de que yo tenga que subir al tercer piso.",
	]
	# Frases especiales por personaje (se mezclan con las genéricas)
	var especiales = {
		"Bodeguero Pedro": "Bienvenido a mi reino: la bodega. Aquí cada caja tiene nombre. A esa de allá le puse 'Paquita'. No la toques.",
		"Don Roberto": "Joven, en mis tiempos las jeringas eran de vidrio y los médicos usaban sombrero. No sé qué era peor.",
		"Sra. Carmen": "Mi nieto dice que soy 'una abuela gamer' porque aprieto el botón de la enfermera como si fuera un videojuego.",
		"Dr. Vargas": "Recuerda: en quirófano la puntualidad salva vidas. Y el café también, pero eso no lo ponen en los manuales.",
		"Recepcionista Ana": "Hoy ya me preguntaron 14 veces dónde está el baño. Está pensando en ponerme un cartel en la frente.",
		"Técnico Carlos": "Si una muestra te mira raro... no, espera, las muestras no miran. Necesito dormir más.",
	}
	if especiales.has(npc_name) and (npc_name.hash() + TiempoLaboral.dia_semana) % 2 == 0:
		return { "texto": especiales[npc_name], "opciones": [{ "texto": "(Sonreír y seguir la ronda)", "siguiente": -1 }] }
	var idx = abs(npc_name.hash() + TiempoLaboral.dia_semana) % frases.size()
	return { "texto": frases[idx], "opciones": [{ "texto": "(Retirarse)", "siguiente": -1 }] }

func _item_que_lleva_jugador() -> String:
	# Paquetes de bodega: van a nombre de una persona concreta (y solo a ella)
	var destino = PlayerInventory.get_datos().get("destino", "")
	if destino != "":
		return PlayerInventory.get_nombre() if destino == npc_name else ""
	# Primero buscar en la lista dinámica
	for it in items_aceptados:
		if PlayerInventory.tiene(it):
			return it
	# Luego el item_necesario fijo
	if item_necesario != "" and PlayerInventory.tiene(item_necesario):
		return item_necesario
	return ""

func _dialogo_entrega(nombre_item: String):
	# Paquete de bodega a medias (p. ej. el kit sin los sueros): no se acepta
	var misiones_paquete: Array = PlayerInventory.get_datos().get("misiones", [])
	var faltan = SistemaMisiones.insumos_faltantes(misiones_paquete)
	if not faltan.is_empty():
		GameManager.show_dialogue(self, {
			"texto": "Gracias, pero esto está incompleto. Aún falta: %s. Vuelve cuando lo tengas todo." % ", ".join(PackedStringArray(faltan)),
			"opciones": [{ "texto": "(Volver a la bodega)", "siguiente": -1 }]
		})
		return
	# Texto propio del ítem (items_entrega) o de su misión de entrega (JSON); si
	# no, una frase genérica: el texto del JSON habla de SU encargo concreto.
	var cfg_item = items_entrega.get(nombre_item, {})
	var es_su_encargo = nombre_item == item_necesario or misiones_paquete.has(mision_entrega_id)
	var frase: String
	if cfg_item.has("texto"):
		frase = cfg_item.texto
	elif texto_recibe_item != "" and es_su_encargo:
		frase = texto_recibe_item
	elif misiones_paquete.size() > 1:
		frase = "¡Todo en un solo viaje! Así da gusto trabajar. Muchas gracias."
	else:
		var frases = [
			"Justo lo que hacía falta. ¡Muchas gracias!",
			"Perfecto, me ahorras una vuelta a la bodega. Gracias.",
			"¡Llegó! Si todo el hospital funcionara así, saldríamos a la hora.",
		]
		frase = frases[abs(nombre_item.hash()) % frases.size()]
	GameManager.show_dialogue(self, {
		"texto": frase,
		"opciones": [{
			"texto": "📦 [Entregar]  " + nombre_item,
			"accion": "entregar_item",
			"item_a_entregar": nombre_item,
			"siguiente": -1
		}]
	})

func _get_dialogo_seguimiento() -> Dictionary:
	for d in dialogue_data:
		if d.get("seguimiento", false):
			return d
	return {
		"texto": "Gracias por tu ayuda. Avísame si necesitas algo más.",
		"opciones": [{ "texto": "De acuerdo.", "siguiente": -1 }]
	}

func _get_dialogo_completado() -> Dictionary:
	# Para NPCs multi-entrega: usar el texto del último ítem entregado
	if not items_entrega.is_empty() and not items_ya_entregados.is_empty():
		var ultimo = items_ya_entregados[-1]
		var cfg = items_entrega.get(ultimo, {})
		if cfg.has("texto_completado"):
			return { "texto": cfg.texto_completado, "opciones": [{ "texto": "De nada, es mi trabajo.", "siguiente": -1 }] }
	# 1. Texto personalizado del JSON (texto_completado)
	if texto_completado != "":
		return { "texto": texto_completado, "opciones": [{ "texto": "De nada.", "siguiente": -1 }] }
	# 2. Diálogo marcado como "completado" en el árbol de diálogos
	for d in dialogue_data:
		if d.get("completado", false):
			return d
	# 3. Fallback genérico
	return {
		"texto": "Muchas gracias, ya está todo resuelto. Buen trabajo.",
		"opciones": [{ "texto": "De nada.", "siguiente": -1 }]
	}

func _is_mision_completada(mision_id: String) -> bool:
	if not SistemaMisiones.misiones.has(mision_id):
		return false
	return SistemaMisiones.misiones[mision_id].estado == SistemaMisiones.Estado.COMPLETADA

# ─── Procesar opción (llamado desde DialogueUI con el dict completo) ──

func procesar_opcion(opcion: Dictionary):
	# BUGFIX: si la opción entrega un ítem al jugador pero ya lleva algo en las
	# manos, antes el ítem nuevo SOBREESCRIBÍA al anterior (p.ej. aceptar la
	# ficha de Ana destruía el paquete de jeringas que llevabas). Ahora se
	# avisa y no se aplica nada de la opción.
	if opcion.has("da_item") and PlayerInventory.tiene():
		GameManager.hud.mostrar_aviso(
			"⚠️ Ya llevas '%s'. Entrégalo primero y vuelve a hablar conmigo." % PlayerInventory.get_nombre())
		end_dialogue()
		return

	# Coste de tiempo
	if opcion.has("costo_tiempo"):
		TiempoLaboral.descontar_tiempo(float(opcion.costo_tiempo), "")

	# Entregar ítem
	if opcion.get("accion", "") == "entregar_item":
		var nombre_item = opcion.get("item_a_entregar", PlayerInventory.get_nombre())
		var misiones_paquete: Array = PlayerInventory.get_datos().get("misiones", [])
		PlayerInventory.entregar(npc_name)

		# Determinar qué misión completar: las del paquete de bodega; si no es un
		# paquete, la de items_entrega o la genérica del NPC
		var cfg_item = items_entrega.get(nombre_item, {})
		var mision_id = cfg_item.get("mision", mision_entrega_id)
		if not misiones_paquete.is_empty():
			for id in misiones_paquete:
				SistemaMisiones.completar_todos_objetivos(id)
		elif mision_id != "":
			# BUGFIX: si la misión seguía PENDIENTE (el jugador consiguió el ítem
			# sin hablar antes con el NPC de origen), la entrega se consumía sin
			# dar crédito. Ahora se acepta automáticamente antes de completarla.
			if SistemaMisiones.misiones.has(mision_id) and \
			   SistemaMisiones.misiones[mision_id].estado == SistemaMisiones.Estado.PENDIENTE:
				SistemaMisiones.aceptar_mision(mision_id)
			SistemaMisiones.completar_todos_objetivos(mision_id)
		else:
			SistemaMisiones.completar_objetivo_por_item(nombre_item, npc_name)

		# Registrar entrega
		if not items_ya_entregados.has(nombre_item):
			items_ya_entregados.append(nombre_item)
		change_reputation(12)
		mision_ya_ofrecida = true

		# mision_completada_flag = true solo cuando todos los ítems del NPC han sido entregados
		if items_entrega.is_empty():
			mision_completada_flag = true
		else:
			var todos = true
			for it in items_entrega:
				if not items_ya_entregados.has(it):
					todos = false
					break
			mision_completada_flag = todos

		_guardar_estado()
		end_dialogue()
		return

	# Dar ítem al jugador
	if opcion.has("da_item"):
		PlayerInventory.tomar(opcion.da_item, opcion.get("desc_item", ""))

	# Reputación
	if opcion.has("reputacion"):
		change_reputation(opcion.reputacion)

	# Aceptar misión — solo marcar como ofrecida si está disponible (PENDIENTE)
	if opcion.has("mision"):
		var m_id = opcion.mision
		var disponible = SistemaMisiones.misiones.has(m_id) and \
			SistemaMisiones.misiones[m_id].estado == SistemaMisiones.Estado.PENDIENTE
		GameManager.accept_mission(m_id)
		if disponible:
			mision_ya_ofrecida = true
			_guardar_estado()

	# Completar objetivo directo
	if opcion.has("completa_objetivo"):
		SistemaMisiones.completar_objetivo(
			opcion.completa_objetivo,
			opcion.get("tipo_objetivo", "hablar_npc")
		)

	# Navegar diálogo
	if opcion.has("siguiente") and opcion.siguiente >= 0:
		current_dialogue_index = opcion.siguiente
		GameManager.show_dialogue(self, dialogue_data[current_dialogue_index])
	else:
		end_dialogue()

func end_dialogue():
	_completar_charla_con_este_npc()
	emit_signal("dialogue_ended", self)
	GameManager.hide_dialogue()

# Completa misiones de "hablar con este NPC" cuyo origen Y objetivo son este mismo
# personaje (firmar pedido con Torres, evaluación con el Director, reporte final).
# Las acepta automáticamente si están disponibles hoy. NO afecta misiones de entrega
# como la ficha de Don Roberto (cuyo origen es otra persona).
func _completar_charla_con_este_npc():
	for id in SistemaMisiones.misiones:
		var m = SistemaMisiones.misiones[id]
		if m.npc_origen != npc_name:
			continue
		var es_charla = m.objetivos.size() > 0
		for obj in m.objetivos:
			if obj.tipo != "hablar_npc" or obj.get("target", "") != npc_name:
				es_charla = false
				break
		if not es_charla:
			continue
		if m.estado == SistemaMisiones.Estado.PENDIENTE:
			SistemaMisiones.aceptar_mision(id)
		if m.estado == SistemaMisiones.Estado.ACTIVA:
			SistemaMisiones.completar_objetivo(id, "hablar_npc")

# ─── Reputación ───────────────────────────────────────────────

func change_reputation(amount: int):
	ReputacionGlobal.cambiar_reputacion(npc_name, amount)
	reputation = ReputacionGlobal.get_reputacion(npc_name)
	if reputation_bar:
		reputation_bar.value = float(reputation)
		reputation_bar.modulate = Color.GREEN if reputation >= 50 else Color.RED

# Cualquier cambio de reputación con este NPC (diálogo, misión, chisme de Genaro...)
func _on_rep_cambiada(nombre: String, nuevo: int, _cantidad: int):
	if nombre != npc_name:
		return
	var real = nuevo - reputation   # cambio efectivo (la reputación se limita a 0–100)
	reputation = nuevo
	if real == 0:
		return
	# Una entrega suele dar reputación por la charla y por la misión a la vez:
	# se suman en un solo texto en vez de dos encimados.
	_rep_pendiente += real
	if not _rep_timer_activo:
		_rep_timer_activo = true
		get_tree().create_timer(0.15).timeout.connect(_mostrar_cambio_rep)

func _mostrar_cambio_rep():
	_rep_timer_activo = false
	var d = _rep_pendiente
	_rep_pendiente = 0
	if d == 0:
		return
	var lbl = Label.new()
	lbl.text = ("+%d ❤" % d) if d > 0 else ("−%d ❤" % -d)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 20
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(90, 24)
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55) if d > 0 else Color(1.0, 0.42, 0.38))
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.9))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.position = Vector2(-45, _y_placa - PIE_Y - 26)
	add_child(lbl)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 30.0, 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.chain().tween_callback(lbl.queue_free)

# El jugador le entregó algo: saltito de alegría + chispas doradas
func _on_item_entregado(_item: String, a_quien: String):
	if a_quien != npc_name:
		return
	var tw = create_tween()
	tw.tween_property(self, "_salto", 7.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_salto", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	var p = CPUParticles2D.new()
	p.position = Vector2(0, -_alto * 0.7)
	p.z_index = 20
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.8
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.gravity = Vector2(0, 170)
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 140.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	var rampa = Gradient.new()
	rampa.set_color(0, Color(1.0, 0.92, 0.45))
	rampa.set_color(1, Color(1.0, 0.70, 0.20, 0.0))
	p.color_ramp = rampa
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

# ─── Estado persistente ───────────────────────────────────────

func _guardar_estado():
	GameManager.guardar_estado_npc(npc_name, mision_ya_ofrecida, mision_completada_flag, items_ya_entregados)
