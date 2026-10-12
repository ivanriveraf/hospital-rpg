extends CharacterBody2D
# 🐈 DOCTOR BIGOTES — el gato del evento "gato_en_bodega".
# Aparece dormido sobre las cajas de la bodega (Piso 1) mientras la misión
# del gato está activa. Lo crea EventosAleatorios.gd. Se puede interactuar
# con él (Enter), aunque, siendo un gato, la conversación es unilateral.

var npc_name: String = "Doctor Bigotes"
var npc_role: String = "Gato"

var interact_hint_visible: bool = false
var _fase: float = 0.0
var _acariciado: bool = false

const COL_CUERPO  = Color(0.90, 0.56, 0.22)   # naranja atigrado
const COL_RAYAS   = Color(0.72, 0.40, 0.12)
const COL_PANZA   = Color(0.97, 0.88, 0.72)
const COL_OREJA   = Color(0.95, 0.72, 0.62)
const COL_LINEA   = Color(0.35, 0.20, 0.08)

func _ready():
	add_to_group("npc")
	_fase = randf() * TAU
	# Área de colisión para que el jugador pueda "hablarle"
	var col = CollisionShape2D.new()
	var cap = CapsuleShape2D.new()
	cap.radius = 12.0
	cap.height = 8.0
	col.shape = cap
	add_child(col)

func _process(delta):
	_fase += delta
	queue_redraw()

func _draw():
	var resp = sin(_fase * 1.6) * 1.0          # respiración lenta (duerme)
	var cola = sin(_fase * 2.2) * 6.0          # la cola sí se mueve, claro

	# Sombra
	draw_set_transform(Vector2(0, 10), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 15, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Cola (curva animada)
	draw_polyline(PackedVector2Array([
		Vector2(11, 5), Vector2(17, 2 + cola * 0.4), Vector2(20, -4 + cola)
	]), COL_CUERPO, 4.0)

	# Cuerpo ovillado (dos círculos + panza)
	draw_circle(Vector2(0, 2 + resp * 0.4), 12, COL_CUERPO)
	draw_circle(Vector2(6, 4 + resp * 0.4), 9, COL_CUERPO)
	draw_circle(Vector2(2, 6 + resp * 0.4), 6, COL_PANZA)
	# Rayas de atigrado
	draw_line(Vector2(-4, -8 + resp * 0.4), Vector2(-1, -4 + resp * 0.4), COL_RAYAS, 2.0)
	draw_line(Vector2(1, -9 + resp * 0.4), Vector2(3, -5 + resp * 0.4), COL_RAYAS, 2.0)
	draw_line(Vector2(7, -4), Vector2(10, -1), COL_RAYAS, 2.0)

	# Cabeza (apoyada, dormido)
	var cy = -8.0 + resp * 0.6
	draw_circle(Vector2(-8, cy), 8, COL_CUERPO)
	# Orejas
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, cy - 4), Vector2(-11, cy - 12), Vector2(-8, cy - 5)]), COL_CUERPO)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, cy - 5), Vector2(-11, cy - 10), Vector2(-9, cy - 5)]), COL_OREJA)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, cy - 6), Vector2(-3, cy - 12), Vector2(-1, cy - 4)]), COL_CUERPO)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, cy - 6), Vector2(-3, cy - 10), Vector2(-2, cy - 5)]), COL_OREJA)
	# Ojos cerrados (dos arcos felices) y nariz
	draw_line(Vector2(-12, cy + 1), Vector2(-9.5, cy + 2), COL_LINEA, 1.4)
	draw_line(Vector2(-9.5, cy + 2), Vector2(-7, cy + 1), COL_LINEA, 1.4)
	draw_line(Vector2(-6, cy + 1), Vector2(-4, cy + 2), COL_LINEA, 1.4)
	draw_circle(Vector2(-8, cy + 4), 1.2, Color(0.85, 0.45, 0.40))
	# Bigotes (es doctor de algo, al fin y al cabo)
	draw_line(Vector2(-13, cy + 4), Vector2(-18, cy + 3), COL_LINEA, 1.0)
	draw_line(Vector2(-13, cy + 5), Vector2(-18, cy + 6), COL_LINEA, 1.0)
	draw_line(Vector2(-3, cy + 4), Vector2(2, cy + 3), COL_LINEA, 1.0)

	# "Zzz" flotante
	var z_alpha = 0.45 + 0.45 * sin(_fase * 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(2, cy - 14), "z Z z",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.70, 0.95, z_alpha))

	# Placa de nombre (mismo estilo que los NPC)
	var ancho = npc_name.length() * 6.2 + 14.0
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.18, 0.82)
	sb.set_corner_radius_all(5)
	draw_style_box(sb, Rect2(-ancho / 2.0, -44, ancho, 15))
	draw_string(ThemeDB.fallback_font, Vector2(-ancho / 2.0 + 7, -33), npc_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.96, 1.0))

	# Cartel de interacción
	if interact_hint_visible:
		var pulso = 0.65 + 0.35 * sin(_fase * 5.0)
		var sb2 = StyleBoxFlat.new()
		sb2.bg_color = Color(0.08, 0.10, 0.16, 0.85)
		sb2.set_corner_radius_all(6)
		draw_style_box(sb2, Rect2(-48, -70, 96, 20))
		draw_string(ThemeDB.fallback_font, Vector2(-40, -56),
			"⏎ Mirar", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 0.65, pulso))

# ─── Interfaz de "NPC" (para Player.gd y DialogueUI) ─────────

func show_interact_hint(show: bool):
	interact_hint_visible = show
	queue_redraw()

func try_deliver_item():
	pass  # No acepta paquetes. Aceptaría atún, pero no está implementado.

func start_dialogue():
	var texto = "Miau. (Doctor Bigotes abre un ojo, te evalúa con autoridad felina y decide que no eres una amenaza para su siesta sobre 'Paquita'.)"
	var opciones = []
	if not _acariciado:
		opciones.append({ "texto": "(Acariciarlo con el respeto que merece)", "accion_gato": "acariciar", "siguiente": -1 })
	opciones.append({ "texto": "(Dejarlo dormir. Es lo correcto.)", "siguiente": -1 })
	GameManager.show_dialogue(self, { "texto": texto, "opciones": opciones })

func procesar_opcion(opcion: Dictionary):
	if opcion.get("accion_gato", "") == "acariciar" and not _acariciado:
		_acariciado = true
		GameManager.ganar_experiencia(5)
		if GameManager.hud:
			GameManager.hud.mostrar_aviso("🐈 Doctor Bigotes ronronea. Te sientes en paz. (+5 XP)")
	GameManager.hide_dialogue()
