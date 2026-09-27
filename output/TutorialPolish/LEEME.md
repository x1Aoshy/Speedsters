# Tutorial y evento de tacos: acabado visual

Los tres RBXL de la raíz están actualizados. Esta carpeta contiene copias del resultado y `backup/` conserva la versión anterior a estos cambios.

- Guía con Fredoka One, contornos oscuros, azul/dorado y la textura de bloques de los menús existentes.
- Oscurecimiento de pantalla mediante cuatro paneles, dejando libre el botón indicado. No hay botones transparentes que intercepten el objetivo.
- Flecha, pasos numerados, progreso, entrada/salida gradual, seguimiento suave y confirmación al completar.
- `Skip guide` permanece disponible en todas las etapas. No hay cierre automático por tiempo.
- Eliminados los botones `?` y las tarjetas de ayuda de Backpack y Evolve.
- Primera oportunidad de Evolve: guía de dos pasos para abrir el menú y evolucionar. Espera a que terminen la carga y las otras guías.
- Icono Evolve con brinco y el mismo distintivo de Rebirth: `!` para una evolución o el número si hay varias. Solo cuenta trajes aún no obtenidos que cumplen nivel y rebirths. El aviso se apaga cuando no quedan evoluciones disponibles, incluso al bajar de nivel por rebirth.
- Evento de tacos sin promoción del creador: sin popup, enlaces, botones Follow, comando `/follow`, descripción del anfitrión ni retrato del perfil en la cinta de tacos. Conserva el anuncio normal, las recompensas y los efectos.

Verificado: compilación de 12 fuentes, 42 casos de posición de tarjetas, requisitos y contador de evoluciones, ausencia de rutas de promoción, regresión de activación/impactos de tacos y reapertura de los tres RBXL con fuentes exactas.

No se ejecutó una sesión Play de Roblox Studio. Para la comprobación visual, vuelve a abrir el RBXL actualizado: prueba la guía en móvil horizontal/vertical, Saltar, primera evolución (nivel 10), varias disponibles, evolución completada y reinicio de nivel por rebirth. Activa `/tacos` para comprobar que aparece el evento sin promociones.

Pruebas: `audit/test_tutorial_polish.luau` y `audit/test_tacos_tutorial_repair.luau`.
Integración: `audit/build_tutorial_polish.luau`.
