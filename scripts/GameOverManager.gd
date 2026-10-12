extends Node
# Autoload: GameOverManager
# Detecta condiciones de Game Over y muestra la pantalla correspondiente

signal game_over_activado(tipo, mensaje, detalle)
signal semana_superada(resumen)

enum TipoFin {
	DESPEDIDO_NEGLIGENCIA,     # Demasiadas misiones fallidas / rep baja
	DESPEDIDO_INCIDENTE,       # Misión crítica fallida
	DESPEDIDO_MENTIRA,         # Múltiples mentiras detectadas
	SEMANA_COMPLETADA,         # Llegó al viernes correctamente
	VICTORIA_PLENA             # Semana completada con rep excelente
}

var incidentes_criticos: int = 0
var misiones_fallidas_total: int = 0
var mentiras_total: int = 0
var game_over_activado_flag: bool = false

const MAX_INCIDENTES    = 2
const MAX_FALLIDAS_DIAS = 4  # Más de 4 misiones fallidas en un día → advertencia seria
const MAX_MENTIRAS      = 3
const REP_MINIMA_GLOBAL = 20

# Reinicio completo (lo llama GameManager.reiniciar_juego)
func reiniciar():
	incidentes_criticos = 0
	misiones_fallidas_total = 0
	mentiras_total = 0
	game_over_activado_flag = false

func _ready():
	SistemaMisiones.mision_critica_fallida.connect(_on_mision_critica_fallida)
	SistemaMisiones.mision_fallida.connect(_on_mision_fallida)
	ReputacionGlobal.reputacion_global_cambiada.connect(_on_rep_global_cambiada)
	TiempoLaboral.semana_terminada.connect(_on_semana_terminada)

func _on_mision_critica_fallida(mision: Dictionary):
	incidentes_criticos += 1
	if incidentes_criticos >= MAX_INCIDENTES:
		_activar_game_over(
			TipoFin.DESPEDIDO_INCIDENTE,
			"INCIDENTE GRAVE EN EL HOSPITAL",
			"Has fallado %d misiones críticas.\nUna negligencia grave con un paciente ha sido reportada a la Dirección.\nEl hospital ha tomado la decisión de prescindir de tus servicios." % incidentes_criticos
		)

func _on_mision_fallida(_mision: Dictionary):
	misiones_fallidas_total += 1
	# Verificar rep global después de cada fallo
	_verificar_condiciones()

func _on_rep_global_cambiada(nuevo_valor: int):
	if nuevo_valor < REP_MINIMA_GLOBAL:
		_activar_game_over(
			TipoFin.DESPEDIDO_NEGLIGENCIA,
			"HAS SIDO DESPEDIDO",
			"Tu reputación en el hospital ha caído a un nivel inaceptable (%d/100).\nLa Dirección ha decidido prescindir de tus servicios por conducta negligente.\nEl hospital necesita técnicos comprometidos con la atención al paciente." % nuevo_valor
		)

func registrar_mentira():
	mentiras_total += 1
	if mentiras_total >= MAX_MENTIRAS:
		_activar_game_over(
			TipoFin.DESPEDIDO_MENTIRA,
			"DESPEDIDO POR DESHONESTIDAD",
			"Se han detectado múltiples casos de información falsa de tu parte.\nLa Dirección no puede tolerar la falta de integridad en el personal sanitario.\nTus servicios han sido dados por terminados con efecto inmediato."
		)

func _verificar_condiciones():
	var rep_global = ReputacionGlobal.get_reputacion_global()
	if rep_global < REP_MINIMA_GLOBAL:
		_on_rep_global_cambiada(rep_global)

func _on_semana_terminada(_resumen: Dictionary):
	if game_over_activado_flag:
		return
	var rep = ReputacionGlobal.get_reputacion_global()
	var completadas = SistemaMisiones.misiones_completadas.size()
	var fallidas    = SistemaMisiones.misiones_fallidas.size()

	if rep >= 70 and completadas >= 8:
		emit_signal("semana_superada", {
			"tipo": TipoFin.VICTORIA_PLENA,
			"titulo": "🏆 SEMANA EXCELENTE",
			"mensaje": "Has completado la semana con una reputación sobresaliente.",
			"completadas": completadas, "fallidas": fallidas,
			"reputacion": rep, "nivel": ReputacionGlobal.get_nivel_texto()
		})
	elif rep >= 40:
		emit_signal("semana_superada", {
			"tipo": TipoFin.SEMANA_COMPLETADA,
			"titulo": "✅ SEMANA COMPLETADA",
			"mensaje": "Has terminado la semana. Hay aspectos a mejorar.",
			"completadas": completadas, "fallidas": fallidas,
			"reputacion": rep, "nivel": ReputacionGlobal.get_nivel_texto()
		})
	else:
		_activar_game_over(
			TipoFin.DESPEDIDO_NEGLIGENCIA,
			"EVALUACIÓN SEMANAL REPROBADA",
			"Tu desempeño esta semana no cumplió los estándares mínimos del hospital.\nReputación final: %d/100 — %s\nMisiones completadas: %d | Fallidas: %d" % [rep, ReputacionGlobal.get_nivel_texto(), completadas, fallidas]
		)

func _activar_game_over(tipo: TipoFin, mensaje: String, detalle: String):
	if game_over_activado_flag:
		return
	game_over_activado_flag = true
	emit_signal("game_over_activado", tipo, mensaje, detalle)
