extends "res://scripts/FloorBase.gd"

func _ready():
	floor_number = 1
	super._ready()

func _definir_areas():
	areas_datos = {
		"area_izq_arriba": { "nombre": "Urgencias",  "color": Color(0.95, 0.5, 0.5, 0.35), "descripcion": "Atención de emergencias médicas" },
		"area_der_arriba": { "nombre": "Recepción",  "color": Color(0.7, 0.5, 0.95, 0.35), "descripcion": "Admisión y registro de pacientes" },
		"area_izq_abajo":  { "nombre": "Farmacia",   "color": Color(0.4, 0.9, 0.55, 0.35), "descripcion": "Dispensación de medicamentos" },
		"area_der_abajo":  { "nombre": "Bodega",     "color": Color(0.95, 0.85, 0.35, 0.35), "descripcion": "Almacén de insumos y material" },
	}

func _crear_npcs():
	var npcs = Node2D.new()
	npcs.name = "NPCs"
	add_child(npcs)

	var lista = [
		["Dr. Ramírez",       "Médico Jefe de Urgencias", Vector2(185, 175), Color(0.85, 0.3, 0.3), 50, "res://data/dialogos_piso1.json"],
		["Recepcionista Ana", "Recepcionista",             Vector2(580, 175), Color(0.6, 0.4, 0.9),  50, "res://data/dialogos_piso1.json"],
		["Farmacéutico Luis", "Farmacéutico",              Vector2(185, 510), Color(0.3, 0.8, 0.45), 50, "res://data/dialogos_piso1.json"],
		["Bodeguero Pedro",   "Encargado de Bodega",       Vector2(580, 510), Color(0.85, 0.7, 0.2), 50, "res://data/dialogos_piso1.json"],
	]
	for datos in lista:
		var npc = crear_npc(datos[0], datos[1], datos[2], datos[3], datos[4], datos[5])
		match datos[0]:
			"Dr. Ramírez":
				npc.item_necesario = "Paquete Jeringas 5ml ×20"
		npcs.add_child(npc)

func _crear_zonas_interactivas():
	var zonas = Node2D.new()
	zonas.name = "Zonas"
	add_child(zonas)

	# Zona interactiva Bodega
	var z_bodega = crear_zona("bodega", "Gestionar Bodega", Vector2(580, 600), Color(0.7, 0.6, 0.1, 0.85))
	zonas.add_child(z_bodega)

	# Zona interactiva Farmacia
	var z_farmacia = crear_zona("farmacia", "Abrir Farmacia", Vector2(185, 600), Color(0.2, 0.7, 0.35, 0.85))
	zonas.add_child(z_farmacia)

	# Escaleras al piso 2
	var z_subir = crear_zona("escaleras_subir", "▲ Subir al Piso 2", Vector2(855, 200), Color(0.3, 0.5, 0.85, 0.85))
	zonas.add_child(z_subir)
