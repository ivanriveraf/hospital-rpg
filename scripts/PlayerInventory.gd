extends Node
# Autoload: PlayerInventory
# El jugador puede llevar UN ítem a la vez (como una bandeja de hospital).

signal item_tomado(nombre, descripcion)
signal item_entregado(nombre, a_quien)
signal manos_vacias

var item_actual: String = ""
var descripcion_actual: String = ""
# Paquetes de bodega: { "destino": NPC que lo recibe, "misiones": [ids] }
var datos_actual: Dictionary = {}

func tomar(nombre: String, descripcion: String = "", datos: Dictionary = {}):
	item_actual    = nombre
	descripcion_actual = descripcion
	datos_actual = datos
	emit_signal("item_tomado", nombre, descripcion)

func entregar(a_quien: String) -> String:
	var entregado = item_actual
	item_actual   = ""
	descripcion_actual = ""
	datos_actual = {}
	emit_signal("item_entregado", entregado, a_quien)
	emit_signal("manos_vacias")
	return entregado

func tiene(nombre: String = "") -> bool:
	if nombre == "":
		return item_actual != ""
	return item_actual == nombre

func get_nombre() -> String:
	return item_actual

func get_descripcion() -> String:
	return descripcion_actual

func get_datos() -> Dictionary:
	return datos_actual
