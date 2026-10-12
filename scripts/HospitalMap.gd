extends Node2D

# Áreas del hospital - cada una tiene nombre, color de fondo y posición
const AREAS = {
	"urgencias": {
		"nombre": "Urgencias",
		"color": Color(0.9, 0.3, 0.3, 0.3),
		"rect": Rect2(50, 50, 350, 280),
		"descripcion": "Atención de emergencias médicas"
	},
	"quirofano": {
		"nombre": "Quirófano",
		"color": Color(0.3, 0.6, 0.9, 0.3),
		"rect": Rect2(450, 50, 350, 280),
		"descripcion": "Sala de cirugías"
	},
	"farmacia": {
		"nombre": "Farmacia",
		"color": Color(0.3, 0.9, 0.5, 0.3),
		"rect": Rect2(50, 380, 350, 280),
		"descripcion": "Distribución de medicamentos"
	},
	"bodega": {
		"nombre": "Bodega",
		"color": Color(0.9, 0.8, 0.3, 0.3),
		"rect": Rect2(450, 380, 350, 280),
		"descripcion": "Almacén de insumos"
	}
}

func _draw():
	var font = ThemeDB.fallback_font

	# Fondo general del hospital
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.95, 0.95, 0.95))

	# Pasillos
	draw_rect(Rect2(395, 0, 50, 720), Color(0.8, 0.8, 0.8))
	draw_rect(Rect2(0, 330, 1280, 50), Color(0.8, 0.8, 0.8))

	# Dibujar cada área con etiqueta
	for area_key in AREAS:
		var area = AREAS[area_key]
		draw_rect(area.rect, area.color)
		draw_rect(area.rect, Color(0.4, 0.4, 0.4), false, 2.0)
		# Nombre del área centrado
		var center = area.rect.get_center()
		draw_string(font, Vector2(center.x - 50, center.y), area.nombre,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.2, 0.2, 0.2))
		draw_string(font, Vector2(center.x - 60, center.y + 22), area.descripcion,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.4, 0.4))

	# Título del hospital arriba
	draw_string(font, Vector2(480, 330), "H  O  S  P  I  T  A  L",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.3, 0.3, 0.3))

	# Señales de pasillo
	draw_string(font, Vector2(402, 200), "↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.5, 0.5, 0.5))
	draw_string(font, Vector2(402, 550), "↓", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.5, 0.5, 0.5))

func get_area_at_position(pos: Vector2) -> String:
	for area_key in AREAS:
		if AREAS[area_key].rect.has_point(pos):
			return area_key
	return ""
