# Sesión 2026-09-20 (tarde): martillos, meteorito de tacos y arreglos de la auditoría

Aplicado a `World1Update3New.rbxl`, `World2Update3new.rbxl`, `World3Update3New.rbxl`. Abrirlos **desde disco**.
Cada pass tiene su carpeta con copias y respaldo: `output/FableHammersAndMotion`, `output/FableTacoMeteor`, `output/FableAuditFixes`.

Verificar todo: `lune run audit/run_fable_checks.luau` (16 suites). **Nada de esto se ha probado en Studio.**

## Pass 1 — Martillos de World 1
- Causa de "se mueven mal / parecen sueltos": el servidor escribía el CFrame de las 12 piezas de cada martillo 30 veces por segundo; cada pieza se replica por separado y llega en paquetes distintos.
- Ahora el servidor no mueve nada: publica pivote, eje, fase e inicio, y cada cliente mueve las piezas reales con un solo `BulkMoveTo` por frame desde el reloj del servidor (`Shared/World1HammerMotion`, `Gameplay/NewWorld1HammerMotion`).
- **Solo se mueven los cercanos:** cada frame a menos de 320 studs, cada 3 frames hasta 640, y nada más lejos.
- **Hammer3 giraba sobre el eje equivocado.** Todos usaban la dirección global del recorrido (Z); Hammer3 está en la plataforma transversal, donde el camino va en X, y barría el camino de costado. El eje sale ahora de la propia cabeza del martillo. Los martillos 1, 4 y 5 no cambian.
- Las muertes siguen igual: el cliente detecta el golpe sobre las piezas que ve; el servidor conserva un respaldo matemático (cajas contra cajas, dos instantes, caras recogidas 0,6 studs).
- Los modelos de martillo pasan a streaming `Atomic` (llegan enteros). El "whoosh" lo reproduce cada cliente.

## Pass 2 — Resto de obstáculos de World 1
- El servidor deja de escribir piezas de un obstáculo cuando no hay ningún jugador a menos de 450 studs de **todo su recorrido** (sigue calculando la pose; al despertar queda exactamente donde debía). Prensas, láseres, cilindro, slides, "fast" y lava.

## Pass 3 — Taco Treadmill: meteorito
- El Taco Treadmill ya no sale del suelo: cae desde 560 studs en diagonal dentro de un **taco gigante**, con 12 tacos orbitando (6 en teléfonos), fuego y humo; acelera hasta el impacto y aterriza derecho en su sitio.
- Impacto: el taco gigante revienta, los tacos salen despedidos, cráter de 30 rocas del color y material del suelo (módulo propio; no usé el RockModule de ZeroDown porque es código descompilado de otro juego), trozos por el aire, anillos de choque y el mismo splash de los tacos de la lluvia a tamaño meteorito.
- Cámara para todos: desde el suelo mirando al cielo → gira al costado mientras entra → empujón y gran angular en el impacto → órbita sobre el cráter. Sin cortes bruscos (probado cuadro a cuadro) y siempre devuelve cámara y FOV.
- Nada de lo creado tiene colisión: no estorba el acceso al treadmill.

## Pass 4 — Auditoría (aprobado)
- Camino caliente del speed: `PeekSpeed` en vez de 3 copias del perfil por tick; una proyección por segundo por jugador en vez de dos.
- Barra de sprint solo para su dueño (`StaminaSync` no fiable + extremos fiables): 0 atributos replicados al esprintar (antes ~8/s por jugador a los 60).
- `BoostState` y `WalkSpeedModeRequest` con limitador que nunca pierde el último estado.
- Animaciones: re-publicación solo al **entrar** un jugador, no en cada respawn.
- Entrada: jugador nuevo sin Update Logs ni Daily en su primer minuto (Daily al acabar tutorial y guía); los demás ven Update Logs solo si hay versión nueva.
- `LevelProgress` como atributo cada 2 s (la barra del dueño sigue fluida por remoto); límites en Sync/Refresh/RequestState; fuera el `print` de cada revive; sombras globales apagadas solo en teléfonos; `PlayerCharacterDestroyBehavior = Enabled`.
- Ritmo: Candy a 2 rebirths (era 3) y Diamond a 4 (era 7). Ganancias intactas; World 2 sigue en 7 rebirths + nivel 100.

## No hecho, y por qué
- **Multiplicador de rebirth ×2,0 en los rebirths 4–7:** según el modelo llevaría World 2 a ~20 min y multiplicaría ×3,2 la ganancia de todos los jugadores actuales en los tres mundos. Es la segunda variable del plan; conviene medir primero la escalera de treadmills.
- **`CanTouch`/`CanQuery` y texturas en W1/W3:** no puedo distinguir por script un adorno de un sensor invisible; hay que hacerlo en Studio con el diseñador.
- **Retirar `PlayerStats` heredado:** cuatro pruebas antiguas leen ese archivo.
- **LOD de animadores:** la animación cuesta 0,8 ms en cliente; el riesgo de reabrir el bug que lo motivó no compensa.
- **Pantalla antes/después del rebirth, objetivo de sesión en el HUD y tarjeta "vuelve mañana":** son UI nueva; conviene hacerlas con el arte del diseñador.
- **Creator Hub:** verificar los IDs nuevos de x2…x32 Speed y el pase 2x Wins, y el precio de entrada.

---

# Segunda tanda (2026-09-20, noche)

Verificar todo: `lune run audit/run_fable_checks.luau` (17 suites). Sigue **sin probar en Studio**.

## Suavidad de los obstáculos de World 1 (`output/FableSmoothObstacles`)
- Yo no había bajado los Hz de esos obstáculos: prensas, láseres, slides, "fast" y lava seguían llegando **por red a 20–30 Hz con jitter**, que es lo que se nota en un parkour. Ahora hacen lo mismo que los martillos: el servidor publica una vez la "pista" de cada obstáculo (`Shared/World1ObstacleMotion`) y cada cliente mueve las piezas reales **en cada frame** desde el reloj del servidor (`Gameplay/NewWorld1TrackMotion`), con un solo `BulkMoveTo` por obstáculo.
- Mismos tiempos de siempre: 54.010 poses comparadas contra las fórmulas del script anterior, error máximo 0,023 studs (precisión float32 a y = 37.500). La prensa pasa de saltos de 18,7 studs por paso visible a 7,2; el bloque "fast" de 8,9 a 3,0.
- Rendimiento: el servidor ya no escribe ni replica ninguna de esas piezas. En cliente solo se mueven los obstáculos a menos de 600 studs (cada 2 frames hasta 1.100, nada más lejos). Los martillos usan los mismos radios ahora.
- El servidor conserva su respaldo de muertes sobre la pose virtual. Solo el cilindro rodante sigue movido por el servidor (con la pausa cuando no hay nadie cerca).

## Meteorito de tacos v2 (`output/FableTacoMeteor`)
- **Caída más larga:** 4,5 s (antes 2,3) y desde 760 studs. El reloj del reveal se estira solo hasta el impacto; el treadmill admin normal no cambia.
- **Fuego del V40** (`src/ui/TacoMeteorAssets.rbxm`, capturado con `audit/capture_taco_meteor_assets.luau`): la bola de fuego de "Bombardiro Crocodilo" envolviendo el taco (las llamas cortas viajan con él, brasas y humo quedan de cola), el chorro del lanzallamas apuntando hacia atrás y el trail de Starfall. Solo emisores de partículas: sin scripts ni sonidos.
- **Impacto más notorio:** explosión del V40 + bola de luz + dos anillos + el splash de tacos ×6 en el centro **y otros 8 alrededor del borde del cráter** uno tras otro.
- **Rocas:** cada roca lanza su propio raycast y toma material, color, variante y altura del suelo que tiene debajo; donde no hay suelo no sale roca. A los 12 s se hunden despacio (1,8 s, escalonadas, encogiéndose) en vez de desaparecer.
- **Sonido:** "Rocket whoosh 01" (sube de tono y volumen mientras cae) y "Cannon_Explode" en el impacto. Son audios de la cuenta oficial de Roblox, así que suenan en cualquier juego; los del V40 son privados de otro grupo y no sonarían en el tuyo.
- **UI oculta durante la cinemática:** se apagan todos los ScreenGui visibles (HUD incluido) y el CoreGui, y al volver la cámara —o si el reveal se corta— se restaura exactamente lo que estaba encendido.
- **Treadmill de tacos (versión final, a pedido):** treadmill normal, sin tacos colgados. Un solo taco flotando encima, que cada cliente mueve en cada frame desde el reloj del servidor (`Admin/TacoTreadmillFloat`; antes lo movía el servidor y se veía a saltos). Menos partículas de tacos (tacos 22→5/s, copos 26→7/s, sin copos de colores). **Más fuego:** 6 fuegos a los pies del treadmill hechos con las piezas de fuego del propio splash de los tacos al caer (`Shared/TacoFire` sobre `StruckVFX`: Fire, FireSpecs, Embers; solo colores cálidos, conservando su flipbook). El meteorito también arde con ese mismo fuego mientras cae.
- **Emisores "corrompidos":** eran texturas de 4×4 cuadros creadas por código sin `FlipbookLayout`, así que cada partícula dibujaba la hoja entera (los racimos de puntitos). `Shared/ParticleFlipbooks` lo corrige en los copos de tacos, fuegos artificiales y en el treadmill.

---

# Tercera tanda (2026-09-20, noche): ajustes tras tu prueba

Verificar todo: `lune run audit/run_fable_checks.luau` (17 suites, 0 fallos). Sigue **sin probar en Studio** por mi parte.

## Evento de tacos
- **Sonido de cohete eliminado.** La caída ya no tiene sonido propio (quedan el retumbar del reveal y el "Cannon_Explode" del impacto). Si quieres otro sonido para la caída, pásame un id de audio público o dime el estilo y lo busco entre los de Roblox.
- **Taco gigante 20 % más chico:** `TacoMeteor.TacoWidth = 1.2` (antes 1,5 veces el ancho del treadmill). La bola de fuego del V40, el chorro y el fuego de tacos se escalan con él.

## Panel admin
- En la tarjeta **Admin treadmill** ya no existe la opción "No disco / With a Disco Party"; los botones Rainbow / Taco / Remove All no envían `withDisco`. El servidor toma la ausencia como "sin disco". El evento **Disco Party** sigue existiendo por separado.

## World 1: lo que ya pasaste deja de moverse
- El servidor publica la dirección del recorrido (`Workspace.NewWorld1CourseDirection`, de stage1 a stage6; el mapa corre en +Z). Cada cliente, cada 0,25 s, marca como "lejos" (no se mueve nada) todo obstáculo que su corredor ya dejó atrás: más de **160 studs más allá del borde más lejano del obstáculo** en la dirección del recorrido (`Motion.TierFor` + `Motion.Reach` en `World1HammerMotion` y `World1ObstacleMotion`). Vale para martillos, prensas, láseres, slides, "fast", lava y cilindro.
- Tu caso, comprobado contra el mapa real: parado en los primeros láseres, los 4 martillos quedan quietos; desde el stage 4 el cilindro también.
- Si vuelves atrás, caes o te teletransportan a un stage anterior, el obstáculo vuelve a moverse en ≤ 0,25 s y **exactamente a tiempo**, porque su pose solo depende del reloj del servidor. Un obstáculo enorme (la lava) no se considera pasado mientras sigas encima: el margen se suma a su tamaño.
- **Servidor:** con el cilindro ya en los clientes, el servidor **no escribe ni replica ninguna pieza de ningún obstáculo**, haya quien haya. Solo calcula poses virtuales (unas 20 cuentas a 30 Hz) para su respaldo de muertes.

## World 1: el cilindro rodante ahora es suave
- Era el último obstáculo que movía el servidor (30 Hz + red): por eso giraba a saltos. Ahora es una pista "Roll": el servidor calcula su ruta sobre el suelo como siempre (166 puntos, ~4,5 KB, una sola vez), la publica, y cada cliente lo hace rodar **en cada frame** con la misma fórmula (`Motion.RollPivot`): espera 0,37 s, rueda a 30 studs/s girando distancia/radio, espera 0,77 s.
- Mismos tiempos: 3.601 poses comparadas con la fórmula anterior, error máximo 0,008 studs; la ventana en la que mata es idéntica. La piel del cilindro pasa de saltos de 3,0 studs por paso visible a 1,0.
- El respaldo de muertes del servidor juzga el contacto donde dice la pose virtual (`characterTouchesExactCylinder(..., cylinderCFrame)`), no donde descansa la pieza, que en el servidor ya no se mueve.

Copias de lo anterior: `output/FableSmoothObstacles/backup_src_v2`, `output/FableTacoMeteor/backup_src_v3`.
