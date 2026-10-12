extends Node
# Autoload: EventosAleatorios
# Eventos aleatorios durante el turno: misiones sorpresa, regalos, contratiempos
# y PERSONAJES OCULTOS que aparecen con baja probabilidad al cambiar de piso.

signal evento_disparado(id, titulo)

# Probabilidades de aparición de personajes ocultos (al cambiar de piso)
const PROB_GENARO  = 0.22   # Conserje chismoso — máx. 1 vez al día
const PROB_AURELIO = 0.08   # Paciente misterioso — máx. 1 vez por semana

# Posiciones seguras (pasillos) donde pueden aparecer los ocultos
const POSICIONES_OCULTOS = [
	Vector2(405, 170), Vector2(405, 540), Vector2(220, 335),
	Vector2(620, 335), Vector2(405, 420)
]

var _eventos_programados: Array = []   # [{ "hora": float, "id": String }]
var _eventos_usados: Dictionary = {}   # id → true (no repetir en la semana)
var _genaro_hoy: bool = false
var _aurelio_semana: bool = false

# 🐈 Doctor Bigotes: posición sobre las cajas de la bodega (Piso 1)
const POS_GATO = Vector2(700, 448)
var _gato_nodo = null

func _ready():
	TiempoLaboral.dia_iniciado.connect(_on_dia_iniciado)
	TiempoLaboral.hora_actualizada.connect(_on_hora)
	FloorManager.piso_cambiado.connect(_on_piso_cambiado)
	SistemaMisiones.mision_completada.connect(_on_mision_completada)

func reiniciar():
	_eventos_programados.clear()
	_eventos_usados.clear()
	_genaro_hoy = false
	_aurelio_semana = false
	if is_instance_valid(_gato_nodo):
		_gato_nodo.queue_free()
	_gato_nodo = null

# ─── Programación diaria ─────────────────────────────────────

func _on_dia_iniciado(_dia: int, _nombre: String):
	_genaro_hoy = false
	_eventos_programados.clear()
	# 1 o 2 eventos por día, en horas aleatorias entre 9:00 y 15:00
	var cuantos = 1 + (randi() % 2)
	var disponibles = _pool_eventos().filter(func(id): return not _eventos_usados.has(id))
	disponibles.shuffle()
	for i in range(min(cuantos, disponibles.size())):
		_eventos_programados.append({
			"hora": randf_range(9.0, 15.0),
			"id": disponibles[i]
		})

func _on_hora(_texto: String, _progreso: float):
	if _eventos_programados.is_empty():
		return
	var hora = TiempoLaboral.hora_actual
	for ev in _eventos_programados.duplicate():
		if hora >= ev.hora:
			_eventos_programados.erase(ev)
			_disparar(ev.id)

func _pool_eventos() -> Array:
	return [
		"cafe_derramado", "donacion_sorpresa", "inspector_sorpresa",
		"peluche_perdido", "gato_en_bodega", "apagon_breve", "visita_payaso"
	]

# ─── Eventos ─────────────────────────────────────────────────

func _disparar(id: String):
	_eventos_usados[id] = true
	emit_signal("evento_disparado", id, id)
	match id:
		"cafe_derramado":
			TiempoLaboral.descontar_tiempo(5, "Limpiando café derramado")
			_aviso("☕ ¡EVENTO! Alguien derramó café en el pasillo. Lo limpiaste tú, claro. Siempre tú. (−5 min)")

		"apagon_breve":
			TiempoLaboral.descontar_tiempo(8, "Apagón breve — esperando al generador")
			_aviso("💡 ¡EVENTO! Microapagón. El generador tardó en arrancar y todos contaron chistes de terror en la oscuridad. (−8 min)")

		"donacion_sorpresa":
			var candidatos = ["Venda de gasa", "Paracetamol 500mg", "Guantes nitrilo (caja)", "Suero IV 500ml", "Mascarilla quirúrgica"]
			var elegido = candidatos[randi() % candidatos.size()]
			if GameManager.inventario and GameManager.inventario.insumos.has(elegido):
				var item = GameManager.inventario.insumos[elegido]
				GameManager.inventario.agregar_insumo(elegido, item.categoria, 20, 100, item.caducidad_dias)
			_aviso("🎁 ¡EVENTO! Una fundación donó insumos al hospital: +20 %s. Hoy es un buen día." % elegido)

		"inspector_sorpresa":
			SistemaMisiones.registrar_mision_dinamica(
				"evento_inspector",
				"🕵️ EVENTO: Inspector de sanidad sorpresa",
				"Un inspector apareció sin avisar (como siempre). Ve a ver al Director en su oficina (Piso 3) para coordinar la visita.",
				"Director Dr. Mendoza",
				[{ "tipo": "hablar_cadena", "target": "Director Dr. Mendoza", "texto": "Director Dr. Mendoza: «¡Por fin llegas! El inspector ya anda husmeando los extintores. Tú sígueme la corriente, sonríe mucho y, por lo que más quieras, esconde el carrito que chirría. Saldremos de esta... probablemente. ¡Buen trabajo manteniendo la calma!»", "cantidad": 1, "completado": false }],
				12, 30, 16.0)
			_aviso("🕵️ ¡EVENTO! Inspector de sanidad sorpresa. El Director te necesita en el Piso 3. Camina rápido pero CON estilo.")

		"peluche_perdido":
			SistemaMisiones.registrar_mision_dinamica(
				"evento_peluche",
				"🧸 EVENTO: Operación Peluche",
				"Un niño de pediatría perdió a 'Sr. Orejas', su conejo de peluche. Recepcionista Ana sabe algo. Sigue la pista del peluche.",
				"Recepcionista Ana",
				[
					{ "tipo": "hablar_cadena", "target": "Recepcionista Ana", "texto": "Recepcionista Ana: «¿El Sr. Orejas? Lo vi pasar en el carrito de la ropa limpia. La Sra. Carmen lo rescató, está en su habitación tejiéndole una bufanda.»", "cantidad": 1, "completado": false },
					{ "tipo": "hablar_cadena", "target": "Sra. Carmen", "texto": "Sra. Carmen: «¿Este conejito? Tome, ya tiene su bufanda nueva. Dígale al niño que el Sr. Orejas se portó muy bien y comió toda su gelatina.»", "cantidad": 1, "completado": false }
				],
				10, 35, 17.0)
			_aviso("🧸 ¡EVENTO! Misión sorpresa: un peluche VIP ha desaparecido. Habla con Recepcionista Ana.")

		"gato_en_bodega":
			SistemaMisiones.registrar_mision_dinamica(
				"evento_gato",
				"🐈 EVENTO: Hay un gato en la bodega",
				"Un gato se coló en el hospital y está durmiendo sobre las cajas de gasas. Pedro está en pánico (le tiene cariño pero hay normas). Coordina el rescate.",
				"Bodeguero Pedro",
				[
					{ "tipo": "hablar_cadena", "target": "Bodeguero Pedro", "texto": "Bodeguero Pedro: «¡Está sobre Paquita, mi caja favorita! Le puse 'Doctor Bigotes'. No lo puedo sacar yo, me mira con autoridad. Avísale a la Enf. Jefa García, ella impone más respeto.»", "cantidad": 1, "completado": false },
					{ "tipo": "hablar_cadena", "target": "Enf. Jefa García", "texto": "Enf. Jefa García: «¿Un gato? *suspiro de 20 años de experiencia* Ya llamé a la protectora. Y NO, Pedro no se lo puede quedar. ...Aunque le dejé un platito de agua. Eso no salió de mí.»", "cantidad": 1, "completado": false }
				],
				10, 35, 17.0)
			_spawn_gato_si_corresponde()
			_aviso("🐈 ¡EVENTO! Un gato tomó la bodega como rehén (versión gato: está dormido). Habla con el Bodeguero Pedro.")

		"visita_payaso":
			GameManager.ganar_experiencia(15)
			_aviso("🤡 ¡EVENTO! Vino el payaso de pediatría y te hizo reír en pleno pasillo. Moral del equipo +100. (+15 XP gratis, cortesía de la risa)")

# ─── Personajes ocultos ──────────────────────────────────────

func _on_piso_cambiado(_numero: int, _nombre: String):
	# El gato reaparece al volver al Piso 1 mientras su misión siga activa
	# (los pisos se reconstruyen al cambiar, así que hay que recrearlo)
	_spawn_gato_si_corresponde()
	# Solo durante el turno activo
	if not TiempoLaboral.activo:
		return
	if not _aurelio_semana and randf() < PROB_AURELIO:
		_aurelio_semana = true
		_spawn_oculto("paciente_aurelio")
	elif not _genaro_hoy and randf() < PROB_GENARO:
		_genaro_hoy = true
		_spawn_oculto("conserje_genaro")

func _spawn_oculto(tipo: String):
	var cont = FloorManager.floor_container
	if cont == null or cont.get_child_count() == 0:
		return
	var piso = cont.get_child(cont.get_child_count() - 1)
	var npc = CharacterBody2D.new()
	npc.set_script(load("res://scripts/NPCOculto.gd"))
	npc.set("tipo_oculto", tipo)
	npc.position = POSICIONES_OCULTOS[randi() % POSICIONES_OCULTOS.size()]
	piso.add_child(npc)
	_aviso("✨ Sientes que alguien inusual anda por este piso...")

func _aviso(texto: String):
	if GameManager.hud:
		GameManager.hud.mostrar_aviso(texto)

# ─── 🐈 Doctor Bigotes (evento del gato en bodega) ───────────

func _gato_mision_activa() -> bool:
	return SistemaMisiones.misiones.has("evento_gato") and \
		SistemaMisiones.misiones["evento_gato"].estado == SistemaMisiones.Estado.ACTIVA

# Crea al gato sobre las cajas de la bodega si la misión está activa,
# estamos en el Piso 1 y no existe ya un gato en escena.
func _spawn_gato_si_corresponde():
	if not _gato_mision_activa():
		return
	if FloorManager.piso_actual != 1:
		return
	if is_instance_valid(_gato_nodo):
		return
	var cont = FloorManager.floor_container
	if cont == null or cont.get_child_count() == 0:
		return
	var piso = cont.get_child(cont.get_child_count() - 1)
	_gato_nodo = CharacterBody2D.new()
	_gato_nodo.set_script(load("res://scripts/Gato.gd"))
	_gato_nodo.position = POS_GATO
	piso.add_child(_gato_nodo)

# Cuando la misión del gato se completa, la protectora se lo lleva
func _on_mision_completada(m):
	if m.get("id", "") != "evento_gato":
		return
	if is_instance_valid(_gato_nodo):
		_gato_nodo.queue_free()
	_gato_nodo = null
	_aviso("🐈 La protectora recogió al Doctor Bigotes. Pedro jura que no está llorando. Está 'ordenando cajas'.")
