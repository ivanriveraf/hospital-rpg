extends Node2D

func _ready():
	# Conectar UI al GameManager
	GameManager.dialogue_ui = $DialogueUI
	GameManager.bodega_ui   = $BodegaUI
	GameManager.farmacia_ui = $FarmaciaUI
	GameManager.hud         = $HUD
	GameManager.stairs_ui   = $StairsElevatorUI

	# Registrar al jugador
	$Player.add_to_group("player")

	# Inicializar el piso
	FloorManager.inicializar($FloorContainer)

	# Piso inicial (el HUD lo actualiza vía señal piso_cambiado en adelante)
	var lbl_piso = get_node_or_null("HUD/TopBar/LblPiso")
	if lbl_piso: lbl_piso.text = "P1 · Planta Baja"
	# Nota: hora_critica, hora_actualizada, piso_cambiado y dia_iniciado
	# los gestiona HUD.gd directamente — no duplicar aquí.

	# Flecha de objetivo (crea también HUD/PanelObjetivo, que recibe el tema)
	$Player.add_child(preload("res://scripts/GuiaObjetivo.gd").new())

	_aplicar_tema()

# ─── Tema visual y tipografía ────────────────────────────────
func _aplicar_tema():
	var t = _construir_tema()
	var rutas = [
		"HUD/TopBar", "HUD/BotonesLaterales", "HUD/PanelInventario", "HUD/PanelMisiones", "HUD/BannerAviso",
		"HUD/PanelObjetivo",
		"DialogueUI/Panel", "BodegaUI/Panel", "FarmaciaUI/Panel",
		"GameOverUI/Panel", "DayResultsUI/Panel", "StairsElevatorUI/Panel",
	]
	for r in rutas:
		var n = get_node_or_null(r)
		if n: n.theme = t
	_fondo_topbar()

func _construir_tema() -> Theme:
	var t = Theme.new()
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI Semibold", "Segoe UI", "Bahnschrift", "Trebuchet MS", "Arial"])
	t.default_font = font
	t.default_font_size = 15

	var panel = StyleBoxFlat.new()
	panel.bg_color = Color(0.11, 0.13, 0.19, 0.96)
	panel.set_corner_radius_all(14)
	panel.set_border_width_all(2)
	panel.border_color = Color(0.30, 0.55, 0.85, 0.7)
	panel.set_content_margin_all(12)
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 10
	t.set_stylebox("panel", "Panel", panel)

	t.set_stylebox("normal", "Button", _sb_boton(Color(0.18, 0.34, 0.55)))
	t.set_stylebox("hover", "Button", _sb_boton(Color(0.26, 0.48, 0.74)))
	t.set_stylebox("pressed", "Button", _sb_boton(Color(0.13, 0.25, 0.40)))
	t.set_stylebox("disabled", "Button", _sb_boton(Color(0.20, 0.22, 0.26)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color(0.95, 0.97, 1.0))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Color(0.82, 0.90, 1.0))
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.57, 0.62))
	t.set_font_size("font_size", "Button", 15)

	t.set_color("font_color", "Label", Color(0.90, 0.93, 0.97))

	var pbg = StyleBoxFlat.new()
	pbg.bg_color = Color(0.07, 0.08, 0.12, 0.9)
	pbg.set_corner_radius_all(6)
	var pfill = StyleBoxFlat.new()
	pfill.bg_color = Color(0.30, 0.70, 0.95)
	pfill.set_corner_radius_all(6)
	t.set_stylebox("background", "ProgressBar", pbg)
	t.set_stylebox("fill", "ProgressBar", pfill)
	return t

func _sb_boton(color_fondo: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color_fondo
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Color(color_fondo.r + 0.15, color_fondo.g + 0.18, color_fondo.b + 0.2, 0.9)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

# Barra oscura tras el TopBar para que el texto se lea sobre el mapa
func _fondo_topbar():
	var hud = get_node_or_null("HUD")
	if hud == null or hud.has_node("FondoTopBar"):
		return
	var fondo = Panel.new()
	fondo.name = "FondoTopBar"
	fondo.position = Vector2(0, 0)
	fondo.size = Vector2(1280, 52)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.18, 0.92)
	sb.border_width_bottom = 2
	sb.border_color = Color(0.30, 0.55, 0.85, 0.55)
	fondo.add_theme_stylebox_override("panel", sb)
	hud.add_child(fondo)
	hud.move_child(fondo, 0)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		GameManager.guardar_partida()
		if GameManager.hud:
			GameManager.hud.mostrar_aviso("💾 Partida guardada.")
