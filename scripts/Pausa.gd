extends Node
# Autoload: Pausa — menú de pausa con volumen y silencio.
# Se abre con la tecla P o con el botón ⏸ del HUD (solo durante la partida).

var _capa: CanvasLayer
var _panel: Panel
var _slider: HSlider
var _btn_silencio: Button
var _fuente: SystemFont

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # funciona con el árbol en pausa
	_fuente = SystemFont.new()
	_fuente.font_names = PackedStringArray(["Segoe UI Semibold", "Segoe UI", "Arial"])
	_construir()

func _construir():
	_capa = CanvasLayer.new()
	_capa.layer = 90
	_capa.visible = false
	add_child(_capa)

	var fondo = ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.anchor_right = 1.0
	fondo.anchor_bottom = 1.0
	fondo.color = Color(0, 0, 0, 0.62)
	_capa.add_child(fondo)

	_panel = Panel.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -230
	_panel.offset_top = -200
	_panel.offset_right = 230
	_panel.offset_bottom = 200
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.13, 0.19, 0.98)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.30, 0.55, 0.85, 0.85)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", sb)
	_capa.add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 26
	vbox.offset_top = 26
	vbox.offset_right = -26
	vbox.offset_bottom = -26
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	var t = Label.new()
	t.text = "⏸   PAUSA"
	t.add_theme_font_override("font", _fuente)
	t.add_theme_font_size_override("font_size", 38)
	t.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(t)

	var lv = Label.new()
	lv.text = "🔊  Volumen de la música"
	lv.add_theme_font_override("font", _fuente)
	lv.add_theme_color_override("font_color", Color(0.80, 0.85, 0.92))
	vbox.add_child(lv)

	_slider = HSlider.new()
	_slider.min_value = 0
	_slider.max_value = 100
	_slider.step = 1
	_slider.value = 65
	_slider.custom_minimum_size = Vector2(0, 26)
	_slider.value_changed.connect(_on_volumen)
	vbox.add_child(_slider)

	_btn_silencio = _boton("🔇  Silenciar música")
	_btn_silencio.pressed.connect(_on_silencio)
	vbox.add_child(_btn_silencio)

	vbox.add_child(HSeparator.new())

	var cont = _boton("▶   Continuar")
	cont.pressed.connect(reanudar)
	vbox.add_child(cont)

	var salir = _boton("✕   Salir del juego")
	salir.pressed.connect(func(): get_tree().quit())
	vbox.add_child(salir)

func _boton(txt: String) -> Button:
	var b = Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _fuente)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	var c = Color(0.18, 0.34, 0.55)
	b.add_theme_stylebox_override("normal", _sb(c))
	b.add_theme_stylebox_override("hover", _sb(c.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", _sb(c.darkened(0.18)))
	return b

func _sb(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(10)
	return sb

# ─── Lógica de pausa ─────────────────────────────────────────

func _en_partida() -> bool:
	return get_tree().get_first_node_in_group("player") != null

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		if _capa.visible or _en_partida():
			alternar_pausa()
			get_viewport().set_input_as_handled()

func alternar_pausa():
	if _capa.visible:
		reanudar()
	else:
		pausar()

func pausar():
	if not _en_partida():
		return
	_sincronizar()
	_capa.visible = true
	get_tree().paused = true

func reanudar():
	_capa.visible = false
	get_tree().paused = false

func _sincronizar():
	if Musica:
		var v = clamp((Musica.volumen_db + 40.0) / 40.0 * 100.0, 0.0, 100.0)
		_slider.set_value_no_signal(v)

func _on_volumen(v: float):
	var db = -40.0 + (v / 100.0) * 40.0
	if v <= 0.5:
		db = -60.0  # extremo izquierdo = prácticamente mudo
	if Musica and Musica.has_method("set_volumen"):
		Musica.set_volumen(db)

func _on_silencio():
	if Musica and Musica.has_method("alternar_silencio"):
		var muteado = Musica.alternar_silencio()
		_btn_silencio.text = "🔈  Reanudar música" if muteado else "🔇  Silenciar música"
