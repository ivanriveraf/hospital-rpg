extends Node
# Autoload: ReputacionGlobal
# Gestiona la reputación con cada NPC y la reputación global del hospital

signal reputacion_npc_cambiada(npc_name, nuevo_valor, diferencia)
signal reputacion_global_cambiada(nuevo_valor)
signal npc_bloqueado(npc_name, razon)
signal npc_desbloqueado(npc_name)
signal advertencia_global(mensaje)

# Reputación por NPC (0–100)
var reputaciones: Dictionary = {
	"Dr. Ramírez":           50,
	"Recepcionista Ana":     50,
	"Farmacéutico Luis":     50,
	"Bodeguero Pedro":       50,
	"Dr. Vargas":            60,
	"Enf. Sofía":            55,
	"Técnico Carlos":        50,
	"Enf. Jefa García":      50,
	"Director Dr. Mendoza":  70,
	"Administradora Torres": 55,
	"Don Roberto":           45,
	"Sra. Carmen":           45,
}

# NPCs bloqueados temporalmente (no hablan contigo)
var npcs_bloqueados: Dictionary = {}  # npc_name: { "razon": str, "turnos": int }

# Historial de malas decisiones por NPC
var malas_decisiones: Dictionary = {}  # npc_name: int (contador)

# Mentiras detectadas
var mentiras_detectadas: Dictionary = {}  # npc_name: bool

const UMBRAL_BLOQUEO      = 20   # Rep < 20 → NPC hostil
const UMBRAL_ADVERTENCIA  = 30   # Rep < 30 → advertencia
const UMBRAL_DESBLOQUEO_EXTRA = 70  # Rep ≥ 70 → misiones especiales

# Copia de los valores iniciales (para reiniciar la partida)
var _reputaciones_iniciales: Dictionary = {}

func _ready():
	_reputaciones_iniciales = reputaciones.duplicate()

# Reinicio completo (lo llama GameManager.reiniciar_juego)
func reiniciar():
	reputaciones = _reputaciones_iniciales.duplicate()
	npcs_bloqueados.clear()
	malas_decisiones.clear()
	mentiras_detectadas.clear()

func cambiar_reputacion(npc_name: String, cantidad: int, razon: String = ""):
	if not reputaciones.has(npc_name):
		reputaciones[npc_name] = 50
	var anterior = reputaciones[npc_name]
	reputaciones[npc_name] = clamp(anterior + cantidad, 0, 100)
	var nuevo = reputaciones[npc_name]
	emit_signal("reputacion_npc_cambiada", npc_name, nuevo, cantidad)
	emit_signal("reputacion_global_cambiada", get_reputacion_global())

	# Verificar bloqueo
	if nuevo < UMBRAL_BLOQUEO and anterior >= UMBRAL_BLOQUEO:
		_bloquear_npc(npc_name, "Reputación demasiado baja con %s" % npc_name)
	elif nuevo >= UMBRAL_BLOQUEO and anterior < UMBRAL_BLOQUEO:
		_desbloquear_npc(npc_name)

	# Advertencia global
	var global = get_reputacion_global()
	if global < 30:
		emit_signal("advertencia_global",
			"⚠️ Tu reputación en el hospital está muy baja (%d/100). El director podría tomar medidas." % global)

func registrar_mala_decision(npc_name: String):
	if not malas_decisiones.has(npc_name):
		malas_decisiones[npc_name] = 0
	malas_decisiones[npc_name] += 1
	# Tras 3 malas decisiones con el mismo NPC → consecuencia grave
	if malas_decisiones[npc_name] >= 3:
		cambiar_reputacion(npc_name, -20,
			"Patrón de negligencia con %s" % npc_name)
		malas_decisiones[npc_name] = 0

func registrar_mentira(npc_name: String):
	mentiras_detectadas[npc_name] = true
	cambiar_reputacion(npc_name, -25, "Mentira detectada")
	cambiar_reputacion("Director Dr. Mendoza", -10, "Reporte de conducta")
	emit_signal("advertencia_global",
		"❌ %s descubrió que le mentiste. Tu reputación ha caído gravemente." % npc_name)

func _bloquear_npc(npc_name: String, razon: String):
	npcs_bloqueados[npc_name] = { "razon": razon, "turnos": 2 }
	emit_signal("npc_bloqueado", npc_name, razon)

func _desbloquear_npc(npc_name: String):
	npcs_bloqueados.erase(npc_name)
	emit_signal("npc_desbloqueado", npc_name)

func esta_bloqueado(npc_name: String) -> bool:
	return npcs_bloqueados.has(npc_name)

func avanzar_bloqueos():
	# Llamar al fin de cada día para reducir bloqueos
	for npc in npcs_bloqueados.keys():
		npcs_bloqueados[npc].turnos -= 1
		if npcs_bloqueados[npc].turnos <= 0:
			_desbloquear_npc(npc)

func get_reputacion(npc_name: String) -> int:
	return reputaciones.get(npc_name, 50)

func get_reputacion_global() -> int:
	if reputaciones.is_empty():
		return 50
	var total = 0
	for npc in reputaciones:
		total += reputaciones[npc]
	return total / reputaciones.size()

func get_nivel_texto() -> String:
	var g = get_reputacion_global()
	if   g >= 80: return "Excelente"
	elif g >= 60: return "Buena"
	elif g >= 40: return "Aceptable"
	elif g >= 25: return "Deficiente"
	else:         return "Crítica"

func puede_acceder_mision_especial(npc_name: String) -> bool:
	return get_reputacion(npc_name) >= UMBRAL_DESBLOQUEO_EXTRA

func get_color_reputacion(valor: int) -> Color:
	if   valor >= 70: return Color(0.2, 0.85, 0.3)
	elif valor >= 50: return Color(0.9, 0.85, 0.2)
	elif valor >= 30: return Color(0.95, 0.55, 0.1)
	else:             return Color(0.9, 0.2, 0.2)
