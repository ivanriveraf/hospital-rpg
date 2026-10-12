extends Node

signal dia_avanzado(dia)
signal experiencia_ganada(cantidad)
signal nivel_subido(nivel)

var inventario: Node
var misiones: Node
var dia_actual: int = 1
var hora_actual: float = 8.0
var experiencia: int = 0
var nivel: int = 1
var xp_para_nivel: int = 100

var dialogue_ui = null
var hud = null
var bodega_ui = null
var farmacia_ui = null
var stairs_ui = null

# Estado persistente de NPCs (sobrevive cambios de piso)
var npc_states: Dictionary = {}  # npc_name → { ofrecida, completada, entregados }

func guardar_estado_npc(npc_name: String, ofrecida: bool, completada: bool, entregados: Array = []):
	npc_states[npc_name] = { "ofrecida": ofrecida, "completada": completada, "entregados": entregados }

func get_estado_npc(npc_name: String) -> Dictionary:
	return npc_states.get(npc_name, { "ofrecida": false, "completada": false, "entregados": [] })

func _ready():
	inventario = get_node_or_null("/root/Inventario")
	misiones   = get_node_or_null("/root/SistemaMisiones")

func _process(_delta):
	pass  # El tiempo lo gestiona TiempoLaboral

func get_hora_texto() -> String:
	return TiempoLaboral.get_hora_texto()

func registrar_incidente_critico(mision: Dictionary):
	# BUGFIX: antes sumaba al contador de MENTIRAS, así que un incidente
	# crítico podía terminar en "Despedido por deshonestidad" (mensaje
	# equivocado). Ahora alimenta el contador correcto de incidentes.
	GameOverManager._on_mision_critica_fallida(mision)

# ─── Diálogos ───────────────────────────────────────────────
func show_dialogue(npc, datos_dialogo: Dictionary):
	if dialogue_ui:
		dialogue_ui.mostrar(npc, datos_dialogo)

func hide_dialogue():
	if dialogue_ui:
		dialogue_ui.ocultar()

# ─── Zonas interactivas ─────────────────────────────────────
func show_transport_dialogue(datos: Dictionary, zona: Area2D):
	if dialogue_ui:
		dialogue_ui.mostrar_transporte(datos, zona)

func abrir_bodega():
	if bodega_ui:
		bodega_ui.abrir()

func abrir_farmacia():
	if farmacia_ui:
		farmacia_ui.abrir()

func abrir_laboratorio():
	# Completar objetivo de misión de muestras
	if misiones:
		misiones.completar_objetivo("muestras_laboratorio", "llevar_muestras")
	ganar_experiencia(15)

# ─── Misiones ───────────────────────────────────────────────
func accept_mission(id: String):
	if misiones:
		misiones.aceptar_mision(id)

func otorgar_recompensa(mision: Dictionary):
	if mision.has("recompensa_exp"):
		ganar_experiencia(mision.recompensa_exp)

# ─── Progresión ─────────────────────────────────────────────
func ganar_experiencia(cantidad: int):
	experiencia += cantidad
	emit_signal("experiencia_ganada", cantidad)
	while experiencia >= xp_para_nivel:
		experiencia -= xp_para_nivel
		nivel += 1
		xp_para_nivel = int(xp_para_nivel * 1.5)
		emit_signal("nivel_subido", nivel)

# ─── Reinicio completo ──────────────────────────────────────
# BUGFIX: reload_current_scene() NO reinicia los autoloads, así que al
# "Reiniciar" tras un Game Over la nueva partida arrancaba con las misiones,
# reputación y día de la semana de la partida anterior. Esto resetea todo.
func reiniciar_juego():
	dia_actual = 1
	hora_actual = 8.0
	experiencia = 0
	nivel = 1
	xp_para_nivel = 100
	npc_states.clear()
	PlayerInventory.entregar("(reinicio)")
	TiempoLaboral.reiniciar()
	SistemaMisiones.reiniciar()
	ReputacionGlobal.reiniciar()
	GameOverManager.reiniciar()
	EventosAleatorios.reiniciar()
	if inventario:
		inventario.reiniciar()
	FloorManager.piso_actual = 1

# ─── Guardado ───────────────────────────────────────────────
func guardar_partida():
	var data = {
		"dia": dia_actual, "hora": hora_actual,
		"experiencia": experiencia, "nivel": nivel,
		"piso": FloorManager.piso_actual,
		"inventario": inventario.insumos if inventario else {},
		"misiones_activas": misiones.misiones_activas if misiones else []
	}
	var archivo = FileAccess.open("user://partida.json", FileAccess.WRITE)
	archivo.store_string(JSON.stringify(data))
	archivo.close()

func cargar_partida():
	if not FileAccess.file_exists("user://partida.json"):
		return
	var archivo = FileAccess.open("user://partida.json", FileAccess.READ)
	var data = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if data:
		dia_actual  = data.get("dia", 1)
		hora_actual = data.get("hora", 8.0)
		experiencia = data.get("experiencia", 0)
		nivel       = data.get("nivel", 1)
		var piso = data.get("piso", 1)
		FloorManager.cambiar_piso(piso)
