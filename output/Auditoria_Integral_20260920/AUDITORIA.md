# Speedster Escape — Auditoría integral (código, red/lag, retención, core loop)

Fecha: 2026-09-20. Fuentes: `src/` (382 fuentes Luau, todas compilan), los tres `.rbxl` de la raíz (leídos con Lune) y 48 CSV de `DataAnalysis/` (datos hasta el 18–19/09).
Nada de esta auditoría modificó el juego. Los parches están en [`patches/`](patches/), compilados con el compilador Luau; el limitador (parche B) además tiene prueba de comportamiento. **Ninguno está aplicado ni probado en Studio.**

Rutas abreviadas: `SSS/` = `src/common/ServerScriptService/`, `SPS/` = `src/common/StarterPlayer/StarterPlayerScripts/`, `W1/` = `src/worlds/World1/`.

---

## 0. Lo esencial

1. **El 13/09 se rompió algo con el mismo tráfico.** Ese día el DAU *subió* (308K → 332K) y a la vez: sesión media 11,4 → 9,0 min, pagadores 3.112 → 1.446, conversión 1,01 % → 0,44 %, D1 de la cohorte 13,5 % → 6,7 %. El ARPPU *subió* (48 → 75 → 117 R$): dejaron de comprar los compradores pequeños, no las ballenas. Tres productos baratos de alto volumen pasaron a **cero ese mismo día**: x2 Speed, x4 Speed y x10 Speed (17,8K R$/día el 12/09, el 12 % del ingreso). Los IDs nuevos (x2…x32 a 20/40/80/160/320 R$) no recuperaron ese ingreso.
2. **La primera sesión no es el problema principal; el regreso sí.** 67 % de los nuevos sigue a los 5 min y 49,5 % a los 10 (mediana de primera sesión ≈ 10 min). Pero D1 ≈ 15 % en su mejor semana y D7 ≈ 1–2 %. El rebote grande está en los **primeros 90 segundos** (−15,3 pts; riesgo máximo entre los 30 y 90 s) y luego el riesgo de abandono **vuelve a subir desde el minuto 5** en vez de bajar: el bucle deja de dar novedades justo cuando el ciclo de rebirth pasa de <4 min a 14–50 min.
3. **Red: el servidor de World 1 mueve ~130–157 piezas del mapa a 30 Hz** (`NewWorld1ServerMotion`), y cada `part.CFrame = …` se replica a todos los clientes. El CSV de rendimiento lo respalda: **4,5 ms por frame de CPU de cliente en "Networking"** (un tercio del total de 13,6 ms), con 26 FPS medios en teléfono (63 % de los concurrentes).
4. **Con `MaxPlayers = 60` hay dos costes O(N²):** `AnimationReplicationSync` hace que *cada respawn* obligue a los 60 clientes a re-publicar su animación (~7.000 eventos de animación por muerte), y la proyección de stats replica ~8 cambios × 2 Hz × 60 jugadores ≈ 960 cambios/s a cada cliente.
5. **Varias premisas del encargo ya no son ciertas** (sección 1). Importa decirlo para no gastar tiempo ahí.

---

## 1. Premisas del encargo que verifiqué y NO se cumplen

| Premisa | Lo que hay en el código |
|---|---|
| `BoostState`/`WalkSpeedModeRequest` conectados a la vez en `Bootstrap` y `PlayerStats` (carrera) | **No corren a la vez.** `SSS/Progression/PlayerStats.server.luau:9-12` hace `return` si el backend modular está activo (`Config.UseModularDataService = true`, `Config.luau:1156`). Son 2.177 líneas de código muerto que se envían en los tres places. No hay doble escritor ni doble Heartbeat. |
| `SetAttribute("BoostStamina")` a 60 Hz | **Ya está limitado a 4 Hz** (`Bootstrap.server.luau:110, 138-160`), con `if ~= value`. Quedan 2 atributos × 4 Hz que llegan a *todos* los clientes (parche D, P2). |
| Partes `Anchored = false` flotando en Workspace | **Cero partes sin anclar** en los tres places (4.686 / 8.045 / 14.720 partes). |
| Loop de correr a 10 Hz | `Config.TrainingTickSeconds = 0.5` (`Config.luau:688`): **2 Hz**. El `or 0.1` de `Bootstrap:543` no se usa. Todas mis cifras usan 2 Hz. |
| Tablas por jugador sin limpiar en `TreadmillTraining` | Falso positivo: son locales de cada iteración (`:1130-1132`). Las tablas por jugador del servidor usan `__mode = "k"` o se limpian en `PlayerRemoving`. |
| Llamadas a `TeleportService`/`MarketplaceService` sin `pcall` | No encontré ninguna que pueda lanzar sin `pcall`. Solo `DataStoreService:GetDataStore(...)` a nivel de módulo (no cede ni falla en producción; sí en un Studio sin acceso a API). |
| Streaming (`MinRadius 64`, `PauseOutsideLoadedArea`) | **Ya corregido** en los tres places: 512 / 1024 / `Disabled` / `LowMemory`. |
| Funnels | Los 9 CSV solo tienen datos de **un día (19/09)** y sin nombres de paso. Son los funnels v1; los v2 descontaminados ya existen en `FunnelAnalytics.luau:84-120` pero aún no hay datos suyos. |

---

## 2. FASE 1 — Bugs y arquitectura

**2.1 Camino caliente del speed (servidor).** Cada tick de speed de cada jugador que corre o entrena:
`Bootstrap:493` `Inspect` → `PlayerStatsBridge:100` `Inspect` → `SessionActor:525` `_notifySubscribers` → `PlayerStatsBridge:116` `Inspect`. Cada `Inspect`/`_buildView` hace **`deepCopy(self.profile)`** (`SessionActor.luau:216`): perfil completo con hasta 200 recibos + ids de operación. Son 4 copias profundas + 1 `StatsProjection.Project` completo (`StatsProjection.luau:94-313`: ~70 comparaciones de atributos, 4 `GetChildren`, `syncStringList` O(n²) con `table.find`, búsquedas en `CosmeticCatalog`, `1.5 ^ r`, escritura de `WalkSpeed`) para sumar un número. A 60 jugadores: ~480 copias y ~120 proyecciones por segundo, más basura para el GC. No tumba el servidor, pero es CPU y GC gastados en el peor sitio. → Parche C.

**2.2 Remotos de estado sin límite.** `Bootstrap.server.luau:175` (`WalkSpeedModeRequest`) y `:225` (`BoostState`) son los únicos remotos de alto tráfico sin limitador ni comprobación de `DataLoaded`. Cada `WalkSpeedModeRequest` numérico hace 2 `SetPreference` (2 proyecciones completas) + 1 `Inspect`: un cliente que lo dispare en bucle satura el servidor para los 60. `RemoteGuard` no sirve aquí porque *descarta* llamadas y un toque rápido de Shift (true→false en 30 ms) dejaría al jugador esprintando. → Parche B (limitador "gana el último").
Sin límite pero baratos (P2): `RebirthSystem.server.luau:252` (`"Sync"`), `DailyLoginSystem.server.luau:431` (`"Refresh"`), `SkinSystem.server.luau:2237` (`"RequestState"`). El resto de los 44 handlers ya usa `RateLimiter.Allow`, `RemoteGuard` o un cooldown propio y valida tipos.

**2.3 Código muerto y ruido.** `PlayerStats.server.luau` (2.177 líneas, inactivo). `SpeedProductPurchases.server.luau:2517` hace `print` en cada evento de `ReviveCommerce` (spam de log en un juego donde se muere constantemente). `RotatingLaser.server/.client` inactivos en W1 nuevo y W2.

**2.4 Ciclo de vida.** `Workspace.PlayerCharacterDestroyBehavior = Default` en los tres places. Conviene fijarlo en `Enabled` explícitamente: `Bootstrap:36` conecta `character.DescendantAdded` en cada spawn y depende de que el personaje viejo se destruya para soltar la conexión.

**2.5 Onboarding (hallado al auditar D1).** `SPS/UI/UpdateLogsController.client.luau:338-341` abre el panel de Update Logs **en cada entrada, para todos**, 0,25 s después de cargar; no consulta `LastSeenUpdateLog` aunque el servidor lo guarda. Al cerrarlo abre Daily Reward. Un jugador nuevo recibe dos modales antes de poder moverse, dentro de la ventana de mayor rebote.

---

## 3. FASE 2 — Red, latencia y lag

Evidencia de cliente (CSV 18–19/09, intervalos de 30 min): FPS medio **Teléfono 26,3** (63 % de concurrentes), Tablet 30,8 (21 %), PC 36,6, Consola 48,6. CPU de cliente 13,6 ms/frame: Scripts 5,0 (pico 31), **Networking 4,5 (pico 13,2)**, Física 2,0, Animación 0,8. Memoria en teléfono 0,90 GB; ~150 salidas por falta de memoria al día (irrelevante frente a 130K DAU); crash 0,5 %. **El cuello es CPU de red + scripts, no memoria.**

| # | Fuente | Tráfico estimado (por cliente) | Base de la estimación |
|---|---|---|---|
| 1 | `W1/ServerScriptService/Gameplay/NewWorld1ServerMotion.server.luau:90` (30 Hz), `:474-491` (`part.CFrame =`), `:1887-1910` | **30–110 KB/s** mientras esas etapas están cargadas | 52 piezas de martillos + 12 de láser + cilindro en movimiento continuo; 63 de prensas, slides, "fast" y lava intermitentes. ~25–30 B por CFrame × 20–30 envíos/s. El presupuesto habitual de Roblox ronda 50 KB/s por cliente. |
| 2 | Proyección de stats (`StatsProjection`, `LevelProgress:146-158`, `CharacterStatsAdapter:68-71`) | ~20–30 KB/s con 60 jugadores | 8 cambios replicados por tick (`leaderstats.Speed`, `RawSpeed` valor + atributo, `LevelProgress` valor + atributo, `Humanoid.WalkSpeed`, `RealWalkSpeedMax`, `RealWalkSpeedSelected`) × 2 Hz × 60. El mismo número viaja tres veces. |
| 3 | `SSS/Infrastructure/AnimationReplicationSync.server.luau:45-57, 95-96` + `StarterCharacterScripts/R15SpeedsterRun.client.luau:559-583` | ráfagas: 2×N remotos + 2×N×(N−1) eventos de animación **por respawn** | El script es de personaje: dispara `ObserverReady` en cada spawn; el servidor responde con `FireClient` a todos, dos veces; cada cliente para y relanza su pista, que se replica a los demás. N = 60 → ~7.000 eventos por muerte. |
| 4 | Stamina (`Bootstrap:138-160`) | 8 cambios/s por jugador que esprinta o regenera, a todos | Atributos de `Player` = replicados a todos. Nadie más dibuja tu barra. |

Son **estimaciones de orden de magnitud**; no tengo captura de red. Para medir: en un servidor lleno de W1, `Shift+F3` (Recv KB/s) y MicroProfiler (`Replicator`), antes y después.

**Solución autoritativa para #1 (la de más impacto, y la única que no es un parche pequeño).** El movimiento ya es una función determinista de `Workspace:GetServerTimeNow() - motionStartServerTime`. El servidor debe **dejar de escribir CFrames**: publica una vez `motionStartServerTime` como atributo del mapa, cada cliente calcula la misma pose en `RenderStepped` solo para los obstáculos cargados, y el servidor conserva sus comprobaciones letales con pura matemática (`checkPlayerContact` ya barre posiciones, no necesita las piezas movidas). Es exactamente la arquitectura de World 3 (`Motion` compartido + `World3Hazards` que valida) y de los Tree Slammers de W2. Resultado: 0 B/s de movimiento, obstáculos a 60 FPS sin tirones y sin desfase por ping. Requiere sesión propia con playtest: toca la detección de muerte. Paliativo de un día si hace falta: bajar `SERVER_MOTION_INTERVAL` a 1/15 (la mitad de tráfico, movimiento más brusco).

**Render y física de cliente.** Los scripts por frame del cliente están razonablemente cuidados (`LOW_POWER` en afterimages, `CanQuery/CanTouch=false` en clones). Lo que sí pesa:
- **World 3: `Lighting.GlobalShadows = true` con ShadowMap y 14.720 partes** (W1 y W2 lo tienen en `false`). En teléfono es el ajuste más caro del place.
- **Texturas como instancias:** W1 8.682 y W3 **18.687** `Texture/Decal` (W2: 103). Pesan en memoria, en el envío por streaming al entrar en cada zona y en draw calls.
- **`CanTouch`/`CanQuery` en casi todo:** W3 13.473 de 14.720 partes, W1 4.665 de 4.686 (W2, ya optimizado: 1.432 de 8.045). Apagar ambos en decoración reduce el coste de `Touched`, raycasts y `GetPartBoundsInBox`.
- `AnimationReplicationSync:28` pone `PreferLodEnabled = false` a todos los Animators: con 60 personajes quita el ahorro de animación a distancia justo en móviles.
- `R15SpeedsterRun:846-852`: `clearAfterimages()` hace `GetChildren()` en cada Heartbeat mientras no se esprinta (asignación por frame; trivial de evitar con un contador).
- W2 conserva 57 scripts dentro de Workspace (25 del kit ASMR, 6 con Heartbeat propio en servidor).

---

## 4. FASE 3 — Retención y métricas reales

**4.1 Serie D1.** 6 % (11/08) → 16–18 % (24/08–04/09, mientras el DAU pasaba de 10K a 330K) → 13,5–16 % (05–12/09) → **6,7 % (cohorte del 13/09)** → 8,3–11,3 % (14–17/09). Medias: 15,0 % (cohortes 06–11/09) frente a 9,6 % (12–17/09). Hay dos escalones: uno leve el 05/09 (18,3 → 13,6 %, coincide con el pico de tráfico de 393K DAU: mezcla de tráfico más fría) y el del 13/09, que **no** es mezcla de tráfico porque cayeron a la vez la sesión de todos (−25 %) y el gasto.
**D7.** 2,0–2,5 % (cohortes 22–29/08) → ~1,0 % (desde la cohorte del 31/08) → 0,8 % (cohortes 07–11/09, cuyo día 7 cae después del 13/09). **D30:** 1–3 %, casi igual que D7: quien llega al día 7 se queda; el agujero está entre el día 1 y el 7.

**4.2 Primera sesión (agregado 22/08–18/09).** Riesgo de abandono por cada 30 s (de los que seguían):

```
0-30s 4,9% | 30-60s 5,6% | 60-90s 5,7% | 90-120s 4,8% | 2-3min 4,0→3,4% | 4-5min 2,6% (mínimo)
5-6min 2,7% | 8min 3,1% | 10min 3,5% | 12min 3,7% | 15-25min 3,6-3,8% (meseta)
```
- **Primer gran rebote: segundos 30 a 90.** A los 2 min ya se fue el 19,3 %; a los 3 min el 25 %. Es la ventana de pantalla de carga → Update Logs → Daily Reward → oferta de Starter Pack → tutorial.
- **Segundo problema, menos visible: el riesgo sube desde el minuto 5 y no vuelve a bajar.** En un bucle sano el riesgo decrece con el tiempo invertido. Aquí coincide con el salto del ciclo de rebirth (sección 5).
- Esta curva es un agregado de 28 días: **no** sirve para diagnosticar el 13/09.

**4.3 Monetización.** Semana 5–11/09 frente a 12–18/09: pagadores diarios −64,5 %, ingresos −37 %, productos de desarrollador **−57 %**, pases −24 % (≈ −1 % por usuario: los pases aguantan). Por producto (media 06–12/09 → 13–18/09, R$/día):

| Producto | Antes | Después | |
|---|---:|---:|---|
| x10 / x4 / x2 Speed (IDs antiguos) | 9.686 / 4.421 / 4.147 | **0 / 0 / 0** | retirados el 13/09 |
| Speed Tier 4 (79 R$, +1000 %) | 9.170 | 2.777 | −70 % |
| Secret Aura / Secret Trail | 4.554 / 4.788 | 966 / 1.491 | −79 % / −69 % (la tienda de cosméticos estuvo rota esos días) |
| Revive (7 R$) | 7.218 | 3.630 | −50 % |
| Flight | 4.500 (producto) | 1.770 (pase, 799 R$) | migración de formato: −61 % |
| 2x Wins (pase) | 1.442 | **0 los días 13–15/09**, luego ~1.000 | tres días sin venderse: botón o pase roto |
| Starter Pack | 2.300 | 1.155 (560 el 13/09) | −50 % |
| "Other" (incluye los IDs nuevos) | 22.527 | 21.558 | **no absorbió** los 18K de los multiplicadores retirados |
| Hacker / Valentine / Admin Treadmill | 25.075 / 9.197 / 6.880 | 19.286 / 6.500 / 5.060 | −23…−29 %, en línea con el DAU |

Lectura: la escalera nueva arranca en **20 R$** donde la antigua arrancaba en unos pocos Robux (3/7/19 según el place OG; es referencia de código, no prueba del precio cobrado). Se perdió la *primera compra barata*, que es la que convierte a un jugador en pagador: por eso cae la conversión (−56 %) y sube el ARPPU. Las treadmills de pase (43 % del ingreso) no están afectadas; no tocar sus precios.

**4.4 Funnels, descontaminados.** Regla de Roblox: un paso posterior completa los anteriores. Con un solo día de datos, esto es lo único que se puede afirmar:

| Funnel (v1) | Dato bruto | Lectura honesta |
|---|---|---|
| Revive: Shown → Purchased 94,4 % → Dismissed 93,9 % → TimedOut 29,7 % | "94 % compra" | Los tres finales son excluyentes y cada uno arrastra al anterior. Restando: **compras ≈ 94,38 − 93,87 = 0,5 % de las ofertas**, cierre manual ≈ 64 %, expiración 29,7 % (real), sin resolver 5,6 %. **Artificial.** |
| Onboarding paso 6 (World2) = 1,54 % | "98 % abandona" | Cohorte de un día e inmadura: nadie llega a 7 rebirths + nivel 100 en su primer día salvo compradores. Ni confirma ni desmiente el muro. **No interpretable aún.** |
| Rebirths: Threshold → Executed 65,5 % → World3 0,3 % | | El 65,5 % apenas está contaminado (solo por el 0,3 %). **Fricción real: un 34 % de las veces que el rebirth está disponible, no se ejecuta en esa sesión.** Probable causa: miedo a perder progreso o botón no visto. |
| Starter Pack: Click 100 % → Prompt 100 % → Compra 0,24 % | | Clic y prompt son el mismo gesto. **0,24 % de los que tocan el icono compran:** muchos toques accidentales en móvil y/o rechazo al precio de 50 R$. Real. |
| Spin: Open → Free 92 % → PaidPrompt 5,5 % → Paid 0,065 % → WinsSpin 0,042 % | | El paso 4 incluye al 5. **Compra real ≈ 0,023 % de las aperturas; 0,4 % de los prompts.** |
| Quests: 7,8 % → 7,3 % → 7,29 % | | Tres pasos casi iguales = autocompletado por el reclamo. Solo es fiable "≈7 % de aperturas acaban en reclamo". |
| AFK: Open → Start 50 % → Reward 4,8 % → Exit 2,3 % | | "Exit" es el último paso y arrastra a Reward. No fiable. |

---

## 5. FASE 4 — Core loop

**5.1 Modelo de ritmo** (`scratch/fb_audit_pacing.py`; constantes de `LevelProgress`, `StatsService.NextRebirthRequirement` = nivel 5 + 15·r, multiplicador 1,5^r, trajes de `SuitCatalog`/`Config`, treadmills gratis 1/3/5/10 en 0/1/3/7 rebirths, tick 0,5 s). Es un **modelo**: jugador gratuito que entrena sin parar, evoluciona y hace rebirth en cuanto puede. No está contrastado con telemetría.

| Rebirth nº | Nivel pedido | Ciclo sin cosméticos | Acumulado | Ciclo con aura+trail naranja (×6,25, 20 Wins) | Acumulado |
|---:|---:|---:|---:|---:|---:|
| 1 | 5 | 0,1 min | 0,1 min | — | — |
| 2 | 20 | 0,6 min | 0,7 min | 0,1 min | 0,1 min |
| 3 | 35 | 1,6 min | 2,2 min | 0,2 min | 0,4 min |
| 4 | 50 | 3,8 min | 6,0 min | 0,6 min | 1,0 min |
| 5 | 65 | **13,6 min** | 19,6 min | 2,2 min | 3,1 min |
| 6 | 80 | **51 min** | 71 min | 8,2 min | 11,3 min |
| 7 | 95 | **4,4 h** | 5,6 h | **42 min** | 53 min |
| World 2 | 100 | 2,5 h | **8,1 h** | 24 min | **78 min** |

- Cada ciclo exige ×7,9 más speed (1,1477^15) y el rebirth solo da ×1,5 más un escalón de traje: **cada ciclo dura ×3–5 el anterior.** Los cuatro primeros rebirths caben en 6 minutos y el quinto ya cuesta 14. Ese codo cae en el minuto 5–20, donde la curva real empieza a perder más gente cada 30 s.
- **¿Es World 2 un muro que expulsa antes de la segunda sesión? Para quien no descubre auras y trails, sí: 8 horas frente a 17 min de juego medio diario.** Para quien compra la aura y el trail naranja (20 Wins en total), son ~80 min: alcanzable en 3–5 días. La diferencia entre ambos mundos es un ×6,25 que el juego no enseñaba si la guía del primer aura no aparecía — y no aparecía a quien entrenaba más de 102 s antes de tocar el pad (corregido hoy en `TutorialFlow`).
- El funnel real lo respalda parcialmente: 34 % de rebirths disponibles no ejecutados.
- Al llegar a W2 el jugador baja de treadmill ×10 a ×10 "Starter" con Candy a 9 rebirths y su WalkSpeed queda en un tercio (`Config.World2WalkSpeedMultiplier = 1/3`): llegar al mundo nuevo se siente como un castigo. El análisis del 19/09 ya lo señaló y lo mantengo.

**Recomendación de balance (una variable cada vez, con test A/B):** no tocar el multiplicador de las treadmills de pago. Suavizar la escalera gratuita a un escalón por rebirth (1 → 2 → 3 → 5 → 7 → 10 → 10) y subir el multiplicador de rebirth de 1,5 a 2,0 *solo* para los rebirths 4–7. Objetivo: que ningún ciclo anterior a W2 dure más de ~2× el anterior (rebirth 7 en ~15–20 min con cosméticos, ~90 min sin ellos).

**5.2 Feedback sensorial.** Lo que hay es bueno para el público: popups de speed por tick con sonido escalado por tier, confeti de nivel, afterimages al esprintar, banner de Level Up con shake, cinemática de portal. Lo que falta está en los momentos de *decisión*, no en los de recompensa:
1. **Equipar un aura no muestra el salto.** El ×2,5 no se ve en ningún número grande en el momento. Debe haber un "×2.5 SPEED!" con el contador de speed/s pasando de N a 2,5N.
2. **El rebirth se siente como pérdida.** El nivel vuelve a 1 y la barra se vacía; lo ganado (×1,5, treadmill nueva, traje) no se presenta. Pantalla de "antes/después" de 2 s con lo que se conserva y lo que se gana.
3. **No hay objetivo de sesión visible.** Tras el tutorial el HUD no dice qué es lo siguiente ("Rebirth 3 → traje Zoom", "20 Wins → aura"). Es la causa más probable de la subida de riesgo desde el minuto 5.

---

## 6. ENTREGABLE 1 — Matriz de priorización

| Sev. | Archivo : línea | Problema | Impacto | Solución |
|---|---|---|---|---|
| **P0** | Creator Hub + `Config.luau:936-941` | Desde el 13/09 los productos x2/x4/x10 Speed venden 0 y los IDs nuevos (desde 20 R$) no los reemplazan; conversión −56 %. "2x Wins" vendió 0 del 13 al 15/09. | ~18K R$/día directos y la pérdida de la primera compra barata. | Verificar en vivo cada ID nuevo (botón visible en móvil → prompt correcto → recibo concede). Probar primer escalón a 9 R$ frente a 20. Revisar por qué el pase 2x Wins estuvo 3 días a cero. |
| **P0** | `W1/…/NewWorld1ServerMotion.server.luau:90, 474-491, 1887` | El servidor escribe el CFrame de ~130–157 piezas a 30 Hz; todo se replica. | 30–110 KB/s por cliente en W1; 4,5 ms/frame de CPU de red; obstáculos con tirones y desfase por ping (muertes "injustas"). | Movimiento determinista en cliente desde `GetServerTimeNow()`; el servidor valida con matemática (patrón de W3). Sesión propia con playtest. |
| **P0** | `SSS/Infrastructure/AnimationReplicationSync.server.luau:45-57, 95-96` | Cada respawn hace re-publicar la animación a los N clientes, dos veces. O(N²) por muerte. | Con 60 jugadores ~7.000 eventos de animación por muerte; picos de red y de CPU de animación en todos. | **Parche A**: re-publicar solo cuando llega un observador nuevo (primer personaje de la sesión) + límite de 1 `ObserverReady`/2 s. |
| **P0** | `SPS/UI/UpdateLogsController.client.luau:338-341` | Update Logs se abre en cada entrada para todos, también jugadores nuevos; al cerrar abre Daily. | Dos modales en los segundos 0–30, la ventana de mayor rebote (−15 pts en 90 s). | No abrir si `FirstTimeTutorialSeen ~= true`; para el resto solo si `LastSeenUpdateLog < PlaceVersion` (el servidor ya lo guarda). Daily tras el primer Win pad. |
| **P1** | `SSS/Services/Data/SessionActor.luau:216, 525`; `SSS/Progression/PlayerStatsBridge.luau:100, 116`; `SSS/Bootstrap.server.luau:493` | 4 `deepCopy` del perfil + 1 proyección completa por tick de speed y jugador. | ~480 copias y ~120 proyecciones/s con 60 jugadores; presión de GC. | **Parche C1–C3**: `PeekSpeed` sin copia y notificación coalescida a 1 s. |
| **P1** | `SSS/Services/Stats/StatsProjection.luau:112-145, 281`; `SSS/Progression/LevelProgress.server.luau:146-158` | El mismo speed se replica 3 veces y `LevelProgress` 2 veces, a todos, en cada tick. | ~960 cambios/s por cliente con 60 jugadores (~20–30 KB/s). | **Parche C4** + quitar el atributo `RawSpeed` o el `NumberValue` duplicado tras migrar lectores. −69 %. |
| **P1** | `SSS/Bootstrap.server.luau:175, 225` | `WalkSpeedModeRequest` y `BoostState` sin límite ni `DataLoaded`; el primero hace 2 proyecciones + 1 copia por llamada. | Un cliente en bucle degrada el servidor de 60. | **Parche B** (limitador que conserva el último estado; probado). |
| **P1** | `World3Update3New.rbxl` → `Lighting.GlobalShadows = true` | Sombras globales con 14.720 partes; W1/W2 las tienen apagadas. | FPS en teléfono (26 de media). | Apagarlas como en W1/W2 o por plataforma. |
| **P1** | `SSS/Progression/RebirthSystem` + `StatsService.luau:650-655`, `StatsProjection.luau:279` | Ciclo de rebirth ×3–5 más largo cada vez; codo en el minuto 5–20. | Riesgo de abandono creciente desde el minuto 5; W2 a 8 h para quien no usa cosméticos. | Sección 5.1: escalera gratuita por rebirth y ×2,0 en rebirths 4–7, con A/B. |
| **P2** | `SSS/Bootstrap.server.luau:138-160` | Stamina (2 atributos × 4 Hz) replicada a todos. | Hasta ~240 cambios/s por cliente. | **Parche D**: `UnreliableRemoteEvent` solo al dueño; el cliente escribe el atributo en local. |
| **P2** | `AnimationReplicationSync:28` | `PreferLodEnabled = false` en todos los Animators. | CPU de animación en móvil con 60 personajes. | Dejar el LOD activo para personajes ajenos a más de ~80 studs. |
| **P2** | W1 8.682 y W3 18.687 `Texture`; `CanTouch/CanQuery` en ~todas las partes de W1/W3 | Memoria, streaming y consultas espaciales. | Entrada a zonas y FPS en móvil. | Pasar studs a `MaterialVariant`/textura en malla; apagar `CanTouch`/`CanQuery` en decoración (como se hizo en W2). |
| **P2** | `RebirthSystem:252`, `DailyLoginSystem:431`, `SkinSystem:2237` | Acciones de "refresco" sin límite. | Spam barato. | `RateLimiter.Allow(player, key, 0.5)`. |
| **P2** | `SSS/Progression/PlayerStats.server.luau` (2.177 líneas), `RotatingLaser.*` | Código muerto enviado en los tres places. | Tamaño, confusión (de ahí la premisa de los handlers duplicados). | Retirar como stub con comentario. |
| **P2** | `SSS/Economy/SpeedProductPurchases.server.luau:2517` | `print` por cada evento de revive. | Ruido de log. | Quitar o condicionar a Studio. |
| **P2** | Workspace de los 3 places | `PlayerCharacterDestroyBehavior = Default`. | Posibles conexiones colgadas por personaje. | Fijar `Enabled`. |
| **P2** | `StarterCharacterScripts/R15SpeedsterRun.client.luau:846-852` | `GetChildren()` por frame para limpiar afterimages inexistentes. | Basura por frame. | Limpiar solo si un contador > 0. |

---

## 7. ENTREGABLE 2 — Plan para D1: tres cambios en los primeros 3 minutos

Antes, una precisión: de los ~5,4 puntos perdidos (15,0 → 9,6 %), la mayor parte llegó el 13/09 junto con una sesión un 25 % más corta para *todos*. **Recuperar esos puntos es sobre todo publicar y verificar los arreglos ya hechos desde el 16/09** (tienda de cosméticos, entrenamiento, vuelo, IDs de multiplicadores), no añadir sistemas. El 17/09 la cohorte ya estaba en 11,3 %. Los tres cambios de abajo apuntan a subir *por encima* del 15 %; +5 a +10 puntos es un objetivo, no algo que los datos permitan prometer.

1. **Segundos 0–30 — cero modales para el jugador nuevo.** Quitar Update Logs y Daily Reward de la primera sesión hasta el primer Win pad; el Starter Pack solo como icono, sin ocupar el centro. Personaje en movimiento y flecha del tutorial visibles en <5 s tras la carga. *Dato:* el 15,3 % se va en los primeros 90 s y el riesgo máximo está entre los 30 y los 90 s. *Medir:* supervivencia a 60 s (hoy 89,8 %) y a 120 s (80,7 %); meta 92 % y 85 %.
2. **Segundos 30–120 — el primer "salto de poder" garantizado antes del minuto 2.** Treadmill → primer Win pad → guía del aura (ya corregida hoy para que salga siempre) → al equiparla, celebración con el número: "×2.5 SPEED" y el speed/s duplicándose en pantalla. Primer rebirth presentado como ganancia (antes/después), no como reinicio. *Dato:* con aura + trail naranja el camino a World 2 baja de 8 h a 78 min; es la decisión que más cambia la experiencia y hoy depende de que el jugador abra la mochila por su cuenta.
3. **Minuto 2–3 — sembrar el motivo para volver mañana, con nombre y hora.** Un objetivo de sesión fijo en el HUD ("Rebirth 3 → traje Zoom") y, al completar la guía, una tarjeta "Mañana: [premio del día 2] + giro gratis en 11:42 h" con el premio visible y bloqueado. Ya existen login de 30 días y giro cada 12 h; falta enseñarlos en la primera sesión, no al volver. *Dato:* la mitad de los nuevos juega 10+ min y aun así solo vuelve el 15 %: no les falta diversión inicial, les falta una promesa concreta.

*Cómo evaluarlo:* un cambio por publicación, comparar cohortes de los mismos días de la semana, mínimo 7 días. D1 y supervivencia a 60/120/300 s como métricas primarias; sesión media y conversión como protección.

---

## 8. ENTREGABLE 3 — Correcciones Luau

En [`patches/`](patches/). Compilan; **no están aplicadas**. Tras aplicar C hay que pasar `audit/persistence/test_regression.luau` y `audit/test_new_persistence.luau` (tocan `SessionActor`).

| Parche | Archivo | Qué hace | Efecto esperado |
|---|---|---|---|
| **A** | [`A_AnimationReplicationSync.server.luau`](patches/A_AnimationReplicationSync.server.luau) | Reemplazo completo. Re-publicación solo por *entrada* de jugador, no por respawn; el observador no se re-publica a sí mismo; 1 `ObserverReady` cada 2 s. | De 2·N remotos + 2·N·(N−1) eventos **por muerte** a 2·(N−1) remotos **por entrada**. |
| **B** | [`B_LatestStateLimiter.luau`](patches/B_LatestStateLimiter.luau) | Módulo nuevo + uso en `Bootstrap:175, 225`. Primera llamada inmediata, las demás se colapsan y **la última se ejecuta al cerrar la ventana**. Probado: 502 llamadas → 2 ejecuciones, estado final correcto. | Un cliente que inunde cuesta 1 ejecución por ventana. No rompe el toque rápido de Shift. |
| **C** | [`C_SpeedHotPath.luau`](patches/C_SpeedHotPath.luau) | `SessionActor:PeekNumber` / `DataService.PeekSpeed` (sin copia), notificación coalescida a 1 s solo para `AccrueSpeed`, `SpeedsterAddSpeed` sin `Inspect`, `LevelProgress` como atributo solo al cambiar de nivel o cada 2 s. | Copias −88 %, proyecciones −50 %, cambios replicados −69 %. La barra del dueño sigue fluida por el remoto. |
| **D** | [`D_OwnerOnlyStamina.luau`](patches/D_OwnerOnlyStamina.luau) | Stamina por `UnreliableRemoteEvent` solo al dueño; un LocalScript de 12 líneas escribe los mismos atributos en local, así HUD, vuelo y Sonic Burst no cambian. Los extremos de la barra (0 y máximo) siguen yendo fiables. | Elimina ~8 cambios/s por jugador activo hacia los otros 59. |

El bloque central de C, como referencia:

```lua
-- SessionActor.luau
function SessionActor:PeekNumber(field: string): number
	local value = self.profile and self.profile[field]
	return if type(value) == "number" then value else 0
end

local SPEED_NOTIFY_SECONDS = 1.0 -- el tick de speed es 0,5 s: la ventana debe ser mayor
function SessionActor:_notifySubscribersCoalesced()
	if typeof(task) ~= "table" or type(task.delay) ~= "function" then
		self:_notifySubscribers() -- Lune: síncrono y determinista
		return
	end
	if self._speedNotifyScheduled then return end
	self._speedNotifyScheduled = true
	task.delay(SPEED_NOTIFY_SECONDS, function()
		self._speedNotifyScheduled = false
		if self.profile and (self.state == "Ready" or self.state == "Ephemeral") then
			self:_notifySubscribers()
		end
	end)
end
-- en AccrueSpeed (línea 525): self:_notifySubscribersCoalesced()
```

Riesgo conocido de C: `Level`, `RawSpeed` y `WalkSpeed` visibles para otros scripts del servidor pueden ir hasta 1 s por detrás del perfil. `Commit` (rebirth, compras) sigue notificando al instante, y la comprobación de rebirth debe leer el perfil, no el atributo. Revisarlo al aplicar.

---

## 9. Límites de este análisis

- Sin captura de red ni MicroProfiler: los KB/s son estimaciones con sus supuestos a la vista.
- El modelo de ritmo supone entrenamiento continuo y multiplicadores multiplicativos; no incluye tiempo corriendo ni auras mejores que la naranja.
- Los CSV no traen tamaño de cohorte, plataforma por cohorte ni versión del place: no puedo separar D1 por dispositivo ni atribuir el 13/09 a un commit concreto. Falta saber qué versión está publicada hoy.
- Funnels: un solo día, v1, sin nombres; los mapeé por número de pasos y valores.
- `MaxPlayers = 60` es el valor del archivo; el de Creator Hub puede diferir y cambia todas las cifras O(N²).
