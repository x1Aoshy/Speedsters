# Auditoría de rendimiento — cliente y servidor (2026-09-16)

---

## 1. La causa principal del lag NO está en el código: es una propiedad del place

```
StreamingEnabled        true
StreamingMinRadius        64      <-- el problema
StreamingTargetRadius   1024
StreamingIntegrityMode  PauseOutsideLoadedArea      <-- el problema
```

Idéntico en World 1 y World 2.

### Por qué importa en ESTE juego

La WalkSpeed real sale de una curva (`RealWalkSpeedMin` 8 -> `RealWalkSpeedAtReference`
300, curva ^2). Calculado sobre la progresión real:

| Speed mostrado | WalkSpeed | Con boost x1.7 | Margen con MinRadius 64 | Con 512 |
|---|---:|---:|---:|---:|
| 1K | 19 | 32 | 1,99 s | 15,9 s |
| 100K | 38 | 65 | 0,98 s | 7,9 s |
| 1M | 52 | 88 | 0,73 s | 5,8 s |
| 1B | 106 | 180 | **0,35 s** | 2,8 s |
| 1T | 182 | 310 | **0,21 s** | 1,7 s |
| tope (3,37e15) | 300 | 510 | **0,13 s** | 1,0 s |

510 studs/s es el **tope absoluto**, no lo normal. Pero a partir de ~1B de speed
mostrado el margen ya baja de medio segundo, y ahí es donde están tus jugadores
avanzados — los que pagan.

El jugador **le gana al streaming**. Y con
`StreamingIntegrityMode = PauseOutsideLoadedArea`, Roblox responde
**congelando al personaje** hasta que el terreno cargue.

Eso explica exactamente lo que dijiste: *"era el lag y la velocidad"*. Y explica
los win pads 50/50 sin que los pads tengan nada malo — si el pad no está
transmitido, o el personaje está pausado, el contacto no se registra.

### Qué cambiar (en Studio, yo no puedo)

Esto son propiedades de `Workspace`, no scripts. `build_core` verifica que el
grafo autorado no cambie, así que **no lo toco desde el pipeline**. Hazlo tú:

| Propiedad | Ahora | Ponlo en | Por qué |
|---|---|---|---|
| `StreamingIntegrityMode` | `PauseOutsideLoadedArea` | **`Disabled`** | Es lo que congela al jugador. Prefieres que corra sobre terreno a medio cargar antes que quedarse clavado. |
| `StreamingMinRadius` | 64 | **512** | A 510 studs/s, 64 studs es un octavo de segundo de margen. |
| `StreamingTargetRadius` | 1024 | 1024 (dejar) | Ya está bien; subirlo cuesta memoria en móvil. |
| `StreamOutBehavior` | `Opportunistic` | **`LowMemory`** | Deja de descargar partes en cuanto puede. Menos pop-in de pads y suelo mientras corres. |

**Pruébalo primero en un servidor privado.** Subir `MinRadius` sube el uso de
memoria del cliente; con 8.034 partes en World 2 conviene medirlo en un móvil
antes de publicar.

---

## 2. Lo que sí arreglé en código

### Cliente: reconstrucción de billboards en bucle

`WinPadTextDistance` corre a 30 Hz. Cuando un pad se invalidaba, reconstruía toda
la tabla de seguimiento **al frame siguiente**, y esa reconstrucción incluye dos
`Workspace:FindFirstChild(nombre, true)` — búsquedas **recursivas del Workspace
entero** (8.034 partes en World 2).

Con StreamingEnabled los pads entran y salen constantemente, así que a velocidad
de speedster eso se disparaba cada pocos frames.

* Las búsquedas de marcador ahora están cacheadas (solo se rehacen si el marcador
  dejó de existir).
* La reconstrucción está limitada a **1 cada 0,5 s**. Para carteles es de sobra.

### Servidor: tráfico de red (de pasadas anteriores)

| Ruta | Antes | Ahora |
|---|---|---|
| Popups de velocidad | 10–20 remotos/s por jugador | agrupados a **5 Hz** |
| Estado de tienda trails/auras | 1 envío por **cada cambio de Wins** | **1/s** coalescido |
| `UserOwnsGamePassAsync` | 1 por ítem de catálogo en **cada** envío de estado | cacheado por jugador; los dev products ya ni se consultan |
| Atributos de estamina | 5 atributos a 60 Hz | 2 que cambian, a **4 Hz** |
| Plataformas que se desvanecen (W2) | 15 escrituras de Transparency por toque, replicadas | desactivadas (las lleva el cliente por jugador) |

---

## 3. Lo que medí y está bien

* **0 partes sin anclar** en ambos mundos. La física del servidor no replica nada.
* **World 1**: 4.655 partes, 8 scripts en Workspace.
* **World 2**: 8.034 partes, 57 scripts en Workspace. De esos, los `Conveyor`
  hacen `script:Remove()` tras configurarse (coste cero) y los `Butter` del kit
  ASMR solo conectan Heartbeat **mientras alguien los pisa**, y se desconectan al
  soltar. Aceptable.
* `MovementGuard` muestrea a 10 Hz por jugador, solo CPU, sin red.
* Escaneé 74 posibles puntos calientes por frame; salvo el de los billboards, el
  resto son falsos positivos (código dentro de callbacks de evento anidados).

---

## 4. Lo que NO puedo medir desde aquí

No hay perfilado real: ni `--!native`, ni microprofiler, ni `AnalyticsService`
(cero usos en todo el código). Todo lo de arriba es análisis estático y lectura de
las propiedades del place.

**Para medirlo de verdad:** abre el MicroProfiler en un servidor privado
(Ctrl+F6), mira `NetworkReceive` / `NetworkSend` en el cliente y el tiempo de
Heartbeat en el servidor con 10-20 jugadores. Si quieres te preparo un script de
diagnóstico que registre esas cifras cada 30 s.

---

## 5. Movimiento suave de partes (árboles y martillos)

### Por qué nada movido por el servidor se ve suave

Cualquier `CFrame` que escribe el servidor **se replica a ~20 Hz**. No importa a qué
ritmo lo calcule el servidor: el cliente recibe ~20 poses por segundo y las aplica
de golpe, sin interpolar (son partes ancladas, no física). De ahí los saltos.

### Árboles de World 2 — ARREGLADO

Medido: 6 árboles x 2 MeshParts de 83 studs. El golpe dura **0,16 s**, así que a
~20 Hz el cliente recibía **unas 3 poses para todo el impacto**. Por eso el árbol
parecía teletransportarse encima del jugador.

**Por qué se podía cambiar sin riesgo:** el daño ya lo decide el cliente con un
`GetPartsInPart` exacto cada RenderStepped. El servidor solo confirma con un radio
**estático** (`treeContactBounds`), nunca con la pose animada — hay un comentario en
el propio código explicando que revalidar con la pose del servidor discreparía de lo
que el jugador ve. La animación del servidor era **puramente visual**.

**Qué hice:** el movimiento es ahora una función pura del tiempo en
`ReplicatedStorage/Shared/TreeSlamMotion`. El servidor publica las constantes una
vez (base, eje, pose de reposo, reloj compartido) y **cada cliente lo dibuja en
local** a su propio framerate desde `Workspace:GetServerTimeNow()`.

* Misma pose en todas las máquinas (reloj sincronizado).
* Suave al framerate del jugador, no a 20 Hz.
* Cero replicación por frame.
* El jugador muere por lo que **ve**, que es más justo que antes.

Las curvas de easing originales (Quint In para bajar, Sine Out para subir) están
reproducidas exactamente, y los tiempos y el desfase entre árboles son idénticos.

Test: `audit/test_tree_slam_motion.luau` comprueba determinismo, continuidad
(ningún salto entre fotogramas), el desfase entre árboles, y que el servidor ya no
escriba CFrames.

### Martillos de World 1 — ENCONTRADO, NO TOCADO

World 1 **ya tiene** un renderizador suave escrito: `World1ClientMotionHazards`
(V306KR, 359 líneas) dibuja Hammer1-5, Presser1-5 y UpDown1-3 en local desde el
reloj del servidor, y `World1ClientHazardAuthority` (180 líneas) valida los golpes
contra una pose virtual.

**Nunca se ejecuta.** Ambos empiezan con:

```lua
if obj:GetAttribute("ClientMotionType") ~= "Hammer" then return end
```

Y ese atributo **no lo pone nadie**: no aparece en ningún script de `src/`, y en el
place autorado hay **0 objetos** que lo tengan. La migración se escribió pero nunca
se encendió.

Resultado: los martillos los sigue moviendo `NewWorld1ServerMotion` a 30 Hz en el
servidor, replicando a ~20 Hz. Por eso no se ven suaves.

**Por qué no lo encendí yo.** Encenderlo no es solo activar una animación: mueve la
**autoridad del daño** del chequeo barrido de `NewWorld1ServerMotion` a la validación
por pose virtual de `World1ClientHazardAuthority`. Son ~540 líneas que nunca han
corrido en producción, y yo solo tengo pruebas estáticas. Si la matemática del
cliente difiere aunque sea poco de la del servidor, los martillos matan donde no
deben. Es exactamente la clase de cambio a ciegas que provocó la regresión del 13
de septiembre.

**Lo que propongo:** encenderlo en un servidor privado, con un test que compare la
pose del cliente contra la del servidor en los mismos instantes antes de publicar.
Si quieres, lo preparo.
