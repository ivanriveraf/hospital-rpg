extends "res://scripts/FloorBase.gd"

func _ready():
	floor_number = 2
	super._ready()

func _definir_areas():
	areas_datos = {
		"area_izq_arriba": { "nombre": "Quirófano",    "color": Color(0.35, 0.55, 0.95, 0.35), "descripcion": "Sala de cirugías programadas" },
		"area_der_arriba": { "nombre": "UCI",           "color": Color(0.95, 0.4, 0.4, 0.35),  "descripcion": "Unidad de Cuidados Intensivos" },
		"area_izq_abajo":  { "nombre": "Laboratorio",  "color": Color(0.35, 0.85, 0.85, 0.35), "descripcion": "Análisis clínicos y muestras" },
		"area_der_abajo":  { "nombre": "Enfermería",   "color": Color(0.95, 0.65, 0.3, 0.35),  "descripcion": "Puesto central de enfermería" },
	}

func _crear_npcs():
	var npcs = Node2D.new()
	npcs.name = "NPCs"
	add_child(npcs)

	var lista = [
		["Dr. Vargas",      "Cirujano Jefe",     Vector2(185, 175), Color(0.3, 0.45, 0.9),  60, "res://data/dialogos_piso2.json"],
		["Enf. Sofía",      "Enfermera UCI",     Vector2(580, 175), Color(0.9, 0.35, 0.35), 55, "res://data/dialogos_piso2.json"],
		["Técnico Carlos",  "Técnico de Lab.",   Vector2(185, 510), Color(0.2, 0.75, 0.75), 50, "res://data/dialogos_piso2.json"],
		["Enf. Jefa García","Enfermera Jefe",    Vector2(580, 510), Color(0.3, 0.75, 0.45), 50, "res://data/dialogos_piso2.json"],
	]
	for datos in lista:
		var npc = crear_npc(datos[0], datos[1], datos[2], datos[3], datos[4], datos[5])
		match datos[0]:
			"Dr. Vargas":
				npc.item_necesario = "Kit Quirúrgico"
			"Enf. Sofía":
				npc.item_necesario = "Sueros IV ×6 (UCI)"
		npcs.add_child(npc)

func _crear_zonas_interactivas():
	var zonas = Node2D.new()
	zonas.name = "Zonas"
	add_child(zonas)

	# Laboratorio interactivo
	var z_lab = crear_zona("laboratorio", "Entregar Muestras", Vector2(185, 600), Color(0.15, 0.65, 0.65, 0.85))
	zonas.add_child(z_lab)

	# Escaleras al piso 1
	var z_bajar = crear_zona("escaleras_bajar", "▼ Bajar al Piso 1", Vector2(855, 400), Color(0.55, 0.35, 0.85, 0.85))
	zonas.add_child(z_bajar)

	# Escaleras al piso 3
	var z_subir = crear_zona("escaleras_subir", "▲ Subir al Piso 3", Vector2(855, 200), Color(0.3, 0.5, 0.85, 0.85))
	zonas.add_child(z_subir)
