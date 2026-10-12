extends Node2D

# Script base para todos los pisos. Cada piso hereda de este.
@export var floor_number: int = 1

const LAYOUT = {
	"area_izq_arriba":  Rect2(50,  50,  330, 260),
	"area_der_arriba":  Rect2(430, 50,  330, 260),
	"area_izq_abajo":   Rect2(50,  380, 330, 260),
	"area_der_abajo":   Rect2(430, 380, 330, 260),
	"corredor_v":       Rect2(380, 0,   50,  720),
	"corredor_h":       Rect2(0,   310, 810, 50),
	"zona_escaleras":   Rect2(820, 100, 90,  520)
}

# Lado de cada sala donde está la puerta (hacia el pasillo central)
const PUERTAS = {
	"area_izq_arriba": "bottom",
	"area_der_arriba": "bottom",
	"area_izq_abajo":  "top",
	"area_der_abajo":  "top",
}
const ANCHO_PUERTA = 88.0

var areas_datos: Dictionary = {}  # Se define en cada piso

func _ready():
	# Orden por profundidad: quien está más abajo en pantalla se dibuja delante.
	# Main y FloorContainer también lo tienen activo, así el jugador se ordena
	# junto con los NPC. "Zonas" no lo activa: se dibuja siempre a ras de suelo.
	y_sort_enabled = true
	_definir_areas()
	_crear_muros()
	_crear_npcs()
	var npcs = get_node_or_null("NPCs")
	if npcs:
		npcs.y_sort_enabled = true
	_crear_zonas_interactivas()

func _definir_areas():
	pass  # Override en cada piso

func _crear_npcs():
	pass  # Override en cada piso

func _crear_zonas_interactivas():
	pass  # Override en cada piso

func _draw():
	var font = ThemeDB.fallback_font

	# ── Exterior del edificio (marco oscuro alrededor del piso) ──
	draw_rect(Rect2(-200, -60, 1560, 850), Color(0.12, 0.15, 0.21))

	# ── Suelo de baldosas en damero (dos tonos + variación sutil) ──
	var tono_a = Color(0.88, 0.91, 0.95)
	var tono_b = Color(0.92, 0.94, 0.97)
	for ty in range(0, 720, 40):
		for tx in range(0, 920, 40):
			var par = ((tx / 40) + (ty / 40)) % 2 == 0
			var col = tono_a if par else tono_b
			# Algunas baldosas ligeramente distintas (rompe la monotonía)
			if ((tx / 40) * 31 + (ty / 40) * 17) % 11 == 3:
				col = col.darkened(0.035)
			draw_rect(Rect2(tx, ty, 40, 40), col)
	# Líneas de junta
	var col_linea = Color(0.83, 0.87, 0.91)
	for x in range(0, 921, 40):
		draw_line(Vector2(x, 0), Vector2(x, 720), col_linea, 1.0)
	for y in range(0, 721, 40):
		draw_line(Vector2(0, y), Vector2(920, y), col_linea, 1.0)

	# ── Zócalo perimetral del edificio ──
	draw_rect(Rect2(0, 0, 920, 720), Color(0.34, 0.39, 0.47), false, 7.0)

	# ── Corredores ──
	_dibujar_corredor(LAYOUT.corredor_v, true)
	_dibujar_corredor(LAYOUT.corredor_h, false)

	# ── Decoración de pasillos y halos de luz de techo ──
	_decorar_pasillos()
	_halos_de_luz()

	# ── Hueco de escaleras / ascensor ──
	_dibujar_escaleras(font)

	# ── Salas ──
	for key in areas_datos:
		var area = areas_datos[key]
		var rect = LAYOUT.get(key, Rect2())
		if rect == Rect2():
			continue
		_dibujar_sala(font, rect, area)

	# ── Puertas ──
	for key in areas_datos:
		var rect = LAYOUT.get(key, Rect2())
		if rect == Rect2():
			continue
		_dibujar_puerta(font, rect, PUERTAS.get(key, "bottom"))

	# ── Cartel de piso ──
	_dibujar_cartel_piso(font)

func _dibujar_puerta(_font, rect: Rect2, lado: String):
	var pos = _centro_puerta(rect, lado)
	var horizontal = lado == "top" or lado == "bottom"
	var media = ANCHO_PUERTA / 2.0
	var g = 9.0                                  # grosor (≈ pared)
	var suelo = Color(0.86, 0.90, 0.93)          # umbral = suelo
	var jamba = Color(0.28, 0.31, 0.36)          # marco
	var madera = Color(0.56, 0.37, 0.21)
	var madera_b = Color(0.32, 0.20, 0.11)
	var pomo = Color(1.0, 0.88, 0.45)

	# Tapete de entrada del lado del pasillo
	var mw = 48.0
	if lado == "bottom":
		_tapete(Rect2(pos.x - mw / 2.0, pos.y + 6, mw, 13))
	elif lado == "top":
		_tapete(Rect2(pos.x - mw / 2.0, pos.y - 19, mw, 13))
	elif lado == "left":
		_tapete(Rect2(pos.x - 19, pos.y - mw / 2.0, 13, mw))
	elif lado == "right":
		_tapete(Rect2(pos.x + 6, pos.y - mw / 2.0, 13, mw))
	if horizontal:
		draw_rect(Rect2(pos.x - media, pos.y - g / 2.0, ANCHO_PUERTA, g), suelo)
		draw_rect(Rect2(pos.x - media - 3, pos.y - 9, 6, 18), jamba)
		draw_rect(Rect2(pos.x + media - 3, pos.y - 9, 6, 18), jamba)
		_hoja(Rect2(pos.x - media + 4, pos.y - g / 2.0, media - 7, g), madera, madera_b)
		_hoja(Rect2(pos.x + 3, pos.y - g / 2.0, media - 7, g), madera, madera_b)
		draw_circle(Vector2(pos.x - 5, pos.y), 2.0, pomo)
		draw_circle(Vector2(pos.x + 5, pos.y), 2.0, pomo)
	else:
		draw_rect(Rect2(pos.x - g / 2.0, pos.y - media, g, ANCHO_PUERTA), suelo)
		draw_rect(Rect2(pos.x - 9, pos.y - media - 3, 18, 6), jamba)
		draw_rect(Rect2(pos.x - 9, pos.y + media - 3, 18, 6), jamba)
		_hoja(Rect2(pos.x - g / 2.0, pos.y - media + 4, g, media - 7), madera, madera_b)
		_hoja(Rect2(pos.x - g / 2.0, pos.y + 3, g, media - 7), madera, madera_b)
		draw_circle(Vector2(pos.x, pos.y - 5), 2.0, pomo)
		draw_circle(Vector2(pos.x, pos.y + 5), 2.0, pomo)

func _hoja(r: Rect2, fill: Color, borde: Color):
	draw_rect(r, fill)
	draw_rect(r, borde, false, 1.5)

func _tapete(r: Rect2):
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.50, 0.58, 0.68, 0.9)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.38, 0.45, 0.55, 0.9)
	draw_style_box(sb, r)

func _centro_puerta(rect: Rect2, lado: String) -> Vector2:
	var cx = rect.position.x + rect.size.x / 2.0
	var cy = rect.position.y + rect.size.y / 2.0
	match lado:
		"top":    return Vector2(cx, rect.position.y)
		"bottom": return Vector2(cx, rect.position.y + rect.size.y)
		"left":   return Vector2(rect.position.x, cy)
		"right":  return Vector2(rect.position.x + rect.size.x, cy)
	return Vector2(cx, cy)

# Colores de las líneas guía de suelo (señalización hospitalaria),
# distintos en cada piso para ayudar a orientarse.
const GUIAS_PISO = {
	1: [Color(0.82, 0.32, 0.30, 0.60), Color(0.28, 0.62, 0.42, 0.60)],
	2: [Color(0.28, 0.52, 0.82, 0.60), Color(0.30, 0.68, 0.68, 0.60)],
	3: [Color(0.58, 0.42, 0.78, 0.60), Color(0.88, 0.60, 0.28, 0.60)],
}

# Corredor limpio con bordes sutiles y líneas guía de color pegadas a los
# lados (como la señalización de suelo real de los hospitales).
func _dibujar_corredor(rect: Rect2, vertical: bool):
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.80, 0.86, 0.90)
	draw_style_box(sb, rect)
	var borde = Color(0.68, 0.76, 0.82, 0.9)
	var guias = GUIAS_PISO.get(floor_number, GUIAS_PISO[1])
	if vertical:
		draw_line(rect.position, rect.position + Vector2(0, rect.size.y), borde, 2.0)
		draw_line(rect.position + Vector2(rect.size.x, 0), rect.position + rect.size, borde, 2.0)
		var x1 = rect.position.x + 7.0
		var x2 = rect.position.x + rect.size.x - 7.0
		draw_line(Vector2(x1, rect.position.y), Vector2(x1, rect.position.y + rect.size.y), guias[0], 2.5)
		draw_line(Vector2(x2, rect.position.y), Vector2(x2, rect.position.y + rect.size.y), guias[1], 2.5)
	else:
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), borde, 2.0)
		draw_line(rect.position + Vector2(0, rect.size.y), rect.position + rect.size, borde, 2.0)
		var y1 = rect.position.y + 7.0
		var y2 = rect.position.y + rect.size.y - 7.0
		draw_line(Vector2(rect.position.x, y1), Vector2(rect.position.x + rect.size.x, y1), guias[0], 2.5)
		draw_line(Vector2(rect.position.x, y2), Vector2(rect.position.x + rect.size.x, y2), guias[1], 2.5)

func _dibujar_sala(font, rect: Rect2, area: Dictionary):
	var base = area.color
	# Caja con sombra y bordes redondeados
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(base.r, base.g, base.b, 0.55)
	sb.set_corner_radius_all(12)
	# Borde grueso = pared de la sala
	sb.border_color = Color(base.r * 0.5, base.g * 0.5, base.b * 0.5, 1.0)
	sb.set_border_width_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(3, 5)
	draw_style_box(sb, rect)

	# Barra de título superior
	var barra = Rect2(rect.position.x, rect.position.y, rect.size.x, 34)
	var sbh = StyleBoxFlat.new()
	sbh.bg_color = Color(base.r * 0.6, base.g * 0.6, base.b * 0.6, 0.95)
	sbh.corner_radius_top_left = 14
	sbh.corner_radius_top_right = 14
	draw_style_box(sbh, barra)

	var icono = _icono_sala(area.nombre)
	draw_string(font, Vector2(rect.position.x + 12, rect.position.y + 23),
		"%s  %s" % [icono, area.nombre], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16, 17, Color(1, 1, 1))

	# Mobiliario propio de la sala (camas, escritorios, estanterías, etc.)
	_dibujar_mobiliario(rect, area.nombre)

	# Icono translúcido de marca de agua en la esquina
	draw_string(font, Vector2(rect.position.x + rect.size.x - 52, rect.position.y + rect.size.y - 16),
		icono, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 1, 1, 0.30))

	# Descripción abajo
	draw_string(font, Vector2(rect.position.x + 12, rect.position.y + rect.size.y - 14),
		area.descripcion, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 12, Color(0.22, 0.26, 0.30))

# Zona de escaleras y ascensor rediseñada: ahora se dibuja un ascensor real
# (marco metálico, puertas dobles y display de piso) y una escalera con
# peldaños y pasamanos, en lugar de las rayas genéricas de antes.
func _dibujar_escaleras(font):
	var rect = LAYOUT.zona_escaleras
	var x = rect.position.x
	var y = rect.position.y
	var w = rect.size.x

	# Panel de fondo
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.45, 0.50, 0.58, 0.97)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.28, 0.32, 0.40)
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.20)
	sb.shadow_size = 6
	draw_style_box(sb, rect)

	# Cabecera azul con el nombre de la zona
	var cab = StyleBoxFlat.new()
	cab.bg_color = Color(0.20, 0.32, 0.50)
	cab.corner_radius_top_left = 12
	cab.corner_radius_top_right = 12
	draw_style_box(cab, Rect2(x, y, w, 40))
	draw_string(font, Vector2(x, y + 17), "Ascensor",
		HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(1, 1, 1))
	draw_string(font, Vector2(x, y + 33), "y escaleras",
		HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.80, 0.88, 1.0))

	# ── Ascensor ──
	var ax = x + 16
	var aw = w - 32
	var ay = y + 74
	var ah = 100.0
	# Display de piso sobre la puerta
	var disp = Rect2(x + w / 2.0 - 16, ay - 20, 32, 14)
	draw_rect(disp, Color(0.07, 0.08, 0.11))
	draw_rect(disp, Color(0.30, 0.34, 0.40), false, 1.5)
	draw_string(font, Vector2(disp.position.x, disp.position.y + 11), "▲%d▼" % floor_number,
		HORIZONTAL_ALIGNMENT_CENTER, disp.size.x, 10, Color(0.98, 0.62, 0.18))
	# Marco metálico
	draw_rect(Rect2(ax - 5, ay - 5, aw + 10, ah + 10), Color(0.66, 0.70, 0.76))
	draw_rect(Rect2(ax - 5, ay - 5, aw + 10, ah + 10), Color(0.32, 0.35, 0.40), false, 2.0)
	# Puertas dobles con brillo vertical
	var mitad = aw / 2.0
	draw_rect(Rect2(ax, ay, mitad - 1, ah), Color(0.55, 0.62, 0.70))
	draw_rect(Rect2(ax + mitad + 1, ay, mitad - 1, ah), Color(0.55, 0.62, 0.70))
	draw_rect(Rect2(ax + 4, ay + 4, 5, ah - 8), Color(0.72, 0.78, 0.85, 0.55))
	draw_rect(Rect2(ax + mitad + 5, ay + 4, 5, ah - 8), Color(0.72, 0.78, 0.85, 0.55))
	# Ranura central y botonera
	draw_line(Vector2(ax + mitad, ay), Vector2(ax + mitad, ay + ah), Color(0.20, 0.22, 0.26), 2.0)
	draw_circle(Vector2(ax + aw + 1, ay + ah / 2.0 - 7), 2.5, Color(0.95, 0.80, 0.30))
	draw_circle(Vector2(ax + aw + 1, ay + ah / 2.0 + 3), 2.5, Color(0.40, 0.75, 0.95))

	# ── Escaleras (peldaños con pasamanos) ──
	var ey = ay + ah + 34
	var fin = y + rect.size.y - 54
	draw_string(font, Vector2(x, ey - 12), "ESCALERAS",
		HORIZONTAL_ALIGNMENT_CENTER, w, 10, Color(1, 1, 1, 0.85))
	var px = x + 16
	var pw = w - 32
	var alto_p = 16.0
	var i = 0
	var py = ey
	while py + alto_p <= fin:
		var tono = 0.70 - 0.045 * (i % 2)
		# Huella del peldaño
		draw_rect(Rect2(px, py, pw, alto_p - 3), Color(tono, tono + 0.03, tono + 0.08))
		# Contrahuella (sombra que da profundidad)
		draw_rect(Rect2(px, py + alto_p - 3, pw, 3), Color(0.26, 0.29, 0.34, 0.9))
		# Banda antideslizante
		draw_line(Vector2(px + 3, py + 2), Vector2(px + pw - 3, py + 2), Color(0.92, 0.75, 0.25, 0.85), 1.5)
		py += alto_p
		i += 1
	# Pasamanos laterales
	draw_line(Vector2(px - 6, ey - 4), Vector2(px - 6, py), Color(0.30, 0.33, 0.38), 3.0)
	draw_line(Vector2(px + pw + 6, ey - 4), Vector2(px + pw + 6, py), Color(0.30, 0.33, 0.38), 3.0)

func _dibujar_cartel_piso(font):
	var rect = LAYOUT.zona_escaleras
	var badge = Rect2(rect.position.x - 4, rect.position.y + rect.size.y - 46, rect.size.x + 8, 42)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.34, 0.58, 0.97)
	sb.set_corner_radius_all(9)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	draw_style_box(sb, badge)
	draw_string(font, Vector2(badge.position.x + 10, badge.position.y + 20), "PISO %d" % floor_number,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1))
	draw_string(font, Vector2(badge.position.x + 10, badge.position.y + 36),
		FloorManager.NOMBRES_PISO.get(floor_number, ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.78, 0.88, 1.0))

func _icono_sala(nombre: String) -> String:
	match nombre:
		"Urgencias":      return "🚑"
		"Recepción":      return "🛎"
		"Farmacia":       return "💊"
		"Bodega":         return "📦"
		"Quirófano":      return "🔪"
		"UCI":            return "❤"
		"Laboratorio":    return "🔬"
		"Enfermería":     return "🩺"
		"Habitaciones A": return "🛏"
		"Habitaciones B": return "🛏"
		"Dirección":      return "🏛"
		"Administración": return "📁"
	return "🏥"

# ─── Mobiliario de cada sala (decorativo, sin colisión) ──────

func _dibujar_mobiliario(rect: Rect2, nombre: String):
	var x = rect.position.x + 16
	var y = rect.position.y + 48
	var w = rect.size.x - 32
	var bottom = rect.position.y + rect.size.y - 18
	match nombre:
		"Urgencias":
			_m_cama(x, y + 4)
			_m_suero(x + 60, y)
			_m_monitor(x + w - 22, y + 2)
			_m_planta(x + w - 18, bottom - 24)
		"Recepción":
			_m_mostrador(x, bottom - 26, w - 6)
			_m_pc(x + 12, bottom - 26)
			_m_silla(x + w - 30, bottom - 12)
			_m_planta(x, y)
		"Farmacia":
			_m_estante(x, y, w * 0.45, 62)
			_m_mostrador(x, bottom - 22, w - 6)
			_m_matraces(x + w - 28, bottom - 20)
		"Bodega":
			_m_cajas(x, y + 8)
			_m_cajas(x + w - 44, y + 8)
			_m_estante(x + (w - 46) / 2.0, y + 6, 46, 56)
		"Quirófano":
			_m_quirofano(x + (w - 44) / 2.0, y + 22)
			_m_monitor(x, y + 6)
			_m_suero(x + w - 12, y + 4)
		"UCI":
			_m_cama(x, y + 4)
			_m_monitor(x + w - 22, y + 2)
			_m_suero(x + 60, y)
		"Laboratorio":
			_m_escritorio(x, y + 18, w * 0.6)
			_m_microscopio(x + 6, y + 4)
			_m_matraces(x + 40, y + 8)
			_m_estante(x + w - 44, y, 44, 60)
		"Enfermería":
			_m_escritorio(x, bottom - 28, w * 0.55)
			_m_pc(x + 10, bottom - 28)
			_m_archivador(x + w - 20, y + 4)
			_m_planta(x + w - 44, bottom - 24)
		"Habitaciones A", "Habitaciones B":
			_m_cama(x, y + 4)
			_m_cama(x, bottom - 30)
			_m_monitor(x + w - 22, y + 2)
		"Dirección":
			_m_escritorio(x + 8, y + 22, w * 0.6)
			_m_pc(x + 18, y + 22)
			_m_libros(x + w - 30, y + 2)
			_m_planta(x, bottom - 24)
		"Administración":
			_m_escritorio(x, y + 22, w * 0.55)
			_m_pc(x + 10, y + 22)
			_m_archivador(x + w - 20, y + 2)
			_m_archivador(x + w - 42, y + 2)
		_:
			_m_planta(x, y)

func _m_cama(x: float, y: float):
	draw_rect(Rect2(x - 2, y - 2, 3, 30), Color(0.62, 0.64, 0.68))      # baranda izq
	draw_rect(Rect2(x + 49, y - 2, 3, 30), Color(0.62, 0.64, 0.68))     # baranda der
	draw_rect(Rect2(x, y, 50, 26), Color(0.96, 0.97, 0.99))             # colchón
	draw_rect(Rect2(x, y, 50, 26), Color(0.52, 0.57, 0.64), false, 1.5)
	draw_rect(Rect2(x + 3, y + 4, 13, 18), Color(0.84, 0.88, 0.93))     # almohada
	draw_rect(Rect2(x + 22, y, 28, 26), Color(0.55, 0.72, 0.85))        # manta

func _m_suero(x: float, y: float):
	draw_line(Vector2(x, y), Vector2(x, y + 32), Color(0.60, 0.62, 0.66), 1.5)
	draw_rect(Rect2(x - 4, y, 8, 11), Color(0.82, 0.92, 0.96, 0.9))
	draw_rect(Rect2(x - 4, y, 8, 11), Color(0.5, 0.6, 0.7), false, 1.0)
	draw_rect(Rect2(x - 6, y + 30, 12, 3), Color(0.5, 0.52, 0.56))      # base

func _m_monitor(x: float, y: float):
	draw_rect(Rect2(x, y, 18, 13), Color(0.12, 0.14, 0.18))
	draw_rect(Rect2(x + 2, y + 2, 14, 9), Color(0.10, 0.18, 0.14))
	draw_polyline(PackedVector2Array([
		Vector2(x + 3, y + 7), Vector2(x + 6, y + 7), Vector2(x + 7, y + 3),
		Vector2(x + 9, y + 10), Vector2(x + 11, y + 6), Vector2(x + 15, y + 7)]),
		Color(0.4, 1.0, 0.6), 1.0)
	draw_rect(Rect2(x + 8, y + 13, 2, 7), Color(0.4, 0.42, 0.46))       # poste

func _m_escritorio(x: float, y: float, w: float):
	draw_rect(Rect2(x, y, w, 14), Color(0.62, 0.45, 0.28))
	draw_rect(Rect2(x, y, w, 14), Color(0.40, 0.28, 0.16), false, 1.5)
	draw_rect(Rect2(x + 2, y + 14, 3, 12), Color(0.40, 0.28, 0.16))
	draw_rect(Rect2(x + w - 5, y + 14, 3, 12), Color(0.40, 0.28, 0.16))

func _m_pc(x: float, y: float):
	draw_rect(Rect2(x, y - 13, 17, 12), Color(0.15, 0.16, 0.20))
	draw_rect(Rect2(x + 2, y - 11, 13, 8), Color(0.40, 0.70, 0.95))
	draw_rect(Rect2(x + 5, y - 1, 7, 2), Color(0.20, 0.20, 0.24))

func _m_silla(x: float, y: float):
	draw_rect(Rect2(x, y - 9, 12, 8), Color(0.26, 0.34, 0.48))
	draw_rect(Rect2(x, y, 12, 11), Color(0.30, 0.40, 0.55))

func _m_estante(x: float, y: float, w: float, h: float):
	draw_rect(Rect2(x, y, w, h), Color(0.70, 0.60, 0.45))
	draw_rect(Rect2(x, y, w, h), Color(0.45, 0.36, 0.24), false, 1.5)
	var n = int(h / 16)
	var cols = [Color(0.90, 0.40, 0.40), Color(0.40, 0.70, 0.95),
				Color(0.50, 0.85, 0.50), Color(0.95, 0.85, 0.40)]
	for s in range(n):
		var sy = y + s * 16
		draw_line(Vector2(x, sy + 16), Vector2(x + w, sy + 16), Color(0.45, 0.36, 0.24), 1.5)
		var bx = x + 3
		while bx < x + w - 5:
			draw_rect(Rect2(bx, sy + 6, 5, 9), cols[(int(bx) + s) % cols.size()])
			bx += 8

func _m_cajas(x: float, y: float):
	var c = Color(0.78, 0.62, 0.38)
	var cb = Color(0.55, 0.42, 0.24)
	for box in [Rect2(x, y + 16, 18, 16), Rect2(x + 20, y + 16, 18, 16), Rect2(x + 7, y, 18, 16)]:
		draw_rect(box, c)
		draw_rect(box, cb, false, 1.5)
		draw_line(Vector2(box.position.x, box.position.y + 5),
			Vector2(box.position.x + box.size.x, box.position.y + 5), cb, 1.0)

func _m_planta(x: float, y: float):
	draw_rect(Rect2(x, y + 13, 12, 10), Color(0.70, 0.45, 0.30))        # maceta
	draw_circle(Vector2(x + 6, y + 9), 8, Color(0.24, 0.58, 0.30))
	draw_circle(Vector2(x + 2, y + 4), 5, Color(0.30, 0.68, 0.35))
	draw_circle(Vector2(x + 11, y + 5), 5, Color(0.20, 0.52, 0.27))

func _m_mostrador(x: float, y: float, w: float):
	draw_rect(Rect2(x, y, w, 13), Color(0.55, 0.62, 0.72))
	draw_rect(Rect2(x, y, w, 13), Color(0.34, 0.40, 0.50), false, 1.5)
	draw_rect(Rect2(x, y + 13, w, 13), Color(0.70, 0.74, 0.82))

func _m_quirofano(x: float, y: float):
	draw_line(Vector2(x + 22, y - 30), Vector2(x + 22, y - 21), Color(0.5, 0.5, 0.55), 2.0)
	draw_circle(Vector2(x + 22, y - 14), 9, Color(0.96, 0.96, 0.72, 0.92))   # lámpara
	draw_circle(Vector2(x + 22, y - 14), 9, Color(0.72, 0.72, 0.52), false, 1.5)
	draw_rect(Rect2(x + 18, y + 16, 4, 12), Color(0.40, 0.45, 0.50))          # pata
	draw_rect(Rect2(x, y, 44, 16), Color(0.55, 0.68, 0.78))                   # mesa
	draw_rect(Rect2(x, y, 44, 16), Color(0.30, 0.40, 0.50), false, 1.5)

func _m_microscopio(x: float, y: float):
	draw_rect(Rect2(x, y + 12, 14, 4), Color(0.30, 0.32, 0.36))
	draw_line(Vector2(x + 7, y + 12), Vector2(x + 7, y + 2), Color(0.30, 0.32, 0.36), 2.0)
	draw_line(Vector2(x + 7, y + 3), Vector2(x + 13, y + 6), Color(0.30, 0.32, 0.36), 2.0)
	draw_circle(Vector2(x + 13, y + 6), 2, Color(0.50, 0.70, 0.90))

func _m_matraces(x: float, y: float):
	draw_rect(Rect2(x, y + 4, 5, 8), Color(0.50, 0.85, 0.60, 0.9))
	draw_rect(Rect2(x + 7, y + 2, 5, 10), Color(0.60, 0.70, 0.95, 0.9))
	draw_rect(Rect2(x + 14, y + 6, 5, 6), Color(0.95, 0.70, 0.40, 0.9))

func _m_archivador(x: float, y: float):
	draw_rect(Rect2(x, y, 16, 28), Color(0.55, 0.58, 0.64))
	draw_rect(Rect2(x, y, 16, 28), Color(0.35, 0.38, 0.44), false, 1.5)
	for i in range(3):
		draw_rect(Rect2(x + 2, y + 3 + i * 9, 12, 6), Color(0.70, 0.73, 0.78))
		draw_rect(Rect2(x + 6, y + 5 + i * 9, 4, 2), Color(0.40, 0.42, 0.46))

func _m_libros(x: float, y: float):
	draw_rect(Rect2(x, y, 26, 30), Color(0.50, 0.36, 0.24))
	draw_rect(Rect2(x, y, 26, 30), Color(0.32, 0.22, 0.14), false, 1.5)
	var cols = [Color(0.80, 0.30, 0.30), Color(0.30, 0.50, 0.80),
				Color(0.40, 0.70, 0.40), Color(0.85, 0.70, 0.30)]
	for row in range(2):
		var bx = x + 3
		var i = 0
		while bx < x + 23:
			draw_rect(Rect2(bx, y + 3 + row * 14, 3, 11), cols[i % cols.size()])
			bx += 4
			i += 1
		draw_line(Vector2(x, y + 15), Vector2(x + 26, y + 15), Color(0.32, 0.22, 0.14), 1.0)

# ─── Decoración de pasillos y zonas comunes ──────────────────
# Bancas, plantas, máquina de café, dispensador de agua, extintor, camilla,
# silla de ruedas, cono de limpieza, reloj de pared y el medallón del cruce.
# Cada piso tiene pequeñas variaciones para que no se sientan clonados.

func _decorar_pasillos():
	# (El cruce de pasillos queda limpio, sin medallón: se probó una cruz
	# médica en el centro y recargaba la zona más transitada del piso.)

	# Vestíbulo superior: bancas de espera y reloj de pared
	_deco_banca(105, 14, 84)
	_deco_banca(555, 14, 84)
	_deco_reloj(405, 22)

	# Esquinas del piso: plantas grandes
	_deco_planta(26, 30)
	_deco_planta(26, 668)
	_deco_planta(778, 30)
	_deco_planta(778, 668)

	# Extintor junto a la zona de escaleras (norma básica de seguridad)
	_deco_extintor(790, 300)

	# ── Variaciones por piso ──
	match floor_number:
		1:
			# Planta baja: máquina de café, dispensador y silla de ruedas
			_deco_maquina_cafe(272, 6)
			_deco_dispensador(452, 12)
			_deco_silla_ruedas(692, 16)
			_deco_cono(366, 372)
		2:
			# Piso clínico: camillas estacionadas y carro de insumos
			_deco_camilla(120, 672)
			_deco_camilla(640, 672)
			_deco_dispensador(452, 12)
			_deco_carrito(280, 14)
		3:
			# Piso de pacientes y oficinas: más verde y tablón de anuncios
			_deco_planta(452, 14)
			_deco_planta(340, 668)
			_deco_tablon(258, 8)
			_deco_silla_ruedas(692, 16)
			_deco_cono(440, 372)

# Halos cálidos de las luces de techo sobre los pasillos
func _halos_de_luz():
	for py in [110, 240, 440, 570, 665]:
		_halo(Vector2(405, py))
	for px in [95, 240, 570, 710]:
		_halo(Vector2(px, 335))

func _halo(c: Vector2):
	draw_set_transform(c, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 34, Color(1.0, 0.95, 0.75, 0.09))
	draw_circle(Vector2.ZERO, 19, Color(1.0, 0.97, 0.85, 0.07))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ── Mobiliario de pasillo ──

func _deco_banca(x: float, y: float, w: float):
	draw_rect(Rect2(x, y, w, 6), Color(0.42, 0.30, 0.18))          # respaldo
	draw_rect(Rect2(x, y + 8, w, 11), Color(0.58, 0.42, 0.26))     # asiento
	draw_rect(Rect2(x, y + 8, w, 11), Color(0.38, 0.27, 0.16), false, 1.5)
	for lx in [x + 3.0, x + w - 6.0]:                              # patas
		draw_rect(Rect2(lx, y + 19, 3, 6), Color(0.30, 0.31, 0.34))
	# Listones del asiento
	var sx = x + 8.0
	while sx < x + w - 6.0:
		draw_line(Vector2(sx, y + 9), Vector2(sx, y + 18), Color(0.46, 0.33, 0.20), 1.0)
		sx += 12.0

func _deco_planta(x: float, y: float):
	draw_rect(Rect2(x - 2, y + 16, 18, 15), Color(0.62, 0.40, 0.26))     # maceta
	draw_rect(Rect2(x - 2, y + 16, 18, 15), Color(0.44, 0.28, 0.17), false, 1.5)
	draw_rect(Rect2(x - 4, y + 14, 22, 4), Color(0.70, 0.47, 0.30))      # borde maceta
	draw_circle(Vector2(x + 7, y + 6), 11, Color(0.24, 0.56, 0.30))
	draw_circle(Vector2(x, y - 1), 7, Color(0.30, 0.66, 0.36))
	draw_circle(Vector2(x + 14, y), 7, Color(0.20, 0.50, 0.27))
	draw_circle(Vector2(x + 7, y - 6), 6, Color(0.34, 0.70, 0.40))

func _deco_maquina_cafe(x: float, y: float):
	draw_rect(Rect2(x, y, 28, 42), Color(0.20, 0.26, 0.38))
	draw_rect(Rect2(x, y, 28, 42), Color(0.12, 0.15, 0.22), false, 2.0)
	draw_rect(Rect2(x + 4, y + 5, 13, 17), Color(0.55, 0.75, 0.95, 0.9))  # ventana
	draw_rect(Rect2(x + 20, y + 6, 5, 3), Color(0.90, 0.40, 0.35))        # botones
	draw_rect(Rect2(x + 20, y + 11, 5, 3), Color(0.95, 0.80, 0.30))
	draw_rect(Rect2(x + 20, y + 16, 5, 3), Color(0.40, 0.80, 0.50))
	draw_rect(Rect2(x + 5, y + 27, 18, 10), Color(0.10, 0.12, 0.16))      # dispensado
	draw_rect(Rect2(x + 11, y + 30, 6, 6), Color(0.85, 0.82, 0.78))       # vasito
	draw_string(ThemeDB.fallback_font, Vector2(x + 3, y + 41), "CAFÉ",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.95, 0.85, 0.55))

func _deco_dispensador(x: float, y: float):
	draw_rect(Rect2(x, y + 14, 14, 22), Color(0.88, 0.91, 0.95))          # base
	draw_rect(Rect2(x, y + 14, 14, 22), Color(0.60, 0.66, 0.74), false, 1.5)
	draw_rect(Rect2(x + 2, y, 10, 15), Color(0.55, 0.78, 0.95, 0.85))     # botellón
	draw_rect(Rect2(x + 2, y, 10, 15), Color(0.35, 0.55, 0.75), false, 1.0)
	draw_rect(Rect2(x + 4, y + 20, 3, 3), Color(0.35, 0.60, 0.85))        # grifos
	draw_rect(Rect2(x + 8, y + 20, 3, 3), Color(0.85, 0.40, 0.35))

func _deco_reloj(x: float, y: float):
	draw_circle(Vector2(x, y), 10, Color(0.95, 0.96, 0.98))
	draw_circle(Vector2(x, y), 10, Color(0.30, 0.33, 0.40), false, 2.0)
	draw_line(Vector2(x, y), Vector2(x, y - 6), Color(0.20, 0.22, 0.28), 1.6)   # minutero
	draw_line(Vector2(x, y), Vector2(x + 4, y + 2), Color(0.20, 0.22, 0.28), 1.6) # horario
	draw_circle(Vector2(x, y), 1.4, Color(0.80, 0.35, 0.30))

func _deco_silla_ruedas(x: float, y: float):
	draw_circle(Vector2(x + 6, y + 22), 9, Color(0.22, 0.24, 0.28))       # rueda grande
	draw_circle(Vector2(x + 6, y + 22), 9, Color(0.45, 0.48, 0.54), false, 1.5)
	draw_circle(Vector2(x + 6, y + 22), 3, Color(0.45, 0.48, 0.54))
	draw_circle(Vector2(x + 19, y + 26), 4, Color(0.22, 0.24, 0.28))      # rueda chica
	draw_rect(Rect2(x + 2, y + 8, 16, 5), Color(0.30, 0.42, 0.60))        # asiento
	draw_rect(Rect2(x, y - 4, 4, 13), Color(0.30, 0.42, 0.60))            # respaldo
	draw_line(Vector2(x + 18, y + 10), Vector2(x + 21, y + 22), Color(0.40, 0.44, 0.50), 2.0)

func _deco_camilla(x: float, y: float):
	draw_rect(Rect2(x, y, 52, 15), Color(0.92, 0.94, 0.97))               # colchón
	draw_rect(Rect2(x, y, 52, 15), Color(0.52, 0.58, 0.66), false, 1.5)
	draw_rect(Rect2(x + 3, y + 3, 10, 9), Color(0.80, 0.86, 0.92))        # almohada
	draw_line(Vector2(x - 2, y + 4), Vector2(x - 2, y + 12), Color(0.55, 0.58, 0.64), 2.5)  # barandas
	draw_line(Vector2(x + 54, y + 4), Vector2(x + 54, y + 12), Color(0.55, 0.58, 0.64), 2.5)
	for wx in [x + 8.0, x + 42.0]:                                        # ruedas
		draw_circle(Vector2(wx, y + 19), 3.2, Color(0.25, 0.27, 0.31))

func _deco_carrito(x: float, y: float):
	draw_rect(Rect2(x, y, 26, 20), Color(0.75, 0.79, 0.85))
	draw_rect(Rect2(x, y, 26, 20), Color(0.48, 0.53, 0.60), false, 1.5)
	draw_line(Vector2(x, y + 10), Vector2(x + 26, y + 10), Color(0.48, 0.53, 0.60), 1.2)
	draw_rect(Rect2(x + 3, y + 2, 7, 5), Color(0.90, 0.45, 0.40))         # frascos
	draw_rect(Rect2(x + 12, y + 2, 7, 5), Color(0.45, 0.70, 0.90))
	for wx in [x + 5.0, x + 21.0]:
		draw_circle(Vector2(wx, y + 23), 2.8, Color(0.25, 0.27, 0.31))

func _deco_extintor(x: float, y: float):
	draw_rect(Rect2(x, y, 11, 20), Color(0.82, 0.24, 0.22))
	draw_rect(Rect2(x, y, 11, 20), Color(0.52, 0.13, 0.12), false, 1.5)
	draw_rect(Rect2(x + 3, y - 4, 5, 4), Color(0.30, 0.32, 0.36))         # válvula
	draw_line(Vector2(x + 2, y - 2), Vector2(x - 3, y + 6), Color(0.20, 0.21, 0.24), 1.5)  # manguera
	draw_rect(Rect2(x + 2, y + 6, 7, 5), Color(0.95, 0.95, 0.97))         # etiqueta

func _deco_cono(x: float, y: float):
	draw_colored_polygon(PackedVector2Array([
		Vector2(x, y - 16), Vector2(x - 8, y), Vector2(x + 8, y)]), Color(0.95, 0.58, 0.15))
	draw_rect(Rect2(x - 10, y - 1, 20, 4), Color(0.95, 0.58, 0.15))       # base
	draw_line(Vector2(x - 4, y - 8), Vector2(x + 4, y - 8), Color(0.98, 0.95, 0.90), 3.0)  # banda

func _deco_tablon(x: float, y: float):
	draw_rect(Rect2(x, y, 44, 30), Color(0.55, 0.40, 0.25))
	draw_rect(Rect2(x + 3, y + 3, 38, 24), Color(0.85, 0.80, 0.68))
	draw_rect(Rect2(x + 6, y + 6, 10, 12), Color(0.95, 0.95, 0.90))       # papeles
	draw_rect(Rect2(x + 19, y + 7, 9, 10), Color(0.75, 0.88, 0.95))
	draw_rect(Rect2(x + 30, y + 6, 8, 13), Color(0.95, 0.85, 0.60))
	draw_circle(Vector2(x + 11, y + 7), 1.2, Color(0.85, 0.30, 0.28))     # chinchetas
	draw_circle(Vector2(x + 23, y + 8), 1.2, Color(0.30, 0.55, 0.85))

# ─── Muros de colisión (paredes y puertas) ───────────────────

func _crear_muros():
	var body = StaticBody2D.new()
	body.name = "Muros"
	add_child(body)
	var t = 8.0
	for key in ["area_izq_arriba", "area_der_arriba", "area_izq_abajo", "area_der_abajo"]:
		_muro_sala(body, LAYOUT[key], PUERTAS[key], t)
	_muros_exteriores(body, t)

func _muro_sala(body: StaticBody2D, rect: Rect2, lado: String, t: float):
	var x = rect.position.x
	var y = rect.position.y
	var w = rect.size.x
	var h = rect.size.y
	var cx = x + w / 2.0
	var cy = y + h / 2.0
	var dw = ANCHO_PUERTA
	# Cada lado: si tiene la puerta, dejamos un hueco centrado
	_pared_h(body, y,     x, x + w, cx, (dw if lado == "top" else 0.0), t)
	_pared_h(body, y + h, x, x + w, cx, (dw if lado == "bottom" else 0.0), t)
	_pared_v(body, x,     y, y + h, cy, (dw if lado == "left" else 0.0), t)
	_pared_v(body, x + w, y, y + h, cy, (dw if lado == "right" else 0.0), t)

# Pared horizontal a la altura 'wy', de x1 a x2, con hueco opcional de ancho 'dw'
func _pared_h(body, wy: float, x1: float, x2: float, gap: float, dw: float, t: float):
	if dw <= 0.0:
		_agregar_muro(body, Vector2((x1 + x2) / 2.0, wy), Vector2(x2 - x1, t))
		return
	var g1 = gap - dw / 2.0
	var g2 = gap + dw / 2.0
	if g1 > x1: _agregar_muro(body, Vector2((x1 + g1) / 2.0, wy), Vector2(g1 - x1, t))
	if x2 > g2: _agregar_muro(body, Vector2((g2 + x2) / 2.0, wy), Vector2(x2 - g2, t))

# Pared vertical en 'wx', de y1 a y2, con hueco opcional de ancho 'dw'
func _pared_v(body, wx: float, y1: float, y2: float, gap: float, dw: float, t: float):
	if dw <= 0.0:
		_agregar_muro(body, Vector2(wx, (y1 + y2) / 2.0), Vector2(t, y2 - y1))
		return
	var g1 = gap - dw / 2.0
	var g2 = gap + dw / 2.0
	if g1 > y1: _agregar_muro(body, Vector2(wx, (y1 + g1) / 2.0), Vector2(t, g1 - y1))
	if y2 > g2: _agregar_muro(body, Vector2(wx, (g2 + y2) / 2.0), Vector2(t, y2 - g2))

func _agregar_muro(body: StaticBody2D, centro: Vector2, tam: Vector2):
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = tam
	cs.shape = rs
	cs.position = centro
	body.add_child(cs)

func _muros_exteriores(body: StaticBody2D, t: float):
	var w = 920.0
	var h = 720.0
	_agregar_muro(body, Vector2(w / 2.0, 0),   Vector2(w, t))   # superior
	_agregar_muro(body, Vector2(w / 2.0, h),   Vector2(w, t))   # inferior
	_agregar_muro(body, Vector2(0, h / 2.0),   Vector2(t, h))   # izquierda
	_agregar_muro(body, Vector2(w, h / 2.0),   Vector2(t, h))   # derecha

# ─── Utilidades para crear nodos ────────────────────────────

func crear_npc(npc_name: String, npc_role: String, pos: Vector2,
			   color: Color, rep: int, archivo_dialogos: String) -> CharacterBody2D:
	var npc_scene_script = load("res://scripts/NPC.gd")
	var npc = CharacterBody2D.new()
	npc.set_script(npc_scene_script)
	# El origen del NPC está en sus pies: se baja para que siga viéndose en 'pos'
	npc.position = pos + Vector2(0, npc_scene_script.PIE_Y)
	npc.set("npc_name", npc_name)
	npc.set("npc_role", npc_role)
	npc.set("npc_color", color)
	npc.set("initial_reputation", rep)
	npc.set("dialogo_archivo", archivo_dialogos)

	# CollisionShape
	var col = CollisionShape2D.new()
	var cap = CapsuleShape2D.new()
	cap.radius = 14.0
	cap.height = 10.0
	col.shape = cap
	npc.add_child(col)

	# Label nombre
	var lbl = Label.new()
	lbl.name = "LabelName"
	lbl.position = Vector2(-45, -58)
	lbl.text = npc_name
	npc.add_child(lbl)

	# Hint interacción (texto vacío: NPC._draw ya dibuja "[Enter] Hablar";
	# el Label sólo se usa como bandera de visibilidad para evitar duplicados)
	var hint = Label.new()
	hint.name = "InteractHint"
	hint.position = Vector2(-15, -75)
	hint.text = ""
	hint.visible = false
	npc.add_child(hint)

	# Barra de reputación
	var bar = ProgressBar.new()
	bar.name = "ReputationBar"
	bar.position = Vector2(-30, -42)
	bar.custom_minimum_size = Vector2(60, 8)
	bar.max_value = 100.0
	bar.value = float(rep)
	npc.add_child(bar)

	return npc

func crear_zona(tipo: String, label: String, pos: Vector2,
				color: Color, destino: int = 0) -> Area2D:
	var zona_script = load("res://scripts/InteractiveZone.gd")
	var zona = Area2D.new()
	zona.set_script(zona_script)
	zona.position = pos
	zona.set("tipo", tipo)
	zona.set("label_texto", label)
	zona.set("color_zona", color)
	zona.set("destino_piso", destino)
	return zona
