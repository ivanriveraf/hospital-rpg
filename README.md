# 🏥 Hospital RPG

> ⚠️ **Prototipo.** Este repositorio muestra una versión en desarrollo del juego con fines de portafolio. La versión final no forma parte de este repositorio.

RPG de gestión en 2D hecho en **Godot 4.6** con **GDScript**. Encarnas a un enfermero en su primera semana de trabajo en un hospital de tres pisos. Tienes que cumplir misiones, atender a pacientes y personal, administrar insumos y cuidar tu reputación antes de que termine cada turno.

## Características

- **Una semana completa** (de lunes a viernes) con días cronometrados y un resumen de resultados al final de cada día.
- **3 pisos** conectados por escaleras y un ascensor animado, cada uno con sus áreas y NPCs.
- **29 misiones fijas**, además de **eventos aleatorios**, **misiones ocultas** y **personajes secretos**.
- **Diálogos con opciones y consecuencias**, cargados desde archivos JSON.
- **Reputación por NPC y reputación global.**
- **Inventario con caducidad y calidad** de los insumos, más interfaces de **bodega** y **farmacia** para preparar y dispensar pedidos.
- **HUD** con hora, día, nivel y misiones activas, y una guía hacia el siguiente objetivo.
- **Guardado y carga de partida**, menú de inicio, pausa y pantalla de *game over*.

## Arquitectura

El estado global se maneja con *singletons* (autoloads): `GameManager`, `Inventario`, `SistemaMisiones` y `ReputacionGlobal`. Cada piso hereda de `FloorBase.gd`, y los diálogos se separan del código en `data/dialogos_piso*.json`.

## Tecnologías

Godot 4.6 · GDScript · JSON

## Cómo abrirlo

1. Descarga [Godot 4](https://godotengine.org/download).
2. En Godot, haz clic en **Importar** y elige el archivo `project.godot`.
3. Presiona **F5** para jugar.

> La música no se incluye en el repositorio.

## Créditos

Desarrollo, diseño y programación: **Iván Rivera** ([GitHub](https://github.com/ivanriveraf) · [LinkedIn](https://linkedin.com/in/ivan-patricio-rivera-fuentealba))

## Licencia

© 2026 Iván Rivera. Todos los derechos reservados. Ver [LICENSE](LICENSE).
