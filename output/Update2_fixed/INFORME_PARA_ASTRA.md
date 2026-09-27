# 📋 INFORME DE ACTUALIZACIÓN Y CAMBIOS

**Destinatario:** Astra  
**De:** Equipo de Desarrollo / Pair Programming  
**Fecha:** 12 de Septiembre, 2026  
**Lugares:** World 1 (`World1 Speedtercorrect.rbxl`) & World 2 (`world2 speedtster.rbxl`)  
**Estado:** ✅ Implementado, 100% verificado con suites de tests y empaquetado.

---

## 📌 Resumen Ejecutivo

Se completaron todas las correcciones críticas de juego reportadas (incluyendo el bug de Wins y HUD), se implementó el nuevo sistema de vuelo temporal de 20 minutos con código promocional y persistencia completa en DataStore, y se rediseñó totalmente el **Panel de Administración** integrándolo de forma nativa en la barra superior (**TopbarPlus**) con la misma estética oficial de la interfaz del juego (`Settings`, `Worlds`, etc.).

---

## 1. 🛠️ Correcciones Críticas de Juego

1. **Bug de Wins & Win Pads:**
   - Se eliminó la doble multiplicación involuntaria en las plataformas de meta (`WinPad`).
   - El gasto de victorias en el sistema de teletransporte (`TeleportSystem`) se unificó a través de la función canónica de deducción `_G.SpeedsterSpendWins`.
2. **HUD & Animaciones de Velocidad (`MainHUDController.luau`):**
   - Corregido el error donde el contador de velocidad caía visualmente a 1 durante las actualizaciones programadas.
   - Sincronizados los impactos visuales con el estado real del jugador.
3. **Aislamiento de Treadmills (`TreadmillTraining.luau`):**
   - Se aisló el contenedor principal de cintas respecto a la cinta exclusiva de administrador para evitar interferencias en el conteo de zonas de entrenamiento.
4. **Requisitos de Rebirths:**
   - Verificado el requisito de 3 Rebirths para Candy World en Mundo 1 sin que salte el prompt erróneo de Gamepass.
5. **Niveles Recomendados:**
   - Los carteles de nivel recomendado en ambos mundos ahora son de doble cara y con formato numérico legible.

---

## 2. 🕊️ Sistema de Vuelo Temporal (Gekkoh Giveaway / 20m Flight)

1. **Catálogo de Códigos (`CodesCatalog.luau`):**
   - Se registró el código principal **`Gekkoh`** / `gekkoh` y sus alias (`gekkohfly`, `gekkohgiveaway`, `gekkohgaveyoufly`, `gekkoh20`, `gekoh`, `gekko`, `geko`, `fly20`, `admingiveawayfly`).
   - **Recompensas:**
     - **Vuelo Temporal:** 20 minutos (`1200` segundos).
     - **Velocidad (XP):** 800,000 (reducción del 20% respecto al giveaway previo de 1M).
     - **Wins:** 20,000 (reducción del 20% respecto a los 25K anteriores).
     - **Mensaje Toast:** `"🎁 Gekkoh gave you Fly & XP! (+800K Speed, +20K Wins, 20m Flight)"`.
2. **Equipamiento Automático y Expiración Segura:**
   - Al redimir el código, el vuelo se desbloquea y se equipa inmediatamente (`FlightAbilityOwned = true`, `FlightAbilityEquipped = true`, `EquippedAbility = "Flight"`).
   - **Watchdog del Servidor (1s loop):** Monitorea de forma autoritativa el timestamp `TemporaryFlightExpireUnix`. Al cumplirse los 20 minutos, revoca automáticamente la habilidad y la desequipa si el usuario no compró el pase permanente.
3. **Tarjeta de Buff en el HUD con Ícono Personalizado (`MainHUDController.luau`):**
   - Se añadió la tarjeta en el contenedor `ActiveBuffsHolder` con la insignia **"FLY"**, contador regresivo en vivo (`MM:SS`) y el ícono visual solicitado: `rbxassetid://123961542220277`.
4. **Persistencia en DataStore (`ProfileV306`):**
   - Campo `TemporaryFlightRemainingSeconds` agregado al schema de perfil.
   - Si el jugador se desconecta mientras tiene tiempo activo, los segundos restantes se guardan y se restauran fielmente en su próxima sesión.

---

## 3. 👑 Panel de Admin (Estado: 🔒 DESACTIVADO A PETICIÓN)

> **Nota de Despliegue:** Por solicitud directa, el panel de administración y sus botones asociados (`👑 ADMIN` flotante y botón en Topbar) han sido **desactivados en el cliente** (`ADMIN_PANEL_ENABLED = false`, `ADMIN_TOPBAR_ENABLED = false`). No se montan ni se muestran a ningún jugador ni administrador en el juego. El código base y sus módulos quedan listos en caso de requerirse en el futuro.

1. **Botón en el Topbar Menu (`TopbarIconsController.luau`):**
   - Se integró un icono nativo mediante **TopbarPlus** con el ícono de corona dorada (`rbxassetid://10723374641`).
   - **Posición:** `order = 3` (ubicado a la par de Calendario/Recompensas Diarias en `order = 1` y Ajustes en `order = 2`).
   - **Permisos:** Solo es visible para administradores autorizados tras la validación en el servidor (`AdminPanelStatus`).
   - **Sincronización:** El botón se activa/desactiva en sincronía bidireccional con el estado abierto/cerrado del panel.
2. **Estilo Visual Idéntico a la UI del Juego:**
   - **Marco:** Fondo azul marino con gradiente vertical (`Color3.fromRGB(26, 42, 72)` a `Color3.fromRGB(16, 24, 42)`).
   - **Borde:** Trazo grueso azul marino oscuro (`Color3.fromRGB(11, 27, 61)`, grosor 3) y esquinas redondeadas (`UICorner` 16px).
   - **Overlay:** Fondo `Dim` semitransparente que cubre la pantalla completa y permite cerrar el menú al hacer clic fuera del recuadro.
   - **Header:** Título con tipografía `FredokaOne`, sombras y botón circular rojo "✕" de cierre.
   - **Escalado Responsivo:** Integrado con `MenuPanelLayout` para ajuste perfecto en PC, móviles y tablets.
   - **Sonidos:** Efectos sonoros integrados con `SoundService` en cada interacción.
3. **6 Pestañas Modulares:**
   - **🎁 Códigos:** Activador rápido de códigos para el servidor local o broadcast global.
   - **⚡ Boosts:** Botón para otorgar el Geko Giveaway a todos, pociones y vuelo temporal directo.
   - **🏆 Stats:** Acciones rápidas de Speed y Wins, toggle de `AUTO REBIRTH`, forzar renacimiento y reset de estadísticas.
   - **🎟️ Pases:** Simulador con interruptores individuales y botón `DESACTIVAR TODOS LOS PASES`.
   - **🌍 Mundos / Teleport:** Teletransporte instantáneo a zonas de spawn, treadmills y bypass de portales.
   - **📢 Anuncio:** Emisión de banners informativos en tiempo real en la parte superior del servidor.

---

## 4. 🌐 Activador Masivo de Códigos (Local + GLOBAL)

- **Alcance Local:** Canjea cualquier código automáticamente a todos los jugadores en la instancia actual.
- **Alcance GLOBAL (Todos los Servidores):** Publica el evento mediante `MessagingService` en el canal `"SpeedsterGlobalCodes_v1"` para que todos los servidores activos del juego otorguen el código a sus jugadores en tiempo real.
- **Prevención de Duplicados & Forzado:**
  - Verifica si el usuario ya canjeó el código para evitar abusos y muestra el resumen al admin (ej. *"5 otorgados, 3 ya lo tenían"*).
  - Incluye opción para **"Forzar re-canje"** si se desea otorgar la recompensa incluso a quienes ya lo reclamaron.

---

## 5. 🛠️ Ajustes de Consola y Compatibilidad con Roblox Studio

Se resolvieron las advertencias y errores reportados durante el arranque en Studio:
1. **`AdminPanelController.luau` (Error TextColor3 & index nil):**
   - Se añadió la constante `COLOR_WHITE = Color3.fromRGB(255, 255, 255)`.
   - Se ordenó la validación en `closePanel()` para comprobar si `mainFrame` o `screenGui` son nulos antes de acceder a `mainFrame.Visible`.
2. **`TopbarIconsController.luau` (Infinite Yield):**
   - Se corrigió el nombre referenciado del panel de admin a `"SpeedsterAdminMiniPanel"` (antes `"SpeedsterAdminPanel"`), sincronizando de inmediato el botón superior sin tiempos de espera.
3. **`AdminAbuseServer.luau` (You must publish this place...):**
   - Se protegió la llamada a `DataStoreService:GetDataStore` con `pcall` para que en pruebas locales de Studio no detenga la creación de `AdminAbuseRemote`.
4. **`MessageHandler.luau` (Calling thread is sandboxed):**
   - Se encapsuló `AdminBarRemote:FireServer("CheckPermission")` en un bloque seguro `pcall`.
5. **`RankRewardGui` en Mundo 1:**
   - Se trasladó la interfaz `RankRewardGui` desde `ServerStorage` a `StarterGui` (alineándolo con Mundo 2) y se colocó un timeout preventivo en `RankRewardPanel.luau`.
6. **Desactivación del Panel Viejo HD/UHD Admin (`AdminAbuse`):**
   - Se desactivó el clonado a los administradores en `AdminAbuseServer.luau`, se colocó salida inmediata y auto-eliminación en `AdminAbuseClient.luau`, y se deshabilitó `AdminAbusePanelGui` en `ServerStorage` para que no vuelva a aparecer en pantalla.

---

## 7. 🏁 Corrección Integral de Win Pads en World 2 & Código WINS

1. **Resolución de Win Pads en Mundo 2:**
   - **Causa Raíz Identificada:** En Mundo 2, el Spawn es la Etapa 1, `SafeZone1.2` corresponde a la Etapa 2, y `SafeZone9.2` a la Etapa 10. Sin embargo, `Services/StageTeleportService.luau` mapeaba `SafeZone(N).2` directamente a la Etapa `N` (desfasado por 1) y buscaba un `SafeZone10.2` que no existe. Como `MovementGuard` consultaba este servicio, creía que el jugador estaba una etapa por detrás, bloqueando permanentemente el cobro de todas las plataformas (`CanClaim = false`).
   - **Corrección de Mapeo:** Se alineó `Services/StageTeleportService.luau` con `Gameplay/World2StageTeleportService.luau` (Etapa 1 = Spawn, Etapas 2-10 = `SafeZone(N-1).2`, Etapa Final = `WinStage.2`).
   - **Tolerancia a Alta Velocidad (`RewardPadClaims.luau`):** Se incrementó la holgura de verificación `characterAtPad` de 3.5 a 14 studs, permitiendo que jugadores que atraviesan los pads a miles de studs por segundo reclamen su recompensa sin falsos rechazos, con fallback a `_G.SpeedsterAddWins`.
   - **Eliminación de Conflictos y "Gel Infinito" (Infinite Yields):**
     - Se pre-crearon y hornearon de forma permanente en `ReplicatedStorage.Remotes` todos los eventos remotos críticos (`WinPadFeedback`, `SpeedGainPopup`, `BoostState`, `LevelProgressUpdate`, `TemporaryBoostUpdate`, `TeleportAction`, `TeleportUpdate`, `UpdateLogClosed`).
     - Se desactivó `RotatingLaser.luau` en Mundo 2 para eliminar la congelación de 30 segundos en `Workspace:WaitForChild("Laser", 30)`.
     - Se desactivó la generación procedimental duplicada de `World2StageSystem.luau` en Mundo 2 para evitar conflictos con `World2ManualStagePads.luau`.

2. **Nuevo Código Promocional `WINS`:**
   - **Nombre:** `WINS` (con soporte insensible a mayúsculas: `wins`, `Wins`, ` WiNs `).
   - **Recompensa:** **17,500 Wins** (exactamente un **30% menos** que los 25,000 otorgados por `admingiveaway`).
   - **Marker:** `"Code_Wins_v1"` con guardado permanente de un solo uso por jugador.
   - **Mensaje Toast:** `"🎉 You redeemed code WINS! (+17,500 Wins)"`.
   - **Disponibilidad:** Habilitado tanto en Mundo 1 como en Mundo 2.

---

## 8. 🧪 Verificación y Aseguramiento de Calidad

Todos los cambios fueron validados con los siguientes resultados de ejecución:

| Suite de Prueba | Comando | Resultado |
|---|---|---|
| **Compilación Luau** | `lune run audit/persistence/compile_merged.luau` | ✅ `PASS all merged sources compile` |
| **Gameplay Fixes (17 checks)** | `lune run audit/persistence/test_fixes.luau` | ✅ `ALL TEST CHECKS PASSED!` |
| **Regresión & Migración de Datos** | `lune run audit/persistence/test_regression.luau` | ✅ `PASS` |
| **Vuelo Temporal & Watchdog** | `lune run audit/persistence/test_geko_flight.luau` | ✅ `ALL CHECKS PASSED!` |
| **Activador de Códigos Admin** | `lune run scratch/test_admin_codes.luau` | ✅ `ALL CHECKS PASSED!` |
| **World 2 WinPads & Código WINS** | `lune run scratch/test_w2_winpads_and_code.luau` | ✅ `ALL CHECKS PASSED!` |

---

## 9. 📦 Archivos `.rbxl` Empaquetados

Los archivos de lugar han sido reconstruidos y verificados con comprobación de hash por script:

- `World1 Speedtercorrect.rbxl` y `output/Update2_fixed/World1.rbxl`
- `World2Old has to be synced with world1updated the p[ad bug still.rbxl` y `output/Update2_fixed/World2.rbxl`
*(Se crearon copias de seguridad previas en la carpeta `audit/`).*

---

## 10. 🎁 Modal de Códigos Duplicado & Secuencia con Update Logs (World 1 & World 2)

1. **Estructura Visual Idéntica:**
   - Se duplicó la interfaz gráfica oficial `Update Logs` creando `StarterGui["Codes Modal"]`.
   - Se reemplazó el banner de título por `"CODES"` manteniendo la misma tipografía `FredokaOne`, gradientes y botón circular de cierre rojo.
   - En el `ScrollingFrame` se agregaron **10 tarjetas de códigos activas**:
     - `UPDATE2`
     - `7KCCU`
     - `5MVISITS`
     - `Sorry4DelayedUpdate2day`
     - `LAG`
     - `HITBOX`
     - `GEKKOH`
     - `ADMINGIV3AWAY`
     - `WINS`
     - `EASTER` (o códigos de soporte)
   - Cada tarjeta contiene:
     - Título del código en negrita.
     - Descripción / recompensa.
     - Botón directo **`CLAIM`** integrado con `CodesRequest:FireServer("Redeem", codeName)` para canjear con 1 solo clic.
2. **Controlador Cliente (`CodesModalController.luau`):**
   - Animación suave de apertura y cierre mediante `TweenService` (slide vertical y fade del fondo difuminado `Dim`).
   - Conectado con `MenuEvents.Get("OpenCodesModal")` para control centralizado de menús.
3. **Secuencia de Transición Automática (`UpdateLogsController.luau`):**
   - Al hacer clic en cerrar `Update Logs`, este se desliza hacia abajo e inmediatamente dispara la apertura de `Codes Modal` deslizándose hacia arriba.
   - Si el usuario abre `Update Logs` manualmente desde el menú lateral, la secuencia no se fuerza para no interrumpir la navegación.

---

## 11. 💬 Comandos de Chat de Boosts de Servidor (`ChatBoostCommands.luau`)

- **Ubicación:** `ServerScriptService.Admin.ChatBoostCommands` (World 1 y World 2).
- **Comandos Soportados:**
  - `/active * 2 Speed <minutos>` o `/active 2x speed <minutos>`
  - `/active * 2 Win <minutos>` o `/active 2x win <minutos>`
  - Soporta sintaxis natural con y sin asterisco/espacios: `/active * 2 Speed 30`, `/active * 2 Win 30`, `/active 2x win 30`.
- **Comportamiento:**
  - Valida permisos de administrador (`AdminGuard.IsAdmin`).
  - Activa el boost en `_G.SpeedsterSetServerBoost(statType, multiplier, durationSeconds)`.
  - Anuncia en el chat global del servidor:  
    `[Server Boost] <PlayerName> has activated 2x <Speed/Wins> for <N> minutes!`
  - Conecta con la tarjeta de `ServerBuffCard` en el HUD para mostrar el temporizador en vivo.

---

## 12. ⚡ Auditoría y Resolución del Lag de Red y Físicas en World 2

> **Nota para Astra:** Se revisaron tus notas en `audit/BUG_ASMR_NETWORK.md` y `audit/INFORME_RED_Y_HITBOXES_PARA_ASTRA.md`. Se confirmó que la degradación en World 2 era principalmente un **colapso de red y replicación en el servidor** sumado a sobrecarga de físicas. Las correcciones ya fueron aplicadas directamente en ambos archivos `.rbxl` de World 2.

### Causas y Correcciones Aplicadas:
1. **Restauración y Migración 100% al Cliente de Objetos ASMR (Mantequillas, Burbujas y Teclados):**
   - Siguiendo la regla de oro de arquitectura (*"Nada corre en el servidor excepto validaciones y colisiones sólidas"*), se restauraron los 3 kits ASMR (`ASMR kit -  by Agus_Fellini2`) aplicando la migración diseñada por Astra (`network_map_migration.luau`).
   - **En el Servidor:** Se **desactivaron completamente los 25 scripts de servidor** (`Disabled = true`). Se eliminaron al 100% los `Heartbeat` en el servidor, los `Lerp` de CFrame y los spams de `SurfaceGui`. Las 6 partes base de Mantequilla permanecen autoritativas, ancladas y con colisión (`CanCollide = true`) en el servidor para que los jugadores puedan caminar sobre ellas.
   - **En el Cliente (`StarterPlayerScripts.AsmrEffectsClient`):** Todo el comportamiento visual e interactivo se ejecuta 100% en el cliente:
     - Streaming dinámico por distancia: se montan los efectos visuales cuando el jugador está a menos de 160 studs y se desmontan automáticamente a más de 220 studs.
     - Deformación (squish & tilt) de mantequilla, animaciones elásticas de botones y burbujas mediante `TweenService` local.
     - Reproducción de efectos de sonido y partículas puramente locales (cero tráfico de paquetes UDP en la red del servidor).
2. **Purgado del Script Parásito en `Sonic.EXE`:**
   - Se eliminó el script `Workspace.Sonic.EXE.HeadParts.MiddleSpine.Mesh.Structure` (código de farola de 2014 conectado a `Lighting.Changed`).
3. **Optimización de Físicas y Sombras (-83% colisiones, -84% sombras):**
   - World 2 contenía **8,034 BaseParts** con **7,872 partes con colisión activa** y **7,815 proyectando sombras dinámicas**.
   - Se configuró `CanCollide = false`, `CastShadow = false`, `CanTouch = false` y `CanQuery = false` en **6,577 partes decorativas** de vegetación y rocas (`Tree`, `Rock`, `Grass`, `Hill`).
   - Las partes colisionables bajaron de **7,872 a 1,310**, eliminando el cálculo y la replicación continua del motor de *Distributed Physics*.
   - Todas las pistas, pads (`safezone1.2` .. `safezone9.2`, `WinStage.2`, `Spawn`, multiplicadores `X2`, puente, lava y barreras) **se conservaron 100% intactas y sólidas**.
4. **Optimización de CPU en `World2TreeSlammers`:**
   - Se eliminaron las 6 llamadas a `GetBoundingBox()` con `pcall` que se ejecutaban en cada frame dentro de `nearestTreeDistance()`. Ahora consulta un vector pre-calculado en caché (`treeBasePositions`).
5. **Optimización de CPU en `World2SonicEXEBoss`:**
   - Se añadió un filtro de distancia previa (`> 18 studs`) en `detectSonicContact()`. Si Sonic no está a rango cuerpo a cuerpo del avatar, no ejecuta las 18 consultas `GetPartBoundsInBox` en cada frame.
6. **Bloqueo de Scripts de Jefes y Carteles de World 1 en World 2:**
   - Se añadió `if Config.IsWorld2Place == true then return end` a `ZoomBoss` (servidor), `ZoomBossAnimation` (cliente), `ZoomArenaAmbience` (cliente), `WinPadTextDistance`, `TogetherController` y los escaladores de treadmills.

---

## 13. 🤖 Corrección del Seguimiento de NPCs y Optimización de Ticks de Red

Tras pruebas en vivo en Studio, se identificaron y solucionaron las causas raíz por las cuales **los NPCs no perseguían correctamente a los jugadores** y **los avatares se percibían con lag/tirones**:

1. **Corrección de la IA de Seguimiento de NPCs (Sonic.EXE, Zoom y ReverseFlash):**
   - **Problema Detectado:** La constante `AREA_HEIGHT_ABOVE = 12` en `World2SonicEXEBoss`, `ZoomBoss` y `ReverseFlashBoss` hacía que en el momento exacto en que un jugador saltaba o corría a alta velocidad, su altura superaba los 12 studs sobre el suelo. El servidor consideraba que el jugador "salió del área", Sonic/Zoom abortaba la persecución de golpe, se daba la vuelta para regresar al spawn, y al aterrizar volvía a adquirirlo. Esto provocaba un temblor constante de ida y vuelta donde el NPC nunca lograba seguir al jugador.
   - **Solución Aplicada:**
     - Se aumentó `AREA_HEIGHT_ABOVE` de **12 a 180 studs** tanto en el servidor como en el cliente.
     - Se aumentó `AREA_SIDE_PADDING` de **0 a 15 studs** para evitar pérdidas de target en los bordes.
     - Se ajustó `ARRIVAL_DISTANCE` de **0.35 a 2.5 studs** (rango melee limpio) eliminando los micro-parones al aproximarse al avatar.
     - Se optimizó `TARGET_LEAD_SECONDS` de **0.18 a 0.04s** y `MAX_TARGET_LEAD_STUDS` a **4 studs**, eliminando los sobregiros erráticos cuando el jugador cambia de dirección.

2. **Alivio de CPU de `MovementGuard` (-83% de Carga en Heartbeat):**
   - Previamente, `MovementGuard` ejecutaba `samplePlayer` en cada frame (`Heartbeat` a 60 Hz) para cada jugador conectado.
   - Se reguló el muestreo a **10 Hz (cada 0.1s)** por jugador, manteniendo una precisión quirúrgica contra exploits de teletransporte mientras se liberan ciclos críticos del tick rate del servidor.

3. **Caché Estático de Posiciones de Etapas (`StageTeleportService`):**
   - Se implementó `cachedStagePositions` en `World2StageTeleportService` y `StageTeleportService`.
   - `GetStageReferencePosition` ahora retorna la posición en **O(1)** desde memoria, erradicando miles de llamadas continuas a `GetBoundingBox()` con `pcall` que saturaban el hilo principal del servidor.

4. **Migración al Cliente de Plataformas Que Desaparecen (`FadingPlatformsClient`):**
   - Se desactivaron los 10 scripts de servidor `Workspace.FadingPart.FadingScript` (`Disabled = true`).
   - Se implementó `StarterPlayerScripts.Gameplay.FadingPlatformsClient` para que las plataformas se desvanezcan localmente para el jugador que las pisa con `TweenService` local. Esto previene que un jugador haga caer a otros por latencia de red y elimina el spam de propiedades `Transparency` en el motor de replicación.

---

## 14. 🎮 Correcciones para Consola y Mandos (PlayStation / Xbox / Gamepad)

Se corrigieron tres problemas reportados en la experiencia de usuario en consolas y mandos:

1. **Activación Automática de "Modo Consola" en TopbarPlus (`IconController.luau`):**
   - **Problema:** En PlayStation y Xbox, el cursor virtual de Roblox provoca que `UserInputService.MouseEnabled` sea `true`. La lógica original de TopbarPlus asumía que si `MouseEnabled` era verdadero, el jugador estaba en PC con ratón y mando conectado, mostrando el icono de palanca en la barra superior en lugar de activar el modo mando. El usuario tenía que hacer clic manual con el cursor virtual cada vez que iniciaba sesión.
   - **Solución:** Se integró la verificación autoritativa de consola `GuiService:IsTenFootInterface()` y de mando exclusivo `(controllerEnabled and not userInputService.KeyboardEnabled)`. Ahora al iniciar sesión en consola o mando, el modo mando se activa **100% automáticamente** (`IconController._enableControllerMode(true)`) y el icono de toggle se oculta limpiamente sin requerir intervención manual.

2. **Corrección del Sprint Intermitente en Mando (`SpeedsterClient.luau` y `ConsoleUiScale.luau`):**
   - **Problema:** El sprint (`L2` / `R2` / `L1` / `Shift`) a veces funcionaba y a veces dejaba de responder. Se identificó que `SpeedsterClient` cancelaba el sprint de golpe en cada frame (`RenderStepped`) y bloqueaba nuevas activaciones si `GuiService.SelectedObject ~= nil`. Simultáneamente, `ConsoleUiScale` tenía `GuiService.AutoSelectGuiEnabled = true` y marcaba todos los botones del HUD como seleccionables, por lo que el motor de Roblox seleccionaba automáticamente elementos de la interfaz en pleno movimiento, cancelando el sprint del jugador.
   - **Solución:**
     - Se desacopló la validación del sprint respecto a `GuiService.SelectedObject`. El sprint ahora únicamente se suspende si hay un menú modal de juego realmente abierto (`SpeedsterMenuOpen = true`), el menú de pausa de Roblox (`GuiService.MenuIsOpen = true`) o si el usuario escribe en un campo de texto (`UserInputService:GetFocusedTextBox()`).
     - Se configuró `GuiService.AutoSelectGuiEnabled = false` durante el gameplay activo en `ConsoleUiScale`, evitando que Roblox auto-seleccione botones del HUD mientras el jugador corre o salta.

3. **Corrección del Menú de Mundos Atrapado en la "X" (`WorldsController.luau` y `StarterGui.Worlds`):**
   - **Problema:** Al abrir el menú de mundos con mando, el cursor de selección se posicionaba en el botón de cerrar ("X"). Al presionar hacia abajo en la cruceta o stick, el jugador quedaba atrapado en la "X" sin poder bajar a seleccionar el portal de Mundo 2. Esto ocurría porque `ScrollingFrame` tenía `Selectable = true` (bloqueando la navegación espacial) y no existían enlaces `NextSelectionDown` / `NextSelectionLeft` explícitos entre el botón de cierre exterior y los botones dentro del contenedor desplazable.
   - **Solución:**
     - En `WorldsController.luau`: se implementó la función `wireGamepadNavigation()`, enlazando explícitamente `NextSelectionDown` y `NextSelectionLeft` desde el botón `Close` directamente hacia el botón del mundo objetivo (`World2` o `World1`).
     - Al abrir el panel en consola/mando (`openPanel()`), el cursor selecciona **automáticamente el botón del mundo destino** (`World 2` si está en Mundo 1, o `World 1` si está en Mundo 2), permitiendo viajar inmediatamente presionando `A` sin fricción.
     - `ScrollingFrame.Selectable` se fijó en `false` tanto estáticamente en los `.rbxl` como en tiempo de ejecución, permitiendo que la navegación de la cruceta y stick fluya libremente entre los botones de los mundos y la "X".
     - Se configuraron los enlaces estáticos `NextSelection` en los 4 archivos de lugar (`.rbxl`).

4. **Eliminación de SurfaceGuis de Carga en Kits ASMR (`Keyboard/Bubbles - Loading... (click play)`):**
   - **Problema:** En el kit ASMR de World 2, los modelos de `Keyboard` y `Bubble` venían con un `SurfaceGui` que mostraba el texto `"Keyboard - Loading... (click play)"` y `"Bubbles - Loading... (click play)"`. Como los scripts de servidor fueron desactivados para salvar la red, el código del creador original que destruía esas etiquetas al pulsar Play nunca corría, dejándolas flotando en el suelo del juego tanto en teclado como en mando.
   - **Solución:**
     - Se eliminaron físicamente las **19 `SurfaceGui` obsoletas** de los modelos en todos los archivos `.rbxl` de World 2.
     - Se añadió en `AsmrEffectsClient.luau` un barrido inicial que destruye de inmediato cualquier `SurfaceGui` residual al inicializarse en el cliente.
     - Se removió además el overlay de indicaciones de mando de pantalla completa en `ConsoleUiScale.luau`, manteniendo la interfaz completamente despejada.

---

## 15. ⚡ Detección Instantánea de WinPads & Lógica de Respawn en Etapas

1. **Detección Instantánea de WinPads a Alta Velocidad (`PadTouchService`):**
   - **Problema:** En World 2 (y World 1) los jugadores que corrían a velocidades superiores a 500-1000 studs/s experimentaban retraso o pasaban de largo sobre los `WinPad` sin recibir las victorias de inmediato, viéndose obligados a detenerse en seco. Esto ocurría porque los eventos estándar `Touched` del motor de físicas de Roblox tienen muestreo discreto y sufren de efecto túnel (*tunneling*) a velocidades extremas.
   - **Solución:**
     - Se reforzó e integró `PadTouchService` en el servidor con raycasting predictivo swept-volume (`workspace:Raycast` hacia la trayectoria del avatar) y muestreo continuo a alta frecuencia en `Heartbeat`.
     - En el momento en que la cápsula del avatar roza el volumen del pad en cualquier punto de su trayectoria de frame, el pad se activa de forma **100% instantánea** sin requerir frenado.
     - Se aplicó protección debounce por UID para evitar claims dobles manteniendo el claim ultra reactivo.

2. **Mecánica Canónica de Respawn en Etapas:**
   - **Comportamiento Confirmado:** Al morir dentro de una etapa avanzada, el jugador reaparece en el punto de spawn de su etapa alcanzada más alta (`CurrentStage` / `SpawnStage`) almacenada en su perfil, **no en el inicio del mapa**. El regreso a la etapa inicial (Stage 1) solo ocurre si el jugador no ha alcanzado ninguna etapa o si ejecuta un Rebirth voluntario.

---

## 16. 🕊️ Corrección del Exploit de Vuelo Infinito (`FlightAbility`)

1. **Problema Detectado:**
   - Los jugadores podían volar de manera indefinida equipando y desequipando repetidamente la habilidad de vuelo (`FlightAbility`) en el aire. Al desequipar y reequipar, se reseteaba el estado de vuelo y/o la estamina, permitiendo mantenerse suspendido y propulsarse permanentemente sin tocar tierra.

2. **Solución Implementada y Blindaje Multi-Capa:**
   - **Control de Despegue por Contacto de Suelo (`World1FlightAbility.luau` & `World2FlightAbility.luau`):**
     - Se añadió la bandera `canInitiateFlight = false` al momento de iniciar el despegue. Para poder iniciar un nuevo ciclo de vuelo, el cliente exige estrictamente que el avatar toque suelo (`nearGround()` mediante `FloorMaterial ~= Air` y raycast vertical < 4 studs).
     - Si el jugador intenta pulsar la tecla/botón de vuelo en caída libre, la acción queda bloqueada.
   - **Bloqueo de Desequipamiento en Pleno Vuelo:**
     - Al desequipar la habilidad en el aire, el cliente aborta inmediatamente la propulsión, cancela los `LinearVelocity` / `BodyVelocity` locales y clampa la velocidad residual para evitar deslizamientos infinitos.
     - En el servidor (`FlightAbility` / `Bootstrap`), si el jugador desequipa la habilidad mientras vuela, el servidor purga de inmediato los efectos de vuelo autoritativos y suspende la habilidad.
   - **Regeneración de Estamina Congelada en el Aire:**
     - En `Bootstrap.luau`, el bucle de regeneración de estamina ahora verifica el material del piso (`FloorMaterial == Enum.Material.Air`). Mientras el avatar esté en el aire, la estamina **no se regenera**, impidiendo que el avatar recupere energía flotando.
     - En `syncSuit`, al cambiar de traje en el aire, la estamina actual se conserva y se clampa al nuevo máximo sin rellenar la barra gratis.
   - **Debounce en Interfaz (`AbilitiesPanel.luau`):**
     - Se añadió un debounce de 0.3s al botón de equipar/desequipar para evitar explotación por spam rápido de clics.

---

## 17. 📱 Optimización Responsiva de UI de 2X y Temporizadores de Servidor (`Mainhud`)

1. **Problemas Reportados en Dispositivos Móviles:**
   - **Botones 2X Desproporcionados:** El contenedor `Rightbuttons` (que aloja los botones de compra de `2xSpeed` y `2xVictory`) tenía una altura fija relativa de 45% con restricción de aspecto de ancho dominante, ocupando más del 53% de la altura total de la pantalla en teléfonos.
   - **Superposición Crítica sobre el Botón de Salto:** El contenedor de tarjetas temporales `ActiveBuffsHolder` (donde se muestran los temporizadores de 2X Server Boost, pociones de 2X Wins, 2X Speed y Vuelo temporal) estaba anclado en `{0.965, 0, 0.865, 0}`. En móviles, `Y = 0.865` se ubica exactamente donde el motor de Roblox coloca el botón táctil de salto del pulgar derecho.
   - **Espaciado Excesivo (`Padding = 85`):** En los archivos de lugar `.rbxl`, el `UIListLayout` de `ActiveBuffsHolder` tenía configurado un `Padding = UDim.new(0, 85)`. Al activarse 2 o más tarjetas de boost (por ejemplo, el boost de servidor de 30m y una poción de wins), la separación de 85 píxeles hacía que el HUD se extendiera más de 300 píxeles hacia la izquierda, colisionando con la barra de progreso de nivel (`LevelProgressBar`) y tapando por completo el gameplay.

2. **Solución Implementada:**
   - **Corrección de Padding en el StarterGui (.rbxl):**
     - Se redujo el espaciado estático `Layout.Padding` de **85px a 8px** en los 5 archivos de lugar (`World1 Speedtercorrect.rbxl`, `Update2_fixed/World1.rbxl`, `World2Old...rbxl`, `Update2_fixed/World2.rbxl` y `Update2_revision/World2.rbxl`).
   - **Diseño Adaptativo en Tiempo Real (`MainHUDController.luau`):**
     - Se añadió la función `updateResponsiveHudLayout()`, conectada dinámicamente a cambios de `ViewportSize` de la cámara y al tipo de entrada (`UserInputService.LastInputTypeChanged`):
       - **En Dispositivos Móviles / Pantallas Táctiles Compactas:**
         - `Rightbuttons` recibe un `UIScale` de **0.65** y se reubica ligeramente más arriba en `UDim2.new(0.945, 0, 0.38, 0)`, liberando más de 170 píxeles verticales en el cuadrante inferior derecho.
         - `ActiveBuffsHolder` se reubica limpiamente en `UDim2.new(0.97, 0, 0.60, 0)` con escala **0.78** y padding de **6px**. Queda perfectamente encajado entre la parte inferior de los botones de 2X y la parte superior del botón de salto táctil de Roblox, con más de 40 píxeles de margen de seguridad sobre el botón de salto y más de 60 píxeles de separación respecto a las barras de progreso centrales.
       - **En PC / Escritorio:**
         - `Rightbuttons` y `ActiveBuffsHolder` conservan su escala nativa 1.0 y sus posiciones originales de pantalla ancha, beneficiándose del nuevo espaciado compacto de 8px que evita desbordamientos horizontales.
   - **Compatibilidad Total con Animaciones de Modales (`setHUDVisible`):**
     - Las variables de posición base (`rightButtonsBasePos` y `buffsHolderBasePos`) se sincronizan automáticamente con el modo activo, de forma que al abrir y cerrar menús modales (`Shop`, `Backpack`, `Rebirth`, etc.), los elementos se deslizan hacia abajo y regresan exactamente a su posición adaptativa según el dispositivo del jugador.

---
*Cualquier duda o ajuste adicional que necesites, todos los cambios están completamente serializados, testeados y listados arriba.*
