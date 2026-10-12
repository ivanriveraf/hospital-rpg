extends Node
# Autoload: Musica
# Reproduce música de fondo en bucle. Solo tienes que poner tu archivo en
# res://assets/music/ con uno de estos nombres (musica.ogg recomendado).
# Si no hay archivo, el juego funciona igual, sin música.

# −6 dB equivale a bajar el volumen a la mitad. Antes estaba en −14 dB y se
# percibía muy fuerte en el menú, así que ahora arranca en −20 dB (50% menos).
@export var volumen_db: float = -20.0   # volumen (0 = máximo, negativo = más bajo)

const RUTAS = [
	"res://assets/music/musica.ogg",
	"res://assets/music/musica.mp3",
	"res://assets/music/musica.wav",
]

var _player: AudioStreamPlayer

func _ready():
	_player = AudioStreamPlayer.new()
	_player.volume_db = volumen_db
	_player.process_mode = Node.PROCESS_MODE_ALWAYS  # sigue sonando con el juego en pausa
	add_child(_player)
	_cargar_y_reproducir()

func _cargar_y_reproducir():
	var ruta = _encontrar_pista()
	if ruta == "":
		return  # Sin archivo de música: el juego sigue normal.
	var stream = load(ruta)
	if stream != null:
		_activar_bucle(stream)
		_player.stream = stream
		_player.play()

# Busca la pista: primero los nombres recomendados, luego CUALQUIER archivo
# de audio dentro de assets/music/ (así sirve con el nombre que tenga).
func _encontrar_pista() -> String:
	for ruta in RUTAS:
		if ResourceLoader.exists(ruta):
			return ruta
	# ResourceLoader y no DirAccess: en el juego exportado solo quedan los
	# ".mp3.import", así que DirAccess no encontraba la pista y no sonaba nada.
	for nombre in ResourceLoader.list_directory("res://assets/music"):
		var low = nombre.to_lower()
		if low.ends_with(".ogg") or low.ends_with(".mp3") or low.ends_with(".wav"):
			return "res://assets/music/" + nombre
	return ""

# Hace que la pista se repita sin cortes
func _activar_bucle(stream):
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

# ─── Control desde otros scripts (opcional) ──────────────────

func set_volumen(db: float):
	volumen_db = db
	if _player:
		_player.volume_db = db

func alternar_silencio():
	if _player:
		_player.stream_paused = not _player.stream_paused
		return _player.stream_paused
	return false

func reproducir():
	if _player and not _player.playing and _player.stream:
		_player.play()
# (fin del archivo)
