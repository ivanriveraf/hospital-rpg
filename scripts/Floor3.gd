extends "res://scripts/FloorBase.gd"

func _ready():
	floor_number = 3
	super._ready()

func _definir_areas():
	areas_datos = {
		"area_izq_arriba": { "nombre": "Habitaciones A", "color": Color(0.55, 0.85, 0.6, 0.35),  "descripcion": "Habitaciones 101 — 110" },
		"area_der_arriba": { "nombre": "Habitaciones B", "color": Color(0.55, 0.7, 0.95, 0.35),  "descripcion": "Habitaciones 111 — 120" },
		"area_izq_abajo":  { "nombre": "Dirección",      "color": Color(0.9, 0.75, 0.3, 0.35),   "descripcion": "Dirección del hospital" },
		"area_der_abajo":  { "nombre": "Administración", "color": Color(0.75, 0.75, 0.75, 0.35), "descripcion": "Gestión administrativa" },
	}

func _crear_npcs():
	var npcs = Node2D.new()
	npcs.name = "NPCs"
	add_child(npcs)

	var lista = [
		["Don Roberto",          "Paciente — Hab. 105",   Vector2(185, 175), Color(0.45, 0.75, 0.5),  45, "res://data/dialogos_piso3.json"],  # item_necesario se asigna abajo
		["Sra. Carmen",          "Paciente — Hab. 112",   Vector2(580, 175), Color(0.45, 0.6, 0.85),  45, "res://data/dialogos_piso3.json"],
		["Director Dr. Mendoza", "Director del Hospital", Vector2(185, 510), Color(0.8, 0.6, 0.2),    70, "res://data/dialogos_piso3.json"],
		["Administradora Torres","Jefa de Administración",Vector2(580, 510), Color(0.6, 0.6, 0.65),   55, "res://data/dialogos_piso3.json"],
	]
	for datos in lista:
		var npc = crear_npc(datos[0], datos[1], datos[2], datos[3], datos[4], datos[5])
		# Don Roberto necesita recibir la ficha clínica
		if datos[0] == "Don Roberto":
			# Acepta dos ítems distintos: ficha y medicación
			# Se evalúa dinámicamente en NPC.gd via items_aceptados
			npc.set("items_aceptados", ["Ficha de Don Roberto", "Medicación de Don Roberto"])
		npcs.add_child(npc)

func _crear_zonas_interactivas():
	var zonas = Node2D.new()
	zonas.name = "Zonas"
	add_child(zonas)

	# Escaleras al piso 2
	var z_bajar = crear_zona("escaleras_bajar", "▼ Bajar al Piso 2", Vector2(855, 400), Color(0.55, 0.35, 0.85, 0.85))
	zonas.add_child(z_bajar)
