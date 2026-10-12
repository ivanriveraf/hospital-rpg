extends Node
# Autoload: Efectos
# Efectos visuales globales: textos flotantes, destellos de pantalla y
# transición al cambiar de piso. Se conecta a las señales del juego.

var _capa: CanvasLayer
var _fade: ColorRect

func _ready():
	_capa = CanvasLayer.new()
	_capa.layer = 60
	add_child(_capa)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.add_child(_fade)

	call_deferred("_conectar_senales")

func _conectar_senales():
	if GameManager:
		if not GameManager.experiencia_ganada.is_connected(_on_xp):
			GameManager.experiencia_ganada.connect(_on_xp)
		if not GameManager.nivel_subido.is_connected(_on_nivel):
			GameManager.nivel_subido.connect(_on_nivel)
	if SistemaMisiones:
		SistemaMisiones.mision_completada.connect(_on_mision_completada)
		SistemaMisiones.mision_fallida.connect(_on_mision_fallida)
		SistemaMisiones.mision_critica_fallida.connect(_on_mision_critica)
	if FloorManager:
		FloorManager.piso_cambiado.connect(_on_piso_cambiado)

# ─── API pública ─────────────────────────────────────────────

# Texto flotante que sube y se desvanece
func popup(texto: String, color: Color = Color.WHITE, pos: Vector2 = Vector2(560, 280), tam: int = 26):
	var lbl = Label.new()
	lbl.text = texto
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", tam)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.position = pos
	_capa.add_child(lbl)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y - 70.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tw.chain().tween_callback(lbl.queue_free)

# Destello de pantalla de un color (breve)
func flash(color: Color, intensidad: float = 0.32):
	var fl = ColorRect.new()
	fl.color = Color(color.r, color.g, color.b, intensidad)
	fl.anchor_right = 1.0
	fl.anchor_bottom = 1.0
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.add_child(fl)
	var tw = create_tween()
	tw.tween_property(fl, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(fl.queue_free)

# Ráfaga de partículas tipo confeti
func burst(pos: Vector2, color: Color, cantidad: int = 26):
	var p = CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.amount = cantidad
	p.lifetime = 0.9
	p.explosiveness = 0.92
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 240)
	p.initial_velocity_min = 130.0
	p.initial_velocity_max = 280.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.color = color
	_capa.add_child(p)
	get_tree().create_timer(1.3).timeout.connect(p.queue_free)

# Temblor de cámara que se va apagando
func sacudir(fuerza: float = 10.0, duracion: float = 0.45):
	var cam = get_viewport().get_camera_2d()
	if cam == null:
		return
	var pasos = 9
	var tw = create_tween()
	for i in range(pasos):
		var f = fuerza * (1.0 - float(i) / pasos)
		tw.tween_property(cam, "offset", Vector2(randf_range(-f, f), randf_range(-f, f)), duracion / pasos)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)

# Fundido rápido para cubrir el cambio de piso
func transicion_piso():
	var tw = create_tween()
	tw.tween_property(_fade, "color:a", 0.6, 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_fade, "color:a", 0.0, 0.38).set_trans(Tween.TRANS_SINE)

# ─── Reacciones a señales del juego ──────────────────────────

func _on_xp(cantidad: int):
	if cantidad > 0:
		popup("+%d XP" % cantidad, Color(0.55, 0.85, 1.0), Vector2(980, 64), 22)

func _on_nivel(nivel: int):
	flash(Color(1.0, 0.85, 0.25), 0.28)
	burst(Vector2(640, 230), Color(1.0, 0.85, 0.3), 34)
	popup("⭐ ¡Nivel %d!" % nivel, Color(1.0, 0.9, 0.35), Vector2(560, 200), 32)

func _on_mision_completada(_m):
	flash(Color(0.2, 0.85, 0.4), 0.26)
	burst(Vector2(640, 260), Color(0.4, 0.95, 0.55), 28)
	popup("✅ ¡Misión completada!", Color(0.45, 1.0, 0.55), Vector2(470, 240), 30)

func _on_mision_fallida(_m):
	popup("✖ Misión fallida", Color(1.0, 0.5, 0.4), Vector2(520, 250), 26)

func _on_mision_critica(_m):
	flash(Color(0.95, 0.10, 0.10), 0.40)
	sacudir(12.0, 0.5)

func _on_piso_cambiado(_numero, _nombre):
	transicion_piso()
