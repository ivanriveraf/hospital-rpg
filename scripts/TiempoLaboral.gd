extends Node
# Autoload: TiempoLaboral
# Gestiona la semana laboral Lunes-Viernes, 8:00-17:00
#
# VELOCIDAD:
#   El día son 9 horas de juego (08:00→17:00 = 540 minutos de juego).
#   minutos_reales_por_día = 540 / (MINUTOS_JUEGO_POR_SEG * 60)
#   Cambia este valor para ajustar:
#     1.80 → 5 min/día
#     1.50 → 6 min/día    (actual: las reposiciones ahora se entregan en persona)
#     0.90 → 10 min/día
#     0.45 → 20 min/día
#     0.25 → 36 min/día   (relajado)

signal hora_actualizada(hora_texto, progreso_dia)
signal dia_iniciado(dia_semana, nombre_dia)
signal dia_terminado(dia_semana, resumen)
signal semana_terminada(resumen_semana)
signal hora_critica(hora)

const DIAS = ["", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes"]
const HORA_INICIO = 8.0
const HORA_FIN    = 17.0
const HORAS_DIA   = HORA_FIN - HORA_INICIO  # 9 horas

# ← Ajusta aquí la velocidad del tiempo (flujo de fondo)
# Las acciones del jugador descuentan tiempo adicional vía descontar_tiempo()
# 1.50 → el día completo (sin acciones) fluye en ~6 minutos reales
const MINUTOS_JUEGO_POR_SEG: float = 1.5

var dia_semana: int = 1
var hora_actual: float = HORA_INICIO
var activo: bool = false   # false = esperando que el jugador inicie el día
var dia_terminado_flag: bool = false

var misiones_completadas_hoy: int = 0
var misiones_fallidas_hoy: int = 0
var rep_inicio_dia: int = 50  # Para calcular el cambio de reputación del día
var xp_inicio_dia: int = 0

# Avisos de tiempo (solo una vez por clave)
var _avisos_dados: Dictionary = {}

# Pausa del reloj de fondo mientras hay UI modal abierta (diálogos, animación
# de escaleras/ascensor, paneles, etc.). Es un contador: varias UIs pueden
# pausar a la vez y el tiempo sólo corre cuando vuelve a 0.
var _bloqueos_tiempo: int = 0

func bloquear_tiempo():
	_bloqueos_tiempo += 1

func desbloquear_tiempo():
	_bloqueos_tiempo = max(0, _bloqueos_tiempo - 1)

func tiempo_bloqueado() -> bool:
	return _bloqueos_tiempo > 0

func _ready():
	# El DayResultsUI llamará a iniciar_dia() cuando el jugador presione "Comenzar"
	pass

# Reinicio completo (lo llama GameManager.reiniciar_juego)
func reiniciar():
	dia_semana = 1
	hora_actual = HORA_INICIO
	activo = false
	dia_terminado_flag = false
	misiones_completadas_hoy = 0
	misiones_fallidas_hoy = 0
	rep_inicio_dia = 50
	xp_inicio_dia = 0
	_avisos_dados.clear()
	_bloqueos_tiempo = 0

func iniciar_dia():
	if dia_semana > 5:
		return
	activo = true
	dia_terminado_flag = false
	_bloqueos_tiempo = 0   # Seguridad: ningún bloqueo heredado puede congelar el día
	_avisos_dados.clear()
	rep_inicio_dia  = ReputacionGlobal.get_reputacion_global()
	xp_inicio_dia   = GameManager.experiencia
	misiones_completadas_hoy = 0
	misiones_fallidas_hoy    = 0
	emit_signal("dia_iniciado", dia_semana, DIAS[dia_semana])
	SistemaMisiones.desbloquear_misiones_del_dia(dia_semana)

func _process(delta):
	if not activo or dia_terminado_flag:
		return
	# Mientras haya un diálogo o animación modal abiertos, el reloj de fondo se
	# detiene. Esto evita que el día termine "debajo" de un diálogo abierto.
	if _bloqueos_tiempo > 0:
		return

	hora_actual += delta * MINUTOS_JUEGO_POR_SEG / 60.0

	emit_signal("hora_actualizada", get_hora_texto(), get_progreso_dia())

	# Avisos de tiempo
	for aviso in [12.0, 14.0, 16.0, 16.5, 16.833]:
		var key = "%d_%.3f" % [dia_semana, aviso]
		if hora_actual >= aviso and not _avisos_dados.has(key):
			_avisos_dados[key] = true
			emit_signal("hora_critica", aviso)

	# Hacer cumplir las horas límite de las misiones (avisos + fallo)
	SistemaMisiones.verificar_limites(hora_actual)

	if hora_actual >= HORA_FIN:
		hora_actual = HORA_FIN
		_terminar_dia()

func _terminar_dia():
	if dia_terminado_flag:
		return
	dia_terminado_flag = true
	activo = false

	# Fallar TODAS las misiones activas del día que no se completaron
	for id in SistemaMisiones.misiones.keys():
		var m = SistemaMisiones.misiones[id]
		if m.estado == SistemaMisiones.Estado.ACTIVA:
			SistemaMisiones.fallar_mision(id)
		# Misiones pendientes (no aceptadas) del día → marcar como inactivas de nuevo
		elif m.estado == SistemaMisiones.Estado.PENDIENTE and m.dia_disponible == dia_semana:
			m.estado = SistemaMisiones.Estado.INACTIVA  # Expiró sin ser atendida

	var resumen = _construir_resumen()
	emit_signal("dia_terminado", dia_semana, resumen)

func _construir_resumen() -> Dictionary:
	var completadas  = []
	var fallidas     = []
	var no_atendidas = []   # PENDIENTE o INACTIVA — nunca aceptadas

	for id in SistemaMisiones.misiones:
		var m = SistemaMisiones.misiones[id]
		if m.dia_disponible != dia_semana:
			continue
		match m.estado:
			SistemaMisiones.Estado.COMPLETADA:
				completadas.append(m)
			SistemaMisiones.Estado.FALLIDA:
				fallidas.append(m)
			SistemaMisiones.Estado.INACTIVA, SistemaMisiones.Estado.PENDIENTE:
				no_atendidas.append(m)  # Disponible hoy pero no aceptada

	return {
		"dia":          dia_semana,
		"nombre":       DIAS[dia_semana],
		"completadas":  completadas,
		"fallidas":     fallidas,
		"no_atendidas": no_atendidas,
		"rep_cambio":   ReputacionGlobal.get_reputacion_global() - rep_inicio_dia,
		"rep_actual":   ReputacionGlobal.get_reputacion_global(),
		"xp_ganada":    GameManager.experiencia - xp_inicio_dia,
		"ultimo_dia":   dia_semana >= 5,
	}

func avanzar_al_siguiente_dia():
	ReputacionGlobal.avanzar_bloqueos()
	if dia_semana >= 5:
		var resumen_semana = {
			"completadas_total": SistemaMisiones.misiones_completadas.size(),
			"fallidas_total":    SistemaMisiones.misiones_fallidas.size(),
			"reputacion_final":  ReputacionGlobal.get_reputacion_global(),
			"nivel_final":       ReputacionGlobal.get_nivel_texto(),
		}
		emit_signal("semana_terminada", resumen_semana)
	else:
		dia_semana  += 1
		hora_actual  = HORA_INICIO
		# El DayResultsUI mostrará el briefing del nuevo día
		# y llamará a iniciar_dia() cuando el jugador pulse "Empezar"

# ─── Helpers ────────────────────────────────────────────────

func get_hora_texto() -> String:
	var h = int(hora_actual)
	var m = int((hora_actual - h) * 60.0)
	return "%02d:%02d" % [h, m]

func get_progreso_dia() -> float:
	return clamp((hora_actual - HORA_INICIO) / HORAS_DIA, 0.0, 1.0)

func get_nombre_dia() -> String:
	return DIAS[dia_semana] if dia_semana >= 1 and dia_semana <= 5 else "?"

func get_tiempo_restante_texto() -> String:
	var restante = max(HORA_FIN - hora_actual, 0.0)
	var h = int(restante)
	var m = int((restante - h) * 60.0)
	return "%dh %02dm restantes" % [h, m]

func descontar_tiempo(minutos: float, razon: String = ""):
	if not activo:
		return
	hora_actual += minutos / 60.0
	if razon != "":
		GameManager.hud.mostrar_aviso("⏱ -%d min — %s" % [int(minutos), razon])
	# Una acción larga también puede hacer vencer una misión con hora límite
	SistemaMisiones.verificar_limites(hora_actual)
	if hora_actual >= HORA_FIN:
		hora_actual = HORA_FIN
		_terminar_dia()

func registrar_mision_completada():
	misiones_completadas_hoy += 1

func registrar_mision_fallida():
	misiones_fallidas_hoy += 1
