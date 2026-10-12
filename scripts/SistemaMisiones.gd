extends Node

signal mision_desbloqueada(mision)
signal mision_aceptada(mision)
signal mision_completada(mision)
signal mision_fallida(mision)
signal mision_critica_fallida(mision)
signal mision_por_vencer(mision, minutos_restantes)

enum Estado { INACTIVA, PENDIENTE, ACTIVA, COMPLETADA, FALLIDA }

var misiones: Dictionary = {}
var misiones_activas: Array = []
var misiones_completadas: Array = []
var misiones_fallidas: Array = []

# Avisos de "misión por vencer" ya emitidos (uno por misión y día)
var _avisos_limite: Dictionary = {}

func _ready():
	_cargar_misiones()
	# Conectar con el tiempo laboral
	TiempoLaboral.dia_iniciado.connect(_on_dia_iniciado)
	TiempoLaboral.dia_terminado.connect(_on_dia_terminado)

# Reinicio completo (lo llama GameManager.reiniciar_juego)
func reiniciar():
	misiones.clear()
	misiones_activas.clear()
	misiones_completadas.clear()
	misiones_fallidas.clear()
	_avisos_limite.clear()
	_cargar_misiones()

func _cargar_misiones():
	# ─── LUNES (día 1) ───────────────────────────────────────
	_m("conseguir_jeringas",    1, "Jeringas para el Dr. Ramírez",
		"Habla con el Dr. Ramírez y consigue 20 jeringas 5ml en bodega antes de las 14:00.",
		"Dr. Ramírez", [_obj("conseguir_insumo","Jeringa 5ml",20)],
		15, 35, false, false, 14.0)

	_m("receta_urgente",        1, "Medicación para la Sra. Carmen",
		"Dispensa la receta de la Sra. Carmen en farmacia y llévasela a su habitación (Piso 3, Hab. 112).",
		"Farmacéutico Luis", [_obj("dispensar_medicamento","",1)],
		12, 25, false, false, 16.0)

	_m("registrar_paciente",    1, "Registrar a Don Roberto",
		"Ayuda a la Recepcionista Ana: lleva la ficha de Don Roberto al piso 3.",
		"Recepcionista Ana", [_obj("hablar_npc","Don Roberto",1)],
		10, 20, false, false, 17.0)

	_m("vendas_urgencias",      1, "Reponer vendas en Urgencias",
		"Urgencias se está quedando sin vendas de gasa. Prepara 15 unidades en bodega y llévaselas al Dr. Ramírez (Urgencias, Piso 1).",
		"Dr. Ramírez", [_obj("conseguir_insumo","Venda de gasa",15)],
		10, 22, true, false, 17.0)

	_m("mascarillas_urgencias", 1, "Reponer mascarillas en Urgencias",
		"Urgencias necesita mascarillas quirúrgicas. Prepara 20 unidades en bodega y llévaselas al Dr. Ramírez (Urgencias, Piso 1).",
		"Dr. Ramírez", [_obj("conseguir_insumo","Mascarilla quirúrgica",20)],
		10, 22, true, false, 17.0)

	# ─── MARTES (día 2) ──────────────────────────────────────
	# REBALANCE: el martes era demasiado fácil (todo se resolvía en bodega
	# antes del mediodía). Ahora dos misiones exigen ENTREGAR el paquete en
	# otro piso, hay una ronda en cadena por 3 pisos y los límites aprietan.
	_m("pedido_bodega",         2, "Reposición urgente de stock",
		"Bodeguero Pedro reporta guantes y sueros casi agotados. Haz el pedido desde bodega.",
		"Bodeguero Pedro", [_obj("conseguir_insumo","Guantes nitrilo (caja)",2)],
		10, 20, false, false, 13.0)

	_m("muestras_laboratorio",  2, "Llevar muestras al laboratorio",
		"Lleva las muestras de urgencias al laboratorio del piso 2.",
		"Técnico Carlos", [_obj("llevar_muestras","",1)],
		8, 20, false, false, 12.0)

	_m("insumos_caducados",     2, "Retirar insumos caducados",
		"Revisa bodega y retira todos los insumos caducados antes de que lleguen a servicios.",
		"Sistema", [_obj("revisar_caducidades","",1)],
		5, 15, false, false, 15.0)

	_m("stock_analgesicos",     2, "Analgésicos para la Farmacia",
		"Farmacia necesita reforzar el stock de paracetamol. Prepara 30 unidades en bodega y entrégaselas al Farmacéutico Luis (Piso 1).",
		"Farmacéutico Luis", [_obj("conseguir_insumo","Paracetamol 500mg",30)],
		10, 22, true, false, 16.0)

	_m("gasas_laboratorio",     2, "Gasas estériles para el laboratorio",
		"El laboratorio pide gasas estériles. Prepara 25 unidades en bodega y entrégaselas al Técnico Carlos (Piso 2).",
		"Técnico Carlos", [_obj("conseguir_insumo","Gasa estéril",25)],
		10, 22, true, false, 16.0)

	# Ronda en cadena por los 3 pisos: obliga a moverse por todo el hospital
	_m("ronda_vitales",         2, "Ronda de control de signos vitales",
		"La Enf. Jefa García organiza la ronda del martes: empieza con ella (Enfermería, Piso 2), sigue con la Sra. Carmen (Hab. 112, Piso 3) y reporta al Dr. Ramírez (Urgencias, Piso 1).",
		"Enf. Jefa García", [
			_objc("Enf. Jefa García", "Enf. Jefa García: «Ronda del martes. Toma la tabla, revisa a la Sra. Carmen del 112 y luego repórtale al Dr. Ramírez. Y no corras por los pasillos... rápido, pero sin correr.»"),
			_objc("Sra. Carmen", "Sra. Carmen: «¿Mis signos vitales? Presión bien, pulso bien, y el ánimo mejor ahora que alguien me visita. Apunte también eso, que es importante.»"),
			_objc("Dr. Ramírez", "Dr. Ramírez: «¿La ronda completa y ANTES de que la pida dos veces? Voy a enmarcar esta tabla. Buen trabajo, técnico.»")
		], 14, 35, true, false, 17.0)

	# ─── MIÉRCOLES (día 3) ───────────────────────────────────
	_m("sueros_uci_urgente",    3, "🚨 UCI sin sueros — CRÍTICO",
		"Tres pacientes en ventilación necesitan sueros IV ahora. Prepara 6 unidades en bodega y ENTRÉGASELAS a la Enf. Sofía en la UCI (Piso 2).",
		"Enf. Sofía", [_obj("conseguir_insumo","Suero IV 500ml",6)],
		18, 40, false, true, 13.0)  # CRÍTICA (límite ajustado a días de 5 min)

	_m("kit_quirurgico",        3, "Kit quirúrgico para el Dr. Vargas",
		"Prepara el kit: 10 jeringas 10ml, 4 sueros IV, 2 cajas guantes nitrilo, y entrégalo al Dr. Vargas en Quirófano (Piso 2) antes de las 15:00.",
		"Dr. Vargas", [
			_obj("conseguir_insumo","Jeringa 10ml",10),
			_obj("conseguir_insumo","Suero IV 500ml",4),
			_obj("conseguir_insumo","Guantes nitrilo (caja)",2)
		], 20, 50, false, true, 15.0)  # CRÍTICA (límite ajustado a días de 5 min)

	_m("informe_semanal",       3, "Informe de inventario semanal",
		"La Enf. Jefa García necesita el informe de stock antes del cierre del día.",
		"Enf. Jefa García", [_obj("revisar_inventario","todos",1)],
		12, 30, false, false, 17.0)

	_m("sueros_reserva",        3, "Reserva de sueros para la UCI",
		"La UCI quiere una reserva de sueros de 1000ml. Prepara 5 unidades en bodega y llévaselas a la Enf. Sofía (UCI, Piso 2).",
		"Enf. Sofía", [_obj("conseguir_insumo","Suero IV 1000ml",5)],
		12, 26, true, false, 17.0)

	_m("alcohol_quirofano",     3, "Antiséptico para quirófano",
		"Quirófano necesita alcohol antiséptico. Prepara 15 unidades en bodega y llévaselas al Dr. Vargas (Quirófano, Piso 2).",
		"Dr. Vargas", [_obj("conseguir_insumo","Alcohol antiséptico",15)],
		12, 26, true, false, 17.0)

	# Misión EN CADENA: hablar con varios NPCs en orden
	_m("coord_quirofano",       3, "Coordinar la cirugía del miércoles",
		"EMPIEZA por la Recepcionista Ana (Recepción, Piso 1). Ella te mandará al Bodeguero Pedro y, por último, al Director (Piso 3).",
		"Director Dr. Mendoza", [
			_objc("Recepcionista Ana", "Recepcionista Ana: «Hoy hay una cirugía importante. Confirma el material con el Bodeguero Pedro y luego avisa al Director.»"),
			_objc("Bodeguero Pedro", "Bodeguero Pedro: «Material revisado y reservado para quirófano. Ahora sube al Director (Piso 3) para la autorización final.»"),
			_objc("Director Dr. Mendoza", "Director Dr. Mendoza: «Todo coordinado y autorizado. Excelente trabajo enlazando los servicios.»")
		], 22, 45, true, false, 17.0)

	# ─── JUEVES (día 4) ──────────────────────────────────────
	_m("firma_pedido",          4, "Firmar pedido mensual de insumos",
		"La Administradora Torres necesita tu firma para el pedido mensual.",
		"Administradora Torres", [_obj("hablar_npc","Administradora Torres",1)],
		8, 15, false, false, 16.0)

	_m("medicacion_roberto",    4, "Medicación urgente — Don Roberto",
		"Don Roberto lleva horas sin medicación. Ve a farmacia y llévala al piso 3.",
		"Don Roberto", [_obj("dispensar_medicamento","",1)],
		10, 20, false, false, 14.0)

	_m("auditoria_inventario",  4, "Auditoría del director — IMPORTANTE",
		"El Director solicita una auditoría completa de inventario. Revisa bodega y farmacia.",
		"Director Dr. Mendoza", [
			_obj("revisar_caducidades","",1),
			_obj("revisar_inventario","todos",1)
		], 25, 60, false, false, 17.0)

	_m("stock_antiinflamatorios", 4, "Reponer antiinflamatorios",
		"El stock de ibuprofeno de farmacia está bajo. Prepara 25 unidades en bodega y llévaselas al Farmacéutico Luis (Farmacia, Piso 1).",
		"Farmacéutico Luis", [_obj("conseguir_insumo","Ibuprofeno 400mg",25)],
		10, 22, true, false, 17.0)

	_m("bisturis_cirugia",      4, "Reponer bisturís desechables",
		"Cirugía necesita bisturís desechables. Prepara 10 unidades en bodega y llévaselos al Dr. Vargas (Quirófano, Piso 2).",
		"Dr. Vargas", [_obj("conseguir_insumo","Bisturí desechable",10)],
		10, 22, true, false, 17.0)

	_m("cateteres_uci",         4, "Catéteres IV para la UCI",
		"La UCI necesita catéteres IV. Prepara 12 unidades en bodega y llévaselos a la Enf. Sofía (UCI, Piso 2).",
		"Enf. Sofía", [_obj("conseguir_insumo","Catéter IV",12)],
		10, 24, true, false, 17.0)

	# ─── VIERNES (día 5) — Evaluación final ──────────────────
	_m("evaluacion_director",   5, "🏆 Evaluación semanal del Director",
		"El Director revisará tu desempeño de la semana. Ve a verlo a Dirección (Piso 3).",
		"Director Dr. Mendoza",
		[_objc("Director Dr. Mendoza", "Director Dr. Mendoza: «Hora del veredicto semanal. *revisa la carpeta* ...Vaya. Mantuviste el hospital a flote, a los pacientes contentos y a mí relativamente cuerdo. Buen trabajo, técnico. Te ganaste el fin de semana.»")],
		30, 80, true, false, 16.0)

	_m("reporte_final",         5, "Reporte final de la semana",
		"Entrega el reporte semanal a la Administradora Torres (Piso 3) antes del cierre.",
		"Administradora Torres",
		[_objc("Administradora Torres", "Administradora Torres: «¿El reporte semanal? Justo a tiempo, y por una vez no falta ni un papel. Es usted una rareza administrativa, y lo digo como elogio. Buen fin de semana.»")],
		15, 30, true, false, 17.0)

	_m("guantes_quirofano",     5, "Dotación de guantes para quirófano",
		"El Dr. Vargas pide una dotación de guantes de látex. Prepara 8 cajas en bodega y llévaselas a Quirófano (Piso 2).",
		"Dr. Vargas", [_obj("conseguir_insumo","Guantes látex (caja)",8)],
		10, 24, true, false, 17.0)

	_m("vendas_enfermeria",     5, "Reposición de vendas en Enfermería",
		"Enfermería necesita reponer vendas elásticas. Prepara 20 unidades en bodega y llévaselas a la Enf. Jefa García (Enfermería, Piso 2).",
		"Enf. Jefa García", [_obj("conseguir_insumo","Venda elástica",20)],
		10, 24, true, false, 17.0)

	_m("insulina_planta",       5, "Jeringas de insulina para planta",
		"La planta necesita jeringas de insulina. Prepara 18 unidades en bodega y llévaselas a la Enf. Jefa García (Enfermería, Piso 2).",
		"Enf. Jefa García", [_obj("conseguir_insumo","Jeringa de insulina",18)],
		10, 24, true, false, 17.0)

	_m("apositos_enfermeria",   5, "Apósitos para Enfermería",
		"Enfermería pide apósitos adhesivos. Prepara 20 unidades en bodega y llévaselos a la Enf. Jefa García (Enfermería, Piso 2).",
		"Enf. Jefa García", [_obj("conseguir_insumo","Apósito adhesivo",20)],
		10, 24, true, false, 17.0)

	# ─── Misiones DE ENTREGA ─────────────────────────────────
	# Preparar el paquete en bodega NO las completa: hay que llevarlo
	# hasta el NPC que la pidió (npc_origen; ver _verificar_completitud).
	# Solo "pedido_bodega" se resuelve en la propia bodega.
	for id_entrega in ["conseguir_jeringas", "sueros_uci_urgente", "kit_quirurgico",
			"gasas_laboratorio", "stock_analgesicos",
			"vendas_urgencias", "mascarillas_urgencias", "sueros_reserva", "alcohol_quirofano",
			"stock_antiinflamatorios", "bisturis_cirugia", "cateteres_uci",
			"guantes_quirofano", "vendas_enfermeria", "insulina_planta", "apositos_enfermeria"]:
		if misiones.has(id_entrega):
			misiones[id_entrega]["requiere_entrega"] = true

	# Misión EN CADENA de cierre de semana
	_m("ronda_despedida",       5, "Ronda de despedida de la semana",
		"Cierra la semana visitando a Don Roberto y a la Sra. Carmen (Piso 3) y al Técnico Carlos (Piso 2).",
		"Técnico Carlos", [
			_objc("Don Roberto", "Don Roberto: «Gracias por todo esta semana, joven. Que descanses el fin de semana.»"),
			_objc("Sra. Carmen", "Sra. Carmen: «Ha sido usted muy atento conmigo. Cuídese mucho, ¿eh?»"),
			_objc("Técnico Carlos", "Técnico Carlos: «Buen trabajo en equipo esta semana. ¡Nos vemos el lunes!»")
		], 20, 45, true, false, 17.0)

# ─── Helpers de construcción ─────────────────────────────────

func _m(id: String, dia: int, titulo: String, desc: String, npc: String,
		objetivos: Array, rep: int, xp: int, auto_activa: bool,
		critica: bool, hora_limite: float):
	misiones[id] = {
		"id": id, "titulo": titulo, "descripcion": desc,
		"npc_origen": npc, "objetivos": objetivos,
		"recompensa_reputacion": rep, "recompensa_exp": xp,
		"dia_disponible": dia, "hora_limite": hora_limite,
		"critica": critica,
		"estado": Estado.INACTIVA,
		"auto_activa": auto_activa,  # Se acepta automáticamente al desbloquearse
	}

func _obj(tipo: String, target: String, cantidad: int) -> Dictionary:
	return { "tipo": tipo, "target": target, "cantidad": cantidad, "completado": false }

# Eslabón de una misión EN CADENA: hay que hablar con 'target' (en orden).
func _objc(target: String, texto: String) -> Dictionary:
	return { "tipo": "hablar_cadena", "target": target, "texto": texto, "cantidad": 1, "completado": false }

# Completa el siguiente eslabón de cadena que corresponda a 'npc_name'.
# Devuelve el objetivo (con su 'texto') o {} si este NPC no es el siguiente paso.
func completar_paso_cadena(npc_name: String) -> Dictionary:
	for id in misiones_activas.duplicate():
		var m = misiones[id]
		for obj in m.objetivos:
			if obj.tipo == "hablar_cadena" and not obj.completado:
				if obj.get("target", "") == npc_name:
					obj.completado = true
					_verificar_completitud(id)
					return obj
				else:
					break  # el siguiente eslabón de esta misión es otro NPC
	return {}

# ¿'npc_name' es el próximo eslabón de alguna misión en cadena activa?
# (Solo consulta; no completa nada.)
func es_siguiente_paso_cadena(npc_name: String) -> bool:
	for id in misiones_activas:
		for obj in misiones[id].objetivos:
			if obj.tipo == "hablar_cadena" and not obj.completado:
				if obj.get("target", "") == npc_name:
					return true
				break
	return false

# Si 'npc_name' forma parte de una misión en cadena activa pero NO es el eslabón
# de turno, devuelve el NPC con el que hay que hablar AHORA (para dar una pista).
# Si no aplica, devuelve "".
func pista_cadena_para(npc_name: String) -> String:
	for id in misiones_activas:
		var m = misiones[id]
		var siguiente := ""
		var este_pendiente := false
		for obj in m.objetivos:
			if obj.tipo == "hablar_cadena" and not obj.completado:
				if siguiente == "":
					siguiente = obj.get("target", "")
				if obj.get("target", "") == npc_name:
					este_pendiente = true
		if este_pendiente and siguiente != "" and siguiente != npc_name:
			return siguiente
	return ""

# ─── Ciclo de vida ───────────────────────────────────────────

func _on_dia_iniciado(dia: int, _nombre: String):
	_avisos_limite.clear()
	desbloquear_misiones_del_dia(dia)

# Llamado desde TiempoLaboral: hace que las horas límite de las misiones
# sean REALES. Avisa 30 min (de juego) antes y aplica consecuencias al vencer.
# Las misiones con límite 17:00 las gestiona el fin de día como siempre.
func verificar_limites(hora_actual: float):
	for id in misiones.keys():
		var m = misiones[id]
		if m.estado != Estado.ACTIVA and m.estado != Estado.PENDIENTE:
			continue
		var limite: float = m.get("hora_limite", TiempoLaboral.HORA_FIN)
		if limite >= TiempoLaboral.HORA_FIN:
			continue
		if hora_actual >= limite:
			if m.estado == Estado.ACTIVA:
				# Solo falla (con consecuencia grave si es crítica) si la ACEPTASTE
				fallar_mision(id)
			else:
				# Pendiente al llegar su hora límite → expira sin incidente,
				# incluso las críticas (no se castiga lo que nunca tomaste).
				m.estado = Estado.INACTIVA
		elif hora_actual >= limite - 0.5 and not _avisos_limite.has(id):
			_avisos_limite[id] = true
			emit_signal("mision_por_vencer", m, int((limite - hora_actual) * 60.0))

func _on_dia_terminado(_dia: int, _resumen: Dictionary):
	# Fallar misiones activas no completadas
	for id in misiones_activas.duplicate():
		fallar_mision(id)
	# avanzar_bloqueos() lo llama TiempoLaboral.avanzar_al_siguiente_dia() — no duplicar aquí

func desbloquear_misiones_del_dia(dia: int):
	for id in misiones:
		var m = misiones[id]
		if m.dia_disponible == dia and m.estado == Estado.INACTIVA:
			m.estado = Estado.PENDIENTE
			emit_signal("mision_desbloqueada", m)
			if m.auto_activa:
				aceptar_mision(id)

func aceptar_mision(id: String):
	if not misiones.has(id): return
	var m = misiones[id]
	# Solo se puede aceptar si está PENDIENTE (desbloqueada para este día)
	# Si está INACTIVA (día futuro), el NPC la ofrece pero el sistema la ignora
	if m.estado != Estado.PENDIENTE:
		return
	m.estado = Estado.ACTIVA
	misiones_activas.append(id)
	emit_signal("mision_aceptada", m)

func completar_objetivo(id_mision: String, tipo: String):
	if not misiones.has(id_mision): return
	var m = misiones[id_mision]
	if m.estado != Estado.ACTIVA: return
	for obj in m.objetivos:
		if obj.tipo == tipo and not obj.completado:
			obj.completado = true
			break
	_verificar_completitud(id_mision)

func _verificar_completitud(id: String):
	var m = misiones[id]
	if m.objetivos.all(func(o): return o.completado):
		# Misiones DE ENTREGA: preparar el paquete en bodega no basta.
		# Solo se completan cuando el paquete llega a manos del NPC
		# (completar_todos_objetivos marca "entregado" al entregar).
		if m.get("requiere_entrega", false) and not m.get("entregado", false):
			return
		m.estado = Estado.COMPLETADA
		misiones_activas.erase(id)
		misiones_completadas.append(id)
		TiempoLaboral.registrar_mision_completada()
		GameManager.otorgar_recompensa(m)
		ReputacionGlobal.cambiar_reputacion(m.npc_origen, m.recompensa_reputacion, "Misión completada")
		emit_signal("mision_completada", m)

func fallar_mision(id: String):
	if not misiones.has(id): return
	var m = misiones[id]
	if m.estado != Estado.ACTIVA: return
	m.estado = Estado.FALLIDA
	misiones_activas.erase(id)
	misiones_fallidas.append(id)
	TiempoLaboral.registrar_mision_fallida()
	# Modo relajado: una misión normal sin terminar NO baja reputación; sólo
	# cuenta como no completada. Las misiones críticas sí mantienen consecuencia.
	# GameOverManager escucha mision_critica_fallida directamente
	if m.critica:
		ReputacionGlobal.cambiar_reputacion(m.npc_origen, -m.recompensa_reputacion / 4, "Misión crítica fallida")
		emit_signal("mision_critica_fallida", m)
	emit_signal("mision_fallida", m)

func get_progreso_objetivo(id: String) -> float:
	if not misiones.has(id): return 0.0
	var m = misiones[id]
	var total = m.objetivos.size()
	var hechos = m.objetivos.filter(func(o): return o.completado).size()
	return float(hechos) / float(total)

# Fuerza la completitud total. Lo llama el NPC al RECIBIR una entrega
# (y bodega para pedidos sin entrega), así que aquí sí se marca "entregado".
func completar_todos_objetivos(id_mision: String):
	if not misiones.has(id_mision): return
	var m = misiones[id_mision]
	if m.estado != Estado.ACTIVA: return
	for obj in m.objetivos:
		obj.completado = true
	m["entregado"] = true
	_verificar_completitud(id_mision)

# Insumos que aún faltan por preparar en esas misiones, como "4 × Suero IV 500ml".
# Un paquete con algo pendiente (p. ej. el kit a medias) no se puede entregar.
func insumos_faltantes(ids: Array) -> Array:
	var faltan = []
	for id in ids:
		if not misiones.has(id):
			continue
		for obj in misiones[id].objetivos:
			if obj.tipo == "conseguir_insumo" and not obj.completado:
				faltan.append("%d × %s" % [obj.cantidad, obj.target])
	return faltan

func completar_objetivo_insumo(nombre_insumo: String):
	for id in misiones_activas:
		var m = misiones[id]
		for obj in m.objetivos:
			if obj.tipo == "conseguir_insumo" and obj.get("target","") == nombre_insumo and not obj.completado:
				obj.completado = true
				_verificar_completitud(id)
				return

# BUGFIX: versión dirigida a UNA misión concreta. Antes, si dos misiones
# activas pedían el mismo insumo (p.ej. miércoles: "Suero IV 500ml" para la
# UCI y para el kit quirúrgico), preparar el pedido completaba el objetivo
# de la misión equivocada según el orden interno de la lista.
func completar_objetivo_insumo_de_mision(id_mision: String, nombre_insumo: String):
	if not misiones.has(id_mision):
		completar_objetivo_insumo(nombre_insumo)
		return
	var m = misiones[id_mision]
	if m.estado != Estado.ACTIVA:
		completar_objetivo_insumo(nombre_insumo)
		return
	for obj in m.objetivos:
		if obj.tipo == "conseguir_insumo" and obj.get("target","") == nombre_insumo and not obj.completado:
			obj.completado = true
			_verificar_completitud(id_mision)
			return
	# La misión indicada no esperaba este insumo: usar la búsqueda general
	completar_objetivo_insumo(nombre_insumo)

# ─── Misiones dinámicas (eventos aleatorios / misiones ocultas) ──────
# Registra una misión creada en tiempo de ejecución y la deja ACTIVA hoy.
func registrar_mision_dinamica(id: String, titulo: String, desc: String, npc: String,
		objetivos: Array, rep: int, xp: int, hora_limite: float = 17.0):
	if misiones.has(id):
		return  # Ya existe (no duplicar si el evento se repite)
	_m(id, TiempoLaboral.dia_semana, titulo, desc, npc, objetivos, rep, xp, false, false, hora_limite)
	var m = misiones[id]
	m.estado = Estado.PENDIENTE
	emit_signal("mision_desbloqueada", m)
	aceptar_mision(id)

func completar_objetivo_por_item(nombre_item: String, npc_destino: String):
	# Busca misión activa que espere la entrega de ese ítem a ese NPC.
	# NOTA: los objetivos guardan su dato en la clave "target" (ver _obj()).
	for id in misiones_activas:
		var m = misiones[id]
		for obj in m.objetivos:
			if obj.tipo == "entregar_item" and not obj.completado:
				if obj.get("target", "") == nombre_item:
					obj.completado = true
					_verificar_completitud(id)
					return
	# Fallback: completar primer objetivo pendiente de tipo hablar_npc
	for id in misiones_activas:
		var m = misiones[id]
		for obj in m.objetivos:
			if obj.tipo == "hablar_npc" and obj.get("target", "") == npc_destino and not obj.completado:
				obj.completado = true
				_verificar_completitud(id)
				return

func get_misiones_por_estado(estado: Estado) -> Array:
	var result = []
	for id in misiones:
		if misiones[id].estado == estado:
			result.append(misiones[id])
	return result

func get_color_estado(estado: Estado) -> Color:
	match estado:
		Estado.INACTIVA:   return Color(0.5, 0.5, 0.5)
		Estado.PENDIENTE:  return Color(0.3, 0.6, 0.95)
		Estado.ACTIVA:     return Color(0.95, 0.85, 0.2)
		Estado.COMPLETADA: return Color(0.2, 0.85, 0.3)
		Estado.FALLIDA:    return Color(0.9, 0.25, 0.25)
	return Color.WHITE

func get_icono_estado(estado: Estado) -> String:
	match estado:
		Estado.INACTIVA:   return "⚫"
		Estado.PENDIENTE:  return "🔵"
		Estado.ACTIVA:     return "🟡"
		Estado.COMPLETADA: return "🟢"
		Estado.FALLIDA:    return "🔴"
	return "?"

# ─── Resaltado de nombres e ítems en NEGRITA (BBCode) ────────
# Pone en [b]negrita[/b] los nombres de NPC y los objetos mencionados en los
# textos de misiones y diálogos, para ayudar al jugador a recordar qué
# necesita y con quién debe hablar. Lo usan HUD, DayResultsUI y DialogueUI
# (requiere mostrarse en un RichTextLabel con bbcode_enabled).

const _NOMBRES_NPC = [
	"Dr. Ramírez", "Recepcionista Ana", "Farmacéutico Luis", "Bodeguero Pedro",
	"Dr. Vargas", "Enf. Sofía", "Técnico Carlos", "Enf. Jefa García",
	"Don Roberto", "Sra. Carmen", "Director Dr. Mendoza", "Administradora Torres",
	"Dra. Méndez",
]

const _TERMINOS_ITEM = [
	"jeringas de insulina", "jeringas de 5ml", "jeringas 5ml", "jeringas 10ml",
	"jeringas", "sueros IV", "sueros de 500ml", "sueros de 1000ml", "sueros",
	"suero IV", "guantes nitrilo", "guantes de látex", "guantes de cocina",
	"guantes", "vendas de gasa", "vendas elásticas", "vendas",
	"gasas estériles", "gasas", "mascarillas quirúrgicas", "mascarillas",
	"ficha clínica", "ficha", "medicamentos", "medicación", "muestras",
	"paracetamol", "ibuprofeno", "bisturís desechables", "bisturís",
	"alcohol antiséptico", "kit quirúrgico", "kit completo", "recetas urgentes",
	"recetas", "receta", "informe de inventario", "informe de stock",
	"catéteres IV", "apósitos adhesivos", "apósitos",
]

func resaltar_bbcode(texto: String) -> String:
	# Ordenar términos de más largo a más corto para no partir frases
	# ("jeringas de 5ml" antes que "jeringas").
	var terminos: Array = []
	terminos.append_array(_NOMBRES_NPC)
	terminos.append_array(_TERMINOS_ITEM)
	terminos.sort_custom(func(a, b): return a.length() > b.length())

	# Sustituir cada aparición por un marcador temporal (área privada Unicode)
	# para que un término corto no vuelva a coincidir dentro de uno largo.
	var res = texto
	var guardados: Array = []
	for t in terminos:
		var desde = 0
		while guardados.size() < 400:
			var idx = res.findn(t, desde)
			if idx == -1:
				break
			var original = res.substr(idx, t.length())
			guardados.append("[b]" + original + "[/b]")
			var token = String.chr(0xE000 + guardados.size() - 1)
			res = res.substr(0, idx) + token + res.substr(idx + t.length())
			desde = idx + 1
	for i in range(guardados.size()):
		res = res.replace(String.chr(0xE000 + i), guardados[i])
	return res
