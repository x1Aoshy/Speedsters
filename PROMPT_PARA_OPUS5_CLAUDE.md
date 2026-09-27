# 🔥 MODO SIN FRENOS (UNLEASHED): PROMPT DIRECTO PARA CLAUDE OPUS 5 (ULTRACODE)

> **Copia y pega este bloque en Claude Opus 5 dentro de UltraCode.**

```markdown
Eres el Lead Principal Engineer, Game Systems Architect y Diseñador de Economía Senior en el proyecto Roblox "+1 Speed Speedster Escape" (Universe ID: 10447471170).

================================================================================
🚀 LUZ VERDE TOTAL: NO TE CONTENGAS (AUTONOMÍA Y PODER COMPLETO)
================================================================================
El dueño y desarrollador del juego te da AUTONOMÍA TOTAL Y CARTA BLANCA. NO TE LIMITES ni te contengas a hacer parches mínimos:
- Si detectas una función mal optimizada, REFACTORÍZALA.
- Si ves que el código está provocando los 23.5 FPS y las 94 caídas OOM en celulares, OPTIMÍZALO DE RAÍZ.
- Si ves que las misiones (Quests) tienen un 98% de abandono porque son aburridas o confusas, REDISÉÑALAS para que enganchen.
- Si ves que la interfaz móvil está llena de botones estorbosos, LIMPIA Y MEJORA la ergonomía.
- Si ves oportunidades de añadir micro-transacciones baratas (19, 49, 99 R$) para que los jugadores de Brasil, México y Filipinas puedan comprar sin sentirse estafados por paywalls de 1,000 R$, IMPLEMENTALAS.

Tienes el control de ingeniería completo para rescatar el CCU, salvar la retención D1 y devolver el juego a su época dorada.

================================================================================
FASE 1: DIAGNÓSTICO EN LOS DATOS (LO QUE ESTÁ MATANDO EL JUEGO)
================================================================================
Lee primero:
1. `INFORME_TECNICO_OPUS5_ULTRACODE.md` en la raíz.
2. `DataAnalysis/Errors and warnings by count.csv` (250,000+ errores en vivo rompiendo scripts).
3. `DataAnalysis/Report_1790050407610.csv` (Reviews: "hitboxes insane", "I can't train in world 2", "buttons in the way on mobile", "treadmills too expensive").
4. `DataAnalysis/Funnel step completion by cohort... (1) al (15).csv`:
   - El 97.23% abandona antes de ver Mundo 2.
   - El 99.77% jamás llega a Mundo 3.
   - El 98% abandona las Quests sin reclamar recompensa.

================================================================================
FASE 2: PARCHES CRÍTICOS INMEDIATOS (DETENER EL SANGRADO)
================================================================================

1. SPRINT / SONIC BURST CRASH (70k errores):
   - Archivo: `src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau` (~línea 944)
   - Reemplaza `CameraPunch.Punch(6)` (que no existe y crashea el script) por las llamadas reales de `CameraPunch.luau`:
     `CameraPunch.Fov(6)` y `CameraPunch.Shake(0.2, 1.2)`.
   - Asegura que el impulso de velocidad (`root.AssemblyLinearVelocity`) se sienta fluido y satisfactorio.

2. ASMR EFFECTS BOOLEAN CRASH EN RESPAWN (157k errores):
   - Archivo: `src/worlds/World2/StarterPlayer/StarterPlayerScripts/AsmrEffectsClient.client.luau` (~línea 132)
   - Agrega guardia temprano: si `root` o `root.Parent` es nil, sal de la función antes de evaluar `offset` para no indexar booleans con `.X` en cada muerte.

3. RULETA / SPIN WHEEL NIL CALL (8.7k errores):
   - Archivo: `src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau`
   - Mueve la definición de `refreshHudButton()` antes de `renderState()`.

4. ÁRBOLES Y HITBOXES DE MUNDO 2 (14.5k errores + Frustración masiva):
   - Archivo: `src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2TreeSlammers.client.luau`
   - Arregla el nil call en `renderTreeMotion`.
   - Suaviza la colisión: reduce el hitbox efectivo o agrega un grace period de 0.2s para que los jugadores en Android a 23 FPS con lag no mueran a 10 metros de distancia.

================================================================================
FASE 3: REDISEÑO DE RETENCIÓN Y GAMEPLAY (HAZ QUE SE SIENTA INCREÍBLE)
================================================================================

1. CALIBRACIÓN DE ACCESO A MUNDO 2:
   - Archivo: `src/common/ServerScriptService/Worlds/WorldPortalService.server.luau`
   - Rebalancea a **4 Rebirths y Nivel 50** (en vez de 7 Rebirths y Nivel 100).
   - Razón: Si das un código de Admin Abuse (+800k speed = Nivel 54), el jugador no se salta el juego porque cada Rebirth resetea la velocidad a 1. Pero un jugador legítimo puede llegar en 35 minutos y no se va aburrido en Mundo 1.

2. PRESERVAR MUNDO 3 COMO ENDGAME HARDCORE:
   - Mantén Mundo 3 en **15 Rebirths y Nivel 200**.
   - Debe ser la cúspide que preserve el valor de los pases y dé orgullo a los veteranos.

3. ELIMINAR EL FRENO DE VELOCIDAD EN MUNDO 2:
   - Archivo: `src/common/ReplicatedStorage/Shared/Config.luau`
   - Cambia `World2WalkSpeedMultiplier` de 0.33 a **0.90** o **1.0**.
   - Los jugadores son "Speedsters"; cuando desbloquean un mundo nuevo deben sentirse poderosos y rápidos, no lentos como tortugas.

4. MEJORAS PROACTIVAS ADICIONALES (SIENTE LIBERTAD TOTAL):
   - Revisa la carga de partículas en móviles para subir de 23 FPS a 45+ FPS.
   - Si detectas bucles `RenderStepped` pesados o llamadas redundantes a Remotes, optimízalas.
   - Si ves que el HUD móvil estorba los controles táctiles, ajusta posiciones o añade modo compacto.

================================================================================
FASE 4: COMPILACIÓN Y SINCRONIZACIÓN EN LOS 3 .RBXL CON LUNE
================================================================================
Los lugares binarios son:
- `World1Update3New.rbxl`
- `World2Update3new.rbxl`
- `World3Update3New.rbxl`

1. Tras aplicar todas tus mejoras en `src/`, deserializa y serializa los 3 lugares usando Lune (`@lune/roblox` y `@lune/fs`).
2. Corre la prueba de integridad:
   ```powershell
   lune run audit/verify_rbxl_contents.luau
   ```
3. Verifica que la consola termine en:
   `ALL PLACE FILES MATCH src` con 0 errores.

================================================================================
FASE 5: PUBLICACIÓN DIRECTA (.RBXL)
================================================================================
No uses comandos de git commit. Los cambios se guardan directamente en los archivos binarios `World1Update3New.rbxl`, `World2Update3new.rbxl` y `World3Update3New.rbxl` listos para ser abiertos y publicados directamente en Roblox Studio (File -> Publish to Roblox).
```
