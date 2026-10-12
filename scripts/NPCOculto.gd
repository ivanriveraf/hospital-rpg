extends "res://scripts/NPC.gd"
# NPC OCULTO — personajes secretos que aparecen aleatoriamente en los pisos.
# Los crea EventosAleatorios.gd. Ahora HEREDA de NPC.gd, así que se dibuja
# exactamente igual que el resto de personajes (sprite pixel-art o figura
# con uniforme, placa de nombre, sombra y animación), en vez del rectángulo
# plano que usaba antes. Sobrescribe la lógica de diálogo con la suya propia.

var tipo_oculto: String = "conserje_genaro"

var _dialogos: Array = []
var _ya_hablo: bool = false

func _ready():
	_configurar()

	# Nodos hijos que NPC.gd espera (los mismos que crea FloorBase.crear_npc)
	var col = CollisionShape2D.new()
	var cap = CapsuleShape2D.new()
	cap.radius = 14.0
	cap.height = 10.0
	col.shape = cap
	add_child(col)

	var lbl = Label.new()
	lbl.name = "LabelName"
	lbl.position = Vector2(-45, -58)
	lbl.text = npc_name
	add_child(lbl)

	var hint = Label.new()
	hint.name = "InteractHint"
	hint.position = Vector2(-15, -75)
	hint.text = ""
	hint.visible = false
	add_child(hint)

	var bar = ProgressBar.new()
	bar.name = "ReputationBar"
	bar.position = Vector2(-30, -42)
	bar.custom_minimum_size = Vector2(60, 8)
	bar.max_value = 100.0
	bar.value = 50.0
	add_child(bar)

	# Inicialización visual y de estado estándar de NPC.gd
	super._ready()

func _configurar():
	match tipo_oculto:
		"conserje_genaro":
			npc_name  = "Conserje Genaro"
			npc_role  = "Conserje (sabe TODO)"
			npc_color = Color(0.45, 0.55, 0.65)
			_dialogos = [
				{
					"texto": "Psst... soy Genaro, el conserje. Llevo 30 años aquí: conozco cada pasillo, cada secreto y cada escondite de galletas de la Enf. Jefa. ¿Quieres un dato útil? Trapeo y cuento, todo al mismo tiempo.",
					"opciones": [
						{ "texto": "🧹 Cuéntame ese dato (escuchar el chisme)", "xp": 15, "rep_aleatoria": 6, "siguiente": 1 },
						{ "texto": "Estoy en turno, Genaro. Otro día.", "siguiente": -1, "desaparece": true }
					]
				},
				{
					"texto": "Escucha bien: si llegas con las cosas ANTES de que te las pidan dos veces, en este hospital te tratan como realeza. Ya hablé bien de ti con alguien del personal. De nada. Ahora me voy: el piso 2 no se trapea solo... aunque llevo años pidiendo que lo haga.",
					"opciones": [
						{ "texto": "Gracias, Genaro. Eres leyenda.", "siguiente": -1, "desaparece": true }
					]
				}
			]
		"paciente_aurelio":
			npc_name  = "Sr. Aurelio"
			npc_role  = "Paciente... ¿de 1987?"
			npc_color = Color(0.7, 0.7, 0.85)
			_dialogos = [
				{
					"texto": "Joven... ¿usted también puede verme? Soy Aurelio. Me dieron de alta en 1987 pero me gustó tanto la gelatina del almuerzo que decidí quedarme. Nadie de administración tiene registro mío... y ahí está el problema: mi expediente se perdió hace décadas.",
					"opciones": [
						{ "texto": "👻 Le ayudo a encontrar su expediente (misión oculta)", "xp": 10, "mision_oculta": "expediente_aurelio", "siguiente": 1 },
						{ "texto": "Voy a... llamar a alguien. No se mueva.", "siguiente": 2 }
					]
				},
				{
					"texto": "¡Magnífico! Pregunte a la Administradora Torres por los archivos antiguos, y luego confirme con el Director. Si lo logra, le revelaré dónde esconden el buen café. El de VERDAD, no esa agua triste de la máquina.",
					"opciones": [
						{ "texto": "Trato hecho, Sr. Aurelio.", "siguiente": -1, "desaparece": true }
					]
				},
				{
					"texto": "Eso dijeron en 1987... aún espero. No se preocupe, joven, aquí estaré. Yo siempre estoy aquí. *sonríe misteriosamente*",
					"opciones": [
						{ "texto": "(Alejarse lentamente sin dar la espalda)", "siguiente": -1, "desaparece": true }
					]
				}
			]

# Dibujo estándar de NPC + chispas místicas para distinguir a los secretos
func _draw():
	super._draw()
	var brillo = 0.55 + 0.45 * sin(_fase * 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(12, _y_placa + 20), "✨",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.85, 0.4, brillo))

func try_deliver_item():
	pass  # Los NPCs ocultos no reciben ítems

func start_dialogue():
	if _dialogos.is_empty():
		return
	GameManager.show_dialogue(self, _dialogos[0])

func procesar_opcion(opcion: Dictionary):
	# Recompensas
	if opcion.has("xp"):
		GameManager.ganar_experiencia(opcion.xp)
	if opcion.has("rep_aleatoria") and not _ya_hablo:
		_ya_hablo = true
		var nombres = ReputacionGlobal.reputaciones.keys()
		if not nombres.is_empty():
			var elegido = nombres[randi() % nombres.size()]
			ReputacionGlobal.cambiar_reputacion(elegido, opcion.rep_aleatoria, "Buena fama (chisme de Genaro)")
			if GameManager.hud:
				GameManager.hud.mostrar_aviso("✨ Genaro habló bien de ti: +%d rep con %s" % [opcion.rep_aleatoria, elegido])
	if opcion.has("mision_oculta"):
		_activar_mision_oculta(opcion.mision_oculta)

	# Navegación
	if opcion.has("siguiente") and opcion.siguiente >= 0:
		GameManager.show_dialogue(self, _dialogos[opcion.siguiente])
	else:
		GameManager.hide_dialogue()
		if opcion.get("desaparece", false):
			# El personaje oculto se esfuma (es parte de su encanto)
			if GameManager.hud:
				GameManager.hud.mostrar_aviso("✨ %s desapareció tan misteriosamente como llegó..." % npc_name)
			queue_free()

func _activar_mision_oculta(id: String):
	match id:
		"expediente_aurelio":
			SistemaMisiones.registrar_mision_dinamica(
				"oculta_expediente_aurelio",
				"🔍 MISIÓN OCULTA: El expediente perdido",
				"El misterioso Sr. Aurelio busca su expediente de 1987. Pregunta a la Administradora Torres y luego confirma con el Director (Piso 3).",
				"Sr. Aurelio",
				[
					{ "tipo": "hablar_cadena", "target": "Administradora Torres", "texto": "Administradora Torres: «¿Aurelio? ¿AURELIO? Ese expediente lleva 30 años en la lista de pendientes. Espere... aquí está, debajo de un sándwich fosilizado. Lléveselo al Director para validarlo.»", "cantidad": 1, "completado": false },
					{ "tipo": "hablar_cadena", "target": "Director Dr. Mendoza", "texto": "Director Dr. Mendoza: «¿El expediente de Aurelio? Vaya, creí que era una leyenda del hospital, como el café decente. Validado. Dígale que... espere, ¿quién me dijo que sigue aquí?»", "cantidad": 1, "completado": false }
				],
				20, 60, 17.0)
			if GameManager.hud:
				GameManager.hud.mostrar_aviso("🔍 ¡Misión oculta desbloqueada: El expediente perdido!")
