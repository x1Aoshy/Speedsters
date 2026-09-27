# Auditoría de retención, bugs y rendimiento: "+1 Speed Speedster Escape"

Universo 10447471170. Auditoría de solo lectura realizada entre el 2026-09-23 y el 2026-09-24 sobre `src/` (unos 148k líneas y 400 archivos), los tres places construidos el 2026-09-22 a las 07:51 (`World1Update3New.rbxl`, `World2Update3new.rbxl`, `World3Update3New.rbxl`) y los CSV de Creator Hub en `DataAnalysis/`.

Trabajaron 17 dimensiones: datos, errores en vivo, core loop, persistencia, rendimiento de servidor, rendimiento de cliente, FTUE, movimiento y muertes, monetización, mundos y streaming, ganchos de regreso, seguridad, cosméticos, places/Lune, regresión, salto/travesía, eventos de admin y presupuesto de entrada. Un verificador revisó cada hallazgo contra el código actual. Las rutas son relativas a la raíz del proyecto. Cuando digo "verificado" significa que la afirmación se comprobó en el `src` actual, no en un informe anterior.

> **Aviso importante antes de leer.** Que un build exista no significa que esté publicado. Los places del 09-22 07:51 contienen todos los arreglos del 20 al 22 de septiembre, pero **ninguna métrica exportada cubre ese build**. Además hay archivos de bloqueo de Studio de W2/W3 del 09-22 08:07-08:08. Si Studio guardó o publicó esos places después, pudo sobrescribir el build. Lo primero es confirmar en el historial de versiones de Creator Hub qué versión está en vivo en cada place (sección 9, P0-1).

---

## 1. Resumen ejecutivo

### 1.1 Qué pasó (línea de tiempo)

Horas en UTC. Fuente: dimensiones data-retention y regression. Los ingresos son R$ netos, aparentemente descontada ya la comisión del 30%.

| Fecha | Evento | Métricas |
|---|---|---|
| 08-22 → 09-12 | Juego OG en crecimiento | D1 15-17% (13.5% el sábado 09-12). Sesión 11.4-12.6 min. Unos 3,100 pagadores/día. Conversión ≈1.0-1.3% |
| 08-31 | Empieza a caer D7, antes de Update 2 | D7 pasa de 1.5-2.5% a ≈1%. Terminan los anuncios patrocinados (08-28) |
| **09-12 ~18:30-21:40Z** | **Se publica Update 2**: se reescribe todo el stack de W1, capa de datos modular, UI del diseñador, escalera x2..x32 a 20-320 R$, Flight a 799 R$, Update Logs automático | Reseña a las 21:41Z: *"perfect until this update"* |
| **09-13** | Primer día completo con Update 2 | **D1 6.7%** (domingo; el domingo anterior fue 14.4%). Sesión 11.4→9.0 min. Juego/DAU 16.3→11.8 min. **Pagadores 3,112→1,446**. Conversión 1.01→0.44%. x2/x4/x10 Speed y Flight (producto) venden **0**. El DAU sube (332k), así que el tráfico estaba intacto |
| 09-13 → 09-15 | Bugs visibles | La tienda de trails/auras falla, flight roto, la tarjeta 2X Win vende otro producto (el pase 2x Wins vende 0 del 13 al 15) |
| **09-16** | **Degradación en recomendaciones** | Impresiones 6.15M→2.77M (−55%) con play-through y "not interested" normales. DAU/benchmark pasa de 1.2-1.3 a 0.6-0.8 |
| 09-17/18 | Recuperación parcial | D1 11.3 / 10.6% |
| 09-19 ~17:06Z | Update 3 (W3, ruleta, AFK, skins) y arreglo de lag de W2 | Streaming con integridad Disabled y MinRadius 512 |
| 09-20 | Nuevo máximo de ingresos del domingo | 82.6k R$ |
| **09-21 ~03:55Z** | Publish del 09-20 (tacos, recorte del Daily ×100-400, tutorial nuevo, cosméticos W3 en todos los mundos) | Ingresos 34-35k/día (−35% frente a jueves/viernes). CCU medio 1,551→701. Los ingresos por CCU **suben** (39.8→48.8), así que la tienda funciona y lo que faltan son jugadores |
| 09-22 07:51 local | Build con todos los arreglos de perf, errores y guías | **Publicación no confirmada**. No hay CSV que lo cubra |

Semana contra semana (09-06..12 frente a 09-13..19): D1 14.8→9.1% (−39%), sesión −21%, juego/DAU −28%, pagadores −74%, conversión −67%. D1 cayó **por igual en todas las fuentes de tráfico** (Home 13.1→9.3, Friends 13.4→9.0, Search 14.9→8.4, Other 11.3→8.1). La causa está **dentro del juego**, no en la calidad del tráfico.

La caída de ingresos (118.5k → 62-66k R$/día en dos semanas) se explica en ≈54% por menos DAU (efecto de la degradación en recomendaciones) y en ≈46% por menos ingreso por DAU (efecto de la escalera de precios). Fuente: data-retention.

### 1.2 Por qué no estamos reteniendo: causas principales ordenadas por impacto estimado

| # | Causa | Evidencia (datos + código) | Conf. | Métrica que debe moverse |
|---|---|---|---|---|
| **1** | **El publish de Update 2 (09-13) empeoró toda la primera sesión a la vez**: modal de Update Logs a los 0.25 s de cada entrada, tienda de cosméticos rota, flight roto, UI nueva y la capa de datos modular (escritura DataStore por cada Commit). Es un paquete de cambios, no un solo bug | D1 −39% en todas las fuentes el mismo día que el publish, con tráfico estable. Sesión −21%. `audit/current/World1/.../UpdateLogsController.luau:290-294` (auto-open), `audit/incoming_20260913/World1/842.luau:108/115` (setTrailOwned antes de declararse). Los bugs visibles ya están arreglados en `src`, pero **no se sabe qué está publicado** | 0.75 (hecho) / 0.4 (qué mecanismo pesa más) | D1 por cohorte del mismo día de la semana, sesión media, supervivencia a 60/120 s |
| **2** | **El primer minuto es lento y contradictorio.** Se camina a 8 studs/s (la mitad del default de Roblox). La guía de rebirth aparece a los ~20 s y **reinicia la velocidad** justo antes del primer obby. Los huecos 1 y 5 de Stage 1 (5.94 y 6.05 studs) superan el salto a pie a Speed 1 (≈5.3). El wall-bounce impide subir a bloques. En teléfono, el dial de velocidad está a 8 px del botón de salto y un toque baja la velocidad al 20% de forma persistente | 15% se va antes de 90 s, 11% nunca pisa una cinta (funnel v2). Reseñas sobre saltos ("can't jump to a brick", "made me slow"). `Config.luau:668` (`RealWalkSpeedMin = 8`), `RebirthController.client.luau:651-652,679-681`, `InstantMovementController.client.luau:975-1026`, `HudErgonomics.luau:56,277`, `WalkSpeedSelector.client.luau:57-62` | 0.65 | Supervivencia a 60/90/120 s, FirstTreadmillRun v2 (objetivo ≥95%), Progress_FirstLap_v2 |
| **3** | **Se eliminó la primera compra barata** (x2 a 3 R$, ≈1,966 compradores/día, ≈63% de los pagadores) y el peldaño repetible x10 | Los pagadores caen 3,112→1,446 de un día para otro. El cubo "Other" no absorbió la pérdida. `Config.luau:966-975` (20/40/80/160/320, máximo x32), `SpeedProductPurchases.server.luau:139-149` (IDs OG solo para recibos pendientes), `MainHUDController.client.luau:1297-1320` (el botón se oculta a partir de x32) | 0.85 | Pagadores/día, conversión, ARPDAU. De forma indirecta, D7 de pagadores |
| **4** | **Muertes injustas con castigo total.** El cliente decide la muerte con cajas AABB (los láseres de W1 matan en un cuadrado de ≈96×96 studs). El respaldo del servidor no rebobina el lag (solo lo hace para martillos). Cualquier muerte que predice el cliente se confirma a los 2.5 s sin validación. Cada muerte devuelve al lobby/Stage 1 y el revive se aplica en el 0.03-0.06% de las ofertas | Queja n.º 1 en reseñas negativas (hitbox, "sin tocar"). `NewWorld1MapMotion.client.luau:504-522`, `NewWorld1ServerMotion.server.luau:1961-1991`, `R15SpeedsterRun.client.luau:1043-1054` + `AdminPanelService.server.luau:937-944`, `SpeedProductPurchases.server.luau:2117-2135` | 0.6 | Muertes por etapa y hazard (telemetría pendiente), finalización de W1, reseñas |
| **5** | **Tartamudeo del servidor por DataStore** (introducido el 09-13 con la capa modular). QuestService escribe el perfil completo de cada jugador cada 10 s. El lock del SessionActor se mantiene durante UpdateAsync y los bucles de carrera y de cinta esperan en línea, así que una escritura congela la ganancia de Speed de todo el servidor. Un fallo de escritura pone la sesión en `Recovering` y descarta la ganancia | Sonda: AccrueSpeed esperó 0.315 s detrás de una escritura de 0.3 s. Presupuesto ≈100% a 60 jugadores (estimado). El snapshot OG del 09-12 solo guardaba cada 30 s desde memoria. `QuestService.server.luau:351-365`, `SessionActor.luau:761-787,616,637-642`, `Bootstrap.server.luau:593-615` | 0.55 (mecanismo 0.8, magnitud sin medir) | Warnings de cola DataStore en logs del servidor, "Could not open the session", fluidez de la ganancia |
| **6** | **Ganchos de regreso débiles** (explica D7 ≈1% y parte de D1). El Daily es rolling de 24 h y se abre bloqueado en cada entrada. El Daily se recortó ×400 el 09-21 (día 2: 1e6 → 2,500 Speed). AFK pierde lo ganado al salir o en el rejoin cada 16 min. Las quests se resetean a las 00 UTC (prime time de América). No hay favorito, notificaciones ni invitaciones. Update Logs aparece el día 2. Quien llegó a W2/W3 siempre vuelve a entrar en W1 | D7/D1 ≈6%. World2 desbloqueado 2-3%. `DailyLoginSystem.server.luau:109-123`, `DailyRewardsData.luau:21-54`, `AfkZoneService.server.luau:253-262,458-460`, `QuestCatalog.luau:216-218`, grep sin `PromptSetFavorite`/`PromptOptIn` | 0.65 | D1 y D7 por cohorte, retorno el día siguiente con Daily reclamable |
| **7** | **Teléfonos limitados por render a 23.5 FPS** (≈2/3 del CCU): 7.1k texturas superpuestas en W1, auras de otros jugadores casi sin LOD en el lobby, y trabajo inútil al entrar (SpawnFloorSurfaceFix, World1ClientMotionHazards, arcoíris del Admin replicado por servidor) | FPS en teléfono 26.3→23.5 mientras la CPU del cliente bajaba 13.6→11.0 ms. `perf_place_edits.luau:73-100` solo quitó las caras Bottom. `SpawnFloorSurfaceFix.client.luau:117,215-232`, `AAA_NewWorld1PadCleanup.server.luau:127-167` | 0.5 | FPS en teléfono, OOM por CCU, supervivencia a 90 s |
| **8** | **Degradación en el algoritmo de recomendación (consecuencia, no causa)**. Llegó 3 días después de la caída de engagement | Impresiones −55% el 09-16 con play-through intacto. Solo se arregla recuperando D1 y el tiempo de juego | 0.7 | Impresiones diarias, DAU/benchmark |

**Qué no explica el 09-13:** los errores en vivo (el único nuevo del 09-13 es ASMR, solo en W2), la física del salto (idéntica a la OG y mejorada el 09-18), la geometría de Stage 1 (idéntica desde la OG) y el streaming (cambió el 09-19). Las causas 2, 4, 6 y 7 son en su mayoría **anteriores** al 09-13: explican la pérdida de base (15% en 90 s, D7 1%), no el salto del 13.

**La caída del 09-21 no está resuelta.** Los ingresos por CCU subieron y la sesión se alargó, lo que apunta a menos tráfico, no a una tienda rota. Pero no hay impresiones ni D1 después del 09-20, y las ventanas comparadas son viernes/sábado frente a lunes. Hay que exportar esos datos antes de atribuirla a un build.

### 1.3 Resumen de hallazgos

- **175 hallazgos verificados**: 2 críticos (ambos son datos: la ruptura de retención y la de monetización del 09-13), 27 altos, 102 medios y 44 bajos. Tras fusionar duplicados entre dimensiones quedan **≈105 entradas únicas** (sección 5).
- **115 sin verificar** (casi todos bajos, sección 10).
- **Tests Lune: 45/45 en verde** (45.2 s). 4 tests adicionales de solo lectura: 2 pasan y 2 fallan por tests obsoletos o demasiado estrictos, no por el producto.
- **Places sincronizados con `src`**: los 944 scripts coinciden byte a byte.

---

## 2. Core loop y pacing

**Bucle:** cinta/correr → Speed → Level (curva exponencial) → Rebirth (Level 5+15R, ×1.5, Speed vuelve a 1). En paralelo: pads del obby → Wins → auras y trails. Los pads pagan una cantidad fija por etapa y no escalan con Speed.

**Fórmula de ganancia por tick de 0.5 s** (`PlayerStatsBridge.luau:103-116`): base × permanente × global × trail × aura × upgrade × gamepass × traje × 1.5^R × vip × poción × server boost × disco. Caminar paga 1 por tick en W1 y 0.25 en W2/W3 (`Config.luau:800`). El traje Flash por defecto da ×5.

**Velocidad al caminar** (`Config.luau:668-673`, `StatsService.luau:167-184`): `8 + 292·(log10(Speed)/15.53)²`. Speed 1 → 8 studs/s, 371 → 16, 1e5 → 38, 1e9 → 106. W2 se multiplica por 0.5 y W3 por 0.25, con un mínimo de 8 (decisión del dueño).

### 2.1 Minutos de cinta hasta cada hito

Modelo de la dimensión core-loop (`pacing_model.py` en scratch). Supone la mejor cinta gratis, evolucionar y hacer rebirth en cuanto se puede, y no cuenta tiempo de obby. No lo reproducí.

| Hito | Sin cosméticos | Par naranja ×6.25 (20 Wins) | Rojo ×25 (200 W) | Morado ×100 (2k W) | Negro+Secret ×1e6 (20M W) |
|---|---|---|---|---|---|
| R1 (L5) | 0.1 min | 1.4 s | 0.3 s | – | 0 |
| R4 (L50) | 5.4 min | 0.9 min | 9 s | 2 s | 0 |
| **Puerta W2 (R6 + L50)** | **38 min** | **6.1 min** | **1.5 min** | 0.4 min | 0 |
| R7 | 2.8 h | 27 min | 6.8 min | 1.7 min | 0 |
| R8 | 13.5 h | 2.2 h | 32 min | 8 min | 0 |
| R10 | 11.6 días | 44.6 h | 11.2 h | 2.8 h | 1 s |
| **Puerta W3 (R15 + L200)** | – | – | – | – | **103 min** |
| R16 | – | – | – | – | 8.95 h |

La puerta anterior (7 rebirths + L100, vigente hasta el 09-22) costaba ≈5.3 h sin cosméticos. **El 2.8% de "World2 desbloqueado" se midió con esa puerta**, así que aún no refleja la nueva (6 + L50).

### 2.2 Muros de grind y desequilibrios

1. **Los cosméticos lo deciden todo** (`CosmeticCatalog.luau:8-57,141-190`). Aura y trail cuestan 10/100/1k/…/10M Wins y dan ×2.5 hasta ×1000 cada uno. El par va de ×6.25 a ×1e6. El rebirth solo da ×1.5 y la escalera de Robux x2 (20 R$) vale menos que un aura de 10 Wins. El juego tiene dos modos: quien no compra cosméticos tarda 38 min en llegar a W2 y quien los compra lo hace en minutos. El juego enseña esto una sola vez, en la guía de la primera aura.
2. **Muro después de W2**: cada ciclo de rebirth crece ×5.3 (L30-100) a ×6.7 (L>100), porque el nivel cuesta ×7.9-×10.1 por cada 15 niveles y el rebirth solo aporta ×1.5. Los cosméticos de W3 añaden únicamente ×1.2-×3.
3. **Viajes de etapa en W1 más baratos que el pad siguiente** (`Config.luau:1169-1180`): el viaje a Stage 10 cuesta 150k y Win11 paga 350k (el pad final, 700k). A partir de ≈150k Wins, el bucle óptimo es comprar el viaje y correr 1-2 etapas, y las etapas 1-9 dejan de importar. W2 ya lo corrigió en su Stage 10 (×1.5 sobre el final).
4. **Ruleta**: los premios de Wins se calculan sobre una vuelta completa (170K/690K en W1). El giro gratis de la primera sesión compra un set completo de cosméticos (verificado: el 25% compra un set y el 14% compra los dos).
5. **Llegada a W2**: con 6 rebirths solo está la Golden ×10, igual que la Diamond de W1. Correr paga ×0.25 y Candy/Diamond piden 9 y 11 rebirths. Además, la Golden de W2 **hereda el lock de 1 rebirth de W1** (`TreadmillTraining.server.luau:35-66`). Solo afecta a quien entra con 0 rebirths, pero encaja con la reseña "I can't train in World 2".

### 2.3 Recompensas en los primeros 10 minutos (modelo más distancias)

Las recompensas llegan rápido: un nivel cada 2-3 s, un pad por minuto y un rebirth cada 1-2 min con el par naranja. **Los puntos débiles son las carreras del obby a 8-19 studs/s y el tramo hasta el primer pad** (Win1 está a 470 studs del spawn; al menos 59 s a 8 studs/s).

---

## 3. Primeros 5 minutos (FTUE) y regreso del día 2

### 3.1 Minuto a minuto: jugador nuevo en teléfono, W1

Fuente: onboarding-ftue más sondas. Tiempos estimados.

| t | Qué pasa | Problema |
|---|---|---|
| Carga | Pantalla negra: espera `IsLoaded` y el HRP, más un final fijo de ~1.24 s (`LoadingScreen.client.luau:267-331`) | No espera a la UI. Al soltar al jugador llega la ráfaga de UI y scripts (sección 4.3) |
| 0 s | Spawn, 8 studs/s. Haz "TRAIN HERE!" hacia la Basic, a **211 studs**, pasando junto a 6 cintas bloqueadas | ~20-26 s de caminata. Las cintas bloqueadas expulsan y abren un prompt de Robux o el panel de Rebirth |
| 0.4-8.4 s | Banners de LEVEL UP 2-5 (el nivel 5 llega con ≈85 Speed) | – |
| ~17-20 s | Toca la Basic y el Step 1 se completa **al primer contacto** | La Basic ×1 paga lo mismo que caminar (`Config.luau:579-585` frente a `:800`). El paso no enseña nada |
| ~20-23 s | **Guía de rebirth**: oscurece el 58% de la pantalla mientras la flecha del Step 2 pide cruzar Stage 1 | Dos instrucciones opuestas a la vez (`RebirthController.client.luau:651-652`) |
| ~25-30 s | Si hace rebirth, Speed vuelve a 1 y camina a 8 | Los huecos 1 y 5 de Stage 1 no se pueden cruzar a pie a 8 studs/s sin Sprint (§5, M50) |
| 30-120 s | Stage 1. Cada muerte devuelve al lobby (470 studs atrás) con una tarjeta de Revive de 15 s | Reverse Flash persigue el primer segmento a 26.5 studs/s (`ReverseFlashBoss.server.luau:815-817`) |
| ~122 s | Si no llegó a Win1, **el Step 2 caduca en silencio** a los 102 s | Sin objetivo en pantalla (`FirstTimeTutorial.server.luau:27,99-102`) |
| ≥124 s | El Daily se abre solo, esté donde esté, con un dim que bloquea toques y oculta el HUD y Sprint | En pleno Stage 1 (`UpdateLogsController.client.luau:361-375`) |
| Win1 | +10 Wins, vuelta al spawn, guía de aura (Naranja ×2.5), Evolve, Daily | El mejor momento llega tarde |
| 3:00 / 6:00 | Time Gift 1 (1,000 Speed) y 2 (70 Wins) | **Sin aviso**: el "!" del botón sigue al Daily, no a los regalos (`MainHUDController.client.luau:1164-1169`) |
| 17:00 | La oferta Starter Pack desaparece | El contador se reinicia en cada servidor |

Supervivencia en la primera sesión (agregado 08-24..09-20): 95.3% a 30 s, 89.9% a 60 s, 84.8% a 90 s, 80.7% a 120 s, 66.5% a 5 min y 48.9% a 10 min. Se pierden 4.7-5.3 puntos cada 30 s en los primeros 2 min.

**Lo que está bien** (verificado): Update Logs ya no se abre para jugadores nuevos, el tutorial está apagado en W2/W3, cada guía tiene Skip y ambos pasos terminan solos, el flag "seen" se guarda con reintentos y el texto del tutorial está en 10 idiomas.

**Pérdida permanente**: quien hace rebirth antes de reclamar Win1 y se va queda marcado como "tutorial visto". A partir de la siguiente sesión no vuelve a recibir ni la flecha ni la guía de aura, la mayor mejora temprana (`FirstTimeTutorial.server.luau:343-349`, `TutorialFlow.luau:10-17`).

### 3.2 Regreso del día 2

| Qué ve al volver | Problema | Código |
|---|---|---|
| Update Logs (siempre el día 2 para jugadores nuevos, porque nunca lo cerraron) | Se compara con `PlaceVersion`, que sube en cada publish (también en hotfixes) y se guarda como un solo número para los 3 places. El texto "UPDATE 3" es estático y en inglés | `UpdateLogsController.client.luau:20-44,377-379`; `Bootstrap.server.luau:313` |
| Daily **abierto por la fuerza en cada entrada, teleport de mundo y rejoin de AFK**, aunque no haya nada que reclamar | Cooldown rolling de 24 h: ≈50% de quienes vuelven al día siguiente lo encuentran bloqueado (estimado con la curva horaria de CCU) | `DailyLoginSystem.server.luau:109-120`; `UpdateLogsController.client.luau:377-382` |
| Recompensa del día 2 = **2,500 Speed** (antes 1e6) | Recorte del 09-21 en los días 1-14 (×100 a ×10,000). Los días 15-30 no se tocaron (salto ×25,000 el día 16) | `DailyRewardsData.luau:21-54` |
| Offline earnings (≥10 min) con una oferta "Get x5" de 19 R$ | Hasta 3 modales antes de poder moverse | – |
| Quest del día | Reset a las 00 UTC (20-21 h en EE. UU. Este y Brasil). Las quests completadas y no reclamadas se pierden (16-18% de quienes completan) | `QuestCatalog.luau:216-218`; `ProfileReducers.luau:606-612` |
| AFK nocturno | Paga como máximo los últimos 16 min: lo ganado vive en memoria y se pierde en el rejoin anti-idle | `AfkZoneService.server.luau:253-262,458-460`; `AfkZoneController.client.luau:146-157` |
| Jugador de W2/W3 | Siempre vuelve a entrar en W1, sin "Continuar en World N" | `WorldPortalService.server.luau:672-677` (TeleportData que nadie lee) |
| Promesas externas | **Ninguna**: sin `PromptSetFavorite`, sin `ExperienceNotificationService`, sin `PromptGameInvite` | grep en `src` sin resultados |

**Corrección a un dato conocido:** el "quest claimed 2.3%" es un artefacto del funnel v1, que abría una sesión nueva en cada apertura del panel. El funnel v2 del mismo día (09-21) da **13.2% de quienes abren** (≈20-24% de quienes eligen una quest). Tampoco el AFK v2 de 1.3% es real: era un bug de id de sesión, ya corregido en `src` (`AfkRewardsService:157-163`).

---

## 4. Lag y rendimiento

### 4.1 Servidor: puntos calientes a 60 jugadores

Estimaciones de orden de magnitud de server-perf. No se midieron en Roblox.

| # | Punto caliente | Frecuencia | Costo estimado | Código |
|---|---|---|---|---|
| 1 | **UpdateAsync del perfil completo en cada Commit + flush de QuestService cada 10 s para todos** | ≈11 escrituras/s, en ráfagas de 60 | Presupuesto de escritura ≈100% (60 + 10N/min). ≈55 KB por escritura | `QuestService.server.luau:170-198,351-365`; `SessionActor.luau:616,662-714` |
| 2 | **El lock se mantiene durante UpdateAsync y los bucles de carrera y cinta esperan en línea** | Cada 10 s y cada 30 s | Congelaciones de 0.1 s a varios segundos para todos | `SessionActor.luau:761-787`; `Bootstrap.server.luau:593-615`; `TreadmillTraining.server.luau:519-537,1139-1177` |
| 3 | Deep copies del perfil (ledger de 512 operaciones: 153 µs por copia frente a 5 µs) | ≈150-200/s | 25-30 ms/s y ≈100k tablas/s | `SessionActor.luau:249,694-711`; `ProfileCodec.luau:720-744` |
| 4 | 2 UpdateAsync no-op en **cada respawn** (applySavedSkin vuelve a otorgar skins ya poseídas) | 2 × muertes | N=60 con una muerte cada 20 s ≈ 55% del presupuesto | `SkinSystem.server.luau:2120-2153` |
| 5 | Heartbeats por jugador y por frame: stamina, PadTouchService, MovementGuard sin caché en W1/W2, jefes | ≈22k iteraciones/s en W1 | 80-150 ms/s | `PadTouchService.luau:135-201`; `MovementGuard.luau:85-124` |
| 6 | Tween arcoíris del Admin de W1 **en el servidor, para siempre** (30 partes) | 60 tweens/s | Pequeño en CPU. 15-35 KB/s por cliente en el lobby | `AAA_NewWorld1PadCleanup.server.luau:127-167` |
| 7 | Replicación de stats: 3 copias de Speed y el NumberValue LevelProgress sin throttle | ≈7.5 cambios/s por corredor × 59 | 6-9 KB/s por cliente | `StatsProjection.luau:111-142,283,306`; `LevelProgress.server.luau:183` |
| 8 | Muestreador de cintas 10 Hz zona × jugador | 4.2k/s | 10-25 ms/s | `TreadmillTraining.server.luau:870-1017` |
| 9 | AnimationReplicationSync: 2 republicaciones por entrada | ≈6.8k eventos de animación por entrada | Ráfagas | `AnimationReplicationSync.server.luau:49-59` |
| 10 | Pushes de Quest (2 s) y Daily (5 s) aunque el panel esté cerrado | 42 mensajes/s | ≈1.25 KB/s por cliente | `QuestService.server.luau:137-167`; `DailyLoginSystem.server.luau:454-463` |
| 11 | Admin/Taco treadmill: **hoy NO escribe** (bug M3), pero el arreglo obvio añadiría 120 UpdateAsync/min por jugador en la cinta | – | Riesgo latente | `TreadmillTraining.server.luau:1019-1049` |

**Corrección de esta síntesis** (comprobado en el código): `isAdminTreadmill` lee `zone.Treadmill:GetAttribute("AdminSpawned")` (`TreadmillTraining.server.luau:1024`). `zone.Treadmill` es el cinturón anidado `Treadmil` (`resolvePhysicalTreadmill`, :106-114), pero `AdminSpawned` solo se pone en el clon (`AdminAbusePanelService.server.luau:1588`). Por eso las 120 escrituras/min por jugador que describían security#1 y persistence#10 **no ocurren hoy**: la cinta de evento no paga los Wins anunciados. Queda como riesgo latente (medio) y el arreglo tiene que acumular en memoria.

**Presupuesto sin confirmar**: el top 25 de errores (mínimo 1,571/día) no muestra warnings de cola DataStore. Las escrituras de leaderboard van a OrderedDataStore, que tiene presupuesto propio, y AutoReconnect está muerto (línea 1). Hacen falta logs del servidor para pasar a "crítico".

### 4.2 Cliente y teléfonos

**Diagnóstico**: la CPU del cliente (media de todos los dispositivos, sin categoría de render) bajó 13.6→11.0 ms mientras el FPS del teléfono bajaba 26.3→23.5 (≈42 ms por frame). El teléfono está limitado **por render/GPU o por trabajo exclusivo del teléfono**, no por el promedio de scripts. Salvedad: las ventanas son viernes/sábado frente a lunes y el CCU se redujo a la mitad. Hace falta un MicroProfiler en un Android medio.

**Render (lo que controla el contenido):**

| Elemento | Datos | Código/place |
|---|---|---|
| Texturas superpuestas | W1: 7,624 Texture (7,581 con transparencia 0.9; 1,036 partes con 5 y 405 con 6). W3: 17,052 | El pase del 09-22 solo quitó las caras Bottom (`audit/perf_place_edits.luau:73-100`) |
| Mallas Precise | W1 132/195, W3 317/484 | Place |
| Auras de otros en el lobby | El LOD de teléfono da detalle completo a todos a <40 studs. Los Highlights **se fuerzan a encendido** en el servidor. No hay opción para ocultar los efectos de otros | `AuraSpecialEffectsClient.client.luau:219-227`; `CosmeticService.luau:218-225` |
| Peor caso con 59 jugadores | Todos con Aquatic: ≈64k partículas y 4,720 Beams. Todos con Galactic: 9,440 Beams. Todos con Shidou: 118 Highlights (el motor dibuja 31) | Sonda de `ServerStorage.AuthoredAuras` |
| Por aura | Lightning V2: 125 emisores. Aquatic: 645 instancias, reclonadas en cada respawn | `CosmeticService.luau:199-236` |
| Streaming | Target 1024 / Min 512, LowMemory. Los teléfonos usan ≈21% de memoria, así que casi nunca se descarga nada | Places |

**Bucles por frame** (≈41 en W1, ≈37 en W2, ≈36 en W3, más 2 por cada portador de aura Cursed). Los más caros:

| Script:línea | Trabajo | Costo en teléfono (est.) |
|---|---|---|
| `World1FlightAbility.client.luau:62-85,973,1028` (las 3 copias son idénticas) | Volando: 2 × (GetDescendants + GetPartsInPart por cada parte del personaje, auras incluidas) | 1-3 ms volando |
| `WinPadTextDistance.client.luau:31,214` | Por debajo de 30 FPS recalcula el texto de **todos** los pads en cada frame (9 GetAttribute con pcall + gsub). Busca WINHERE/X2HERE, que no existen | 0.2-0.4 ms |
| `InstantMovementController.client.luau:1111` | 8-24 raycasts | 0.1-0.3 ms |
| `WallImpactAntiFling.client.luau:526,594` | Blockcast + hasta 21 rayos | 0.1-0.3 ms |
| `AuraSpecialEffectsClient.client.luau:323` | 60 jugadores × 5 llamadas | 0.1-0.2 ms |
| `AdminAbuseEffects.client.luau:3335-3368` | 6 actualizadores inactivos más TacoImpactShake sobre 60 jugadores | 40-80 µs |
| `RemoteAnimatorFidelity.client.luau:22-62` | Desactiva throttling y LOD de animación para los 60 personajes | ≈0.77 ms de CPU de animación en total (bajo) |

**Memoria**: ≈0.90 GB en teléfono (21%). OOM 153→111/día en total, pero por CCU de teléfono subió +59% (0.125→0.199). Ambos datos son ciertos; las ventanas no son comparables y los conteos son pequeños (la serie de Computer vale exactamente 1 por bucket, lo que parece un artefacto). Fugas: pequeñas (OverheadStats, 2 conexiones por cada respawn remoto).

### 4.3 Presupuesto de los primeros 90 s en teléfono (W1)

| Costo | Estimación | Acción |
|---|---|---|
| Copia de StarterGui: **5,738 instancias, 26 ScreenGuis** y ≈45 controladores que arrancan juntos al spawnear. ModalJuice (≈158k nodos visitados), ConsoleUiScale (1,761 listeners, también en teléfono), tarjetas del Backpack | Decenas de ms repartidos en 1-3 s | Clonar los paneles (Shop, Daily, Backpack, SpinWheel, TimeGift, StageTeleport ≈ 4,000 instancias) al abrirlos por primera vez |
| **SpawnFloorSurfaceFix** busca `Spawn1Outline`, que **no existe en ninguno de los 3 places**: 20 búsquedas recursivas/s durante 15 s y luego una por cada lote de streaming, toda la sesión, en los 3 mundos | ~3-10% de un núcleo en los primeros 20 s | Retirar (stub) |
| **World1ClientMotionHazards** (legado): 13 hilos × 10 búsquedas recursivas/s durante 20-30 s (≈2,900). Busca `ClientMotionType`, que nadie asigna | Idem | Retirar (stub) |
| Descargas: música, 2 pistas de ZoomArena y 2 de BossArea (no 4 ZoomArena como decía un informe anterior), malla del taco | Varios MB compitiendo con el streaming. ≈9.5k sesiones/día no las cargan en 10 s | Cargar por proximidad o evento |
| 10 handlers `Workspace.DescendantAdded` permanentes + ~8 escaneos completos al entrar + rescaneos del tutorial | Por instancia replicada | CollectionService |

**No hay esperas infinitas en W1** (verificado por sonda). Los warnings de infinite yield (24.7k/día) vienen de WaitForChild sin timeout en hilos propios; son ruido.

### 4.4 Eventos de admin (lo que vive el jugador normal)

- **La revelación del taco** toma la cámara de **todos los jugadores del servidor** durante ≈6.5 s y oculta **toda** ScreenGui, incluido el TouchGui (joystick y salto). El movimiento sigue a `CurrentCamera`, así que el corredor avanza en la dirección de la cámara cinemática, sin protección frente a hazards. La versión arcoíris hace lo mismo 4.3 s con quien esté a más de 90 studs (`AdminTreadmillReveal.client.luau:834-846,910-942`; `InterfaceHider.luau:23-28`; `InstantMovementController.client.luau:518-538`).
- No hay ninguna exención: ni tutorial, ni pantalla de carga, ni muerto. Con scope All llega **a todos los servidores de los 3 mundos**, y el único límite es un rate limit de 0.3 s. `/tacotreadmill` no tiene ninguno.
- Los trolls con "Everyone + All" (FakeReset "DATA ERROR!", Rocket 170 studs/s, Jumpscare) también llegan a jugadores nuevos.
- Raining Tacos: ≈45 instancias por impacto, ≈4.5 impactos/s en teléfono, cámara temblando en todo el recorrido.
- La cinta de evento (×315) supera a la Hacker (×300), el artículo que más factura. Es decisión de diseño; se menciona solo por su costo.

---

## 5. Bugs confirmados (fusionados)

Veredicto: **C** = confirmado, **P** = parcial (el mecanismo es real pero el impacto está sobrestimado o incompleto), **V** = encontrado por el verificador. Esfuerzo: S (horas), M (1-3 días), L (más). "Dims" = dimensiones que lo reportaron.

### 5.1 Altos

| ID | Título | Archivo:línea | Impacto en el jugador | Arreglo | Esf. | Ver. |
|---|---|---|---|---|---|---|
| H1 | **El pase de Rebirth da +1 Rebirth en cada entrada** (el flag es un atributo que no se guarda) | `src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau:2239-2258,2480,2689-2692`; `PlayerStatsBridge.luau:363-374` | Los dueños del pase 1979150655 acumulan rebirths infinitos (×1.5 cada uno) al reentrar o cambiar de mundo. Salta las puertas de W2/W3 e infla los leaderboards | Guardar el grant en el perfil (GrantUpgrade `RebirthPassGranted` con operationId fijo) en el mismo Commit y comprobar el perfil. Auditar a los dueños actuales | S | C (4 dims; comprobado por mí: el atributo solo aparece en ese archivo) |
| H2 | **QuestService hace Commit (UpdateAsync del perfil completo) de cada jugador cada 10 s**, sin condición y todos en el mismo frame | `src/common/ServerScriptService/Social/QuestService.server.luau:170-198,351-365` | Ráfagas de escritura. Presupuesto ≈100% a 60 jugadores (estimado). Carga de perfil más lenta al entrar. Claim de quest falla con "Saving progress" durante el flush (`:173-175,272-275`) | Acumular playtime/stages en memoria y persistir con el autosave. Flush solo en Choose, Claim o salida | S-M | P (4 dims; magnitud sin medir) |
| H3 | **El lock del SessionActor se mantiene durante UpdateAsync y los bucles de Speed esperan en línea**. En `Recovering` se descarta la ganancia y `DataLoaded` pasa a false | `SessionActor.luau:761-787,616,532-537,637-642`; `Bootstrap.server.luau:593-615`; `TreadmillTraining.server.luau:519-537,1139-1177`; `StatsProjection.luau:310` | La ganancia de Speed y los popups se congelan para todo el servidor cada 10 s y 30 s. Tras un fallo de DataStore la cinta no paga hasta 10-30 s y los portales, códigos y el Daily se bloquean | AccrueSpeed sin lock (en memoria). Snapshot bajo lock y escritura fuera. `task.spawn` por jugador en los bucles. Aceptar mutaciones en Recovering | M | C (5 dims) |
| H4 | **Los láseres giratorios de W1 se evalúan con `GetPartBoundsInBox` (caja alineada al mundo)**: una barra de 132 studs en diagonal mata en ≈96×96 studs | `src/worlds/World1/StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1MapMotion.client.luau:40,504-523`; servidor sin validación `NewWorld1MapSystems.server.luau:58-84` | A 30 studs del centro, la parte letal de cada giro pasa de ≈8% a ≈74%. Muertes con el haz lejos. Afecta a todos en Stage 5-6 | Test exacto (`GetPartsInPart(laser)` u OBB como en W3) para todas las claves, no solo Hammer/Cylinder | S | C (conf. 0.5-0.6: confirmar en Studio que la consulta usa AABB) |
| H5 | **El respaldo del servidor en W1 no rebobina el lag** salvo para martillos: prensas, ola Fast, láseres y LavaUp matan a quien ya pasó | `src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ServerMotion.server.luau:1874-1896,1961-1991` | 10-75 studs de alcance extra (v × 0.1-0.25 s). Los teléfonos tienen más ping | Aplicar la regla de martillo (`getHammerRewindSeconds`) a todos los grupos | S | C |
| H6 | **Cualquier muerte que predice el cliente se hace real a los 2.5 s**: `PlayerResetRequest` mata sin validar, así que los rechazos del servidor no sirven | `src/common/StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau:1043-1054,1113-1141`; `AdminPanelService.server.luau:937-944`; `R6DeathRagdoll.server.luau:595-603` | Los falsos positivos del cliente (H4, zonas seguras ignoradas, predicción por nombre "kill/laser/lava") siempre matan | Evento separado "muerte local no confirmada": el servidor revalida o revive. Añadir `SafeZoneProtected` al guard | M | C |
| H7 | **La guía de rebirth salta a los ~20 s, durante el Step 2**: oscurece la pantalla y, si se sigue, deja al jugador a 8 studs/s antes del primer obby | `src/common/StarterPlayer/StarterPlayerScripts/UI/RebirthController.client.luau:638-687`; `Config.luau:668,924`; `TutorialGuide:363-367` | Casi todos los nuevos reciben dos órdenes opuestas. Stage 1 a velocidad mínima | Retener la guía hasta el primer claim de Win pad. Sin dim mientras `FirstTimeTutorialActive`. Valorar `RealWalkSpeedMin` 16 o un mínimo por rebirth | S | C |
| H8 | **El "!" de Time Gifts sigue al Daily**, así que los regalos de 3:00 y 6:00 nunca se anuncian | `src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau:1151-1173` | Regalo 1 = 4× el Daily 1. Regalo 2 = 7 claims de Stage 1. Invisibles en los minutos 3-10 | Badge desde `PlaytimeRewardsUpdate` y temporizador local con toast | S | C |
| H9 | **Lo ganado en AFK vive solo en memoria**: se pierde al salir y en cada rejoin anti-idle de 16 min | `src/common/ServerScriptService/Social/AfkZoneService.server.luau:185-209,247-264,458-460`; `AfkZoneController.client.luau:146-169` | "AFK toda la noche" paga como máximo 16 min. `flush()` es código muerto | Commit por lotes cada 2-5 min. Claim en PlayerRemoving. El cliente reclama antes del Teleport | S | C |
| H10 | **MovementGuard neutralizado**: los 3 mundos llaman `Rebase` justo antes de `CanClaim`, W2 SafeZones rebasa 12.5 veces/s y el atajo de "etapa más cercana" acredita cualquier etapa | `NewWorld1ManualStagePads.server.luau:521-526`; `World2ManualStagePads.server.luau:459-462`; `World3ManualStagePads.server.luau:377-380`; `World2SafeZones.server.luau:230-239`; `MovementGuard.luau:157-163,194-216,254-259` | Un teleport de exploit sobre el pad final paga 700k/1M/10M × multiplicadores cada ~2 s. Hay exploiters activos (≈38k errores de executor/día desde 09-21) | Quitar Rebase de los pads (solo tras teleports sancionados). API monotónica para las zonas seguras. Quitar el atajo. **Antes, contar los rechazos legítimos** | S | C |
| H11 | **Cada respawn hace 2 UpdateAsync no-op** (vuelve a dar skins ya poseídas) antes de aplicar el traje | `src/common/ServerScriptService/Economy/SkinSystem.server.luau:2120-2153,511-534` | El avatar por defecto se ve 0.2-1 s tras cada muerte. Hasta ≈55% del presupuesto de DataStore | `if not ownsSkin` antes de `unlockSkin`. Commit sin escritura si todos los comandos son no-op | S | C |
| H12 | **Arcoíris del Admin de W1 hecho con tweens en el servidor para siempre** (30 partes, 60 tweens/s) | `src/worlds/World1/ServerScriptService/Infrastructure/AAA_NewWorld1PadCleanup.server.luau:127-167` | 900-1,800 actualizaciones de color/s replicadas a cada cliente del lobby (estimado) | Color estático en el servidor y ciclo HSV local en el cliente | S | C |
| H13 | **El wall-bounce del salto** lanza hacia atrás a ≥18 studs/s desde cualquier cara a menos de ~1.9 studs, así que no se puede subir a un bloque que se tiene delante | `src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau:39-50,143-153,975-1026` | Saltos a bloques de 2.3-7 studs siempre fallan (reseñas del 09-03 y 09-05) | Rebote solo en Freefall bajando y con cara más alta que la cabeza. Escalar con la velocidad al caminar | M | C |
| H14 | **Escalera de Speed: se quitó el peldaño de 3 R$ y el x10 repetible; a partir de x32 no hay botón** | `src/common/ReplicatedStorage/Shared/Config.luau:966-975,1025-1033`; `MainHUDController.client.luau:1244-1322`; `SpeedProductPurchases.server.luau:139-149` | Primera compra 6.7× más cara. Quien está en x32+ no ve ni 2xSpeed ni 2xVictory | A/B de x2 a 5-9 R$ más un peldaño repetible; nunca ocultar el botón | S | C (4 dims) |
| H15 | **Ofertas de impulso eliminadas el 09-13**: botón HUD de Infinite Revives, Flight de 79 R$ (producto) a 799 R$ (pase). El cliente fuerza un precio mínimo de 799 | `Config.luau:100-103`; `AbilitiesPanel.client.luau:208-213`; `SpeedProductPurchases.server.luau:219-228` (registra un id de pase como producto); `RevivePrompt.client.luau:373,496` | Infinite Revives vende 0 casi todos los días desde el 09-16. Flight: 3.5k→1.7k R$/día | Ofrecer Infinite Revives en el prompt de revive tras la 2.ª muerte. Probar Flight más barato o temporal. Quitar el clamp a 799 | S | P |
| H16 | **El 90% de los errores en vivo (3.13M/día) solo está arreglado en el build 09-22**, cuya publicación no está confirmada | `AdminAbuseEffects.client.luau:2535-2540,2585-2588`; `R6DeathRagdoll.server.luau:72-75,85`; `AsmrEffectsClient.client.luau:142`; `World2TreeSlammers.client.luau:160,326`; `SpinWheelController.client.luau:345,545` | Si el build vivo es anterior: tormentas de sonido en cada evento de tacos y, en W2, **los árboles no se mueven ni matan** desde el 09-19 | Confirmar el build vivo y publicar. Volver a exportar errores a las 24 h (esperado ≈0.33M/día) | S | C |

### 5.2 Medios

| ID | Título | Archivo:línea | Arreglo | Esf. | Ver. |
|---|---|---|---|---|---|
| M1 | Ledger de 512 operaciones guardado con el perfil (≈48-58 KB por guardado; deep copy 30× más cara) | `SessionActor.luau:694-711`; `ProfileCodec.luau:720-744` | IDs deterministas solo donde haya deduplicación (recibos). Recorte por edad o tope de 32-64 | M | P |
| M2 | Rutas calientes que hacen deep copy del perfil para leer un número (popup de cinta 2 Hz, AFK 1 Hz, sync de quest 0.5 Hz) | `TreadmillTraining.server.luau:1051-1064`; `PlayerStatsBridge.luau:148-161`; `AfkZoneService:212-237`; `QuestService:46-56` | `PeekField` o atributos. Quitar `VisualAmount` | S | C |
| M3 | La cinta Admin/Taco lee atributos del cinturón anidado: **no paga los Wins anunciados** ni muestra efectos de taco. El arreglo ingenuo = 120 UpdateAsync/min por jugador en la cinta | `TreadmillTraining.server.luau:106-117,541-546,1019-1049,1166`; `AdminAbusePanelService.server.luau:1586-1595` | Leer `zone.AuthoredContainer` **y** acumular Wins en memoria con Commit cada 30-60 s | S | C (bajé la severidad de security#1/persistence#10 de alta a media latente) |
| M4 | 3 copias replicadas de Speed + NumberValue LevelProgress sin throttle | `StatsProjection.luau:111-142,283,306`; `LevelProgress.server.luau:146-212` | Quitar duplicados. LevelProgress solo para el dueño | S | C |
| M5 | AnimationReplicationSync reinicia las animaciones de todos 2 veces por entrada | `AnimationReplicationSync.server.luau:49-59,90-95`; `R15SpeedsterRun.client.luau:556-584` | Una sola republicación con fade, o ninguna | M | C |
| M6 | Auras de otros jugadores en teléfono: LOD débil a <40 studs, Highlights forzados, auras de 125-645 instancias reclonadas por respawn | `AuraSpecialEffectsClient.client.luau:219-320`; `CosmeticService.luau:199-236` | K más cercanos con detalle, apagar Beams/Highlights ajenos, opción "efectos de otros" | M | P |
| M7 | Comprobación de barrera de Flight 2×/frame con GetPartsInPart por parte | `World1FlightAbility.client.luau:62-85,446-453,964-1030` (×3 copias) | Tags + un GetPartBoundsInBox a 10-20 Hz | S | C |
| M8 | **SpawnFloorSurfaceFix** busca `Spawn1Outline`, que no existe en ningún place (20 Hz durante 15 s y luego en cada lote de streaming, toda la sesión, 3 mundos) | `src/common/ReplicatedFirst/SpawnFloorSurfaceFix.client.luau:9,116-120,190-232` | Retirar como stub | S | C (5 dims) |
| M9 | **World1ClientMotionHazards** legado: 13 hilos de polling recursivo durante 20-30 s en cada entrada a W1 | `src/worlds/World1/StarterPlayer/StarterPlayerScripts/Gameplay/World1ClientMotionHazards.client.luau:92-96,221-246,290` | Stub (como su copia raíz). Retirar también `World1ClientHazardAuthority` | S | C (4 dims) |
| M10 | Texturas superpuestas (7.1k W1 / 17k W3) + mallas Precise; LowPowerGraphics no las toca | Places; `LowPowerGraphics.client.luau:10-89`; `audit/perf_place_edits.luau:73-100` | MaterialVariant o borrar las caras no visibles. RenderFidelity Automatic. Medir antes y después | L | P |
| M11 | WinPadTextDistance recalcula todos los textos cada frame en teléfono | `WinPadTextDistance.client.luau:31,91-243` | Recalcular solo cuando cambia un atributo. Escalar solo dentro de MaxDistance a 10-15 Hz | S | C |
| M12 | Throttling y LOD de animación forzados a off para 60 personajes | `RemoteAnimatorFidelity.client.luau:22-62` | A/B: fidelidad completa solo para el personaje local | S | P |
| M13 | La entrada no difiere nada: ráfaga de 5.7k instancias de UI, ≈45 controladores, escaneos de Workspace y descargas justo al quitar la pantalla negra | `LoadingScreen.client.luau:267-331`; `BackpackScript.client.luau:1797-1827`; `ModalJuice.luau:231-274`; `ConsoleUiScale.client.luau:244-304` | Fase A (HUD, movimiento, tutorial) y el resto tras tocar la primera cinta o a los 10-15 s | M | P |
| M14 | Daily rolling de 24 h + panel forzado en cada entrada, teleport y rejoin de AFK aunque esté bloqueado | `DailyLoginSystem.server.luau:109-123,394`; `UpdateLogsController.client.luau:377-382`; `DailyRewardController.client.luau:354-377` | Día calendario UTC o ~20 h. Auto-abrir solo si `CanClaim`. No en teleports ni AFK | S | P (2 dims) |
| M15 | Recorte del Daily el 09-21 en los días 1-14 (día 2 ×400 menos); días 15-30 sin tocar (salto ×25,000) | `DailyRewardsData.luau:21-54` | Una sola escala. Día 2-3 claramente valioso (ticket de ruleta, poción) | S | C (3 dims). Nota: sí se multiplica por las ganancias del jugador (`DailyLoginSystem:396-405`) |
| M16 | Hacer rebirth antes del primer claim cancela el tutorial y la guía de aura en todas las sesiones siguientes | `FirstTimeTutorial.server.luau:38,343-349`; `TutorialFlow.luau:10-17`; cliente `:685-687` | Ofrecer la guía de aura si `BackpackTutorialSeen` es false y hay ≥10 Wins | S | C |
| M17 | El Step 2 caduca en silencio a los 102 s y después el Daily se abre en mitad del recorrido | `FirstTimeTutorial.server.luau:27,99-137`; `UpdateLogsController.client.luau:361-375` | No caducar mientras haya progreso. Chip persistente con la meta. Daily solo en el lobby | M | C |
| M18 | Update Logs usa `PlaceVersion` compartido entre 3 places, vuelve tras cada publish y el día 2 aparece siempre a los nuevos | `UpdateLogsController.client.luau:20-44,352-383`; `Bootstrap.server.luau:309-315`; `ProfileReducers.luau:409` | Clave de contenido (`Config.UpdateLogId`). No mostrar a quien empezó después. Máximo un modal por entrada | S | C (4 dims) |
| M19 | El Step 1 enseña una cinta ×1 = caminar, que además es la más lejana (211 studs) tras 6 cintas bloqueadas | `Config.luau:579-585,721-722,800`; `TreadmillTraining.server.luau:1158-1197`; place | Basic junto al spawn o bonus ×3 para 0 rebirths. Pedir 5-10 s de entrenamiento con comparación visible | S | C |
| M20 | Sin favorito, notificaciones ni invitaciones | grep en `src` | `PromptSetFavorite` + `PromptOptIn` tras la primera aura o el primer rebirth | S | C |
| M21 | El kill de Sonic.EXE en el servidor no rebobina el lag (Zoom y Reverse Flash sí) | `src/worlds/World2/ServerScriptService/Bosses/World2SonicEXEBoss.server.luau:20-37,565-571,652-671` | `BossContact` con historial y rewind por ping | S | P (solo W2) |
| M22 | Carrera en el revive: `RevivePurchasePending` queda en true y la muerte siguiente nunca respawnea | `RevivePrompt.client.luau:531-590,409-411`; `SpeedProductPurchases.server.luau:2103-2106,2506,2541-2588` | Limpiar el flag al terminar la oferta más un watchdog de 60 s. El cliente contesta PromptFailed | S | C |
| M23 | Cada muerte devuelve a Stage 1 (`LastReachedStage = 1`); el revive de 7 R$ se aplica en el 0.03-0.06% de las ofertas | `SpeedProductPurchases.server.luau:2117-2135`; `Config.luau:1093-1096` | Respawn en la última zona segura para jugadores nuevos, o 1 revive gratis por carrera | M | P (existen viajes de etapa con Wins e Infinite Revives) |
| M24 | Láseres de W3 Stage 10: el servidor mata con la raíz retrasada contra la pose actual | `World3Hazards.server.luau:385-405`; `World3HazardMotion.luau:267,284-322` | Poner la barra en `elapsed - rewind` | S | C |
| M25 | El tile de Starter Pack abre el prompt de Roblox al primer toque, sin mostrar el contenido; el temporizador se reinicia en cada sesión | `StarterPackOffer.client.luau:45-47,176-188,277-332,370-377` | Tarjeta de contenido antes del prompt. Mostrar tras la primera cinta. Caducidad guardada | S | P |
| M26 | Oferta de revive en cada muerte (Stage 1 incluida), 15 s aunque Config diga 10, sin indicar la etapa | `SpeedProductPurchases.server.luau:2013-2159`; `RevivePrompt.client.luau:127` | Saltar si stage ≤1. "Continuar desde Stage N". Límite de frecuencia. 8-10 s | S | P |
| M27 | El pase 2X Speed (249) = peldaño x2 de 20 R$; la tienda lo marca como comprado a partir de x2 | `ShopController.client.luau:184,324-330`; `SpeedProductPurchases.server.luau:2261-2281,2659-2670` | Escalera desde x4 o pase como multiplicador aparte | S | C (2 dims) |
| M28 | La ruleta abre una sesión de funnel nueva y registra 3 eventos cada 2 s con el panel abierto | `SpinWheelController.client.luau:1446-1453`; `SpinWheelService.server.luau:441-449` | `opened=true` solo al abrir | S | C |
| M29 | Premios de Wins de la ruleta calibrados a una vuelta completa (170K/690K en W1) | `SpinWheelCatalog.luau:34-43,124-133` | Escalar al progreso del jugador | S | P |
| M30 | Viajes de etapa, Skip y vuelta al spawn con `PivotTo` sin `RequestStreamAroundAsync`, con integridad Disabled desde el 09-19 | `StageTeleportService.luau:136-139`; `World2StageTeleportService.luau:302-305`; `World3StageTeleportService.luau:429-432` | `RequestStreamAroundAsync` antes de mover. Suelo `Persistent` | S | P (conf. 0.45) |
| M31 | Sin recuperación de caída bajo los mapas de W1/W2 (y≈37k): ≈20 s de caída | `MovementGuard.luau:36-46`; places (`FallenPartsDestroyHeight -500`) | Plano de vacío por etapa como en W3. Destroy height ≈36.8k/36k | S | P |
| M32 | Los jugadores de W2/W3 siempre vuelven a entrar en W1 | `WorldPortalService.server.luau:672-677` | Guardar `LastWorld` y ofrecer "Continuar en World N" | M | C |
| M33 | Quests: reset a las 00 UTC sin auto-claim; el Claim falla durante el flush de 10 s | `QuestCatalog.luau:26,216-218`; `ProfileReducers.luau:582,606-612`; `QuestService.server.luau:170-176,266-276` | Auto-claim en el rollover. Quest activa 24 h desde que se elige | M | C/V |
| M34 | Objetivos de quest redondeados hacia arriba hasta 2.5× el Speed actual; "Reborn" siempre pide 1 rebirth | `QuestCatalog.luau:51-162,204-250` | Escalar al ritmo de ganancia y redondear hacia abajo | S | P |
| M35 | El funnel Onboarding_Ladder solo cuenta dentro de una sesión de servidor, así que muestra un muro falso | `FunnelAnalytics.luau:240-285,319-329` | Cohorte persistida en el perfil | S | C |
| M36 | Time Gifts: el cliente lee el array de reclamados como si fuera un mapa (bloquea y rotula mal los regalos) | `TimeGiftController.client.luau:70,78-84,97` | `claimed[tonumber(i)] = true` | S | C |
| M37 | **Panel admin con target "All" por defecto**; ResetStats/SetStat/RemoveStat/Remove Pass/Remove Treadmill sin confirmación, y Set/Remove también de forma global | `AdminAbusePanelController.client.luau:135,441-447,624-675`; `AdminAbusePanelService.server.luau:101-104,1895-1968,2439-2497,2569-2586,2092-2137` | Default Self. Guard de "All" como en WipeData. Confirmación escrita. Log de acciones | S | C (3 dims; comprobado `selectedTarget = "All"`) |
| M38 | Remotes que hacen Commit o Flush en cada llamada (equip de aura/trail/skin del Index sin límite, códigos con GetAsync) | `SkinSystem.server.luau:20-34,2270-2329`; `CosmeticService.luau:70-127,565-607,665-676`; `CodesSystem.server.luau:159-169,283-304` | Guardar la selección como preferencia. Cooldown de 1-2 s. Límite de códigos | M | P |
| M39 | `PromptGamePassPurchaseFinished(wasPurchased)` se usa como prueba de compra en 8 handlers (incluido +1 Rebirth repetible) | `SpeedProductPurchases.server.luau:2625-2703`; `TreadmillTraining.server.luau:1209-1222` | `UserOwnsGamePassAsync` antes de otorgar | S | P (depende de si se puede falsificar) |
| M40 | AdminTacoHit confía en los golpes que reporta el cliente (+75 Speed base × todos los multiplicadores, 5/s) | `AdminAbusePanelService.server.luau:1671-1695` | Tope por evento y taco validado por el servidor | S | C |
| M41 | Etiquetas [DEV]/[Tester] asignadas por DisplayName (suplantación) | `Config.luau:1245-1272`; `Bootstrap.server.luau:380-399`; `VipChatTag.client.luau:27-40` | Solo por UserId | S | C |
| M42 | **DarkZonic (limitado de pago) da ×1 en W2/W3** (×300 en W1), peor que el Flash gratis | `src/common/ReplicatedStorage/Shared/Config.luau:863-884` frente a `:902` | Añadir `DarkZonicSuit = 300` o usar una sola tabla. Test | S | C (2 dims; comprobado: solo existe en la tabla de W1) |
| M43 | DarkZonic no se puede comprar en el juego (no hay `Workspace.DarkZonic` en ningún place); el equip del claim no persiste; tras agotarse, quien compra en la web no recibe nada | `SkinSystem.server.luau:1388-1401,2590-2664`; `IndexScript.client.luau:144-148` | Tarjeta de compra con stock. `persistSkinSelection`. Otorgar a todo dueño verificado | M | C |
| M44 | Los toques de Comprar/Equipar del Backpack se descartan (RemoteGuard 0.25 s) justo después de los RequestState automáticos, **también en el paso de la primera aura** | `BackpackScript.client.luau:150-188,344,451,972,1165`; `RemoteGuard.luau:36-43` | `onDropped` que reintente, o RequestState fuera del guard | S | C |
| M45 | El traje de Reverse Flash aplica ApplyDescriptionReset 4 veces en cada respawn | `SkinSystem.server.luau:1237-1300` | Reintento condicional como en `applyCatalogSuit` | S | C |
| M46 | El jefe Reverse Flash (26.5 fijo) persigue todo el primer segmento; un jugador nuevo camina a 8 | `ReverseFlashBoss.server.luau:47,815-817,829-855` | Velocidad relativa al corredor (como Sonic) o apagarlo en el tutorial | S | C |
| M47 | Los cosméticos de W3 se venden y funcionan en todos los mundos (un trail de 60 R$ ×1200 supera al Black ×1000 de 179 R$) | `CosmeticCatalog.luau:69-128,203-301`; `BackpackScript.client.luau:1357-1375`; `StatsProjection.luau:210-222` | Solo en W3, o multiplicador solo si `CurrentWorld == 3` | S | C |
| M48 | Dos grupos de colisión: "Players" deshace la cubierta lisa de las cintas en la primera vida de cada sesión | `Bootstrap.server.luau:12-37,481-482`; `TreadmillCollisionFix.server.luau:58-91` | Un solo grupo, o no colisionable Players↔VortexTreadmillVisuals | S | C |
| M49 | Huecos de Stage 1 de 5.94 y 6.05 studs frente a ≈5.3 de alcance a 8 studs/s; el hueco 3 exige precisión de un frame | `Config.luau:655,658,668`; `InstantMovementController.client.luau:1098-1104`; geometría del place | Cerrar a ≤4 studs, velocidad mínima en el aire de 11 o pista de "Sprint" | S | P (geometría no revisada por el verificador) |
| M50 | **Dial de velocidad a 8 px del botón de salto en teléfono**; un toque pasa a Green (×0.2, sin mínimo) y queda guardado | `HudErgonomics.luau:56,266-310,458`; `WalkSpeedSelector.client.luau:57-62,317-327`; `CharacterStatsAdapter.luau:56-64`; `Bootstrap.server.luau:232-253` | `max(RealWalkSpeedMin, ...)`. Ciclo Red→Yellow→Green. Separación de 24 px. Volver a Red si Speed es bajo | S | P (2 dims) |
| M51 | El Sprint espera un viaje de ida y vuelta al servidor | `SpeedsterClient.client.luau:193-216`; `InstantMovementController.client.luau:902-904` | Predecir en el cliente con `SprintHeld` | S | C |
| M52 | Soltar el stick en el aire frena en seco; no hay coyote time; el impulso de Sonic Burst se sobrescribe | `InstantMovementController.client.luau:945-949,1083-1104`; `Config.luau:1228` | Conservar inercia en el aire, 100 ms de coyote y jump buffer | S | C |
| M53 | Revelación de admin: cámara Scriptable y movimiento que sigue a la cámara, TouchGui oculto (taco), sin exenciones, global y sin cooldown | `AdminTreadmillReveal.client.luau:83-92,634-684,834-942,1054-1066`; `InterfaceHider.luau:23-114`; `AdminAbusePanelService.server.luau:2016-2052,2174,2662-2677` | Solo para quien está en el lobby, gracia en el servidor, Skip, respetar `readiness()` como el portal, cooldown de 10 min | M | P/C (5 hallazgos) |
| M54 | Trolls "Everyone + All" (FakeReset "DATA ERROR!", Rocket, Jumpscare) sin exenciones | `AdminAbusePanelService.server.luau:101-104,327-358,2034-2036`; `AdminAbuseEffects.client.luau:95-102,528-534` | Excluir a jugadores nuevos. Bloquear FakeReset/Rocket globales | S | C |
| M55 | Raining Tacos: VFX de 39 emisores clonado ≈4.5/s en teléfono y temblor constante | `AdminAbuseEffects.client.luau:2543,2619-2717,2798-2803` | Pool y Emit. Solo en el lobby. Sin temblor en teléfono | S | C |
| M56 | Multiplicadores de cosméticos dominantes y muro de endgame (ciclos ×5-×7) | `CosmeticCatalog.luau`; `LevelProgress.server.luau:25-82` | Comprimir (aditivo o tope). Rebirth ×2-×3 escalado | M | P (diseño) |
| M57 | Viajes de W1 más baratos que el pad siguiente | `Config.luau:1169-1180`; `NewWorld1ManualStagePads.server.luau:48-61` | Precio contra el mejor pad alcanzable en 1-2 etapas | S | C |
| M58 | Expulsión al entrar tras ~9 s si el lease (120 s) está ocupado; `StoreUnavailable` no se reintenta | `Bootstrap.server.luau:357-371`; `SessionActor.luau:391-400`; `WorldPortalService.server.luau:666-689` | Reintentar hasta ~130 s con pantalla de "Cargando partida". `StoreUnavailable` reintentable. Release antes del teleport | M | P/V |
| M59 | Un segundo recibo se rechaza con NotProcessedYet mientras se procesa el primero | `SpeedProductPurchases.server.luau:1993-2011` | Cola por jugador | S | C/P |
| M60 | Recibos de regalo: solo se completan si el destinatario está en el mismo servidor; el contexto viejo bloquea o redirige compras posteriores | `SpeedProductPurchases.server.luau:1826-1835,1856-1857,2858-2931`; `ProfileReducers.luau:506-517` | Buzón en el perfil del destinatario. Caducidad del contexto | M | C/V |
| M61 | Secret Aura y Secret Trail venden 0 desde el 09-20 (≈9.3k R$/día antes del 09-13); causa desconocida | `CosmeticCatalog.luau:31-37,164-170`; `BackpackScript.client.luau:586-600,1077-1092` | Probar la compra en teléfono. Posible canibalización por M47 o M29 | S | P (el ThemeColor duplicado quedó refutado) |

### 5.3 Bajos (compacto)

| ID | Título | Archivo:línea | Arreglo |
|---|---|---|---|
| L1 | Precarga de 2+2 pistas de ambiente en cada entrada a W1 | `ZoomArenaAmbience.client.luau:151-198`; `NewWorld1MapMotion.client.luau:249-278` | Cargar por proximidad |
| L2 | La Golden de W2 hereda el lock de 1 rebirth de W1; W2/W3 sin puerta de entrada | `TreadmillTraining.server.luau:35-66` | Aplicar el bucle solo si `IS_NEW_WORLD1` |
| L3 | `UserOwnsGamePassAsync` dentro del bucle de cintas de 0.1 s | `TreadmillTraining.server.luau:331-372` | Comprobar al entrar y usar solo caché en el bucle |
| L4 | El producto x2 Wins-pad paga los Wins en un Commit aparte (doble pago si hay reintento) | `SpeedProductPurchases.server.luau:1109-1183,1922-1928` | Wins dentro de los comandos del recibo |
| L5 | Carrera entre el Commit pendiente y el Release al salir (Wins de pad o quest) | `RewardPadClaims.luau:75-98`; `QuestService:341-348` | Hook previo al release |
| L6 | 2x Speed pass y escalera no se acumulan (misma variable con max) | `SpeedProductPurchases.server.luau:2272-2279` | Decisión del dueño |
| L7 | Atributos de cuenta atrás de AFK cada segundo | `AfkZoneService.server.luau:228-264` | Enviar la hora del próximo pago una vez |
| L8 | Muestreador de cintas 10 Hz y GetFullName | `TreadmillTraining.server.luau:870-1017` | Índice espacial y 5 Hz |
| L9 | Heartbeats por jugador por frame (stamina, PadTouch, MovementGuard, jefes) | `Bootstrap:633-693`; `PadTouchService:135-201`; `MovementGuard:85-124` | 10-30 Hz y cachés |
| L10 | Pushes de quest cada 2 s y de Daily cada 5 s con el panel cerrado | `QuestService:137-167,351-365`; `DailyLoginSystem:454-463` | Solo si cambia o el panel está abierto |
| L11 | 11-13 listeners de Workspace con strings y threads por instancia | `World2ManualPadTextDistance:36-48`; `World2TreeSlammers:380-403`; `ZoomArenaAmbience:51-89` | Índice compartido con tags |
| L12 | El Daily se auto-abre en mitad del recorrido tras el timeout del Step 2 | `UpdateLogsController:361-375` | Solo en el lobby |
| L13 | Funnels sin pasos de tutorial ni de primer claim | `FunnelAnalytics.luau:37,135-143,341-356` | Onboarding_Tutorial_v3 |
| L14 | El check de hazards del cliente en W1 y el remote ignoran las zonas seguras; el hitbox de Fast es 35 studs más alto | `NewWorld1MapMotion:477-497`; `NewWorld1MapSystems:58-83` | `SafeZoneProtected` y recortar el hitbox |
| L15 | Sin telemetría de muertes por etapa, hazard o ping | `FunnelAnalytics.luau:205-207` | Evento por muerte |
| L16 | Remote `World1ClientHazardAuthority` sin uso: 11 escaneos recursivos por llamada (palanca de lag para exploiters) | `World1ClientHazardAuthority.server.luau:18-70,152-184` | Stub |
| L17 | Regalo de 2x Speed o Flight que no hace nada (solo se comprueba la posesión del pase) | `SpeedProductPurchases.server.luau:2857-2878`; `GiftedPasses.luau:59-73` | Comprobar el efecto |
| L18 | VIP se retira toda la sesión si falla la consulta | `VipSystem.server.luau:38-62` | Reintentar y no retirar |
| L19 | La cinemática del portal puede empezar en mitad del recorrido (tiene Skip) | `WorldPortalCinematic.client.luau:508-535`; `WorldPortalService:786-805` | `readiness()` solo en zona segura |
| L20 | El panel de viajes no muestra los mensajes del servidor | `TeleportController.client.luau:299-318` | Label de estado |
| L21 | Viaje de mundo sin reintento; amigos separados; "PortalWorld2" visible para el jugador | `WorldPortalService.server.luau:440-453,515,672-718` | Reintentos y ServerInstanceId |
| L22 | Teleport fallido + restauración fallida = expulsión | `WorldPortalService.server.luau:440-445` | Reintentar antes de expulsar |
| L23 | Salir de AFK no funciona si falla el Commit | `AfkZoneService.server.luau:349-358` | Salir igualmente y reintentar el grant |
| L24 | Poderes de admin repartidos en 6 cuentas y 8 listas; la id 111827288 está etiquetada como Gekkoh (es pxuto) | `AdminBannerConfig.luau:3-44`; `ChatBoostCommands.server.luau:36-53` | Un único módulo de roles |
| L25 | Evolve abre un prompt de Robux cuando falta el rebirth (gratis); los mensajes del servidor no se muestran | `EvolveController.client.luau:476-521`; `IndexScript.client.luau:256-274` | Abrir el menú de Rebirth y mostrar `Message` |
| L26 | Constantes de movimiento de W2 cambiadas 4 veces (la caminata a 2.67 tras un rebirth ya existía en la OG) | `Config.luau:16,800`; `StatsService.luau:185-196` | Changelog para jugadores |
| L27 | El HUD no comprueba `IsForSale` en la escalera de Wins | `MainHUDController.client.luau:573-604,1281-1321` | Ocultar lo que no está a la venta |
| L28 | GO! lleva al lobby desde etapas avanzadas sin aviso; si el jugador está muerto la tarjeta se cierra sin más | `AdminTreadmillReveal.client.luau:737-766`; `AdminAbusePanelService:1627-1669` | Confirmación y `MovementGuard.Rebase` |
| L29 | Meteorito de taco pesado en teléfono (≈270 instancias y 700 partículas en el impacto) | `TacoMeteor.luau:150-494` | Recortar en LOW_POWER |
| L30 | La cinta de evento ×315 supera a Hacker ×300 | `Config.luau:518-539` | Decisión del dueño |
| L31 | `RedBallContact` muerto en los 3 places | `RedBallContact.client.luau:20-21` | Stub |
| L32 | **`_G.SpeedsterGrantExactStat` usa `HttpService` sin declarar**: los comandos give de admin siempre fallan | `src/common/ServerScriptService/Progression/PlayerStatsBridge.luau:344` (comprobado: es la única mención en el archivo) | `local HttpService = game:GetService("HttpService")` |
| L33 | Fricción de rebirth y quests (20-23% no hace rebirth; métrica sesgada por sesión) | `FunnelAnalytics.luau:48-54` | Tarjeta de antes y después |

Entradas únicas: 16 altas + 61 medias + 33 bajas = **110** (de los 175 verificados).

---

## 6. Monetización frente a retención

**Ingresos por producto** (R$ netos/día, 09-06..12 frente a 09-13..19; fuente data-retention):

| Producto | Antes | Después | Nota |
|---|---|---|---|
| x10 / x4 / x2 Speed (OG, 20/7/3 R$) | 9,682 / 4,421 / 4,145 | 0 | No se ofrecen desde el 09-13 (H14) |
| Flight (producto de 79) → pase de 799 | 4,500 | 1,837 (pase) | H15 |
| Speed Tier 4 | 9,170 | 3,080 | −66% |
| Secret Trail / Aura | 4,788 / 4,536 | 1,314 / 864 → **0 desde el 09-20** | M61 |
| Revive | 7,208 | 3,592 | 0.03-0.06% de las ofertas (v2) |
| Other (escalera nueva, ruleta, AFK x5…) | 22,516 | 20,909 | **No absorbió la pérdida** |
| Hacker / Valentine / Admin Treadmill | 24,915 / 9,197 / 6,880 | 19,086 / 6,195 / 5,335 | Estables por DAU |
| Infinite Revives | 2,343 | 449 → 0 | H15 |

- Los productos de desarrollador cayeron −58% (−45% por DAU). Los pases, −24%, que por DAU es plano.
- **La relación con la retención**: el x2 a 3 R$ convertía a ≈2,000 jugadores/día en pagadores, y los pagadores retienen más. La caída de pagadores (−54% en un día) coincide con la caída de D1. No se puede separar cuánto D1 perdido se debe al precio y cuánto al resto de Update 2; los dos cambios salieron en el mismo publish.
- **Fricción que ahuyenta**: una oferta de revive en cada muerte (M26), el prompt directo de Starter Pack (M25; 6-7% toca y 0.15-0.3% de ellos compra), las cintas bloqueadas que abren un prompt de Robux en el camino a la Basic (M19) y el Evolve que abre Robux (L25).
- **Canibalización**: los premios de la ruleta (M29), los cosméticos de W3 de 60 R$ en W1 (M47) y la cinta de evento ×315 (L30).
- **Precios inconsistentes**: el pase 2X Speed es igual al peldaño de 20 R$ (M27) y los viajes de W3 cuestan lo mismo que los de W1.
- **IDs pendientes**: la tienda los maneja bien ("Soon!", "coming soon", "Not giftable"). Config ya no tiene IDs pendientes. `TenXSpeedGamePassId` es nil y está manejado. `AbilityFlightProductId` es un id de pase registrado como producto (muerto).
- **Los precios vivos pueden diferir de Config** (Revive neto 9 ≈ 13 R$ de lista; Tier 4 ≈350). La UI lee el precio vivo. Confirmar en el dashboard. El Starter Pack ya estaba a 50 R$ en vivo **antes** del 09-13 (las ventas son múltiplos de 35 netos), así que el "7→50" solo ocurrió en Config.

**Recomendación**: A/B de un único SKU cada vez (x2 a 5-9 R$ primero), comparando cohortes del mismo día de la semana. Pedir la exportación por producto con IDs, porque "Other" oculta la escalera nueva, los packs de ruleta y el AFK x5.

---

## 7. Datos persistentes, compras y seguridad

**Lo que está bien** (verificado): un solo DataStore `SpeedsterEscape_MainSave_v17`, clave `Player_<id>`, en los 3 places. Lease con CAS sobre `Update2WriteId`. Los recibos se otorgan solo tras un Commit durable que registra el id. ProfileCodec conserva claves desconocidas. Las migraciones solo suben flags. Los multiplicadores OG viajan a W2/W3 por el perfil. **No se encontró ningún bug que borre o revierta el progreso normal.** El `PlayerStats.server.luau` legado está muerto (`:9-12`; `UseModularDataService = true` en `Config.luau:1190`). Hay un único handler de ProcessReceipt. Todas las llamadas DataStore, Marketplace, Teleport, Messaging, Policy y Badge van dentro de pcall.

**Riesgos reales:** H2, H3, M1 (bajo carga), M58 (expulsión al entrar), M59/M60 (recibos), L4/L5, H1 y M39 (grants).

**Seguridad:**
- **Backdoors: ninguno.** Los 944 scripts de los places corresponden al manifest. No hay `require(id)`, `loadstring`, `getfenv`, webhooks ni RemoteFunctions.
- Los remotes de hazards solo matan a quien los envía. Todos los remotes de admin comprueban una allowlist por UserId en el servidor.
- **Exploiters activos**: ≈38k errores/día de un executor (`CoreGui.7996.Loadstring`) desde el 09-21 20:26.
- Superficies explotables: H10 (claim del pad final cada ~2 s), M39 (grant por evento del cliente), M40 (tacos), L16 (lag por escaneos), M38 (drenar el presupuesto de DataStore; el de códigos es el más creíble).
- **El mayor riesgo de pérdida masiva de datos está en las herramientas de admin** (M37): un clic con el target por defecto "All" resetea Speed, Wins y Rebirths de todo el servidor. SetStat y RemoveStat también funcionan de forma global.
- Suplantación de [DEV] por DisplayName (M41). Poderes de Ban/Wipe universales repartidos en 6 cuentas más el rango 254+ del grupo (L24): decisión del dueño.

---

## 8. Estado técnico

### 8.1 Tests Lune

- **Suite `audit/run_fable_checks.luau`: 45/45 en verde, 45.2 s.** El comentario dice 48, pero la lista tiene 45. Se ejecutó desde una copia en scratch; el test de tacos se redirigió para que no escribiera en `output/`.
- 4 tests extra de solo lectura (49 invocaciones en total):
  - `test_world_lag_and_streaming` **PASA**, y además compila todos los scripts de W2 y W3.
  - `test_saved_uis` **PASA**.
  - `test_world3_place` **FALLA** en `:138`: StarterGui/ServerStorage de W3 difieren de W2 (QuestGui Quantity TextScaled, ids de jaula de TungTung). El test es demasiado estricto.
  - `test_backpack_layout` **FALLA** en `:177`: aserción de string obsoleta tras el rediseño del 09-22.
- **Deuda de tests**: 4 tests de la suite usan copias viejas del 09-19 (`audit/merged`) de los módulos de datos, RemoteGuard y pads, no `src`. El camino de producción del notify coalescido de SessionActor nunca corre en Lune.

### 8.2 Sincronía src ↔ places

| | W1 | W2 | W3 |
|---|---|---|---|
| Scripts en el place / en el manifest / idénticos a src | 307/307/307 | 348/348/348 | 289/289/289 |
| Huérfanos o faltantes | 0 | 0 | 0 |
| Deshabilitados | 0 | 35 (stubs ASMR/FadingScript) | 0 |

Build del 09-22 07:51. El único archivo de `src` más nuevo es `manifest.json` (7 s después). Existen `World2Update3new.rbxl.lock` y `World3Update3New.rbxl.lock` (09-22 08:07-08:08). **Riesgo**: si Studio guardó o publicó esos places después, el build pudo quedar sobrescrito.

### 8.3 Inventario de los places

| | W1 | W2 | W3 |
|---|---|---|---|
| Instancias totales / Workspace | 30,407 / 14,219 | 19,621 / 10,194 | 43,842 / 34,383 |
| BaseParts (CanTouch) | 4,686 (4,665) | 8,045 (1,432) | 14,720 (13,473) |
| Texture | 7,624 | 86 | 17,052 |
| MeshParts (Precise) | 195 (132) | 109 (38) | 484 (317) |
| Emisores de mapa / luces | 45 / 25 | 27 / 17 | 26 / 29 |
| GlobalShadows (place) | false | false | true (en runtime AAA_ReferenceClipLighting lo enciende en todos; LowPowerGraphics lo apaga en teléfono) |
| Streaming | 1024/512, Integrity Disabled, LowMemory (los 3) | | |
| MaxPlayers / RespawnTime | 60 / 3 (los 3) | | |
| ClientAnimatorThrottling | Disabled (los 3) | | |
| `Spawn1Outline` / `DarkZonic` en Workspace | faltan en los 3 | | |
| StarterGui | 26 ScreenGuis, 5,764 descendientes (los 3) | | |

IDs de producción (confirmados por el dueño el 09-19): 85065221510105 / 116359653478954 / 128432111599629. **La nota de memoria que dice que los IDs de Config son de prueba está desactualizada.**

---

## 9. Plan de acción priorizado

### P0: hoy o mañana

| # | Acción | Archivos | Esf. | Métrica |
|---|---|---|---|---|
| P0-1 | **Confirmar en Creator Hub qué versión está en vivo en cada place** (historial de versiones con hora). Si no es el build 09-22, publicarlo (cuidando los .lock de W2/W3). Anotar la hora de cada publish a partir de ahora | – | S | 24 h después, errores ≈0.33M/día (desde 3.47M) |
| P0-2 | Exportar D1/D7 de las cohortes 09-19..09-24, impresiones y DAU del 09-20 en adelante, e ingresos por producto con ID | Creator Hub | S | Separar tráfico de juego en la caída del 09-21 |
| P0-3 | Arreglar el pase de Rebirth +1 por entrada (H1) y auditar a los dueños | `SpeedProductPurchases.server.luau:2239-2258,2689-2692` | S | Distribución de Rebirths de los dueños |
| P0-4 | Quitar el Commit de 10 s de QuestService (H2): acumular en memoria y guardar en Claim, Choose o salida | `QuestService.server.luau:170-198,351-365` | S | Warnings de DataStore; éxito del Claim; TasksCompleted→Claimed |
| P0-5 | Retirar como stubs SpawnFloorSurfaceFix (M8), World1ClientMotionHazards y World1ClientHazardAuthority (M9, L16) y RedBallContact (L31). Pasar el arcoíris del Admin al cliente (H12) | `ReplicatedFirst/SpawnFloorSurfaceFix.client.luau`; `worlds/World1/.../World1ClientMotionHazards.client.luau`; `AAA_NewWorld1PadCleanup.server.luau:127-167` | S | FPS en teléfono, supervivencia a 90 s |
| P0-6 | FTUE rápido: retener la guía de rebirth hasta el primer claim (H7); dial de velocidad con mínimo y orden Red→Yellow→Green (M50); badge de Time Gifts (H8) y array de reclamados (M36) | `RebirthController.client.luau:638-687`; `CharacterStatsAdapter.luau:61`; `WalkSpeedSelector.client.luau:57-62`; `MainHUDController.client.luau:1151-1173`; `TimeGiftController.client.luau:80` | S | Supervivencia a 60/120 s, reclamos de Time Gift |
| P0-7 | Hitboxes de W1: test exacto para Laser y los demás (H4) y rewind en todos los grupos del backstop (H5), tras comprobar en Studio el AABB de `GetPartBoundsInBox` | `NewWorld1MapMotion.client.luau:504-523`; `NewWorld1ServerMotion.server.luau:1961-1991` | S | Muertes en Stage 5-9 (añadir telemetría L15) |
| P0-8 | A/B de la entrada barata: x2 Speed a 5-9 R$ y peldaño repetible; nunca ocultar el botón (H14) | Dashboard y `Config.luau:966-975`; `MainHUDController.client.luau:1297-1320` | S | Pagadores/día, conversión |
| P0-9 | Arreglos baratos para pagadores: DarkZonic en la tabla de W2/W3 (M42) y no-op en `applySavedSkin` (H11) | `Config.luau:863-884`; `SkinSystem.server.luau:2146-2147` | S | Tiempo del traje tras el respawn; tickets de soporte |
| P0-10 | Blindar el panel de admin: target por defecto Self y guard de "All" para ResetStats, SetStat, RemoveStat y Remove Pass/Treadmill (M37) | `AdminAbusePanelController.client.luau:135`; `AdminAbusePanelService.server.luau:2439-2586` | S | – |
| P0-11 | AFK: Commit por lotes y claim antes del rejoin o la salida (H9) | `AfkZoneService.server.luau`; `AfkZoneController.client.luau:146-157` | S | AFK v2 RewardEarned, D1 de usuarios AFK |

### P1: esta semana

| # | Acción | Archivos | Esf. | Métrica |
|---|---|---|---|---|
| P1-1 | AccrueSpeed sin lock, escritura fuera del lock, `task.spawn` en los bucles, aceptar mutaciones en Recovering (H3) | `SessionActor.luau:761-787,532-537,637-642`; `Bootstrap.server.luau:593-615`; `TreadmillTraining.server.luau:519-537` | M | Fluidez de la ganancia; "Could not open the session" |
| P1-2 | Recortar el ledger (M1) y usar Peek en rutas calientes (M2) | `SessionActor.luau:694-711`; `PlayerStatsBridge.luau:148-161` | M | CPU del servidor, tamaño del perfil |
| P1-3 | Muerte local no confirmada que el servidor revalida (H6); Sonic y W3 con rewind (M21, M24); zonas seguras en el cliente (L14) | `R15SpeedsterRun.client.luau:1043-1054`; `World2SonicEXEBoss.server.luau:652-671`; `World3Hazards.server.luau:385-405` | M | Muertes por hazard, reseñas |
| P1-4 | Movimiento: wall-bounce (H13), coyote time e inercia en el aire (M52), Sprint predicho (M51), huecos de Stage 1 (M49) | `InstantMovementController.client.luau`; place W1 | M | Finalización de Stage 1 |
| P1-5 | FTUE: Basic junto al spawn o bonus inicial (M19), Step 2 sin timeout silencioso (M17), guía de aura sin depender de SawTutorial (M16), Reverse Flash relativo al corredor (M46), Backpack sin taps perdidos (M44) | `FirstTimeTutorial.server.luau`; `TutorialFlow.luau`; `ReverseFlashBoss.server.luau:815-817`; `AuraShopSystem`/`TrailShopSystem` | M | FirstTreadmillRun v2, supervivencia 90 s |
| P1-6 | Ganchos del día 2: Daily por día calendario y abierto solo si se puede reclamar (M14), reescalar el Daily (M15), Update Logs por id de contenido (M18), auto-claim de quests (M33), favorito y notificaciones (M20) | `DailyLoginSystem.server.luau`; `DailyRewardsData.luau`; `UpdateLogsController.client.luau`; `QuestCatalog.luau` | M | D1/D7 |
| P1-7 | Revelaciones de admin: solo en el lobby, gracia, Skip, respetar `readiness()`, cooldown; trolls sin nuevos (M53, M54, M55) | `AdminTreadmillReveal.client.luau`; `AdminAbusePanelService.server.luau` | M | – |
| P1-8 | Anti-exploit: quitar Rebase de los pads y el atajo de MovementGuard (H10), tras un contador de rechazos legítimos; `UserOwnsGamePassAsync` en PromptGamePassPurchaseFinished (M39); tope a AdminTacoHit (M40); dev/tester por UserId (M41) | `MovementGuard.luau`; pads W1/W2/W3; `SpeedProductPurchases.server.luau:2625-2703` | M | Picos del leaderboard de Wins |
| P1-9 | Revive: flag atascado (M22), oferta con etapa, filtro y 8-10 s (M26), Infinite Revives dentro del prompt (H15) | `RevivePrompt.client.luau`; `SpeedProductPurchases.server.luau:2013-2159` | S | Conversión del revive |
| P1-10 | Streaming en teleports (M30), plano de vacío en W1/W2 (M31), reintentos de lease al entrar (M58) | `StageTeleportService.luau:136-139` y equivalentes; `Bootstrap.server.luau:357-371` | M | Muertes a <3 s del viaje; expulsiones |
| P1-11 | Rendimiento en teléfono: LOD de auras de otros (M6), WinPadText (M7/M11), Flight (M7), entrada diferida (M13) | `AuraSpecialEffectsClient.client.luau`; `WinPadTextDistance.client.luau`; `World*FlightAbility` | M | FPS en teléfono |
| P1-12 | Monetización: tarjeta de contenido del Starter Pack (M25), pase 2X Speed (M27), funnel de la ruleta (M28), cosméticos W3 solo en W3 (M47), investigar Secret Aura/Trail (M61) | `StarterPackOffer.client.luau`; `ShopController.client.luau`; `SpinWheelService.server.luau` | S-M | Conversión por SKU |

### P2: después

- Texturas superpuestas y mallas Precise (M10), con MicroProfiler antes y después (L).
- Rediseño del pacing: comprimir cosméticos, rebirth escalado, precios de viajes de W1, premios de la ruleta (M56, M57, M29) (L).
- "Continuar en World N" (M32), viaje con amigos y reintentos (L21).
- Regalos a destinatarios offline (M60) y cola de recibos (M59).
- DarkZonic comprable en el juego (M43). Cinta de evento que pague Wins en memoria (M3).
- Replicación de stats (M4), AnimationReplicationSync (M5), throttling de animación en A/B (M12), grupos de colisión (M48).
- Limpieza: código muerto (MonetizationService, ProductRegistry, AutoReconnect, PlayerStats), unificar allowlists de admin (L24), `HttpService` en PlayerStatsBridge (L32), tests que usan `audit/merged`.
- Telemetría: muertes por etapa/hazard/ping (L15), funnel del tutorial (L13), Onboarding_Ladder persistido (M35).

---

## 10. Qué no se pudo confirmar, afirmaciones falsas y lo que ya estaba arreglado

### 10.1 Qué mirar en Studio y Creator Hub

| Pregunta | Dónde | Por qué importa |
|---|---|---|
| Hora exacta de cada publish (09-12, 09-13, 09-16/17, 09-19, 09-21, 09-22) y **qué build está vivo** | Historial de versiones | Toda atribución depende de esto |
| D1, impresiones y DAU desde el 09-20 | Analytics | Tráfico o juego en el 09-21; efecto de los cambios del 09-20/22 |
| ¿`GetPartBoundsInBox` usa el AABB de una parte rotada? (barra de 132×3×2 a 45°, consulta a 30 studs) | Studio | Si es así, H4 es crítico |
| Warnings "DataStore request was added to queue", "Could not open the session", DataLoadFailed | Logs del servidor o informe completo de errores | Magnitud de H2, H3 y M58 |
| ¿Los huecos 1 y 5 de Stage 1 se cruzan a Speed 1 sin Sprint? | Studio | M49 |
| MicroProfiler en un Android medio: lobby lleno, recorrido, evento de tacos | Dispositivo | Render (texturas, auras) frente a scripts |
| Sound ids 10468691302 y 15898694877 (1.94M "not authorized" en total) | Buscar en los .rbxl | No están en `src` |
| ¿Cuántos dueños tiene el pase Rebirth 1979150655? ¿Está a la venta? | Creator Hub | Tamaño de H1 |
| Venta real y `IsForSale` de la escalera nueva (3710622733…) y de la de Wins (3710772221…, "Disabled" el 09-16) | Dashboard | L27, H14 |
| ¿Las tarjetas de Black Aura / Secret Trail se ven y cobran en teléfono? | Prueba en vivo | M61 |
| ¿Se puede falsificar `PromptGamePassPurchaseFinished`? | Prueba con una cuenta alternativa | M39 |
| CollisionFidelity de los árboles de W2, geometría bajo el spawn de W2 | Studio | Muertes en W2, jugadores atascados |
| ¿Se puede entrar directo a W2/W3 (seguir a un amigo)? | Ajustes del place | L2 |
| ¿Cada cuánto se usan las revelaciones y los trolls "All"? | No hay log; añadir evento | M53, M54 |

### 10.2 Afirmaciones de informes anteriores que resultaron falsas o inexactas

- **"Quest claimed 2.3%"**: artefacto del funnel v1. El real es 13.2% de quienes abren el panel (v2).
- **AFK v2 1.3%**: artefacto de id de sesión, ya corregido en `src`.
- **"Los IDs de place en Config son de prueba"** (nota de memoria): falso. Son los de producción; los de prueba están en `TestingPlaceIds`.
- **"4 pistas de ZoomArena precargadas"**: son 2 de ZoomArena más 2 de BossArea.
- **Cinta Admin/Taco "120 UpdateAsync/min por jugador"**: hoy no ocurre, porque el atributo se lee del cinturón anidado y la cinta no paga Wins (M3, comprobado en esta síntesis).
- **"El presupuesto de DataStore ya se excede"**: no está demostrado. AutoReconnect está muerto y los leaderboards usan OrderedDataStore, con presupuesto propio. No hay warnings de cola en el top 25.
- **"El 09-12 Update Logs encadenaba el Daily"**: falso para ese snapshot (el Daily solo se abría por evento).
- **"Starter Pack pasó de 7 a 50 R$ el 09-13"**: solo en Config. En vivo ya costaba 50 antes.
- **"El Daily se concede con GrantExact, sin multiplicadores"**: falso. Se multiplica antes (`DailyLoginSystem:396-405`).
- **"No hay aviso a mitad de sesión cuando el Daily está listo"**: falso. Existe el badge del topbar.
- **"El revive devuelve al lobby"**: falso. Va a la referencia de etapa más cercana. Es la muerte **sin** revive la que resetea a Stage 1.
- **"La oferta de revive dura 10 s"**: en pantalla dura 15 s, porque `math.max(15, Config 10)` pisa el valor de Config.
- **"Aura04 tiene ThemeColor duplicado"**: refutado.
- **"La caminata de 2.67 tras un rebirth en W2 fue una regresión"**: ya existía en la OG. Se corrigió el 09-22.
- **Contradicción OOM** (−27% total frente a +59% por CCU de teléfono): los dos datos son ciertos, pero las ventanas no son comparables (viernes/sábado frente a lunes) y los conteos son pequeños o parecen tener un suelo.
- **"El 09-21 es solo tráfico"** frente a **"es el publish"**: ninguna de las dos está probada sin impresiones posteriores al 09-20.
- **"La física del salto empeoró el 09-13"**: falso. Es idéntica a la OG y mejoró el 09-18 (se quitó `airStartRestricted`).

### 10.3 Ya arreglado en `src` (verificado; su publicación depende de P0-1)

Caché negativa de zonas seguras (`SpeedProductPurchases:440-477`); gate de StageDecor en W3 (`:28-31`); láseres de W3 y obstáculos de W1 dirigidos por el cliente (excepto los fades de puente y tobogán); `CameraPunch.Punch` eliminado (`IMC:942-944`); raíz nil en ASMR (`:142`); ids de sonidos de taco y de la animación GetUp vacíos, con guard (`AdminAbuseEffects:2535-2540`, `R6DeathRagdoll:72-87`); `nearestTreeDistance` y `refreshHudButton` declarados antes de uso; `setTrailOwned` declarado antes de uso (`TrailShopSystem:90`); guard de RemoteGuard en EquipSkin; exploit de precio de teleport (`WinsMath.GetStageTripPrice`, `TeleportSystem:40-54`); LOD de teléfono en auras y en el VFX de cintas (un emisor); Bloom, SunRays, DoF y Highlights del lobby apagados en teléfono; Update Logs ya no aparece en cada entrada; limpieza de afterimages; AnimationReplicationSync republica solo al entrar; parches B/C/D del 09-20 (LatestStateLimiter, PeekSpeed y notify coalescido, StaminaSync unreliable) y parche A (queda abierto `PreferLodEnabled=false`); mínimo de 8 aplicado después de la escala de mundo; funnel AFK v2; `airStartRestricted` eliminado (09-18). `PlayerStats` legado y `AutoReconnect` confirmados como código muerto.

**Siguen abiertos del informe del 09-20**: `PreferLodEnabled=false`, `RawSpeed` replicado dos veces, spam de prints del revive, 2,177 líneas muertas de PlayerStats y pacing de rebirth sin cambios.
