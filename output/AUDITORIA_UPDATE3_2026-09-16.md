# Auditoría Update 3 — 7 puntos

Fuente canónica: `src/`. Construido con `audit/build_core.luau` → los 4 `.rbxl` de la
raíz + `output/Update2_core/`. Verificado con `audit/verify_rbxl_contents.luau`, que
compara script por script lo que hay **dentro** de cada place contra `src/`.

**43 suites, 3 pasadas seguidas, 0 fallos.** Tests nuevos: `audit/test_update3_audit.luau`,
`audit/test_wins_economy.luau` y `audit/test_studio_log_fixes.luau` (ver Anexos).

> **Actualización:** el Anexo 2 cambia tres cosas de este documento. El x2 de los pads vuelve a
> ser un gamepass permanente, el escalón x2 de la escalera pasa al dev product `3710772221`, y la
> espera de la skin del punto 1 se corrigió porque causaba la skin negra al morir.

---

## 1. Retardo de la skin Evolve al reaparecer

**Archivo:** `src/common/ServerScriptService/Economy/SkinSystem.server.luau`

**Causa raíz:** `player.CharacterAdded` esperaba **`task.wait(1)` fijo** antes de llamar
a `applySavedSkin`. Un segundo entero, incondicional, en cada respawn. Lo mismo en la
ruta de entrada inicial.

Investigué qué necesita de verdad `applyCatalogSuit`: solo `player.Character` y un
`Humanoid`. Pero **no se puede aplicar antes de que Roblox termine de cargar su propia
apariencia**, o el avatar por defecto la pisa — probablemente por eso alguien puso el
segundo fijo en lugar de arreglarlo.

**Corrección:** esperar a las dos dependencias reales en vez de a un reloj.

```lua
local function waitForCharacterReady(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = character:WaitForChild("Humanoid", 5)
	end
	if not humanoid then
		return false
	end

	local deadline = os.clock() + 3
	while os.clock() < deadline do
		if player.Parent == nil or player.Character ~= character then
			return false
		end
		local ok, loaded = pcall(function()
			return player:HasAppearanceLoaded()
		end)
		if not ok or loaded then
			break
		end
		task.wait()
	end

	return player.Parent ~= nil and player.Character == character
end
```

> **Corregido después (Anexo 2):** `HasAppearanceLoaded()` es por jugador, no por personaje;
> en un respawn ya da `true` con el personaje todavía sin avatar, y eso dejaba la skin negra.
> Ahora se espera `CharacterAppearanceLoaded` de ese personaje.

En un respawn la apariencia está cacheada, así que sale en uno o dos frames. El techo
de 3 s solo existe para no colgarse nunca.

---

## 2. Compra con Robux del Blue Trail

**Archivos:** `CosmeticCatalog.luau`, `TrailShopSystem.server.luau`,
`StarterGui/Backpack/BackpackScript.client.luau`

Los IDs están **bien**: Trail07 usa el gamepass `1940887606`, igual que en el OG. No hay
mismatch de tipo. Encontré dos defectos reales:

**a) El que rompía la tienda entera (ya corregido antes en esta sesión).**
`ownsTrail` llamaba a `setTrailOwned` **antes de declararla**. En Luau eso resuelve a un
global `nil` y lanza excepción — y esa rama solo se ejecuta para **quien posee un
gamepass de trail, es decir el Blue Trail**. Reventaba `collectOwnedMap` → `buildState`
→ `sendState`, así que a esos jugadores el menú de trails nunca les llegaba. Ese es el
síntoma "el Blue Trail no se puede comprar".

**b) Llamadas web bloqueantes al montar el menú.** `resolveRobux` hace `GetProductInfo`,
que **cede**, y se llamaba **dos veces por ítem** durante el wiring. Además Trail07 es la
**única** entrada del catálogo **sin `RobuxPrice`**, así que si la consulta fallaba su
botón quedaba en `"??"` permanente.

**Corrección:** el id y el tipo salen del catálogo sin red, así el clic funciona desde el
primer frame; la consulta en vivo solo refina el precio.

```lua
		local catalogId = tonumber(entry.RobuxPurchaseId)
		local declaredType = tostring(entry.RobuxPurchaseType or "Auto")
		item.robuxPurchaseId = catalogId
		item.robuxPurchaseType = if declaredType == "GamePass" or declaredType == "DeveloperProduct"
			then declaredType
			elseif catalogId < 3000000000 then "GamePass"
			else "DeveloperProduct"
```

**Pendiente tuyo:** ponle `RobuxPrice` a Trail07 en `CosmeticCatalog` (es el único sin
él) para que tenga respaldo si Marketplace no responde. No lo invento yo.

---

## 3. "2x Victory" mal mapeado en la tienda

**Archivo:** `src/common/StarterPlayer/StarterPlayerScripts/UI/ShopController.client.luau`

**Causa raíz, exactamente lo que describiste:**

```lua
["2X Win"] = (doubleWinsProductId and doubleWinsProductId > 0)
    and { type = "Product", id = doubleWinsProductId }   -- Config.DoubleWinsPadProductId
    or { type = "GamePass", id = doubleWinsPassId },
```

`DoubleWinsPadProductId` es `3712435111`, que en tu dashboard es **"2x Wins (PAD)"** — el
dev product del pad del mapa. La tarjeta vendía el pad.

De ahí salen los dos síntomas:

1. Mostraba el precio del pad (23 R$), no el del gamepass (249 R$).
2. **Nunca podía marcarse "Purchased"**: un developer product es consumible, no tiene
   propiedad que consultar. `UserOwnsGamePassAsync` recibía un id de producto y devolvía
   false siempre.

**Corrección:**

```lua
local twoXVictoryPassId = tonumber(Config.TwoXVictoryGamePassId)
	or tonumber(Config.DoubleWinsPadGamePassId)
	or 0

	["2X Win"] = { type = "GamePass", id = twoXVictoryPassId },
```

Y la propiedad ahora lee `TwoXVictoryOwned` (que solo escribe la ruta del gamepass), con
refresco al cambiar el atributo y al cargar los datos.

---

## 4. Escalera de multiplicadores de Wins

**Archivo:** `src/common/ReplicatedStorage/Shared/Config.luau`

Usé los IDs y precios **reales** de tus capturas, no los del OG (los del OG,
`3674002277` / `3674011914` / `3674018331`, son productos distintos y quedan retirados).

**La canibalización, con números:** la escalera estaba a 20/40/80/160/320 R$ contra un
gamepass x2 de **249 R$**. O sea, **x32 por 320 costaba solo un 28 % más que x2 por
249**. Nadie tenía motivo para comprar el pase.

> **Cambiado después (Anexo 2):** el gamepass `1941409601` vuelve a ser el pase permanente de
> los pads x2, y el escalón x2 de la escalera es el dev product `3710772221`.

**Curva nueva.** El escalón x2 es el **gamepass**, y cada escalón de dev product cuesta
más que él:

| Escalón | Multiplicador | ID | Precio antes | Precio ahora |
|---|---|---|---:|---:|
| 1 | x2 | gamepass `1941409601` | 249 | 249 |
| 2 | x4 | `3710772271` | 40 | **349** |
| 3 | x8 | `3710772305` | 80 | **649** |
| 4 | x16 | `3710772331` | 160 | **1199** |
| 5 | x32 | `3710772380` | 320 | **2199** |

**Balance económico:** la primera versión de esta tabla tenía dos errores. Contaba la
vuelta a World 1 sin el pad final (457.020 en vez de **1.157.020**) y calculaba los
teleports sobre su coste base, cuando en realidad ya subían con el multiplicador. Con
los números correctos, quitar el x32 no arregla nada: x16 rompe la economía casi igual.
El análisis completo y el arreglo están en el **Anexo** al final.

**Pendiente tuyo:** los 4 productos y el gamepass están **Disabled** en el dashboard. Hay
que reactivarlos y poner los precios nuevos (Managed pricing está desactivado, así que
son manuales). Ojo: **las 6 pociones también están Disabled** y la tienda las sigue
ofreciendo.

---

## 5. Sistemas solo en Studio

Los tres paneles no estaban "a medias": estaban **apagados en todas partes** con
`if true then return end`, incluido Studio. Ahora son condicionales.

| Sistema | Archivo | Antes | Ahora |
|---|---|---|---|
| Quests | `UI/QuestController.client.luau` | `if true then return end` | `if not RunService:IsStudio() then return end` |
| AFK | `UI/AfkRewardsController.client.luau` | igual | igual |
| Admin | `UI/AdminPanelController.client.luau` | igual | igual |
| Icono Admin | `UI/TopbarIconsController.client.luau` | `ADMIN_TOPBAR_ENABLED = false` | `= RunService:IsStudio()` |
| Glass Shatter | `Shared/GlassShatter.luau` | `if true then return end` dentro de `Play` | `if not RunService:IsStudio() then return end` |

Glass Shatter lo cerré **dentro del módulo compartido**, no en las llamadas: así cubre
`CtrlShiftLock` e `InstantMovementController` a la vez y no toco la lógica de sprint.

El icono del Admin sigue al panel: si no, en producción abriría la nada.

---

## 6. Responsividad de Quests y AFK

**Hallazgo: la premisa era medio incorrecta.** Ambos paneles **ya siguen** la guía de
estilos — usan `Shared/GamePanelStyle` (marco `24,38,68`, trazo `11,27,45`, esquinas de
12, FredokaOne, tarjetas y botones compartidos). No hacía falta rediseñarlos.

**La causa real de que se rompan en móvil** es un argumento:

```lua
PanelStyle.Panel(screenGui, modalFrame, header, 680, 620, true)   -- adaptive = true
```

`GamePanelStyle.Panel` tiene dos modos:

* `adaptive = true` → **encoge el marco** (`panel.Size = min(width, view.X-24) ...`).
* `adaptive = false` → **escala todo con `UIScale`** (`scale.Scale = min(1, ...)`).

Conté el contenido de ambos paneles: **14 y 16 usos de offset, cero `fromScale`**. Con
`adaptive`, el marco se encoge en el móvil pero **los hijos conservan sus offsets de
680 px**, y como el panel tiene `ClipsDescendants = true`, **la UI se corta en silencio**.
Ese es el desbordamiento que ves.

**Corrección:** `adaptive = false` en los dos. El modo `UIScale` escala el marco **y sus
hijos offset** juntos, que es exactamente para lo que existe.

Es un cambio de un argumento por panel en lugar de reescribir 1.100 líneas, y usa el
mecanismo que el propio proyecto ya tenía.

---

## 7. Ciclo de vida de Time Gifts

**Archivos:** `Social/PlaytimeRewards.server.luau`, `UI/TimeGiftController.client.luau`,
`Shared/PlaytimeRewards.luau`

**Lo que está correcto** (verificado, no asumido):

* El temporizador usa `Workspace:GetServerTimeNow()` **en los dos lados**. Inmune al reloj
  del cliente.
* El claim es **atómico e idempotente**: `operationId == receiptId ==
  "playtime:<sessionId>:<index>"`, así que un reintento responde `AlreadyCommitted` en vez
  de pagar dos veces.
* El servidor valida el tiempo transcurrido antes de conceder.
* **Morir no resetea nada.** La sesión cuelga del objeto `Player`, no del Character; solo
  se crea en `PlayerAdded`. Respawnear no la toca.

**El fallo que encontré:** `DataService.Commit` era la **única llamada sin proteger** en la
ruta de claim. Si lanzaba, se saltaba todos los `finish()` y **`session.Busy` quedaba en
`true` para siempre** — el jugador no podía volver a reclamar ningún Time Gift en toda la
sesión.

```lua
	local ok,result=pcall(DataService.Commit,handle,{operationId=id,receiptId=id,fingerprint=id,
		commands={{kind="GrantExact",stat=reward.Type,amount=reward.Amount}}})
	if not ok then
		warn("[PlaytimeRewards] Claim commit failed for "..player.Name..": "..tostring(result))
		finish("Something went wrong. Try again shortly.",false);return
	end
```

También borré ~50 líneas muertas (`waitForGrantFunctions`, `snapshotStat`, `rollback`):
sobras de la ruta de concesión anterior a DataService, sin ninguna llamada.

**Lo que NO persiste, y es por diseño:** el progreso es **por sesión de servidor**. Al
teletransportarte entre World 1 y World 2 entras a otro servidor, se dispara
`PlayerAdded` y el temporizador **y** los reclamos se reinician. No es un exploit (el
temporizador también se reinicia, y la curva sube de 1K a 1M, así que saltar de servidor
es estrictamente peor), pero **sí pierdes progreso al cambiar de mundo**. Si quieres que
sobreviva al teleport hay que persistirlo en el perfil; dime y lo hago.

---

## Extra: HUD en móvil cuando falta 2xVictory

`Mainhud.Rightbuttons` usa un `UIListLayout` con `VerticalAlignment.Top` dentro de un
frame anclado al centro y de 0,45 de alto. Con los dos botones se ve equilibrado; **al
ocultar 2xVictory el que queda se queda flotando arriba con medio frame vacío debajo**,
que en móvil es muy visible. Además los tres hijos tenían `LayoutOrder = 0`.

Corregido a `VerticalAlignment.Center` y con `LayoutOrder` explícito (2xSpeed = 1,
2xVictory = 2), así ocultar uno simplemente recentra el otro.

> **Revertido después (Anexo 2)** a pedido: el layout autorado se veía como querías.

---

## Anexo: balance de la escalera de Wins (x32)

Pregunta: ¿se balancea o se elimina el x32?

**Se balancea. Y el escalón no era el problema.**

### Lo que medí

Recompensas leídas del código, no de memoria
(`NewWorld1ManualStagePads.server.luau:44`, `Config.World2StageWinRewards`):

* Vuelta completa a World 1 = **1.157.020** wins (11 pads de stage = 457.020, más el
  pad final de 700.000). Mi nota anterior decía 457.020 — se comía el pad final.
* Vuelta completa a World 2 = **2.985.000**.

Inventario **completo** de sinks de wins del juego:

| Sink | Coste | ¿Escalaba con el multiplicador? |
|---|---:|---|
| 7 auras de tienda | 11.111.110 | No |
| 7 trails de tienda | 11.111.110 | No |
| Flight | 25.000.000 | No |
| Teleports de World 2 | 75K–725K, **por uso** | Sí, ×multiplicador |

Y eso es todo. Verificado: **los rebirths cuestan Level, no Wins**
(`getNextRebirthLevelRequirement`), así que no son un sink. Y `ExperimentalAuras`
—11 auras costeadas hasta 1.000.000.000— **es una lista de deseos, no contenido**:
`CosmeticTemplateBuilder` exige exactamente 6 normales + 1 negra por tipo y lanza si
no, esas 11 no tienen VFX, reutilizan iconos de otras auras y no tienen SKU. No se
pueden encender con un flag.

Pool fijo real = **47.222.220 wins**.

### Por qué eliminar el x32 no arreglaba nada

| Tier | Vueltas a W1 para comprar **todo** el juego |
|---|---:|
| x1 | 40,8 |
| x4 | 10,2 |
| x8 | 5,1 |
| x16 | 2,6 |
| **x32** | **1,3** |

x16 limpia el mismo pool en 2,6 vueltas. El pool es corto, no el escalón. Capar la
escalera solo mueve el número — y encima te quita el SKU más caro.

### El arreglo, que ya tenía precedente en tu propio código

`TeleportSystem` **ya** escalaba su precio con el multiplicador
(`baseCost * multiplier`). El patrón correcto ya existía; solo estaba en un sitio, y
además al 100 %, que es su propio problema: quien compraba x32 veía todos los
teleports multiplicarse por 32 y **no ganaba nada**. Eso es sensación de estafa.

Lo unifiqué en `Shared/WinsMath` con amortiguación por raíz cuadrada:

```lua
WinsMath.DefaultProgressionPriceExponent = 0.5

function WinsMath.GetProgressionPrice(baseCost: any, totalMultiplier: any, exponent: any?): number
	local base = finite(baseCost)
	if base == nil or base <= 0 then
		return 0
	end

	local scale = multiplier(totalMultiplier)
	local power = finite(exponent)
	if power == nil or power < 0 then
		power = WinsMath.DefaultProgressionPriceExponent
	end

	local priced = base
	if scale > 1 and power > 0 then
		local factor = finite(scale ^ power)
		if factor ~= nil and factor >= 1 then
			priced = base * factor
		end
	end

	local rounded = math.ceil(priced)
	if finite(rounded) == nil or rounded < 0 then
		return math.floor(base)
	end
	return math.clamp(rounded, 0, 9007199254740991)
end
```

**La regla, en una línea:** lo que es *progresión* (Flight, teleports) sube con el
multiplicador amortiguado; lo que es *recompensa* (auras, trails) no sube nada. Comprar
un escalón siempre acelera, nunca salta la partida.

`Config.ProgressionPriceMultiplierExponent = 0.5` — ponlo en `0` para volver a precios
planos, en `1` para el comportamiento lineal viejo.

### Curva resultante (salida real del código)

| Tier | Precio de Flight | Vueltas a Flight | Vueltas para todos los cosméticos | Vueltas para **todo** |
|---|---:|---:|---:|---:|
| x1 | 25.000.000 | 21,6 | 19,2 | 40,8 |
| x2 | 35.355.340 | 15,3 | 9,6 | 24,9 |
| x4 | 50.000.000 | 10,8 | 4,8 | 15,6 |
| x8 | 70.710.679 | 7,6 | 2,4 | 10,0 |
| x16 | 100.000.000 | 5,4 | 1,2 | 6,6 |
| x32 | 141.421.357 | 3,8 | 0,6 | 4,4 |

Antes: x32 compraba el juego entero en **1,28** vueltas. Ahora en **4,4**, y llega a
Flight 5,7× más rápido que un x1 sin que deje de ser una sesión de verdad. Cada escalón
sigue siendo estrictamente mejor que el anterior — eso está aserido en el test.

### Archivos tocados

| Archivo | Cambio |
|---|---|
| `Shared/WinsMath.luau` | `GetProgressionPrice` / `GetProgressionPriceFor` |
| `Shared/Config.luau` | `ProgressionPriceMultiplierExponent = 0.5`; nota económica corregida |
| `Core/Abilities/FlightService.luau` | `flightWinsCost(player)` — **la cotización y el cobro salen de la misma función** |
| `Worlds/TeleportSystem.server.luau` | precio amortiguado en vez de `baseCost * multiplier` |
| `Economy/SpeedProductPurchases.server.luau` | payload post-compra con el precio correcto |
| `UI/AbilitiesPanel.client.luau` | placeholder amortiguado, para que la tarjeta no parpadee el precio sin escalar |

El detalle que más importa de esa tabla: en `FlightService` el precio que se **muestra** y
el que se **cobra** ahora son la misma llamada. Estaban separados como dos referencias a
la misma constante, lo que funcionaba solo mientras la constante fuera constante.

Revisando esto apareció otro riesgo, que también quedó cerrado. Hay **dos** definiciones de
`_G.SpeedsterGetPermanentWinsMultiplier` y no coinciden: `PlayerStats` lee solo el
atributo y `PlayerStatsBridge` usa `math.max(atributo, perfil guardado)`. Si Flight se
cotizaba leyendo solo el atributo, un jugador que entra y compra antes de que el atributo
replique pagaba el precio de x1. Ahora Flight usa el mismo getter que los teleports:

```lua
local function flightWinsCost(player)
	local multiplier
	if type(_G.SpeedsterGetPermanentWinsMultiplier) == "function" then
		local ok, value = pcall(_G.SpeedsterGetPermanentWinsMultiplier, player)
		if ok then multiplier = value end
	end
	if type(multiplier) ~= "number" then
		return WinsMath.GetProgressionPriceFor(WINS_COST, player, Config.ProgressionPriceMultiplierExponent)
	end
	return WinsMath.GetProgressionPrice(WINS_COST, multiplier, Config.ProgressionPriceMultiplierExponent)
end
```

Que existan dos getters distintos con el mismo nombre global es anterior a este cambio y
gana el script que se ejecute último. No lo toqué: unificarlos afecta a todo lo que paga
Wins, no solo a estos precios.

También revisé que ningún otro sitio calcule precios por su cuenta: `TeleportController`
solo muestra y devuelve la cotización del servidor (y pide otra cuando cambia el
multiplicador), y los avisos de `SpeedProductPurchases` no llevan precios.

### Verificación

`audit/test_wins_economy.luau`, 46 aserciones: tasas de ingreso leídas del código fuente,
el pool fijo, monotonía de la escalera, que los cosméticos **no** se amortiguan, que las
auras experimentales siguen fuera de la tienda, casos borde (nan, nil, multiplicador < 1,
exponente 0 y 1), que cotización y cobro coinciden en Flight y en teleports, y que
Flight usa el getter canónico del multiplicador.

Dos tests existentes afirmaban el precio lineal viejo y los actualicé al intent nuevo:
`test_stage_transactions` (esperaba `725.000 × 16 = 11.600.000`, ahora
`725.000 × √16 = 2.900.000`, calculado con el `WinsMath` real en vez de un número a mano)
y `test_flight_start` (su stub no conocía el módulo nuevo).

**42 suites, 3 pasadas seguidas, 0 fallos**, sin cambios entre pasadas.

Una pasada anterior falló porque edité `FlightService` en `src/` mientras corría:
`build_core` exige que `audit/merged` sea idéntico a `src/`, `verify_rbxl_contents`
compara los places contra `src/`, y los dos van al final de la suite. Perdí el log de esa
pasada, así que es la causa más probable, no una confirmada. Después de resincronizar,
las tres pasadas salieron limpias.

### Lo que sigue pendiente de ti

El techo real del endgame sigue siendo 25M. Si quieres que x32 tenga una meta de verdad y
no solo una rampa, las 11 auras de `ExperimentalAuras` ya están costeadas hasta 1.000M —
son 1.880M de sink, 37× la economía actual. Necesitan VFX, icono propio y, si las quieres
también por Robux, SKU. Eso es trabajo de contenido, no de config.

---

## Anexo 2: pase de pads, escalera, regalos, skin al morir y errores de Studio

### Pase de pads x2 = gamepass permanente `1941409601`

Comprado una vez, todos los pads x2 pagan doble para siempre, igual que en el OG
(`audit/OG/173_WinPads.luau`). El dev product por reclamo `3712435111` queda retirado: nada
lo abre, y `SpeedProductPurchases` solo paga un recibo que ya estuviera en vuelo.

`Services/DoubleWinsPad.luau` ahora:

* Consulta la propiedad una vez por sesión (`UserOwnsGamePassAsync`), por si el jugador
  llega al pad antes de que termine el chequeo de entrada.
* Si no tiene el pase, abre el prompt del **gamepass** y no paga nada.
* Si lo compra parado sobre el pad, `PadTouchService.ResumePad` vuelve a evaluar ese pad y
  se cobra por el camino normal (MovementGuard, cooldowns, `RewardPadClaims`). Si ya se
  fue, no pasa nada.

También corté los acoples que mezclaban las dos compras:

| Dónde | Antes | Ahora |
|---|---|---|
| `SpeedProductPurchases` (entrar, comprar, regalar) | el pase subía `PermanentWinsMultiplier` a x2 | solo marca los pads |
| `grantPermanentWinsMultiplierTransaction` | comprar la escalera desbloqueaba los pads | no |
| `StatsProjection` | tener x2 guardado desbloqueaba los pads | solo un grant de admin guardado |
| Scripts de pads de World 1 y 2 | listener que subía el multiplicador | eliminado |
| `MainHUDController` (cliente) | el pase contaba como x2 Wins y el botón 2xVictory se saltaba el escalón x2 | no |
| `ShopController`, tarjeta "2X Win" | tener x2 de la escalera la marcaba "Purchased" | solo el pase |
| Admin "2X WINS" | cambiaba el multiplicador | desbloquea los pads |

### Escalera = los 5 dev products de tu captura

`3710772221` (x2), `3710772271` (x4), `3710772305` (x8), `3710772331` (x16) y
`3710772380` (x32). El botón 2xVictory del HUD vende esta escalera.

### HUD derecho revertido

Se quitó el bloque que forzaba `VerticalAlignment` y `LayoutOrder`. El HUD vuelve al layout
autorado.

### Botón de pago del popup de regalos

El ícono de Robux es una imagen fija al **centro** del botón, encima de 4 espacios dentro de
`"Gift (    500)"`. Esos espacios solo caen bajo el ícono con precios de 3 dígitos: con 39 o
2199 el ícono pisaba el paréntesis o los números, y mis mensajes largos ("Passes can't be
gifted") quedaban debajo del ícono. Ahora:

* El texto se equilibra midiendo con `TextService:GetTextSize` y la fuente del propio label,
  así el hueco queda centrado con cualquier precio. Con 500 sale idéntico al autorado. No se
  cambia ningún tamaño ni posición.
* Si el botón muestra un mensaje en vez de un precio, el ícono se oculta. Los mensajes son
  cortos: "Not giftable", "You", "Wait..." y "Try again" (que vuelve al precio a los 2 s).

### Skin negra al morir

Causa: mi arreglo del punto 1. `Player:HasAppearanceLoaded()` es por jugador y ya da `true`
en un respawn con el personaje todavía sin avatar. El traje se armaba sobre
`GetAppliedDescription()` de ese personaje vacío: colores del cuerpo en negro, sin cara ni
accesorios. Los reintentos de 0,35 s y 1 s volvían a leer esa misma descripción.

Arreglo: se registra `CharacterAppearanceLoaded`, que dispara por cada personaje, y se espera
eso con un tope de 8 s. En un respawn el avatar está cacheado, así que sigue siendo mucho más
rápido que el segundo fijo de antes. Con el código anterior el test nuevo falla, porque el
traje entraría en t=0.

### Errores del log de Studio

| Línea del log | Causa | Estado |
|---|---|---|
| `Infinite yield ... AfkRewardsRequest` / `QuestRequest` | Gateé los paneles a Studio pero no sus servicios, que seguían con `if true then return end` | **Arreglado**: servicios gateados igual. Además los dos usaban `Players` sin declararlo, y eso reventaba al activarse |
| `cannot fire 'GlobalAnnouncementRequest' ... sandboxed` | `StarterGui.Messages.MessageHandler` venía con `Sandboxed = true` en World 1 y en World 2 | **Arreglado** en los dos con un parche de propiedad declarado en `build_core` |
| `Failed to load sound 9114223175: Asset type does not match` | GlassShatter usaba un ID que no es audio | **Arreglado**: sin sonido hasta que pongas uno real en `GlassShatter.SoundId` |
| `Could not get ProductInfo for 212690295` | El precalentamiento le pedía a Marketplace el tipo de camisas y pantalones, que ya se conoce | **Arreglado**: solo consulta máscaras y trajes |
| `icon = {...}` | 3 `print` de debug en `IconController` | **Arreglado** |
| `Missing new World 1 treadmill: Admin3000` | La crea el panel admin en tiempo de ejecución | **Arreglado**: marcada `SpawnedAtRuntime` |
| `StudioAccessToApisNotAllowed` (cada minuto) | Studio sin acceso a APIs; los leaderboards reintentaban siempre | **Arreglado el spam**: avisan una vez y paran esa sesión. Live no cambia |
| `Failed to load sound 10468693967` / `10468691302` / `15898694877` | Sounds autorados sin permiso: `Workspace.Folder.Zoom.HumanoidRootPart.LightningSound`, `.LightningStart` y `Workspace.Trampoline.Trampoline_Hitbox.JumpSound` | **Tuyo**: "Click to share access" o reemplazarlos |
| `Failed to load animation 137493859009439` | Animación de levantarse del ragdoll sin permiso para la experiencia | **Tuyo**: compartir acceso o resubirla con la cuenta dueña |
| `ReverseFlashBoss is expected to be an R6 rig` | El modelo del place es R15 (tiene `UpperTorso`) | Aviso real; no cambié la lógica del boss sin verlo en juego |
| `Workspace.DarkZonic R6 dummy was not found` | No existe en ningún place | Contenido faltante: el cartel de Dark Zonic no aparece |
| `ZonitoVisuals`, `Animation Spoofer`, `plugin icon` | Plugins de Studio | No son del juego |

### Música

`ReplicatedStorage.Music` tiene 17 sonidos autorados (15 sin contar los de admin), y la lista de
PXuTo de Config solo se usaba si esa carpeta estaba **vacía**. "DRIFT NIGHT PHONK (Car Motion
Edit)" no está en la carpeta, así que nunca sonaba. Ahora la playlist es la carpeta más las
pistas de Config que no estén en ella, sin duplicados.

### Para confirmar

World 2 aparece con dos PlaceIds. `WorldPortalService` teletransporta a `116359653478954`,
mientras `Config.World2PlaceId`, `WorldsController` y el tutorial usan `96501592055150`. El
viaje lo hace el servidor, así que el teleport no se rompe, pero conviene confirmar cuál es el
World 2 actual.

### Verificación

`test_monetization_structure`, `test_ragdoll_flight_and_x2_pad`, `world2_pad_prompt_probe`
(con los módulos reales: prompt, cancelación, compra sobre el pad = 100 × 2 × 16 = 3200, pase
permanente y commit rechazado), `test_update3_audit` (espera de la skin), `test_gift_panel`
(hueco centrado de 1 a 5 dígitos), `test_runtime_panels` (servicios inertes en live y
respondiendo en Studio), `test_music_playlist` (mezcla de carpeta + Config) y el nuevo
`test_studio_log_fixes`.

**43 suites, 3 pasadas seguidas, 0 fallos**, sin cambios entre pasadas.

---

## Anexo 3: preview, ruleta y AFK con la UI del diseñador, regalos de pases y panel admin

### Quién ve lo nuevo

La ruleta, AFK (panel y zona), Quests y el Glass Shatter pasan por `Shared/FeatureGate.luau`:

| Dónde | Quién lo ve |
|---|---|
| Studio | Todos |
| Places en `Config.PreviewFeatures.TestingPlaceIds` | Todos (la lista está vacía: falta el PlaceId del testing place) |
| Servidores live | Solo `Config.PreviewFeatures.UserIds` = `767108248` |

`767108248` es la cuenta con display name "GekkoH", que ya estaba en tus admins. El
`111827288` que en `ChatBoostCommands` dice "Gekkoh / Owner" es **pxuto** (Pluto) según la
API de Roblox, por eso no lo usé. Los servicios y los paneles hacen la misma pregunta: en live
los servicios corren, pero ignoran a quien no está en la lista.

### La UI del diseñador dentro del juego

Los places se reconstruyen desde bases inmutables más `src/`, así que la UI no se puede pegar
en StarterGui. Se convierte a código:

* `scratch/import_designer_ui.luau` lee el `.rbxm` y escribe `Shared/DesignerUi/SpinWheelGui.luau`
  y `EarningsGui.luau`, propiedad por propiedad (incluye `StrokeSizingMode = ScaledSize`,
  degradados y esquinas). `Shared/DesignerUiBuilder` la arma en el cliente.
* `test_designer_ui` reconstruye los módulos y los compara con el `.rbxm`: 3020 propiedades
  idénticas.
* Para actualizarla: reemplazar `design/ui/SpinWheelAndEarnings.rbxm` y correr
  `lune run scratch/import_designer_ui.luau design/ui/SpinWheelAndEarnings.rbxm SpinWheel SpinWheelGui`
  (y lo mismo con `Earnings EarningsGui`).
* Ningún tamaño ni posición autorada se toca: el código solo pone textos, imágenes y
  visibilidad. Lo único que agrego yo es el botón dorado de Wins (clon de X1) y los % sobre
  la rueda.

### Ruleta

| # | Premio | Probabilidad |
|---|---|---|
| 1 | Wins chico (según nivel) | 30% |
| 2 | 2x Speed 10 min | 13% |
| 3 | Speed chico (5% de tu Speed) | 30% |
| 4 | Aura o Trail rara | 3% |
| 5 | Wins grande | 12% |
| 6 | 2x Wins 10 min | 12% |

* El arte del diseñador tiene 6 rebanadas puestas a mano dentro de frames rotados, y
  `AbsolutePosition` de Roblox ignora la rotación de los padres. `Shared/GuiGeometry` calcula
  el ángulo real de cada premio desde las propiedades autoradas: 0°, 60°, 121°, 181°, 240° y
  300°, con la flecha a 1,5°. El test rota el árbol real y comprueba que el premio pagado
  queda bajo la flecha y que ningún otro queda más cerca.
* Botones: Spin con contador "Nx", X1 y X3 (packs de Robux, precio en vivo del producto),
  countdown "1+ Spin in" y el botón dorado de Wins encima de X3.
* Compra con Wins: precio = premio grande de Wins del jugador × 20 (mínimo 50K), subido por
  el multiplicador permanente de Wins ^0,5. Nivel 1: 100K; nivel 100: 2,6M; con x32 cuesta
  5,7 veces más. **Máximo 2 por hora**, guardado en el perfil
  (`SpinWinsWindowStart` y `SpinWinsWindowCount`). El cobro, el límite y el ticket van en una
  sola transacción: si algo falla no se cobra nada ni se gasta el límite.
* Rueda 3D en el lobby con el mismo arte, girando despacio; el ProximityPrompt abre el panel.
* Si `ArePaidRandomItemsRestricted`, se ocultan los packs de Robux y la compra con Wins.

### AFK

* Panel "Earnings!" del diseñador: tarjeta del zapato = Speed; tarjeta del fuego = Wins (con
  el ícono de trofeo); "!" = hay una poción bonus en este reclamo; Claim! = normal;
  Get x5 = 5x con VIP (sin VIP abre la compra del pase y la etiqueta muestra su precio real).
* Zona AFK en el lobby: +0,5% de tu Speed (mínimo 500) cada minuto y +1 Spin cada 10 minutos,
  solo estando adentro. Al salir se pausa, no se pierde. HUD con los dos contadores.

### Precio del botón verde de Gift (segundo arreglo)

Mi arreglo anterior estaba mal. Metía todos los espacios en el medio, lo que no centra nada:
solo alargaba el texto, `TextScaled` lo achicaba y `TextWrapped` partía la línea en el hueco
("Gift (" arriba y "500)" abajo). Además, al abrir el panel subía **todos** los ZIndex a 51, y
el fondo oscuro de cada fila (ZIndex -1) quedaba encima de nombres y avatares.

Ahora el precio va en una sola línea con espacios de no-corte, el hueco se mide contra el
ícono al tamaño real que renderiza el texto y se centra con relleno por fuera, y ya no se
aplanan los ZIndex. El test cubre precios de 1 a 5 dígitos en dos tamaños de pantalla.

### Regalar gamepasses

Roblox no deja comprar un pase para otro jugador, ni con el pase mismo. La vía es **un dev
product por pase, al mismo precio**:

* `Config.GamePassGiftProducts`: 2x Wins Pads, 2x Speed, VIP, Infinite Revives, Flight y
  Starter Pack. **Faltan sus ProductId.**
* Al comprarlo para alguien, el recibo guarda `GiftedPass:<id>` en el perfil del que lo recibe
  (Flight y los pads guardan además su upgrade), en la misma transacción del recibo. Se activa
  al instante y en cada entrada; el chequeo del VIP ya no lo borra.
* Si el otro ya tiene el pase, la fila dice "Owned" y no cobra.
* Un pase sin producto sigue diciendo "Not giftable".

### Panel admin básico

`Admin/AdminAbusePanelService`, `Admin/AdminAbusePanelController` y
`Admin/AdminAbuseEffects`. Se abre con la corona del topbar o con F2. Tienen acceso: Studio,
`767108248`, `5113549114`, AdminBannerConfig, el dueño del juego y rango ≥254 del grupo.

| Pestaña | Qué hace |
|---|---|
| Abuse/Trolls | Rocket, Ragdoll, Jail, Balloon, Tiny, Inverse, Control, Jumpscare y No Gravity, con duración y cooldown por tarjeta |
| Events | Disco Lights, Sandstorm y Confetti Party, con duración y ON/OFF |
| Boosts & Mults | 2x/4x Speed, 2x/5x Wins y multiplicador propio para Speed o Wins |
| Treadmills | Caminadora admin frente a ti, con multiplicador y minutos; "Remove All" |
| Music | Lista de pistas (carpeta Music + Config), Play y Stop; la música de fondo se silencia mientras suena |
| Announcements | Mensaje filtrado para todos |
| Moderation | Kick, Ban (`Players:BanAsync`, 0 horas = permanente), Mute/Unmute, TP to Player, Bring, Give/Remove Speed |

* "All Servers" manda eventos, boosts, anuncios y los abusos a Everyone a todos los servidores
  por MessagingService.
* La moderación no funciona contra otros admins.
* "TP to Server" quedó como "TP to Player" y "Bring" dentro del servidor: llevar a alguien a
  otro servidor exige saber en cuál está. Queda para cuando llegue la UI final.
* "Sandstorm (World 3)" funciona en cualquier mundo; todavía no existe un World 3.

### Pendiente de tu parte

1. PlaceId del testing place → `Config.PreviewFeatures.TestingPlaceIds`.
2. Crear los 2 dev products de spins (X1 y X3) → `Config.SpinWheel.Products[].ProductId`.
3. Crear los 6 dev products de regalo de pases → `Config.GamePassGiftProducts[].ProductId`.
4. Mandar el `.rbxm` de las UIs de Quests y de admin para pasarlas por el importador.

### Verificación

Tests nuevos: `test_designer_ui`, `test_spin_wheel`, `test_gamepass_gifts`,
`test_admin_abuse_panel` y `test_afk_zone` (el servicio real, segundo a segundo). Tests
actualizados: `test_gift_panel`, `test_runtime_panels` (servicios reales: GekkoH atendido en
live, los demás ignorados, todos en Studio), `test_studio_log_fixes` y `test_update3_audit`.

**48 suites, 3 pasadas seguidas, 0 fallos.** `World1NewestStable.rbxl` y
`World2NewestStable.rbxl` reconstruidos, con los 10 scripts nuevos adentro.

---

## Anexo 4: colores de la rueda, botones chuecos, posición en todas las pantallas y barras AFK

### Botones chuecos

`Shared/UiShake` leía la rotación "de reposo" **antes** de devolver a su sitio la sacudida
anterior. Al tocar Spin sin spins, los botones X1, X3 y Wins se sacudían; un segundo toque a
mitad de la sacudida guardaba el ángulo inclinado como reposo y el botón quedaba torcido para
siempre. Ahora lee el reposo después de restaurar. `test_ui_shake` reproduce el caso: con el
código anterior el botón terminaba a 53,5°, y con el arreglo vuelve a 0°.

### "+5000000000000000Dc" en la rueda

El formateador de la ruleta tenía 12 sufijos y, al pasarse, dejaba el número entero delante
de "Dc". Ahora usa los mismos 22 sufijos del HUD (hasta Vg) y después notación científica
corta.

### Colores por rareza

| Rareza | Premios | Color |
|---|---|---|
| Común | Wins chico, Speed chico | Verde |
| Grande | 2x Speed, 2x Wins | Morado |
| Grande | Wins grande | Dorado |
| Rara | Aura/Trail | Celeste |

No hay dos porciones vecinas del mismo color. UI no dibuja porciones de pastel y los
CanvasGroup se ven borrosos o en blanco en celulares con poca memoria, así que cada porción
está hecha con tiras rectas pegadas a sus dos bordes. Los bordes quedan exactos, con un centro
y un anillo encima. `test_spin_wheel` verifica 9.552 puntos: cada uno muestra el color de su
propia porción y nada sale del anillo.

### Posición en todas las pantallas, sin números fijos

* `Shared/SpinWheelLayout` calcula todo desde la UI del diseñador y el tamaño real de la
  pantalla: ángulos, colores, porcentajes y el botón de Wins. El botón se recoloca cada vez
  que cambia el tamaño de la pantalla.
* El botón de Wins mide lo mismo que X1 en esa pantalla y va a la izquierda de la rueda,
  centrado con todo lo que dibuja (su etiqueta inclinada incluida). Debajo lleva
  "2 left this hour" o "Refill in mm:ss".
* Un test prueba 7 formas de pantalla (escritorio, laptop, tablet, dos celulares, ultrawide y
  cuadrada). En todas, el botón y su texto quedan en pantalla y no tocan la rueda, X1, X3,
  Spin, el countdown ni la X.
* Para revisarlo sin Studio: `lune run scratch/preview_panels.luau output/ui_preview` y
  `python scratch/render_preview.py output/ui_preview` dibujan los paneles en esas pantallas.

### Barras AFK con brillo

* Al pisar la zona AFK se abre el panel "Earnings!". La tarjeta del zapato se llena hacia la
  próxima recompensa de Speed (1 minuto) y la otra hacia el próximo Spin (10 minutos), con una
  franja de brillo que recorre el relleno. Cuando cae la recompensa, la barra vuelve a cero y
  la tarjeta se sacude.
* La tarjeta de Speed muestra lo que va a pagar la próxima recompensa (`AfkZoneNextSpeed`).
* Al salir de la zona el panel se cierra (si lo abrió la zona). La línea de texto
  "AFK ZONE - Speed in..." solo aparece si cerraste el panel, y ahora va abajo del todo.
* Recompensas offline: las dos barras llenas, y Claim! y Get x5 como antes.
* El subtítulo va en una sola línea con textos cortos. El mensaje largo del servidor se
  dibujaba en dos renglones encimados.

### Verificación

`test_spin_wheel` (colores, 7 pantallas, números), `test_ui_shake` (nuevo),
`test_runtime_panels` (la zona abre el panel y llena 45/60 y 300/600), `test_afk_zone`
(`AfkZoneNextSpeed`) y el resto de la suite.

**49 suites, 3 pasadas seguidas, 0 fallos.** `World1NewestStable.rbxl` y `World2NewestStable.rbxl` reconstruidos.
