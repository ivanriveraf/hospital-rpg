extends CanvasLayer
# Pantalla de animación al usar escaleras o ascensor.
# Se registra en GameManager como stairs_ui.

@onready var panel      = $Panel
@onready var lbl_titulo = $Panel/VBox/LblTitulo
@onready var lbl_arte   = $Panel/VBox/LblArte
@onready var lbl_desc   = $Panel/VBox/LblDesc
@onready var lbl_cuenta = $Panel/VBox/LblCuenta

var _callback: Callable = Callable()
var _cuenta_activa: bool = false
var _segundos_restantes: float = 0.0
var _animando: bool = false   # true mientras una animación está en curso
var _visual: Control = null   # mini-escena animada (sustituye al arte ASCII)

func esta_animando() -> bool:
	return _animando

const COSTO_ESCALERAS = 13
const COSTO_ASCENSOR  = 7
const COSTO_AVERIA    = 25

func _ready():
	panel.visible = false
	lbl_cuenta.add_theme_color_override("font_color", Color(0.95, 0.45, 0.2))
	_crear_visual()

func _crear_visual():
	_visual = load("res://scripts/AscensorVisual.gd").new()
	_visual.custom_minimum_size = Vector2(0, 200)
	_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_visual.visible = false
	var vbox = lbl_arte.get_parent()
	vbox.add_child(_visual)
	vbox.move_child(_visual, lbl_arte.get_index())
	# Ocultar el antiguo arte ASCII (ya no se usa)
	lbl_arte.visible = false
	lbl_arte.custom_minimum_size = Vector2(0, 0)

func _process(delta):
	if _cuenta_activa and _segundos_restantes > 0:
		_segundos_restantes -= delta
		lbl_cuenta.text = "⏳ Esperando... %.0f segundos" % max(_segundos_restantes, 0)
		if _segundos_restantes <= 0:
			_cuenta_activa = false
			_terminar()

# ─── Escaleras ───────────────────────────────────────────────

func mostrar_escaleras(subiendo: bool, cb: Callable):
	if _animando:
		return
	_callback = cb
	lbl_titulo.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	lbl_titulo.text = "🪜  " + ("Subiendo por las escaleras..." if subiendo else "Bajando por las escaleras...")
	lbl_desc.text   = "Más lento, pero siempre confiable.\n−%d minutos de tu turno de trabajo." % COSTO_ESCALERAS

	_visual.play("escaleras", subiendo, 2.5)
	_iniciar(2.5)

# ─── Ascensor OK ─────────────────────────────────────────────

func mostrar_ascensor_ok(subiendo: bool, cb: Callable):
	if _animando:
		return
	_callback = cb
	lbl_titulo.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
	lbl_titulo.text = "🛗  " + ("Ascensor subiendo..." if subiendo else "Ascensor bajando...")
	lbl_desc.text   = "Rápido y sin incidentes.\n−%d minutos de tu turno." % COSTO_ASCENSOR

	_visual.play("ascensor", subiendo, 1.8)
	_iniciar(1.8)

# ─── Ascensor averiado ───────────────────────────────────────

func mostrar_ascensor_averia(cb: Callable):
	if _animando:
		return
	_callback = cb
	lbl_titulo.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2))
	lbl_titulo.text = "🛗  ¡ASCENSOR AVERIADO!"
	lbl_desc.text   = (
		"El ascensor se ha detenido entre pisos.\n" +
		"El técnico de mantenimiento está en camino.\n\n" +
		"Penalización: −%d minutos adicionales de tu turno." % COSTO_AVERIA
	)
	_visual.play("averia", false, 4.0)

	_animando = true
	TiempoLaboral.bloquear_tiempo()
	_cuenta_activa = true
	_segundos_restantes = 4.0
	panel.visible = true

# ─── Helpers internos ────────────────────────────────────────

func _iniciar(duracion: float):
	_animando = true
	TiempoLaboral.bloquear_tiempo()
	lbl_cuenta.text = ""
	panel.visible   = true
	get_tree().create_timer(duracion).timeout.connect(_terminar)

func _terminar():
	# Idempotente: sólo actúa una vez por animación, aunque lo llamen el timer
	# y el contador (_process) a la vez.
	if not _animando:
		return
	_animando       = false
	_cuenta_activa  = false
	panel.visible   = false
	if _visual:
		_visual.visible = false
	TiempoLaboral.desbloquear_tiempo()
	var cb = _callback
	_callback = Callable()
	if cb.is_valid():
		cb.call()
