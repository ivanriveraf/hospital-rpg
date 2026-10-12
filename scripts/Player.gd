extends CharacterBody2D

const SPEED = 150.0

# ─── Sprite del personaje ────────────────────────────────────
# Carpeta con las 8 rotaciones (south.png, north.png, east.png, etc.). Si existe,
# el personaje mira hacia donde camina. Si la carpeta no existe, se intenta una
# imagen única (sprite_path). Si tampoco, se dibuja la figura simple por defecto.
@export var sprite_dir: String = "res://assets/sprites/A_man_nurse_character_light/A_man_nurse_character_light/rotations"
@export var sprite_path: String = "res://assets/player.png"   # imagen única alternativa
# Pixel art: solo escalas enteras; con decimales los píxeles salen de tamaños distintos.
@export var escala_sprite: int = 1

var _sprite: Sprite2D = null
var _texturas: Dictionary = {}     # "south" -> Texture2D
var _dir_actual: String = ""
var _sprite_y: float = 0.0         # sube el sprite para que los pies queden en el origen
var _anim_t: float = 0.0           # reloj de animación de caminar
var _polvo_t: float = 0.0          # temporizador para las nubecitas de polvo

const _DIRECCIONES = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

@onready var interaction_area = $InteractionArea

var current_npc = null
var facing_direction = Vector2.DOWN

func _ready():
	add_to_group("player")
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	PlayerInventory.item_tomado.connect(func(_n, _d): queue_redraw())
	PlayerInventory.manos_vacias.connect(func(): queue_redraw())
	_cargar_sprite()

# Carga el sprite: primero las 8 rotaciones de la carpeta, luego una imagen única.
func _cargar_sprite():
	for n in _DIRECCIONES:
		var ruta = sprite_dir.path_join(n + ".png")
		if ResourceLoader.exists(ruta):
			_texturas[n] = load(ruta)
	if _texturas.is_empty() and sprite_path != "" and ResourceLoader.exists(sprite_path):
		_texturas["south"] = load(sprite_path)
	if _texturas.is_empty():
		return   # No hay sprite: se usa el dibujo por defecto
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * escala_sprite
	_sprite_y = _y_para_pies(_texturas.get("south", _texturas.values()[0]))
	_sprite.position = Vector2(0, _sprite_y)
	add_child(_sprite)
	_aplicar_direccion("south")
	queue_redraw()

# Desplazamiento vertical que deja la última fila visible de la textura (los pies)
# justo en el origen del nodo: ahí está la colisión y es lo que usa el orden por Y.
func _y_para_pies(tex: Texture2D) -> float:
	var img = tex.get_image()
	var fondo = img.get_used_rect().end.y if img else tex.get_height()
	return -(fondo - tex.get_height() / 2.0) * escala_sprite

# Cambia la textura según la dirección ("south", "north-east", ...)
func _aplicar_direccion(dir: String):
	if not _texturas.has(dir):
		dir = "south" if _texturas.has("south") else _texturas.keys()[0]
	if dir == _dir_actual:
		return
	_dir_actual = dir
	_sprite.texture = _texturas[dir]

# Convierte el vector de movimiento en el nombre de dirección más cercano (8 dir.)
func _dir_desde_vector(v: Vector2) -> String:
	var ang = rad_to_deg(v.angle())
	if ang < 0.0:
		ang += 360.0
	var idx = int(round(ang / 45.0)) % 8
	return _DIRECCIONES[idx]

func _draw():
	# Sombra bajo los pies (con sprite, los pies están en el origen)
	var pie_y = 0.0 if _sprite != null else 16.0
	draw_set_transform(Vector2(0, pie_y), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 12, Color(0, 0, 0, 0.16))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Dibujo por defecto SOLO si no hay sprite cargado
	if _sprite == null:
		# Cuerpo
		draw_rect(Rect2(-14, -20, 28, 36), Color(0.2, 0.5, 0.9))
		# Cabeza
		draw_circle(Vector2(0, -30), 14, Color(0.9, 0.75, 0.6))
		# Cruz de enfermero
		draw_rect(Rect2(-3, -16, 6, 14), Color.WHITE)
		draw_rect(Rect2(-8, -12, 16, 5), Color.WHITE)
		# Etiqueta "TÚ"
		draw_string(ThemeDB.fallback_font, Vector2(-10, -50), "TÚ",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	# Ítem que lleva el jugador
	if PlayerInventory.tiene():
		# Caja/bandeja encima del personaje
		draw_rect(Rect2(-20, -75, 40, 20), Color(0.9, 0.75, 0.2))
		draw_rect(Rect2(-20, -75, 40, 20), Color(0.6, 0.5, 0.1), false, 1.5)
		var nombre_corto = PlayerInventory.get_nombre()
		if nombre_corto.length() > 12:
			nombre_corto = nombre_corto.substr(0, 11) + "…"
		draw_string(ThemeDB.fallback_font, Vector2(-18, -60), nombre_corto,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.15, 0.1, 0.0))

func _physics_process(delta):
	var dir = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	var moviendo = dir != Vector2.ZERO
	if moviendo:
		facing_direction = dir.normalized()
		velocity = facing_direction * SPEED
		if _sprite != null:
			_aplicar_direccion(_dir_desde_vector(facing_direction))
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_actualizar_anim(delta, moviendo)

# Animación procedural por píxeles enteros: rebote al caminar y respiración de
# 1 px en reposo. (Escalar el sprite —squash— hacía temblar el pixel art.)
func _actualizar_anim(delta: float, moviendo: bool):
	if _sprite == null:
		return
	if moviendo:
		_anim_t += delta * 11.0
		_sprite.position.y = _sprite_y - roundf(absf(sin(_anim_t)) * 3.0)
		_emitir_polvo(delta)
	else:
		_anim_t += delta
		_sprite.position.y = _sprite_y - (1.0 if sin(_anim_t * 2.0) > 0.0 else 0.0)

# Nubecitas de polvo en los pies al caminar
func _emitir_polvo(delta: float):
	_polvo_t -= delta
	if _polvo_t > 0.0:
		return
	_polvo_t = 0.28
	var p = CPUParticles2D.new()
	# 1 px por encima de los pies: el orden por Y la dibuja justo detrás del jugador.
	# (Antes usaba z_index = -1 y quedaba tapada por el suelo: nunca se veía.)
	p.position = global_position + Vector2(0, -1)
	p.emitting = true
	p.one_shot = true
	p.amount = 5
	p.lifetime = 0.45
	p.explosiveness = 0.85
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, 40)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(0.72, 0.70, 0.64, 0.5)
	get_parent().add_child(p)
	get_tree().create_timer(0.7).timeout.connect(p.queue_free)

func _input(event):
	# is_instance_valid: el NPC pudo ser liberado (ocultos y el gato desaparecen)
	if current_npc != null and not is_instance_valid(current_npc):
		current_npc = null
		return
	if event.is_action_pressed("ui_accept") and current_npc != null:
		current_npc.start_dialogue()
	if event.is_action_pressed("ui_deliver") and current_npc != null:
		current_npc.try_deliver_item()

func _on_interaction_area_body_entered(body):
	if body.is_in_group("npc"):
		current_npc = body
		body.show_interact_hint(true)

func _on_interaction_area_body_exited(body):
	if body.is_in_group("npc"):
		body.show_interact_hint(false)
		if current_npc == body:
			current_npc = null
