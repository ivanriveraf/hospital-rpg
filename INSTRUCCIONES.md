# Hospital RPG — Instrucciones para abrir en Godot 4

## Requisitos
- **Godot 4.3** (descargar gratis en https://godotengine.org)

## Cómo abrir el proyecto
1. Abre Godot 4
2. Clic en **"Import"**
3. Navega a esta carpeta (`HospitalRPG/`) y selecciona `project.godot`
4. Clic en **"Import & Edit"**

## Estructura de archivos

```
HospitalRPG/
├── project.godot          ← Configuración del proyecto
├── scripts/
│   ├── GameManager.gd     ← Singleton principal (tiempo, guardado, recompensas)
│   ├── Player.gd          ← Movimiento y detección del jugador
│   ├── NPC.gd             ← Sistema de reputación y diálogos
│   ├── Inventario.gd      ← Gestión de insumos con caducidad
│   ├── SistemaMisiones.gd ← Misiones con objetivos y recompensas
│   ├── HUD.gd             ← Interfaz: inventario, misiones, hora/día
│   ├── DialogueUI.gd      ← Ventana de diálogo con opciones
│   └── HospitalMap.gd     ← Mapa del hospital y sus áreas
├── data/
│   └── dialogos_ejemplo.json  ← Diálogos del Dr. Ramírez y Enf. García
└── scenes/                ← Aquí crearás las escenas (.tscn) en el editor
```

## Próximos pasos en el editor de Godot

### 1. Configurar Autoloads (Project > Project Settings > Autoload)
Agrega estos scripts como singletons:
- `scripts/GameManager.gd` → nombre: `GameManager`
- `scripts/Inventario.gd` → nombre: `Inventario`
- `scripts/SistemaMisiones.gd` → nombre: `SistemaMisiones`

### 2. Crear la escena principal (Main.tscn)
- Nodo raíz: `Node2D` con script `HospitalMap.gd`
- Agrega un nodo `TileMap` para el mapa de tiles del hospital
- Agrega un nodo `CharacterBody2D` con script `Player.gd`
- Agrega la UI: un `CanvasLayer` con script `HUD.gd`
- Agrega otro `CanvasLayer` con script `DialogueUI.gd`

### 3. Crear un NPC (ejemplo: Dr. Ramírez)
- Nodo `CharacterBody2D` con script `NPC.gd`
- En el Inspector, configura:
  - `npc_name`: "Dr. Ramírez"
  - `npc_role`: "Médico Jefe"
  - `initial_reputation`: 50
- Hijos necesarios: `AnimatedSprite2D`, `Label` (nombre), `Label` (hint [E]), `ProgressBar` (reputación)

### 4. Crear sprites simples para el prototipo
Puedes usar rectángulos de color mientras no tengas sprites:
- En `AnimatedSprite2D`, usa `SpriteFrames` con un `ColorRect` de 32x48px

## Mecánicas implementadas

| Mecánica | Estado |
|----------|--------|
| Movimiento del jugador | ✅ Script listo |
| Mapa del hospital (4 áreas) | ✅ Script listo |
| Sistema de NPC con reputación | ✅ Script listo |
| Diálogos con opciones y consecuencias | ✅ Script listo |
| Inventario con caducidad y calidad | ✅ Script listo |
| Sistema de misiones con objetivos | ✅ Script listo |
| HUD (hora, día, nivel, misiones) | ✅ Script listo |
| Guardado/carga de partida | ✅ Script listo |
| Sprites y arte | 🔲 Pendiente |
| Música y sonidos | 🔲 Pendiente |
| Más NPCs y misiones | 🔲 Pendiente |
| Sistema de turnos/días completo | 🔲 Pendiente |
| Eventos aleatorios (1–2 por día) | ✅ Script listo |
| Misiones ocultas (eventos sorpresa) | ✅ Script listo |
| Personajes ocultos (Genaro y Aurelio) | ✅ Script listo |
| Reinicio limpio de partida | ✅ Script listo |

## 🎲 Eventos aleatorios y secretos (NUEVO)

Cada día laboral se programan **1 o 2 eventos aleatorios** entre las 09:00 y
las 15:00 (gestionados por `scripts/EventosAleatorios.gd`, autoload):

- **☕ Café derramado** — pierdes 5 min limpiando.
- **💡 Microapagón** — pierdes 8 min esperando al generador.
- **🎁 Donación sorpresa** — +20 unidades de un insumo aleatorio.
- **🕵️ Inspector de sanidad** — misión sorpresa: ve con el Director.
- **🧸 Operación Peluche** — misión en cadena: Ana → Sra. Carmen.
- **🐈 Gato en bodega** — misión en cadena: Pedro → Enf. Jefa García.
- **🤡 Payaso de pediatría** — +15 XP gratis.

**Personajes ocultos** (aparecen al cambiar de piso, con suerte):

- **Conserje Genaro** (~22%, máx. 1/día): escucha su chisme y mejora tu
  reputación con un NPC aleatorio (+XP).
- **Sr. Aurelio** (~8%, máx. 1/semana): un paciente... peculiar. Desbloquea
  la **misión oculta "El expediente perdido"** (Torres → Director, +60 XP).

Los eventos no se repiten dentro de la misma semana.
