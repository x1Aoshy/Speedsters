# Revisión de peligros letales — 13 septiembre 2026

Inspección previa a cambios: archivos root actuales y scripts extraídos en `audit/hazard_current`; inventario de geometría en `audit/hazard_current_inventory.json`. No se ha ejecutado Roblox Studio ni medido ping.

## Hallazgos confirmados

- HZ-01: TreeSlammers cliente y servidor no respetan `StageTeleportInvulnerable`, a diferencia de los peligros World1. Una llegada protegida puede morir al contactar el árbol.
- HZ-02: La señal TreeSlammers acepta cualquier índice convertible y mata sin comprobar contacto, incluso índices fraccionarios. Se debe validar índice entero y contacto con partes corporales reales del personaje que envía la señal. No se amplían cajas ni se confía en partes enviadas por cliente.
- HZ-03: World1 Presser1Controller consulta cualquier parte de personaje, incluidos Handles de accesorios/equipamiento. Un accesorio voluminoso puede matar sin contacto corporal. Su barrido usa una caja, incluso para geometría no rectangular: debe emplear la caja como candidatos y validar el volumen real del obstáculo trasladado.
- HZ-04: NewWorld1ServerMotion memoriza para siempre las partes del avatar en la primera consulta de martillo. Si se hizo antes de completar el avatar o éste cambia, queda una hitbox corporal obsoleta. Debe actualizarse al añadir/quitar partes directas.
- HZ-05: El cliente TreeSlammers puede procesar eventos del personaje anterior después de respawn; sus conexiones no se desconectan. Puede incorporar el Humanoid/raíz antiguo al estado nuevo. Se debe desconectar al cambiar personaje y filtrar partes directas.

## Afirmaciones del informe Gemini que no quedan probadas

- Los martillos actuales son varias `Part`, no una malla única gigante. Los árboles sí contienen dos MeshParts por árbol (máximo 38.95 × 83.15 × 40.66). Las dimensiones no prueban que sus colisiones sean una caja ni dónde están las ramas visibles. Lune no expone correctamente CollisionFidelity de estos archivos; no se inventa una calibración ni se reduce el árbol por porcentaje.
- `ClientMotionType`, `ClientMotionEpoch` y `ClientMotionBaseCFrame` no tienen escritor en scripts servidor actuales World1. Los scripts cliente/authority nuevos esperan atributos que nadie configura. El movimiento activo sigue en NewWorld1ServerMotion/Presser1Controller; el supuesto desfase temporal descrito para authority no demuestra la causa actual.
- El número de llamadas a SetAttribute o de partes no equivale a número de paquetes ni prueba un ping concreto. La mejora real de red requiere medición en Roblox.

## Validación prevista

Pruebas de funciones reales con mocks de consultas: protección de teleport, entradas remotas inválidas, contacto corporal versus accesorios, actualización de caché y limpieza tras respawn; compilación Luau de cambios. La fidelidad geométrica de MeshPart y contacto físico bajo latencia requieren Roblox.
