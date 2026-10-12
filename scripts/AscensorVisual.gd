extends Control
# Mini-escena animada de escaleras/ascensor (dibujada por código).
# La usa StairsElevatorUI en lugar del antiguo arte ASCII.

var _modo: String = "ascensor"   # "escaleras" | "ascensor" | "averia"
var _subiendo: bool = true
var _duracion: float = 1.8
var _t: float = 0.0

func play(modo: String, subiendo: bool, duracion: float):
	_modo = modo
	_subiendo = subiendo
	_duracion = maxf(duracion, 0.1)
	_t = 0.0
	visible = true
	queue_redraw()

func _process(delta):
	if not visible:
		return
	_t += delta
	queue_redraw()

func _progreso() -> float:
	return clampf(_t / _duracion, 0.0, 1.0)

func _draw():
	# Fondo de la escena
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.10, 0.15, 0.6))
	match _modo:
		"escaleras": _draw_escaleras()
		"averia":    _draw_averia()
		_:           _draw_ascensor()

# ─── Helpers de dibujo ───────────────────────────────────────

func _caja(r: Rect2, fill: Color, borde: Color, radio: int = 6, grosor: int = 2):
	var sb = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radio)
	sb.border_color = borde
	sb.set_border_width_all(grosor)
	draw_style_box(sb, r)

func _enfermero(pos: Vector2, esc: float = 1.0, asustado: bool = false):
	draw_rect(Rect2(pos.x - 9 * esc, pos.y - 2 * esc, 18 * esc, 22 * esc), Color(0.22, 0.52, 0.9))
	draw_rect(Rect2(pos.x - 2 * esc, pos.y + 2 * esc, 4 * esc, 9 * esc), Color.WHITE)
	draw_rect(Rect2(pos.x - 5 * esc, pos.y + 4 * esc, 10 * esc, 4 * esc), Color.WHITE)
	draw_circle(pos + Vector2(0, -11 * esc), 8.5 * esc, Color(0.92, 0.79, 0.66))
	if asustado:
		draw_circle(pos + Vector2(7 * esc, -13 * esc), 2.5 * esc, Color(0.5, 0.8, 1.0, 0.9))

# ─── ASCENSOR ────────────────────────────────────────────────

func _draw_ascensor():
	var s = size
	var p = _progreso()
	var cx = s.x / 2.0
	var shaft = Rect2(cx - 80, 12, 160, s.y - 24)
	_caja(shaft, Color(0.12, 0.14, 0.19), Color(0.30, 0.34, 0.42), 10, 3)
	draw_line(Vector2(shaft.position.x + 12, shaft.position.y + 8), Vector2(shaft.position.x + 12, shaft.end.y - 8), Color(0.28, 0.32, 0.40), 2)
	draw_line(Vector2(shaft.end.x - 12, shaft.position.y + 8), Vector2(shaft.end.x - 12, shaft.end.y - 8), Color(0.28, 0.32, 0.40), 2)

	var y_top = shaft.position.y + 14
	var y_bot = shaft.end.y - 78
	var cy = lerpf(y_bot, y_top, p) if _subiendo else lerpf(y_top, y_bot, p)

	# Líneas de velocidad (detrás de la cabina)
	if p > 0.08 and p < 0.85:
		var dir = 1.0 if _subiendo else -1.0
		for i in range(4):
			var lx = cx - 48 + i * 32
			var ly = fmod(_t * 320.0 + i * 50.0, shaft.size.y)
			draw_line(Vector2(lx, shaft.position.y + ly), Vector2(lx, shaft.position.y + ly + 16.0 * dir), Color(0.5, 0.7, 1.0, 0.22), 2)

	# Cable
	draw_line(Vector2(cx, shaft.position.y + 5), Vector2(cx, cy), Color(0.55, 0.58, 0.64), 2)

	# Cabina
	var cab = Rect2(cx - 60, cy, 120, 66)
	_caja(cab, Color(0.60, 0.65, 0.72), Color(0.38, 0.42, 0.50), 7, 2)
	var inter = Rect2(cab.position.x + 7, cab.position.y + 9, cab.size.x - 14, cab.size.y - 16)
	draw_rect(inter, Color(0.84, 0.88, 0.92))
	_enfermero(Vector2(inter.get_center().x, inter.end.y - 12), 0.9)

	# Puertas que se abren al llegar
	var apert = clampf((p - 0.80) / 0.20, 0.0, 1.0)
	var dw = (inter.size.x / 2.0) * (1.0 - apert)
	if dw > 0.5:
		draw_rect(Rect2(inter.position.x, inter.position.y, dw, inter.size.y), Color(0.52, 0.56, 0.63))
		draw_rect(Rect2(inter.end.x - dw, inter.position.y, dw, inter.size.y), Color(0.52, 0.56, 0.63))
		draw_line(Vector2(inter.get_center().x, inter.position.y), Vector2(inter.get_center().x, inter.end.y), Color(0.33, 0.36, 0.42), 1)

	# Display de flecha (parpadea)
	var blink = 0.5 + 0.5 * sin(_t * 8.0)
	draw_string(ThemeDB.fallback_font, Vector2(cab.position.x + 8, cab.position.y - 5),
		"▲" if _subiendo else "▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.45, 0.9, 1.0, blink))

	_luces_piso(shaft, cy)

func _luces_piso(shaft: Rect2, cy: float):
	var lx = shaft.end.x + 16
	var nombres = ["P3", "P2", "P1"]
	var ys = [shaft.position.y + 18, shaft.get_center().y, shaft.end.y - 18]
	for i in range(3):
		var activa = absf(ys[i] - (cy + 33.0)) < 42.0
		draw_circle(Vector2(lx, ys[i]), 6.0, Color(0.4, 0.95, 0.5) if activa else Color(0.3, 0.34, 0.40))
		draw_string(ThemeDB.fallback_font, Vector2(lx + 12, ys[i] + 5), nombres[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.75, 0.82))

# ─── AVERÍA ──────────────────────────────────────────────────

func _draw_averia():
	var s = size
	var cx = s.x / 2.0
	var shaft = Rect2(cx - 80, 12, 160, s.y - 24)
	_caja(shaft, Color(0.12, 0.14, 0.19), Color(0.5, 0.20, 0.20), 10, 3)

	var cy = shaft.get_center().y - 20.0
	var shake = Vector2(sin(_t * 40.0) * 3.0, sin(_t * 33.0) * 2.0)
	var cab = Rect2(cx - 60 + shake.x, cy + shake.y, 120, 66)

	draw_line(Vector2(cx, shaft.position.y + 5), Vector2(cx + sin(_t * 10.0) * 4.0, cab.position.y), Color(0.5, 0.5, 0.5), 2)
	_caja(cab, Color(0.55, 0.50, 0.50), Color(0.7, 0.25, 0.25), 7, 3)
	var inter = Rect2(cab.position.x + 7, cab.position.y + 9, cab.size.x - 14, cab.size.y - 16)
	draw_rect(inter, Color(0.75, 0.70, 0.70))
	_enfermero(Vector2(inter.get_center().x, inter.end.y - 12), 0.9, true)

	var blink = 1.0 if fmod(_t, 0.6) < 0.3 else 0.2
	draw_string(ThemeDB.fallback_font, Vector2(cab.position.x - 6, cab.position.y - 6), "⚠", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.8, 0.1, blink))
	draw_string(ThemeDB.fallback_font, Vector2(cab.end.x - 16, cab.position.y - 6), "⚠", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.8, 0.1, blink))
	for i in range(3):
		var sx = cx - 30 + fmod(_t * 130.0 + i * 50.0, 60.0)
		var sy = cab.position.y - 8 + sin(_t * 20.0 + i) * 3.0
		draw_line(Vector2(sx, sy), Vector2(sx + 4, sy - 5), Color(1.0, 0.9, 0.3, blink), 2)

# ─── ESCALERAS ───────────────────────────────────────────────

func _draw_escaleras():
	var s = size
	var p = _progreso()
	var pasos = 6
	var x0 = s.x * 0.30
	var x1 = s.x * 0.70
	var ytop = 30.0
	var ybot = s.y - 30.0
	var ancho = (x1 - x0) / pasos
	var alto = (ybot - ytop) / pasos

	for i in range(pasos):
		var ex = x0 + i * ancho
		var ey = (ybot - (i + 1) * alto) if _subiendo else (ytop + i * alto)
		draw_rect(Rect2(ex, ey, ancho + 1, alto + 1), Color(0.55, 0.58, 0.66))
		draw_rect(Rect2(ex, ey, ancho + 1, 4), Color(0.70, 0.73, 0.80))
		draw_rect(Rect2(ex, ey, ancho + 1, alto + 1), Color(0.35, 0.38, 0.45), false, 1.5)

	var paso_actual = int(clampf(p * pasos, 0, pasos - 1))
	var px = x0 + (paso_actual + 0.5) * ancho
	var py = (ybot - (paso_actual + 1) * alto) if _subiendo else (ytop + paso_actual * alto)
	var bob = absf(sin(_t * 12.0)) * 4.0
	_enfermero(Vector2(px, py - 14 - bob), 1.0)

	if _subiendo:
		draw_line(Vector2(x0, ybot - 4), Vector2(x1, ytop - 4), Color(0.45, 0.50, 0.60), 3)
	else:
		draw_line(Vector2(x0, ytop - 4), Vector2(x1, ybot - 4), Color(0.45, 0.50, 0.60), 3)
