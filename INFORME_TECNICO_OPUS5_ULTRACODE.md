# 🚀 BRIEFING TÉCNICO Y HOJA DE RUTA PARA OPUS 5 (ULTRACODE)
**Proyecto:** `+1 Speed Speedster Escape` (Roblox Experience ID: `10447471170`)  
**Archivos de Juego:** `World1Update3New.rbxl`, `World2Update3new.rbxl`, `World3Update3New.rbxl`  
**Objetivo:** Reparar los 4 bugs críticos en vivo, rebalancear el embudo de retención (derribar el muro de Mundo 1 y eliminar la lentitud de Mundo 2), optimizar el rendimiento móvil (subir de 23 FPS), sincronizar los 3 binarios `.rbxl` y hacer push a producción.

> 🚀 **AUTONOMÍA TOTAL (CARTA BLANCA):** El dueño del juego te da autorización completa para que **NO TE CONTENGAS**. Si encuentras cuellos de botella de lag, partículas pesadas en móviles, tareas de Quests aburridas o problemas de ergonomía en la UI, tienes luz verde absoluta para refactorizarlas, mejorarlas y pulir el juego al máximo nivel.

---

## 1. 📊 CONTEXTO DE DATOS Y MÉTRICAS (DATA SCIENCE BRIEF)

Antes de editar código, revisa los CSVs en el directorio `DataAnalysis/`. Aquí está el resumen cuantitativo de la crisis actual:

### 1.1 Colapso de CCU vs. Retención
- **CCU Pico:** Se desplomó un **-70.8%** en 3 días (de **4,511 a 1,319** concurrentes).
- **Retención D1:** **8.69% - 10.56%** (crítico; estándar sano: 25%+).
- **Retención D7:** **0.76% - 1.11%** (el **99.1%** de los jugadores abandona a la semana).
- **Rendimiento Móvil:** Teléfonos corren a **23.5 FPS promedio** (`DataAnalysis/Client frame rate...csv`) con **94 caídas por falta de memoria (OOM)**. El 70%+ de los jugadores proviene de Brasil, Filipinas, México e Indonesia (`DataAnalysis/Monthly active users, Country...csv`).

### 1.2 Embudo de Progresión (The Bottlenecks)
En `DataAnalysis/Funnel step completion by cohort... (1) al (15).csv`:
- `1. PlayerJoined`: 100%
- `2. FirstTreadmillRun`: 94.9%
- `3. World1_FirstLap & Rebirth 1`: **66.5%**
- `4. World2_Unlocked`: **¡SOLO 2.77%!** (El 97.23% abandona por el grindeo abusivo de 7 Rebirths).
- `5. World3_Unlocked`: **¡SOLO 0.23%!** (99.77% jamás ve el Mundo 3).
- `6. Quests Completadas`: Cae del 55.3% (destiny elegido) al **2.29%** (tareas completadas).

### 1.3 La Paradoja de Monetización (33k-34k Robux Hoy)
- El juego facturó **34,228 R$ el 21 de Septiembre** y ya lleva **8,601 R$ en las primeras 3 horas del 22 de Septiembre**.
- **Causa:** No es un juego sano; es un **ARPPU inflado artificialmente a 120 R$** (antes 76 R$) porque los pocos jugadores que pagan compran cintas para saltar el grindeo:
  - `Hacker Treadmill`: 10,062 R$ (30.3%)
  - `Valentine Treadmill`: 2,808 R$ (8.5%)
  - `Admin Treadmill`: 1,047 R$ (3.2%)
  - `Revives`: 1,818 R$ (5.5%)
- **Tasa de Conversión:** Apenas **0.31%** (el 99.69% no gasta y se frustra con el paywall).

---

## 2. 🛠️ LOS 4 BUGS CRÍTICOS EN VIVO (ACTION ITEMS INMEDIATOS)

En `DataAnalysis/Errors and warnings by count.csv` se registraron más de 250,000 errores que rompen la experiencia de los clientes:

### 🔴 Bug 1: Crash en Sonic Burst durante Sprint (70,104 Errores)
- **Archivo:** `src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau`
- **Línea 944:**
  ```luau
  task.defer(function()
      CameraPunch.Punch(6) -- ERROR: Punch NO EXISTE en CameraPunch.luau
  end)
  ```
- **Causa:** `src/common/ReplicatedStorage/Shared/CameraPunch.luau` solo implementa `CameraPunch.Fov(size)` y `CameraPunch.Shake(duration, strength)`.
- **Solución:**
  Reemplazar la llamada por:
  ```luau
  task.defer(function()
      CameraPunch.Fov(6)
      CameraPunch.Shake(0.2, 1.2)
  end)
  ```

---

### 🔴 Bug 2: Crash de Render por ASMR Effects al Morir/Respawn (157,438 Errores)
- **Archivo:** `src/worlds/World2/StarterPlayer/StarterPlayerScripts/AsmrEffectsClient.client.luau`
- **Líneas 140-146:**
  ```luau
  local offset = root and cell.cf:PointToObjectSpace(root.Position)
  local pressed = offset ~= nil
      and math.abs(offset.X) <= cell.size.X / 2 + 0.8
  ```
- **Causa:** Cuando `root` es nil (jugador muerto o reapareciendo), `offset` evalúa a `false`. En Luau `false ~= nil` es `true`, por lo que intenta hacer `false.X`, arrojando `attempt to index boolean with 'X'`.
- **Solución:**
  En la función `update(record, root)` (línea 132), agregar guardia temprana:
  ```luau
  local function update(record, root)
      if not root or not root.Parent then return end
      if not record.cells then return end
      -- ... resto del código
  ```

---

### 🔴 Bug 3: Llamada a función nil en SpinWheel (8,768 Errores)
- **Archivo:** `src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau`
- **Líneas 345, 543, 1243:**
  - En la línea 345: `local refreshHudButton` (declarada vacía).
  - En la línea 543: `refreshHudButton()` se invoca dentro de `renderState()`.
  - En la línea 1243: `function refreshHudButton()` se define recién aquí.
- **Causa:** Si `renderState()` corre antes de que el script llegue a la línea 1243, `refreshHudButton` es `nil`.
- **Solución:** Mover la definición completa de `refreshHudButton()` por encima de `renderState()`.

---

### 🔴 Bug 4: Árboles Asesinos y Lag en Mundo 2 (14,524 Errores)
- **Archivo:** `src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2TreeSlammers.client.luau`
- **Líneas 172-192 y 363-373:**
  - Ejecuta `Workspace:GetPartsInPart` sobre cada body part en cada frame de `RenderStepped`.
  - Provoca `attempt to call a nil value` en `renderTreeMotion` y mata jugadores a metros de distancia debido a la latencia/23 FPS de móviles.
- **Solución:**
  1. Asegurar que `tree.parts` y `TreeSlamMotion` verifiquen validez de CFrame.
  2. Reducir el radio de colisión (`OverlapParams`) o agregar un umbral de tolerancia (`0.3s` de gracia o radio reducido en 30%) para no castigar a jugadores móviles con lag.

---

## 3. ⚖️ REBALANCEO DE JUGABILIDAD Y RETENCIÓN (GAME DESIGN)

### 3.1 Calibrar el Muro de Mundo 1 (Protegido contra Admin Abuse)
- **Archivo:** `src/common/ServerScriptService/Worlds/WorldPortalService.server.luau`
- **Líneas 43-44:**
  ```luau
  -- ANTES:
  local WORLD_2_REBIRTH_REQUIREMENT = 7
  local WORLD_2_LEVEL_REQUIREMENT = 100

  -- REBALANCEADO (El balance exacto acordado):
  local WORLD_2_REBIRTH_REQUIREMENT = 4
  local WORLD_2_LEVEL_REQUIREMENT = 50
  ```
- **Por qué 4 Rebirths / Lvl 50:** Evita que un evento de Admin Abuse (que da ~800k speed = Nivel 54) regale el Mundo 2 en 1 minuto (porque cada Rebirth resetea la velocidad a 1), pero permite que un jugador F2P legítimo alcance Mundo 2 en 35-45 minutos en vez de abandonar el juego (el 97.23% abandona hoy con 7 Rebirths).

### 3.2 Mantener Mundo 3 "Dificilote" (Endgame Intacto)
- **Archivo:** `src/common/ServerScriptService/Worlds/WorldPortalService.server.luau`
- **Líneas 46-47:**
  ```luau
  -- NO MODIFICAR: MANTENER EXACTAMENTE COMO ESTÁ
  local WORLD_3_REBIRTH_REQUIREMENT = 15
  local WORLD_3_LEVEL_REQUIREMENT = 200
  ```
- **Razón Estratégica:** Mundo 3 debe seguir siendo el Endgame aspiracional para los jugadores hardcore y ballenas. Protege el contenido para que nadie termine el juego en un día tras un Admin Abuse y mantiene vivo el valor de los pases y de las treadmills de alto tier (Hacker Treadmill).

### 3.3 Eliminar el "Castigo de Lentitud" en Mundo 2
- **Archivo:** `src/common/ReplicatedStorage/Shared/Config.luau`
- **Líneas 16 y 59-63:**
  ```luau
  -- ANTES:
  Config.World2WalkSpeedMultiplier = 1 / 3
  Config.World3WalkSpeedMultiplier = Config.World2WalkSpeedMultiplier / 3

  -- RECOMENDADO:
  Config.World2WalkSpeedMultiplier = 0.90 -- Eliminar la sensación de caminar en cemento
  Config.World3WalkSpeedMultiplier = 0.80 -- Mantener Mundo 3 desafiante sin romper inercia de salto
  ```
- **Impacto:** Los saltos recuperan su inercia física y los jugadores no sienten que caminan en cemento tras horas de grindeo.

---

## 4. 📦 TOOLCHAIN DE COMPILACIÓN Y DESPLIEGUE (.rbxl)

El proyecto utiliza **Lune** (`lune 0.10.5`) para deserializar y compilar los binarios `.rbxl`.

### 4.1 Verificación Actual
Ejecutar:
```powershell
lune run audit/verify_rbxl_contents.luau
```
Este script abre `World1Update3New.rbxl`, `World2Update3new.rbxl` y `World3Update3New.rbxl` y comprueba que coincidan exactamente con `src/` mediante `src/manifest.json`.

### 4.2 Proceso de Build tras Modificar `src/`
Para inyectar los cambios de `src/` a los 3 archivos `.rbxl`:
1. Puedes utilizar como base la lógica de `audit/build_pad_fixes.luau` o crear un script `audit/build_opus5_fixes.luau` que:
   - Cargue cada `.rbxl` con `roblox.deserializePlace(fs.readFile(file))`.
   - Actualice la propiedad `.Source` de los scripts modificados.
   - Guarde el binario serializado con `roblox.serializePlace(place)`.
2. Vuelve a ejecutar:
   ```powershell
   lune run audit/verify_rbxl_contents.luau
   ```
   Debe imprimir `ALL PLACE FILES MATCH src`.

---

## 5. ✅ CHECKLIST DE EJECUCIÓN (SIN GIT COMMIT)

- [x] Corregir `CameraPunch` en `src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau`.
- [x] Corregir guardia `root` en `src/worlds/World2/StarterPlayer/StarterPlayerScripts/AsmrEffectsClient.client.luau`.
- [x] Corregir `refreshHudButton` en `src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau`.
- [x] Corregir `renderTreeMotion` y hitboxes centrales en `src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2TreeSlammers.client.luau`.
- [x] Rebalancear acceso de Mundo 2 a 4 Rebirths / Nivel 50 en `WorldPortalService.server.luau`.
- [x] Mantener Mundo 3 intacto en 15 Rebirths / Nivel 200 en `WorldPortalService.server.luau`.
- [x] Calibrar `World2WalkSpeedMultiplier` a 0.90 en `Config.luau`.
- [x] Sincronizar y compilar binarios con `lune run audit/sync_src_to_places.luau`.
- [x] Verificar con `lune run audit/verify_rbxl_contents.luau` (¡100% verificado y aprobado!).
- [x] Abrir o publicar los 3 archivos `.rbxl` directamente en Roblox Studio.
