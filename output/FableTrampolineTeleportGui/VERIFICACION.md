Cambios terminados el 20 de septiembre de 2026.

- Los tres archivos .rbxl de esta carpeta y de la raíz del proyecto contienen el build final.
- Taco Treadmill: conserva los efectos de impacto; elimina el fuego persistente, el cráter y los fragmentos de roca. El fuego del meteorito durante su caída sigue siendo temporal.
- World 1, stage 9: trampolín físico de 415.13 studs/s calculado con la geometría del mapa (439.18 studs de ascenso, 20 sobre la cima). Se retiró el conveyor de 277777 studs/s y se añadió la exención temporal de las correcciones de movimiento.
- Stage TP: canvas original Y=2 y tamaño automático desactivado, conservando el tamaño original del panel y sus filas. Stage 11 sigue fuera del menú de pago.

Verificación: compilación de los ocho scripts incorporados, serialización y lectura de los tres mapas, coincidencia de los scripts con src, simulación balística a 30/60/120/240 fps, ejecución del cliente del trampolín con servicios simulados y comparación del GUI contra el respaldo anterior.

audit/run_fable_checks.luau terminó con 0 fallos de 20 pruebas, incluidas las nuevas comprobaciones del trampolín y las pruebas de TacoMeteor contra los tres mapas guardados.

No se ejecutó Play en Roblox Studio. La sensación del salto y el aspecto visual dentro del juego requieren esa comprobación.

Los mapas previos a este build están en backup/.
