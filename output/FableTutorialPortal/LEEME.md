# Tutorial + cinemática del portal (2026-09-20, Fable)

Aplicado a `World1Update3New.rbxl`, `World2Update3new.rbxl`, `World3Update3New.rbxl` (copias aquí; originales en `backup/`).
Abre los .rbxl **desde disco** (si Studio tenía uno abierto y lo guardas encima, se pierde este build).

## Qué cambió
1. **Tarjeta del tutorial** (`Shared/TutorialGuide`): mini‑ventana con el arte del juego (hoja de bloques `106477372921851`, borde azul marino, icono + título Fredoka sobre el borde, texto en placa azul marino, botón Skip rojo de studs `135496826236732`, flecha del juego `74885007861450`, anillo dorado con línea azul marino). Se dimensiona a partir del botón del HUD (antes 280×144 px fijos).
2. **Tutorial de Win / primer aura**: el paso 2 del servidor caduca a los 102 s; quien entrenaba más (hasta rebirth) antes de tocar el pad nunca recibía la guía. Ahora la guía se debe desde que se reclama el primer Win pad (o uno posterior), en cualquier momento de la sesión del tutorial, y vuelve si un respawn la cerró (`Shared/TutorialFlow`). La guía de Evolve también se vuelve a ofrecer si algo la cerró.
3. **Badge de Evolve**: 0.34 del botón y dentro del botón (antes 0.46 centrado en el borde derecho: se metía ~25 px sobre Teleport). Cambiado en código y en la instancia guardada de StarterGui.
4. **Cinemática del portal** (`UI/WorldPortalCinematic` + `Shared/WorldPortalShot`):
   - El frente sale de la propia losa del portal (su eje delgado, del lado del lobby). Antes se usaba la primera pieza llamada "Sign" del Workspace; en World 1 esa pieza mira de lado, así que la cámara quedaba de canto/detrás.
   - Cierre tipo obturador: cierra → corte al portal → abre a barras → vuelo de 34° a de frente → cierra → vuelve al jugador → abre. El lobby se pide por streaming antes del plano y un raycast acerca la cámara si algo estorba.
   - **Una sola vez por mundo, para siempre**: `Worlds/WorldPortalService` guarda `World2Unlocked`/`World3Unlocked` en el instante en que se cumplen los requisitos (mismo commit idempotente del portal) y el cliente solo reproduce cuando esa bandera pasa a true en vivo. Ya no se repite al entrar, morir, subir de nivel ni tras rebirth.
   - Efecto de juego: el mundo queda desbloqueado aunque un rebirth baje el nivel antes de cruzar el portal.
   - Para probarla en Studio: panel admin → quitar y volver a dar World 2 (el reinicio admin permite repetirla).

## Verificar
```
lune run audit/run_fable_checks.luau
lune run audit/test_fable_tutorial_portal.luau places
```
Reconstruir: `lune run audit/build_fable_tutorial_portal.luau`

## Pendiente (no es de este cambio)
- ~19 scripts de `audit/` (incluido `build_core`) aún leen `World{N}Update3.rbxl`; los places ahora se llaman `...New.rbxl`, así que `scratch/run_suite.luau` no corre completo.
- `test_saved_uis`: `src/ui/QuestGui.rbxm` está desactualizado respecto a `QuestUi.Decorate`.
- `test_admin_treadmill_reveal`: su mock no tiene `GetAttribute` (el reveal lo usa desde el 09‑20).
- Falta playtest en Studio de la apariencia (Lune no renderiza UI).
