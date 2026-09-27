# Update 2 — Correcciones y limpieza (2026-09-15)

Fuente canónica: `src/`. Construido con `lune run audit/build_core.luau`.
Artefactos: `output/Update2_core/World{1,2}.rbxl` (y los `.rbxl` de la raíz, ya actualizados).
Verificación: 32 suites, 3 iteraciones seguidas, 0 fallos.

---

## 1. Pad x2 Wins (lo que pediste)

**Cómo estaba:** el pad x2 se regalaba a quien tuviera el multiplicador permanente
(`DoubleWinsPadUnlocked` o `PermanentWinsMultiplier >= 2`), y además la línea que
calculaba el premio era `local reward = isDouble and baseReward or baseReward`.
Resultado: para esos jugadores el pad x2 pagaba exactamente lo mismo que el pad normal.
World 1 y World 2 ni siquiera hacían lo mismo entre sí.

**Cómo queda:**

* El pad x2 es **dev product repetible**: se compra cada vez que lo quieras usar.
  Una compra = un cobro doblado en ese pad. La entitlement se consume al pagar.
* El x2/x4/x8/x16/x32 Wins permanente es **otro sistema, aparte**, y se **multiplica
  encima**: pad x2 con x8 permanente = `base × 2 × 8`.
* Tener el permanente ya **no** desbloquea el pad.
* El cartel del pad muestra el número real que vas a cobrar, porque cliente y
  servidor leen el mismo módulo.

Archivos: `Shared/WinsMath.luau` (nuevo), `Services/DoubleWinsPad.luau` (nuevo),
`NewWorld1ManualStagePads`, `World2ManualStagePads`, `RewardPadClaims`,
`PlayerStatsBridge`, `SpeedProductPurchases`, `WinPadTextDistance`.

**Cambio de economía a tener en cuenta:** los pads aplicaban SOLO el multiplicador
permanente. Ahora aplican el mismo conjunto que el resto del juego (permanente ×
VIP × poción × confetti × boost de servidor), que es lo que el cartel ya prometía.
Los pads pagan más que antes a VIPs y a quien tenga pociones activas.

---

## 2. Trails y auras

* **Trails encogidos:** `CosmeticTemplateBuilder` forzaba por código los attachments
  `t0`/`t1` a ±0.75 studs y aplastaba `a1..a5` a 0.4/0.2/0.4. Eso convertía una cinta
  autoral de 6–8 studs en una de 1.5. Eliminado: ahora se usa la geometría tal cual
  la dejó el artista.
* **Posición en la espalda:** el offset autoral real respecto al HumanoidRootPart es
  `(0, +2.0, +26.8)`. Los 26.8 son la separación de la sala de exhibición; el `+2.0`
  de altura se había perdido al fijar `(0, 0, 0.55)`. Ahora se conserva la altura
  autoral y solo se sustituye la profundidad: `(0, 2.0, 0.55)`.
* **R6 / R15:** el offset se declara relativo al HumanoidRootPart y `CosmeticService`
  lo convierte al hueso al que suelda. Se quitó la corrección mágica de `+0.8` para R15.
* **Auras:** verificado contra el pack real — `(0, -0.5, 0)`, correcto, sin cambios.

Test nuevo: `audit/test_cosmetic_geometry.luau` (construye las 14 plantillas desde el
`RawCosmeticPack` real de ambos places).

---

## 3. Menú de trails / auras (Backpack)

* **Tarjetas encogidas:** cada tarjeta tiene `UIAspectRatioConstraint` 3.69:1 con
  `FitWithinMaxSize`, pero su alto autoral (0.1517 del scroll) es demasiado bajo para
  esa forma, así que la restricción resolvía por alto y dibujaba cada tarjeta a ~38 %
  de su ancho. Se libera el alto para que **la restricción del diseñador** resuelva por
  ancho. No se elige ningún tamaño en código.
  Con eso, 7 tarjetas + padding caben justo en el `CanvasSize = 3` autoral.
* **Multiplicador mal:** las tarjetas azules decían "x10 Speed" cuando el catálogo da
  x25. Ahora el texto se rellena desde `CosmeticCatalog`, que es lo que aplica el servidor.

Test nuevo: `audit/test_backpack_layout.luau`.

---

## 4. Se desequipaban solos / el menú se rompía

* `ownsTrail` llamaba a `setTrailOwned` **antes de declararla** (y `ownsAura` a
  `setAuraOwned`): en Luau eso resuelve a un global `nil` y lanza error. A cualquiera
  con el gamepass del Blue Trail se le caía `collectOwnedMap` → `sendState` → el menú
  entero. Corregido con declaración adelantada.
* `syncPlayerTrail` / `syncPlayerAura` **borraban el equipado** cuando la comprobación
  de propiedad fallaba. Un `UserOwnsGamePassAsync` throttleado devolvía "no lo tiene" y
  te desequipaba. Ahora solo se limpia si el id no existe en el catálogo.
* `CosmeticService` re-persistía en cada cambio de atributo y `StatsProjection` devolvía
  el valor durable a ese atributo tras **cada** commit (diez por segundo corriendo).
  `SpeedsterEquipTrail/Aura` ahora solo commitea si el valor realmente cambió.

---

## 5. Popups de velocidad fuera de tiempo

* El cliente encolaba un popup por tick (10/s, 20/s con boost) y el worker solo podía
  sacar ~8/s. La cola era el cuello de botella. Ahora la cola es corta y lo que no cabe
  se funde en el popup pendiente, así el número que aparece es el total real.
* El HUD tenía el fallo de fondo: al impactar, el popup escribía `commitSpeedText` con
  el total **capturado al encolarse**, que ya estaba viejo — bajaba el contador. Ahora
  un impacto nunca baja la lectura.
* Servidor: los popups de correr se agrupan y se envían a 5 Hz en vez de 10–20 Hz.

---

## 6. Red

* **Tormenta de llamadas web:** las tiendas de trails y auras llamaban a
  `UserOwnsGamePassAsync` una vez por entrada de catálogo en **cada** reconstrucción de
  estado, y reconstruían en **cada** cambio de Wins. Nuevo `CosmeticOwnership.luau`:
  cachea por jugador, solo consulta ids que de verdad son gamepass (los dev products
  `>3e9` ya no se consultan) y distingue "no lo tiene" de "no se pudo comprobar".
* **Estado de tienda:** `sendState` en cada cambio de Wins → ahora 1 refresco por segundo.
* **Popups:** ~5× menos eventos remotos por jugador.
* **Plataformas que se desvanecen (World 2):** había 10 `FadingScript` de servidor
  duplicando el sistema por jugador `FadingPlatformsClient`. El de servidor apagaba la
  colisión **para todos** cuando uno la pisaba (otros jugadores se caían sin tocarla) y
  replicaba 15 escrituras de Transparency por toque. **Desactivados**; manda el cliente.
  Nota: `audit/BUG_PAD_VOLUMES.md` decía "no se desactivarán indiscriminadamente" — no es
  indiscriminado, es un duplicado con un bug de colisión; si lo prefieres al revés, se
  revierte quitando el `if true then return end`.
* Medido en los places actuales: 0 partes sin anclar en ambos mundos.

---

## 7. Modularización

Módulos nuevos, compartidos por los dos mundos:

| Módulo | Qué unifica |
|---|---|
| `ReplicatedStorage/Shared/WinsMath` | Toda la aritmética de multiplicadores de Wins. Antes había **cuatro** copias que no coincidían: `PlayerStats`, `PlayerStatsBridge`, `RewardPadClaims` y el cartel del pad. |
| `ServerScriptService/Services/DoubleWinsPad` | Entitlement, prompt y estado pendiente del pad x2. Antes duplicado en World 1 y World 2, y ya había divergido. |
| `ServerScriptService/Economy/Cosmetics/CosmeticOwnership` | Resolución y caché de propiedad de gamepass para trails y auras. |

Otros arreglos de coherencia:

* `SpeedsterAddWins` devuelve `(ok, acreditado)`; el rollback del pad x2 usa `DebitWins`
  con la cifra exacta (antes hacía `AddWins(-reward)`, que el reducer rechaza: el
  rollback no revertía nada).
* Eliminado `checkPendingDoubleWins` en World 1 (código muerto que habría pagado dos veces).

---

## 8. Vuelo

Sin cambios: el fix ya estaba aplicado e idéntico en ambos mundos
(`World1FlightAbility.client.luau` == `World2FlightAbility.client.luau`, mismo hash),
y el servidor ya delega en el `FlightService` compartido. Las suites de vuelo pasan.

---

## Cómo reconstruir

```bash
lune run audit/export_compat_sources.luau
lune run audit/build_core.luau
```

Suite completa (12 iteraciones): `lune run audit/verify_all_loop.luau`

---

## 9. Estructura de SKUs de Wins (segunda pasada)

**El problema real no era el pad, era el escalón de 20 R$.**

El dev product "x2 Wins" (3674002277, **20 R$**) otorgaba `PermanentWinsMultiplier = 2`
**permanente** — exactamente lo mismo que el gamepass 2X Victory. Y además ponía
`DoubleWinsPadUnlocked = true`, que antes desbloqueaba el pad x2 gratis de por vida.
Sumado al "x2 Speed" (3710622733, 20 R$), **40 R$ en dev products reemplazaban al VIP
de 499 R$** (x2 speed + x2 wins).

### Qué cambió

* `Config.PermanentWinsMultiplierProducts` queda con **una sola entrada**: el gamepass
  2X Victory (`IsGamePass = true`). El botón `2xVictory` del HUD ahora vende el gamepass
  y se oculta al comprarlo (`TwoXVictoryOwned`).
* Los 7 dev products retirados (x2/x4/x8/x10/x16/x32) pasan a
  `Config.RetiredPermanentWinsMultiplierProducts`: **no se ofrecen**, pero siguen
  registrados en `ProcessReceipt` para que un recibo en vuelo se honre y Roblox no lo
  reintente para siempre.
* El pad x2 sigue siendo dev product repetible, por claim, para todos. Con el stacking:
  dueño del gamepass que compra el pad cobra `base × 2 (pad) × 2 (gamepass)` = **x4**.

### Pendiente tuyo (no lo puedo hacer yo)

1. **Deshabilitar los 7 dev products en el dashboard de Roblox.** Mientras existan,
   se pueden comprar desde la web aunque la tienda del juego ya no los ofrezca.
2. Confirmarme el precio real del gamepass 2X Victory (el HUD lo lee en vivo; el 199
   del Config es solo fallback mientras carga).
3. Quien ya compró un dev product **conserva** su multiplicador: vive en el perfil
   guardado, no se revoca.

### Lo mismo sigue roto en Speed

`PermanentSpeedMultiplierProducts` tiene el mismo escalón x2 a 20 R$ contra el gamepass
2X Speed (1941060529). No lo toqué porque no me lo pediste. Se arregla igual: dejar el
x2 solo en gamepass y empezar la escalera de dev products en x4.

---

## 10. Coste de estamina del vuelo

**Dato:** `MovementGuard.CanClaim` exige `progress >= stage`, así que volando **no** se
pueden saltar checkpoints — hay que pasar físicamente por cada safe zone. Lo que sí se
podía era cruzar los obstáculos *entre* checkpoints, porque **planear era gratis**:
solo el vuelo propulsado gastaba estamina.

* `AbilityFlightDrainPerSecond`: 11.7 → **14** (propulsado).
* `AbilityFlightGlideDrainPerSecond`: **3.5** (nuevo; planear ahora gasta).
* El vuelo termina al agotarse la estamina, con autoridad de servidor
  (`FlightService`) y corte inmediato en cliente (ambos mundos).
* Ponlo en `0` para volver al planeo ilimitado.

Con estamina base (17): ~1.2 s de subida y ~4.9 s de planeo máximo. Con el traje tope
(60): ~4.3 s de subida o ~17 s de planeo. Son números para iterar, están todos en Config.

---

## 11. Vuelo: nerf real y control usable (segunda pasada)

**Por qué se sentía permanente:** solo la subida propulsada gastaba estamina. Subías
~1 s y **planeabas gratis**; además el traje tope (60 de estamina) compraba varias
veces más tiempo de vuelo que el básico (17) con el mismo input.

Ahora el coste vive en `ReplicatedStorage/Shared/FlightStamina` y cada drenaje es
`max(plano, porcentaje del máximo del jugador)`, así que el traje ya no rompe el
balance:

| Traje | Estamina | Tiempo máximo en el aire |
|---|---:|---:|
| FlashSuit | 5 | 1,4 s |
| Base (sin traje) | 17 | 3,3 s |
| SonicSuit | 50 | 6,4 s |
| SuperSaiyanSonicSuit | 60 | 6,4 s |

Subida pura con traje tope: **3,2 s**. Diferencia entre el traje más débil y el más
fuerte: **4,5x** (antes era ilimitada por el planeo gratis).

Knobs en Config: `AbilityFlightDrainPerSecond` / `...PercentPerSecond` y
`AbilityFlightGlideDrainPerSecond` / `...PercentPerSecond`. Pon los de planeo en `0`
para volver al planeo infinito.

**Control:** antes había que mantener pulsado 0,85 s en el suelo, por eso se sentía
que "hay que saltar muchas veces". Ahora **saltas una vez y mantienes**: el vuelo
engancha `AbilityFlightAirborneHoldSeconds` (0,18 s) después de despegar. El timer de
suelo sigue como respaldo para despegar sin saltar.

Test nuevo: `audit/test_flight_balance.luau` simula el bucle real a 60 Hz y falla si
alguien vuelve a dejar el vuelo sin techo.

---

## 12. Promo codes retirados

* **`CodesCatalog` queda con un solo código: `BOOST`** (2x Speed + 2x Wins, 15 min).
  Retirar códigos es seguro: los marcadores de reclamo siguen en el perfil, así que
  a quien ya reclamó no le pasa nada, y un código desconocido responde "inválido".
* **El panel de códigos queda aparcado**: `Config.PromoCodesUiEnabled = false`. No se
  abre, y sobre todo **ya no se auto-abre al cerrar el Update Logs** (antes se te
  plantaba encima sí o sí). Se reactiva con esa sola línea.
* **El banner del Update Logs se genera desde el catálogo** (`CodesCatalog.Active`),
  no de texto fijo. Ya no puede anunciar un código que no canjea. Ahora lee
  `Codes: BOOST`.

Test nuevo: `audit/test_promo_codes.luau` verifica que solo BOOST canjea, que ningún
código retirado responde, que lo anunciado coincide con lo que canjea, y que el panel
no puede aparecer.

⚠️ **Decisión tuya:** con el panel apagado no hay UI para canjear BOOST. Si quieres
que BOOST sea canjeable, hay que dejar el panel activo. Dime cuál de las dos.

---

## 13. Trail: corrección de altura (tercera pasada)

Restauré el offset vertical autoral (+2.0) creyendo que era diseño. **No lo era** —
era altura de vitrina, igual que los 26.8 studs de profundidad. Medido contra el pack:

```
Cuerpo R6 respecto al HumanoidRootPart : -3.00 (pies) .. +2.00 (cabeza)
Cinta autoral respecto a su holder     : -4.90 .. +5.40  (10.3 studs, centro +0.25)
Con offset +2.0  -> cinta en           : -2.90 .. +7.40   toda por encima de la cabeza
```

Ahora el builder **mide** el cuerpo del maniquí y la extensión real de la cinta, y
centra una sobre la otra. Sin números mágicos: si el artista reexporta el pack, se
recalcula solo.

```
LocalOffset final : (0.00, -0.75, 0.55)
Cinta vs HRP      : -5.65 .. +4.65   centro -0.50  =  centro del cuerpo -0.50
```

Cubre de pies a cabeza y sobresale ~2,6 studs por arriba y por abajo: la estela.

El test `test_cosmetic_geometry.luau` ahora exige que la cinta **alcance los pies y
la cabeza** y esté centrada en el cuerpo (±0.35), en vez de comprobar un número fijo.

---

## 14. Primera sesión: Update Log → Daily Reward → Starter Pack

### Cadena

Al cerrar el Update Logs ahora se abre el **Daily Reward** (antes se abría el panel
de códigos, ya aparcado). Es lo único del onboarding que le da al jugador una razón
para volver mañana, y es justo donde perdemos al 85 % (D1 15 %).

### Daily Reward: cuatro bugs reales, no solo cosmética

1. **Las 30 tarjetas tenían `LayoutOrder = 0`** y el `UIListLayout` está en
   `SortOrder.LayoutOrder`. Sin nada que ordenar, los días podían renderizarse en
   cualquier orden. Ahora cada tarjeta lleva su número de día.
2. **Abría siempre en el Día 1.** Con 30 días en una lista, el jugador tenía que
   buscar a mano el día que podía reclamar. Ahora centra solo el día reclamable.
   Ojo: la lista es **horizontal**, así que el scroll va en X (lo leí del layout,
   no lo asumí).
3. **El botón Claim seguía brillante y clicable** en un día ya reclamado. Ahora se
   apaga y se desactiva cuando no hay nada que reclamar.
4. **Las etiquetas se resolvían por el texto de plantilla** (`text:match("^Day")`,
   `text:find("Victory")`). Si alguien editaba el texto, la tarjeta perdía sus
   labels en silencio y no volvía a actualizarse. Ahora hay respaldo por posición.

### Starter Pack

**El servidor ya lo tenía completo**: el remote `StarterPackClaim`, `grantStarterPackOnce`
con versionado, y las recompensas en Config (100K speed, 100 wins, Trail02).
**Lo que faltaba era la UI: no existía ningún cliente que lo ofreciera.** Por eso
nunca se le mostraba a nadie.

Porté `StarterPackOffer` del OG (`+1 Speedster Escape OGGG.rbxl`) a
`StarterPlayer/StarterPlayerScripts/UI/StarterPackOffer.client.luau`, con dos cambios:

* Usa el sonido de compra compartido en vez de crear su propia copia.
* **Comprueba propiedad.** En el OG ese check estaba comentado, así que seguía
  ofreciendo el pack a quien ya lo había comprado. Ahora se oculta con
  `StarterPackOwned` / `StarterPackGranted` y reacciona al cambio de atributo.

Conserva el temporizador de 17 min, el layout responsive (móvil y escritorio), el
precio en vivo desde Marketplace y los 6 reintentos de claim tras la compra.

Test nuevo: `audit/test_onboarding_flow.luau`.

---

## 15. Canjear códigos desde el HUD (icono en el topbar)

**Dónde lo puse y por qué.** En el **topbar**, junto a Daily y Settings, no en el
LeftSideBar. Razones:

* Es el patrón que el juego ya usa (`TopbarIconsController` ya monta Daily y
  Settings con TopbarPlus). Cero cambios en GUI autorada.
* El `LeftSideBar` es un `UIGridLayout` con celdas de 0.6 x 0.35 y **ya tiene 8
  botones** (Ability, Shop, Index, Rebirth, Evolve, Teleport, Backpack, Time Gifts).
  Meter un noveno obligaría a clonar un botón y pelearme con la rejilla — justo lo
  que me pediste no hacer.
* El topbar está siempre visible: se canjea sin abrir ningún menú.

**A dónde lleva.** A la **misma UI de códigos de la Shop**, como pediste. Resulta
que `MenuEvents` ya declaraba un evento `OpenCodesPanel` apuntando a la GUI de la
Shop, pero **nadie lo escuchaba** — era cableado muerto. Ahora el `ShopController`
lo atiende: abre la Shop, hace scroll directo a la sección Codes y **enfoca el
TextBox**, así el jugador puede escribir de una.

Antes: abrir Shop → buscar la sección Codes bajando. Ahora: un toque.

**Limpieza de nombre.** `Config.PromoCodesUiEnabled` pasó a
`Config.PromoCodesModalEnabled`, porque solo apaga el **card list duplicado** (el
que se auto-abría encima al cerrar el Update Logs), no el canje. El canje vive en
la Shop y está activo. El nombre anterior daba a entender que no se podía canjear
nada, y eso ya no es cierto.

El icono sale de `Config.CodesTopbarIconImage` (por defecto
`rbxassetid://138738878130228`, el arte de códigos que ya usa la Shop), así que lo
cambias sin tocar código.

**Nota aparte:** los 8 botones del `LeftSideBar` tienen todos `LayoutOrder = 0` con
`SortOrder.LayoutOrder`, igual que las tarjetas del daily. Hoy el orden sale del
orden de hijos y se ve estable, pero es frágil. No lo toqué para no reordenarte el
menú sin permiso; si quieres se lo fijo.

---

## 16. Panel de regalos

Investigado. Eran tres cosas distintas, y la tercera explica lo de "no puedes
regalar nada".

### No se podía llegar al último jugador

El `ScrollingFrame` del panel tiene `CanvasSize = (0, 0, 2, 0)` fijo y
`AutomaticCanvasSize = None`. Las filas se clonan por jugador, pero **nadie
actualizaba el canvas**. Medido contra el place autorado:

```
alto de fila (autorado)  0.1719 escala + 0.01 de padding
canvas autorado          2.0 escala
capacidad                10 filas EXACTAS
```

Con más de 10 jugadores aceptando regalos, el resto quedaba fuera del canvas y no
había forma de llegar. Ahora el canvas se calcula del número de filas usando el
**alto autorado de la plantilla**, no un número inventado. Y la lista pasa a
`ScrollingDirection.Y`: antes era `XY`, así que se podía arrastrar de lado y sacar
las filas de la pantalla.

### El panel se congelaba al abrirlo

`GetUserThumbnailAsync` es una llamada web que **cede**, y se llamaba **dentro del
bucle de filas**, una por jugador. En un servidor lleno eso bloqueaba el panel
varios segundos mientras se construía. Ahora las fotos se piden fuera del camino
crítico y se cachean por usuario; las filas aparecen de inmediato.

### "No puedes regalar nada"

De los **11 botones Gift** del shop, **8 están sobre gamepasses**: los 3 treadmills,
ExclusiveVIP, 2X Win, 2X Speed, Revive y Starter Pack.

**Roblox no permite regalar un gamepass.** El flujo de regalo de este juego es un
developer product que el servidor redirige al destinatario (`GiftContextRequest` ->
`SetGiftContext` -> `ProcessReceipt`), y eso solo existe para productos. Los
gamepasses no pueden regalarse, punto.

Lo que estaba mal no era la mecánica: era que el botón **no lo decía**. Había que
abrir el panel, elegir un jugador, hacer clic, y solo entonces una etiqueta pequeña
cambiaba a "Gift unavailable". Ahora el panel lo dice **al abrirse**: las filas
muestran "Passes can't be gifted" y el botón queda desactivado. Tu propia fila dice
"That's you".

**Sí se puede regalar**: las 6 pociones y el 2X Server Speed. Esos son productos.

Si quieres que los treadmills o el VIP sean regalables, hace falta **crear un
developer product paralelo** por cada uno y mapearlo; dime y lo monto.

### Extra

La lista solo se construía al abrir, así que quien entraba o salía mientras estaba
abierta dejaba una fila fantasma o no aparecía. Ahora se refresca en vivo.

Test: `audit/test_gift_panel.luau`, que además verifica contra el place que el
canvas autorado realmente solo daba para 10 filas.
