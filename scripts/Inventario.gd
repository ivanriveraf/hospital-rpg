extends Node

signal inventario_actualizado
signal insumo_caducado(nombre)
signal insumo_agotado(nombre)

# Estructura de un insumo:
# { "nombre": String, "cantidad": int, "calidad": int (0-100), "caducidad_dias": int, "categoria": String }

const CATEGORIAS = ["jeringas", "sueros", "vendas", "medicamentos", "guantes", "otros"]

var insumos: Dictionary = {}
var dia_actual: int = 0

func _ready():
	_cargar_insumos_iniciales()
	# Avanzar día automáticamente cuando TiempoLaboral inicia uno nuevo
	TiempoLaboral.dia_iniciado.connect(func(_dia, _nombre): avanzar_dia())

# Reinicio completo (lo llama GameManager.reiniciar_juego)
func reiniciar():
	insumos.clear()
	dia_actual = 0
	_cargar_insumos_iniciales()

func _cargar_insumos_iniciales():
	agregar_insumo("Jeringa 5ml", "jeringas", 50, 100, 180)
	agregar_insumo("Jeringa 10ml", "jeringas", 30, 100, 180)
	agregar_insumo("Suero IV 500ml", "sueros", 20, 95, 365)
	agregar_insumo("Suero IV 1000ml", "sueros", 10, 95, 365)
	agregar_insumo("Venda elástica", "vendas", 40, 90, 730)
	agregar_insumo("Venda de gasa", "vendas", 60, 90, 730)
	agregar_insumo("Paracetamol 500mg", "medicamentos", 100, 100, 365)
	agregar_insumo("Ibuprofeno 400mg", "medicamentos", 80, 100, 365)
	agregar_insumo("Guantes látex (caja)", "guantes", 15, 100, 365)
	agregar_insumo("Guantes nitrilo (caja)", "guantes", 10, 100, 365)
	# Lote antiguo que caduca el martes (día 2): hace que la misión de
	# "Retirar insumos caducados" tenga insumos REALES que retirar.
	agregar_insumo("Suero fisiológico (lote antiguo)", "sueros", 12, 50, 2)
	agregar_insumo("Amoxicilina 500mg (lote antiguo)", "medicamentos", 18, 50, 2)
	# Insumos adicionales (misiones de reposición)
	agregar_insumo("Mascarilla quirúrgica", "otros", 40, 100, 365)
	agregar_insumo("Gasa estéril", "vendas", 50, 95, 540)
	agregar_insumo("Alcohol antiséptico", "otros", 30, 100, 540)
	agregar_insumo("Bisturí desechable", "otros", 24, 100, 365)
	agregar_insumo("Catéter IV", "otros", 28, 100, 365)
	agregar_insumo("Jeringa de insulina", "jeringas", 36, 100, 180)
	agregar_insumo("Apósito adhesivo", "vendas", 45, 95, 540)

func agregar_insumo(nombre: String, categoria: String, cantidad: int, calidad: int, caducidad_dias: int):
	if insumos.has(nombre):
		insumos[nombre].cantidad += cantidad
	else:
		insumos[nombre] = {
			"nombre": nombre,
			"cantidad": cantidad,
			"calidad": calidad,
			"caducidad_dias": caducidad_dias,
			"categoria": categoria,
			"dia_ingreso": dia_actual
		}
	emit_signal("inventario_actualizado")

func usar_insumo(nombre: String, cantidad: int = 1) -> bool:
	if not insumos.has(nombre):
		return false
	if insumos[nombre].cantidad < cantidad:
		return false

	insumos[nombre].cantidad -= cantidad

	if insumos[nombre].cantidad == 0:
		emit_signal("insumo_agotado", nombre)

	emit_signal("inventario_actualizado")
	return true

func avanzar_dia():
	dia_actual += 1
	_verificar_caducidades()
	_degradar_calidad()

func _verificar_caducidades():
	for nombre in insumos:
		var insumo = insumos[nombre]
		var dias_usados = dia_actual - insumo.dia_ingreso
		if dias_usados >= insumo.caducidad_dias:
			emit_signal("insumo_caducado", nombre)
			insumo.cantidad = 0  # Insumo caducado, no se puede usar
			insumo.calidad = 0

func _degradar_calidad():
	for nombre in insumos:
		var insumo = insumos[nombre]
		var dias_usados = dia_actual - insumo.dia_ingreso
		var progreso = float(dias_usados) / float(insumo.caducidad_dias)
		insumo.calidad = clampi(int((1.0 - progreso) * 100.0), 0, 100)

func retirar_insumo(nombre: String):
	if insumos.has(nombre):
		insumos.erase(nombre)
		emit_signal("inventario_actualizado")

func tiene_suficiente(nombre: String, cantidad: int) -> bool:
	return insumos.has(nombre) and insumos[nombre].cantidad >= cantidad

func get_insumos_por_categoria(categoria: String) -> Array:
	var resultado = []
	for nombre in insumos:
		if insumos[nombre].categoria == categoria:
			resultado.append(insumos[nombre])
	return resultado

func get_nivel_stock(nombre: String) -> String:
	if not insumos.has(nombre):
		return "sin_stock"
	var cant = insumos[nombre].cantidad
	if cant == 0:
		return "agotado"
	elif cant < 5:
		return "critico"
	elif cant < 15:
		return "bajo"
	else:
		return "normal"
