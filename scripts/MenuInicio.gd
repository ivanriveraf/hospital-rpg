extends Control
# Menú de inicio. Es la escena principal del juego (ver project.godot).
# "Jugar" carga la partida (Main.tscn). La música suena sola (autoload Musica).

var _titulo: Label = null
var _t: float = 0.0
var _fuente: SystemFont = null

func _ready():
	_fuente = SystemFont.new()
	_fuente.font_names = PackedStringArray(["Segoe UI Semibold", "Segoe UI", "Bahnschrift", "Arial"])
	_construir()

func _construir():
	# ── Título (grande, con doble contorno y animación de brillo/escala) ──
	_titulo = Label.new()
	_titulo.text = "🏥 HOSPITAL RPG"
	_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titulo.add_theme_font_override("font", _fuente)
	_titulo.add_theme_font_size_override("font_size", 92)
	_titulo.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_titulo.add_theme_color_override("font_outline_color", Color(0.12, 0.45, 0.90))
	_titulo.add_theme_constant_override("outline_size", 16)
	_titulo.add_theme_color_override("font_shadow_color", Color(0.0, 0.15, 0.35, 0.85))
	_titulo.add_theme_constant_override("shadow_offset_x", 0)
	_titulo.add_theme_constant_override("shadow_offset_y", 6)
	_titulo.add_theme_constant_override("shadow_outline_size", 6)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_titulo.offset_top = 70
	_titulo.offset_bottom = 200
	_titulo.pivot_offset = Vector2(640, 65)
	add_child(_titulo)

	# ── Subtítulo ──
	var sub = Label.new()
	sub.text = "Un turno en el hospital: cumple las misiones del día, gánate al equipo y sobrevive a la semana."
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_theme_font_override("font", _fuente)
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.62, 0.72, 0.86))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_left = 240
	sub.offset_right = -240
	sub.offset_top = 225
	sub.offset_bottom = 295
	add_child(sub)

	# ── Botones (centrados) ──
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.add_theme_constant_override("separation", 18)
	vbox.offset_left = -170
	vbox.offset_right = 170
	vbox.offset_top = 25
	vbox.offset_bottom = 200
	add_child(vbox)

	var jugar = _boton("▶   Jugar", Color(0.20, 0.52, 0.34))
	jugar.pressed.connect(_jugar)
	vbox.add_child(jugar)

	var salir = _boton("✕   Salir", Color(0.42, 0.26, 0.30))
	salir.pressed.connect(_salir)
	vbox.add_child(salir)

	jugar.grab_focus()

	# ── Pie de pantalla (solo los controles; sin notas de desarrollo) ──
	var cred = Label.new()
	cred.text = "Muévete con las flechas o WASD  ·  Enter para confirmar"
	cred.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cred.add_theme_font_override("font", _fuente)
	cred.add_theme_font_size_override("font_size", 13)
	cred.add_theme_color_override("font_color", Color(0.45, 0.52, 0.62))
	cred.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cred.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cred.offset_top = -42
	cred.offset_bottom = -16
	add_child(cred)

func _boton(txt: String, color: Color) -> Button:
	var b = Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(340, 58)
	b.add_theme_font_override("font", _fuente)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.add_theme_stylebox_override("normal", _sb(color))
	b.add_theme_stylebox_override("hover", _sb(color.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", _sb(color.darkened(0.18)))
	b.add_theme_stylebox_override("focus", _sb(color.lightened(0.18)))
	return b

func _sb(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(color.r + 0.2, color.g + 0.2, color.b + 0.2, 0.9)
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _process(delta):
	_t += delta
	if _titulo:
		# Brillo suave + "respiración" de escala para que el título llame la atención
		_titulo.modulate.a = 0.88 + 0.12 * sin(_t * 2.2)
		var esc = 1.0 + 0.018 * sin(_t * 1.6)
		_titulo.scale = Vector2(esc, esc)

func _draw():
	var s = size
	if s.x < 10.0:
		s = get_viewport_rect().size
	# Fondo
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.07, 0.10, 0.16))
	draw_rect(Rect2(0, 0, s.x, s.y * 0.55), Color(0.10, 0.14, 0.22, 0.55))
	# Cruces médicas decorativas
	_cruz(Vector2(s.x * 0.15, s.y * 0.60), 130, Color(0.20, 0.42, 0.72, 0.10))
	_cruz(Vector2(s.x * 0.85, s.y * 0.30), 95, Color(0.20, 0.50, 0.62, 0.10))
	_cruz(Vector2(s.x * 0.80, s.y * 0.80), 75, Color(0.30, 0.42, 0.72, 0.08))

func _cruz(c: Vector2, r: float, col: Color):
	var w = r * 0.34
	draw_rect(Rect2(c.x - w / 2.0, c.y - r / 2.0, w, r), col)
	draw_rect(Rect2(c.x - r / 2.0, c.y - w / 2.0, r, w), col)

func _jugar():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _salir():
	get_tree().quit()
