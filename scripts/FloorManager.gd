extends Node

signal piso_cambiado(numero, nombre)

var piso_actual: int = 1
var floor_container: Node2D = null

const NOMBRES_PISO = {
	1: "Planta Baja",
	2: "Primer Piso",
	3: "Segundo Piso"
}

const ESCENAS_PISO = {
	1: "res://scenes/Floor1.tscn",
	2: "res://scenes/Floor2.tscn",
	3: "res://scenes/Floor3.tscn"
}

# Posición donde aparece el jugador al llegar a cada piso
const POSICION_ENTRADA = {
	1: Vector2(615, 360),
	2: Vector2(615, 360),
	3: Vector2(615, 360)
}

func inicializar(container: Node2D):
	floor_container = container
	cargar_piso(1)

func cambiar_piso(numero: int):
	if numero < 1 or numero > 3:
		return
	if numero == piso_actual:
		return

	piso_actual = numero
	cargar_piso(numero)

	# Mover al jugador a la entrada del nuevo piso
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.position = POSICION_ENTRADA[numero]

	emit_signal("piso_cambiado", numero, NOMBRES_PISO[numero])

func cargar_piso(numero: int):
	if floor_container == null:
		return

	# Descargar piso actual
	for child in floor_container.get_children():
		child.queue_free()

	# Cargar nuevo piso
	var escena = load(ESCENAS_PISO[numero])
	if escena == null:
		push_error("No se pudo cargar el piso: " + str(numero))
		return
	var instancia = escena.instantiate()
	floor_container.add_child(instancia)

func get_nombre_piso() -> String:
	return NOMBRES_PISO.get(piso_actual, "Desconocido")
