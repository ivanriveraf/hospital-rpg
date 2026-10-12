extends Area2D

signal zona_usada(tipo, datos)

@export var tipo: String = "escaleras_subir"
@export var label_texto: String = "▲ Subir"
@export var color_zona: Color = Color(0.4, 0.4, 0.8, 0.7)
@export var destino_piso: int = 0

# Costes de tiempo (en minutos de juego)
const COSTO_ESCALERAS = 13
const COSTO_ASCENSOR  = 7
const COSTO_AVERIA    = 25   # Tiempo extra si el ascensor falla
const PROB_AVERIA     = 0.30 # 30% de probabilidad de avería

var player_dentro: bool = false
var hint_label: Label = null
var en_cooldown: bool = false  # Evita activar dos veces seguidas

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var shape = CollisionShape2D.new()
	var rect  = RectangleShape2D.new()
	rect.size = Vector2(70, 50)
	shape.shape = rect
	add_child(shape)

	hint_label = Label.new()
	hint_label.position = Vector2(-55, -55)
	hint_label.add_theme_color_override("font_color", Color.YELLOW)
	hint_label.visible = false
	add_child(hint_label)
	_actualizar_hint()

func _actualizar_hint():
	if hint_label:
		hint_label.text = "[Enter] %s" % label_texto

var _pulso: float = 0.0

func _process(delta):
	_pulso += delta
	queue_redraw()

func _draw():
	var late = 0.3 * sin(_pulso * 2.0)
	# Caja redondeada con sombra
	var sb = StyleBoxFlat.new()
	sb.bg_color = color_zona
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.75)
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = 4
	draw_style_box(sb, Rect2(-35, -25, 70, 50))

	# Halo pulsante: más intenso si el jugador está dentro
	var intensidad = (0.75 + 0.25 * sin(_pulso * 6.0)) if player_dentro else (0.25 + 0.1 * sin(_pulso * 2.0))
	var halo = StyleBoxFlat.new()
	halo.bg_color = Color(0, 0, 0, 0)
	halo.set_corner_radius_all(12)
	halo.set_border_width_all(3 if player_dentro else 2)
	halo.border_color = Color(1, 1, 0.55, intensidad)
	draw_style_box(halo, Rect2(-40 - late, -30 - late, 80 + 2 * late, 60 + 2 * late))

	# Texto en hasta dos líneas centradas (antes se cortaba, ej. "Subir al")
	var lineas = _partir_texto(label_texto)
	var font = ThemeDB.fallback_font
	if lineas.size() == 1:
		draw_string(font, Vector2(-34, 4), lineas[0],
			HORIZONTAL_ALIGNMENT_CENTER, 68, 11, Color.WHITE)
	else:
		draw_string(font, Vector2(-34, -3), lineas[0],
			HORIZONTAL_ALIGNMENT_CENTER, 68, 11, Color.WHITE)
		draw_string(font, Vector2(-34, 11), lineas[1],
			HORIZONTAL_ALIGNMENT_CENTER, 68, 11, Color.WHITE)

# Divide el texto en dos líneas por el espacio más cercano al centro
func _partir_texto(txt: String) -> Array:
	if txt.length() <= 11 or not " " in txt:
		return [txt]
	var mitad = txt.length() / 2
	var mejor = -1
	for i in range(txt.length()):
		if txt[i] == " " and (mejor == -1 or abs(i - mitad) < abs(mejor - mitad)):
			mejor = i
	if mejor == -1:
		return [txt]
	return [txt.substr(0, mejor), txt.substr(mejor + 1)]

func _unhandled_input(event):
	if event.is_action_pressed("ui_accept") and player_dentro and not en_cooldown:
		# No abrir el menú si ya hay un diálogo o una animación de transporte en
		# curso (evita que se apilen y se quede pegado el diálogo).
		if _ui_ocupada():
			return
		_mostrar_menu_transporte()
		get_viewport().set_input_as_handled()

func _ui_ocupada() -> bool:
	var d = GameManager.dialogue_ui
	if d != null and d.has_method("esta_visible") and d.esta_visible():
		return true
	var s = GameManager.stairs_ui
	if s != null and s.has_method("esta_animando") and s.esta_animando():
		return true
	return false

func _mostrar_menu_transporte():
	# Si es zona de otro tipo (bodega, farmacia), activar directamente
	if tipo not in ["escaleras_subir", "escaleras_bajar", "ascensor"]:
		_activar_zona()
		return

	# Mostrar elección: escaleras vs ascensor
	var es_subir = tipo == "escaleras_subir"
	var direccion = "Subir" if es_subir else "Bajar"
	var datos_dialogo = {
		"texto": "¿Cómo prefieres %s de piso?" % direccion.to_lower(),
		"opciones": [
			{
				"texto": "🪜 Escaleras  (−%d min, siempre funciona)" % COSTO_ESCALERAS,
				"accion": "escaleras"
			},
			{
				"texto": "🛗 Ascensor   (−%d min, %d%% avería = −%d min extra)" % [
					COSTO_ASCENSOR, int(PROB_AVERIA * 100), COSTO_AVERIA],
				"accion": "ascensor"
			},
			{
				"texto": "Quedarme en este piso",
				"accion": "cancelar"
			}
		]
	}
	GameManager.show_transport_dialogue(datos_dialogo, self)

func usar_transporte(accion: String):
	var subiendo = (tipo == "escaleras_subir")
	match accion:
		"escaleras":
			TiempoLaboral.descontar_tiempo(COSTO_ESCALERAS, "")
			GameManager.stairs_ui.mostrar_escaleras(subiendo, _cambiar_piso)
		"ascensor":
			if randf() < PROB_AVERIA:
				TiempoLaboral.descontar_tiempo(COSTO_ASCENSOR + COSTO_AVERIA, "")
				GameManager.stairs_ui.mostrar_ascensor_averia(_cambiar_piso)
			else:
				TiempoLaboral.descontar_tiempo(COSTO_ASCENSOR, "")
				GameManager.stairs_ui.mostrar_ascensor_ok(subiendo, _cambiar_piso)
		"cancelar":
			pass

func _cambiar_piso() -> void:
	en_cooldown = true
	match tipo:
		"escaleras_subir":
			FloorManager.cambiar_piso(FloorManager.piso_actual + 1)
		"escaleras_bajar":
			FloorManager.cambiar_piso(FloorManager.piso_actual - 1)
		"ascensor":
			FloorManager.cambiar_piso(destino_piso)
	# Cooldown para evitar re-activación inmediata
	get_tree().create_timer(1.0).timeout.connect(func(): en_cooldown = false)

func _activar_zona():
	match tipo:
		"bodega":
			GameManager.abrir_bodega()
		"farmacia":
			GameManager.abrir_farmacia()
		"laboratorio":
			# BUGFIX: si el jugador venía sin hablar con el Técnico Carlos, la
			# misión seguía PENDIENTE y el objetivo no se registraba (el aviso
			# decía "entregadas" pero la misión nunca se completaba).
			var m_id = "muestras_laboratorio"
			if SistemaMisiones.misiones.has(m_id) and \
			   SistemaMisiones.misiones[m_id].estado == SistemaMisiones.Estado.PENDIENTE:
				SistemaMisiones.aceptar_mision(m_id)
			TiempoLaboral.descontar_tiempo(11, "Entregando muestras en laboratorio")
			SistemaMisiones.completar_objetivo(m_id, "llevar_muestras")
			GameManager.hud.mostrar_aviso("🔬 Muestras entregadas en laboratorio.")

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_dentro = true
		if hint_label: hint_label.visible = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_dentro = false
		if hint_label: hint_label.visible = false
