# Plan de unificación del core, red e hitboxes

Fecha: 13 septiembre 2026. Estado: propuesta de ejecución basada en inspección; la migración de arquitectura todavía no se ha aplicado. Este documento sirve también como traspaso a Gemini.

## 1. Decisión recomendada

Mantener **una sola fuente editable del core** y generar World1 y World2 desde esa fuente, con configuración y assets propios de cada mundo. Primero consolidar código sin cambiar sus resultados; después mover efectos y optimizar por medición. No hacer una reescritura simultánea de guardado, movimiento, UI y economía.

El servidor conserva datos, compras, recompensas, permisos, estado autoritativo y reglas de juego. El cliente dibuja la UI y ejecuta partículas, sonidos, tweens, animaciones y predicción visual. La geometría compartida se calcula con funciones puras usadas por ambos. Un cliente no decide cuánto gana, qué compró ni si otro jugador debe morir. Esta frontera coincide con las [reglas de validación de Roblox](https://create.roblox.com/docs/scripting/security/client-server-boundary).

`ReplicatedStorage.Shared` contendrá contratos, catálogos públicos y matemáticas. **DataService, recibos y lógica administrativa permanecerán en ServerScriptService.** Una carpeta llamada Packages no comparte automáticamente código entre places: cada servidor ejecuta su copia. Lo que evita el desfase es construir esas copias desde la misma revisión y verificar sus hashes.

## 2. Qué se inspeccionó realmente

Se leyeron el informe completo actualizado `INFORME_PARA_ASTRA.md` (secciones 1–17), los informes de red/hitboxes, los proyectos JSON, las fuentes afectadas y los dos `.rbxl` recientes. Se guardó una instantánea independiente en `audit/incoming_core_plan` y el inventario en `audit/core_inventory.json`.

| Evidencia actual | World1 | World2 |
|---|---:|---:|
| Scripts en el archivo, incluidos módulos y scripts desactivados | 182 | 229 |
| BaseParts en Workspace | 4.655 | 8.034 |
| BaseParts desancladas en el archivo | 0 | 0 |
| Scripts habilitados dentro de Workspace | 8 | 22 |
| Fuentes del `.rbxl` distintas de `audit/merged` | 4 | 14 |

Hay **140 rutas comunes con un único script por mundo cuyo contenido es idéntico**, normalizando finales de línea. Hay otras 14 rutas comunes diferentes y scripts exclusivos de cada mundo. El detalle completo está en el JSON; la igualdad no implica que todos deban ejecutarse en todos los mundos.

Caso inmediato: `Gameplay/World1FlightAbility` y `Gameplay/World2FlightAbility` del servidor solo difieren en el texto del último `print`. Son candidatos claros a una única implementación con dos adaptadores temporales.

### Cambios de Gemini que se conservan como base de revisión

- ASMR cliente, superficies sólidas conservadas, reducción de decoración física y retirada de carteles de carga.
- Cachés de referencias de etapas y árboles; filtro de distancia de Sonic; ajuste de adquisición de objetivos de NPCs.
- HUD móvil, espaciado de buffs, navegación del menú Worlds, cambios de mando/Topbar y sprint.
- Vuelo con control de despegue, regeneración en suelo, conservación de estamina al cambiar traje y debounce de equipamiento.
- Nuevos códigos/modal y comandos de boosts.

No se sustituyen automáticamente por versiones antiguas de `audit/merged`. Los 18 conflictos de fuente tienen que resolverse antes del siguiente empaquetado. Los assets de UI y posiciones authored de Gemini también son parte de la base, no solo el texto de los scripts.

### Hallazgos que impiden aceptar el “100% verificado” del informe

1. `PadTouchService` actual crea volúmenes de **14 studs**, añade márgenes y barre hasta **256 studs por muestra**, ejecutándose cada Heartbeat. El informe menciona `Workspace:Raycast`, pero el archivo inspeccionado usa intersección de segmentos con cajas. La prueba anterior falla porque exigía volumen de 5 studs. Esto demuestra cambio de contrato, no por sí solo que 14 studs esté mal: hay que medir solapamiento y falsos cobros antes de aceptarlo.
2. El detector rápido y `RewardPadClaims.characterAtPad` no usan todavía el mismo criterio. Un segmento puede cruzar el pad mientras la posición actual ya queda fuera del margen de cobro. Aumentar cajas arbitrariamente no resuelve esa discrepancia.
3. El código de peligros World1 conserva `BODY_PADDING=(2.6,3.5,2.6)` en pruebas letales de caja expandida. Puede considerar contacto sin cuerpo visible dentro del obstáculo. También conserva historial de posición sin asociarlo a la identidad del Character en esa ruta. Esa segunda corrección del agente quedó pendiente; no debe presentarse como terminada.
4. `FadingPlatformsClient`, dentro del `.rbxl` nuevo, cambia colisión local además de transparencia, cambia tiempos frente al script previo y no limpia sus tablas al salir instancias del streaming. Hay que tratarlo como cambio de mecánica con ciclo de vida, no solo como optimización cosmética.
5. El informe afirma respawn de etapa persistido como `CurrentStage`/`SpawnStage`; no aparece una implementación canónica de esos campos en las fuentes de Data inspeccionadas. Se debe trazar CharacterAdded, RespawnLocation y el perfil real antes de afirmar persistencia o introducir una migración.
6. Los JSON Rojo actuales apuntan a carpetas separadas y exportaciones de auditoría. No representan por sí solos un proyecto reproducible con clases de scripts, mapas y UI preservadas. Debe verificarse clase por clase; compilar Luau no detecta que un Script ejecutable fue convertido accidentalmente en ModuleScript.

Pruebas repetidas en esta revisión: compilación merged, estamina, contacto de peligros con motor simulado y regresión de persistencia en ambos mundos pasan. `test_pad_volumes` falla en la expectativa de altura. El registro está en `audit/core_plan_validation.json`. Estas pruebas no cubren todos los cambios nuevos de Gemini ni reemplazan Studio.

## 3. Arquitectura destino

```text
src/
  shared/
    Contracts/       -- tipos, versiones y formatos de mensajes
    Catalogs/        -- productos, trajes, niveles, códigos públicos
    Math/            -- curvas, trayectorias, geometría pura
    WorldConfig/     -- datos públicos de cada mundo
  server/
    BootstrapServer
    Data/            -- Actor, Codec, Reducers, Adapter, migraciones
    Economy/         -- recibos, regalos, canjes, precios autoritativos
    Progression/     -- speed, rebirth, wins, checkpoints
    Abilities/       -- Flight y estamina autoritativos
    World/           -- teleport, registry de pads/peligros, NPCs
    Network/         -- handlers, validación, límites, publicación
    Admin/           -- permisos y comandos
  client/
    BootstrapClient
    UI/              -- HUD, paneles, navegación, escalado
    Input/           -- teclado/touch/mando y estado de menús
    Abilities/       -- controles y presentación de Flight
    Effects/         -- ASMR, confeti, partículas, sonidos, tweens
    World/           -- presentación de peligros/NPCs y streaming
  worlds/
    World1/          -- configuración privada y adaptadores de mapa
    World2/
entrypoints/
  Main.server.lua
  Main.client.lua
assets/
  worlds/World1.rbxl
  worlds/World2.rbxl
  ui/                -- plantillas authored, referencias preservadas
packages/            -- dependencias externas fijadas por versión
projects/
  core.project.json
  world1.project.json
  world2.project.json
tools/
tests/
releases/
```

Ubicación en Roblox: shared → `ReplicatedStorage.Shared`; client → `ReplicatedStorage.Client`; paquetes públicos → `ReplicatedStorage.Packages`; server → `ServerScriptService.Core`; dependencias privadas → `ServerScriptService.Packages`; assets solo de servidor → `ServerStorage`. Los dos entrypoints quedan en sus contenedores de ejecución correspondientes.

Elegir un formato de fuente admitido por la versión instalada de Rojo y fijarlo. Los sufijos `.server.lua`/`.client.lua` distinguen Script y LocalScript; los módulos usan `.lua`. Si se conserva `.luau`, verificar su soporte mediante un build de prueba y el manifest de clases. Mantener archivos/modelos y metadatos para propiedades que una exportación de código no representa. [Conversión de archivos y límites de sincronización de Rojo](https://rojo.space/docs/v7/sync-details/).

### Contratos mínimos, sin un framework grande

- `WorldConfig`: worldId, placeId, destinos válidos, mapa lógico de etapas, referencias/tags de spawn, catálogo de cintas, boss/hazards habilitados y opciones de UI. La elección del mundo en servidor procede del despliegue; no de un valor enviado por el cliente.
- `WorldRegistry`: resuelve StageId/TreadmillId/HazardId a instancias. Se registra al iniciar y se actualiza por alta/baja/cambio de instancia; no recorre Workspace por cada tick.
- `FlightService`: Init(dependencies, worldConfig), Start(), Stop(); decide equipamiento, despegue, estamina y expiración. `FlightController` solo envía intención y presenta movimiento.
- `HudController`: recibe una vista pública de estado y una configuración de layout. Un solo dueño del escalado, del estado de menú y de los tweens de cada panel.
- `HazardMotion`: `TransformAt(definition, serverTime)` pura, sin servicios ni escritura a instancias. Servidor y cliente calculan la misma fase a partir de seed/epoch/version.
- `HazardService`: mantiene estado letal y valida contacto con geometría corporal adecuada. `HazardRenderer` dibuja la malla y efectos.
- `EffectController`: Mount, Update si hace falta, Unmount; crea recursos solo dentro de su ámbito y los destruye al salir del streaming, morir o finalizar el efecto.
- `DataService`: conserva inicialmente su API y sus garantías actuales. Se mueve la fuente, no se reescribe el protocolo de guardado durante la extracción.

Cada módulo debe declarar dependencias y no empezar loops al hacer require. Bootstrap ejecuta Init/Start una vez y Stop destruye conexiones/tareas. Evitar referencias circulares. Los `_G.Speedster*` existentes se mantienen temporalmente como adaptadores a servicios, con listado de consumidores y retirada gradual.

## 4. Matriz servidor/cliente por sistema

| Sistema actual | Servidor conserva | Cliente ejecuta | Condición antes de mover |
|---|---|---|---|
| Bootstrap/Data/PlayerStatsBridge | sesiones, commits, acumulación, decisiones de estamina | barras interpoladas | conservar estados y leases |
| PotionServer/códigos/daily/rank | entrega y duración autoritativa | tarjetas, cuenta atrás, sonidos | timestamp/duración y recibo idempotente |
| TreadmillTraining | zona válida, requisito/pase, ganancia | cinta visual, billboard, zapatitos | una misma definición de zona/ganancia |
| PadTouchService/RewardPadClaims | detección/validación, retorno, premio | color, texto, feedback | sweep y prueba de cobro coherentes |
| Martillos/árboles/láseres | fase y decisión de daño | mallas no sólidas, partículas/tweens | misma geometría/tiempo; soporte de lag |
| Plataformas que transportan al avatar | soporte físico y reglas compartidas | presentación y detalles | probar contactos/transporte; no quitar física a ciegas |
| Plataformas que desaparecen | estado compartido si ese es el diseño; reglas antiexploit | transparencia y sonido | decidir explícitamente si son personales o compartidas |
| NPCs/jefes | objetivo, estados de combate, daño, proxy necesario | animación y detalles | no crear dos perseguidores/colisionadores |
| ASMR | suelo/superficie sólida | piezas cosméticas, squish, sonido | limpiar streaming y limitar instancias activas |
| Confeti | puntos recogibles, validación y bonus | lluvia decorativa, color y rotación | cliente no mueve objeto premiable |
| Menús/HUD | estado público y resultado de acciones | navegación, layout, tweens | una sola conexión por acción |
| Anuncios/admin | permiso, filtrado y evento deduplicado | render/sonido | nada de entrega por cierre de prompt |

“Todo en cliente” no es la meta. Para una plataforma que sostiene al jugador, mover únicamente su apariencia puede provocar caída o desajuste. Ese caso necesita conservar un proxy físico o diseñar expresamente simulación personal con validación compatible.

## 5. Fases de implementación y criterios de salida

### Fase 0 — Consolidar la base y cerrar red/hitboxes urgentes

1. Congelar snapshots de fuentes, mapas e informe de Gemini con hash. Nunca volver a empaquetar desde `incoming_20260913` o `incoming_gemini_network` encima de la base nueva sin reconciliación.
2. Resolver los 18 conflictos listados en core_inventory: etapa/caché, MovementGuard, bosses, ASMR, Fading y controladores desactivados por mundo. Comparación de tres versiones: snapshot anterior, fuente editable actual y nuevo `.rbxl`.
3. Registrar ajustes de posición, Size, Anchored, CanQuery/CanCollide/CanTouch, GUI Padding/NextSelection y scripts Disabled por **instancia**, conservando hermanos con nombres repetidos.
4. Revisar la desactivación masiva de decoración: una coincidencia de nombre Tree/Rock no demuestra que sea decorativa. Excluir modelos de hazard y comprobar que su renderer/validator dispone de geometría consultable.
5. Unificar prueba de contacto de pads: volumen authored configurable, sweep relativo al Character actual, reinicio después de teleport, límite físico de desplazamiento y prueba de contacto usada por el mismo claim. No aceptar solo el relato del cliente.
6. Terminar el contacto letal World1: separar broad phase de narrow phase; eliminar muertes causadas únicamente por caja expandida; excluir accesorios; manejar respawn y movimientos discontinuos. No encoger MeshParts por porcentaje sin inspección visual.
7. Revisar ASMR cliente y Fading: limpieza de conexiones/tablas/tweens al desaparecer instancia y coherencia al reaparecer; evitar generar 570 piezas en servidor. Conservar las superficies necesarias.
8. Mantener la publicación de estamina a 4 Hz con extremos inmediatos y getter autoritativo de servidor. Probar además los cambios nuevos de vuelo/suelo de Gemini.

Salida: ambas bases coherentes; manifiesto de cambios deliberados; pruebas de persistencia y contacto pasan con los contratos decididos; ningún controlador requerido queda desactivado por una condición del mundo equivocada. La física y red todavía deben pasar el escenario de Studio de la fase 1.

### Fase 1 — Medir antes de afirmar que desapareció el lag

Crear una escena reproducible por mundo: 60 s quieto, 60 s corriendo/sprint, 60 s en cinta, recorrido de pads, zona de NPCs, ASMR, martillos/árboles y apertura repetida de UI. Repetir tras respawn y tras entrar/salir 20 veces de zonas con streaming.

Ejecutar con 1, 5 y 15 jugadores o el máximo configurado si es menor. Separar prueba local de carga de servidor de prueba publicada entre dispositivos; varias ventanas en un PC comparten CPU y no representan 15 móviles independientes. Probar conexión normal y latencia emulada, anotando el valor y su semántica (no confundir latencia unidireccional con RTT).

Guardar CPU/frame del servidor y cliente (p50/p95/p99), tráfico recibido/enviado por categoría, memoria, instancias, consultas espaciales por subsistema, frecuencias de mensajes y actividad de DataStore. Etiquetar tareas con debug.profilebegin/end sin imprimir cada frame.

Roblox permite distinguir física, datos y assets en los dumps de red de MicroProfiler; la captura de red se inspecciona en el dump, no solo en el overlay. Usar comparación A/B sobre la misma escena y dispositivo. [Captura de red](https://create.roblox.com/docs/performance-optimization/microprofiler/network), [guía de MicroProfiler](https://create.roblox.com/docs/performance-optimization/microprofiler/use-microprofiler).

Presupuestos iniciales de aceptación (objetivos propuestos, no resultados medidos): efectos cosméticos sin publicación de transformaciones por frame; estamina estable sin escrituras repetidas; recursos desmontados regresan cerca del baseline tras ciclos de streaming; no crecimiento monotónico de memoria/conexiones; ninguna regresión de frame p95 >10% sin justificación. Fijar el presupuesto absoluto de ms/KB/s después de medir hardware y carga objetivo. No prometer “menos de 60 ms de ping” a cualquier usuario.

### Fase 2 — Una sola fuente para el código ya idéntico

1. Crear `src` y migrar grupos idénticos del inventario, preservando nombres públicos, clase y orden de arranque.
2. Ambos proyectos apuntan a los mismos directorios shared/server/client. Los outputs de World1/2 son generados y no editables a mano.
3. Inicialmente conservar entrypoints heredados pequeños cuando dependan de `script.Parent` o de assets hijos. El adaptador hace require del módulo común y le pasa referencias explícitas.
4. Convertir dependencias de ruta en parámetros donde sea necesario. No convertir un script con efectos al cargar en un módulo requerido dos veces por loaders diferentes.
5. Probar que cada servicio y handler arranca una sola vez, que todos los remotes requeridos existen antes del cliente y que no hay infinite yields.

Salida: los dos builds comparten el mismo hash del core y contienen las clases correctas; un cambio de HUD/Bootstrap/Codec se hace en un archivo fuente; equivalencia de resultados frente a fixtures previos. La extracción no cambia balance ni schema.

### Fase 3 — Configuración por mundo y adaptadores

Extraer las diferencias legítimas: StageId→SafeZone, recompensas, spawn, requisitos de cintas, disponibilidad de SpeedForce, NPCs/hazards y assets. Identificadores estables y únicos; validación de referencias faltantes al iniciar.

Sustituir combinaciones dispersas de IsWorld2Place/PlaceId/nombre de mapa por WorldConfig. Mantener ambas IDs históricas si forman parte del despliegue real, dentro de un registro explícito. Config actual y portal contienen IDs distintos de World2: verificar los places de destino, no escoger por intuición.

Salida: para añadir World3 se añade configuración y assets/adaptador, sin copiar DataService, Bootstrap, HUD, PotionServer o Flight. Crear un World3 mínimo de prueba para demostrarlo; no publicar un tercer mundo real.

### Fase 4 — Flight, progreso, cintas y UI comunes

Flight servidor: extraer primero el archivo casi idéntico; conservar las reglas nuevas de suelo, estamina, vuelo temporal/permanente y equipamiento persistente. Después unificar cliente mediante configuración de teclas/features, no mezclando autoridades.

TreadmillService: una definición por ID con geometría de zona y requisitos; validación y ganancia solo en servidor. TreadmillPresenter: posición/billboard responsive/animación local. Conservar posición y layout Gemini con fixtures de instancias y comparación visual.

HUD: un solo controller y plantillas versionadas; eventos de estado y un InputContext compartido. Menús modales, navegación del HUD, chat y menú Roblox se distinguen expresamente. Evitar tanto cancelar sprint por una selección incidental como activarlo mientras se está navegando un menú real.

Salida: W1/W2 equivalentes en PC, móvil y consola; cobertura de cinta Admin x100, Candy 3 rebirths, Rank, Rebirth con un precio, popup, buffs móviles, Worlds y compra/cancelación. Sin dos controladores escalando o moviendo el mismo panel.

### Fase 5 — Presentación cliente de peligros y NPCs

Migrar una familia a la vez: primero decorativos y sonidos; después peligros deterministas no transportadores; al final plataformas físicas/NPCs complejos.

Por peligro: definición de geometría de daño, función temporal, epoch/seed, estado activo y versión. En cliente, distancia/visibilidad y streaming controlan si se dibuja; en servidor, relevancia espacial decide a quién consultar. El servidor no manda CFrame cada frame para efectos deterministas.

Para eventos de golpe sugeridos por cliente: validar tipo, ID registrado, personaje vivo, mundo, estado letal y ventana temporal limitada. Rechazar timestamps futuros/antiguos fuera de política. Comparar contra estado reconstruido o historial corto servidor. No matar por la unión de una caja enorme de todo el recorrido. Si el historial ya no permite decidir, fallar sin daño; no inventar contacto.

Definir criterio de contacto corporal para R6/R15 y escalas admitidas. Usar broad phase barata para candidatos, narrow phase acorde a geometría y barrido si la velocidad lo necesita. Evitar GetDescendants, GetBoundingBox y consultas por cada accesorio en cada frame.

NPCs: conservar decisión de target y combate en servidor. Cachear partes/hitboxes y consultar solo dentro de radio calculado desde el tamaño real, no un número fijo que deje de funcionar con otra skin. Mantener hysteresis al entrar/salir del área sin perseguir a jugadores 180 studs por encima si el diseño no lo requiere. Medir antes de reducir ticks de IA/contacto.

Salida: cero muertes en casos de no contacto documentados; contacto visible detectado en recorridos de prueba; teleport/respawn protegidos; datos de profiler mejores sin deteriorar detección. Casos extremos deben incluir movimiento del jugador y del obstáculo simultáneos.

### Fase 6 — Protocolo de red y publicación de estado

Inventariar cada Remote con dirección, payload, permisos, máximo tamaño, frecuencia, respuesta y política de retry. Crear remotes en un bootstrap único. Peticiones económicas son fiables e idempotentes; nunca usar un canal descartable para premios/compras.

Enviar deltas públicos, no el perfil completo. El estado privado viaja al propietario; efectos con relevancia local se envían a interesados. Publicar inicio/fin/epoch de un efecto en vez de transformaciones por frame. El cliente interpola y se resincroniza si recibe una revisión nueva. Limitar colas y eventos antes de funciones que ceden ejecución.

No agrupar todo en un paquete gigante de cada frame ni eliminar aliases de atributos antes de retirar consumidores. Mantener una ventana de compatibilidad de mensajes durante despliegue entre versiones.

### Fase 7 — Persistencia, build y despliegue coordinado

Durante la extracción conservar `SpeedsterEscape_MainSave_v17`, prefijo `Player_`, campos legacy/extension, ledger de recibos, identidad de operación, session leases y cierre seguro. No introducir un almacén por mundo si el progreso es compartido.

Para campos nuevos, migración aditiva e idempotente con fixtures OG y rollback que siga pudiendo leerlos. Probar servidor viejo/nuevo simultáneos, teleport entre mundos de distinta versión compatible y caída durante Commit/Release. El checkpoint persistente es un requisito que primero se debe demostrar/definir, no asumir desde el informe.

Pipeline propuesto: exportar snapshot → reconciliar manifest → compilar/testear → generar ambos places con misma revisión → deserializar outputs → validar clases/dependencias/propiedades → emitir ReleaseManifest → prueba privada → publicar todos los places del release y verificar versión en servidores nuevos.

ReleaseManifest: revisión del código, hashes core/assets por mundo, versión de contrato/schema, versiones de dependencias, lista de cambios de propiedades, resultados de pruebas y places de destino verificados. Guardar artifacts del release previo. Rollback vuelve al binario compatible anterior; no restaura datos antiguos encima de compras nuevas.

Usar Roblox Packages para assets/UI si ayuda al equipo; fijar la revisión usada por el release. Su actualización automática ocurre al abrir el place en Studio y las copias modificadas tienen reglas especiales; no garantiza actualización atómica de todos los servidores publicados. [Ciclo de versiones de Packages](https://create.roblox.com/docs/projects/assets/packages).

### Fase 8 — Retomar el bug hunt integral

Una vez que red/hitboxes y los gates anteriores están resueltos, volver al backlog de seguridad, economía, UI y rendimiento. Reconciliar cada ID de `audit/BUG_*.md` con fuente actual y prueba que lo cubre. Especial atención a regalos interrumpidos, efectos temporales de recibos, checkpoints y comandos de admin.

No cerrar el objetivo global por contar pruebas verdes: hay que verificar los casos de uso y el entorno publicado, incluidos datos, compras, cambio de mundo y consola.

## 6. Plan de trabajo para Astra/Gemini sin pisarse

Una persona/agente integra y es la única que escribe los `.rbxl` de entrega. Los demás editan fuentes asignadas y entregan diff, prueba y riesgos. No editar simultáneamente `Bootstrap`, `Config`, builder o perfil. Antes de cada lote, revisar hash del input: si Gemini o Studio lo cambió, rebasar ese lote.

| Lote | Dueño sugerido | Entradas/ownership | Entrega verificable |
|---|---|---|---|
| A: baseline | integrador | snapshots, manifest, builder | 18 conflictos resueltos y UI/mapa preservados |
| B: red/ASMR | agente red | Effects y publicación; no Data | profiler A/B, streaming limpio, límites de instancias |
| C: contacto | agente gameplay | Pad/HazardGeometry/authority | tests geométricos y escenas de no contacto/contacto |
| D: core común | integrador | src/proyectos/adaptadores | mismo hash core en los dos mundos |
| E: UI/input | agente UI | HUD, menú, mando, layout | capturas/test matriz dispositivos |
| F: datos/economía | agente persistencia | Data/Economy; tras D estable | migración/timeout/recibos/multi-servidor |
| G: aceptación | integrador | release artifacts | manifest, reporte y verificación publicada |

B/C pueden avanzar en paralelo tras fijar interfaces con A. D no mueve archivos mientras B/C los editan. E/F empiezan con la nueva ruta estabilizada. Si hay límite de tokens, parar en un lote verificable y dejar un traspaso; no mandar a Gemini a “arreglar todo” sin una base/versiones concretas.

### Prompt reutilizable para el próximo lote

> Trabaja sobre el snapshot/revisión indicado en el manifest. Lee PLAN_CORE_COMPARTIDO_RED_HITBOXES.md y el informe específico del lote. Ejecuta únicamente el lote [ID], con ownership [rutas]. Antes de editar registra el bug con evidencia. Conserva cambios de Gemini, schema/store/receipts y assets authored. No sobrescribas inputs ni empaquetes places. Entrega fuentes cambiadas, pruebas funcionales de esas rutas, resultados, limitaciones y cualquier cambio requerido en manifest. Si encuentras conflicto con otro lote, informa y evita editar su ownership. No declares validación Studio si solo ejecutaste mocks.

## 7. Criterio de finalización y siguiente acción

La unificación está terminada cuando World1 y World2 se generan desde una sola fuente del core, World3 mínimo funciona sin copiarlo, los hashes y contratos son verificables, no hay arranques duplicados y se conservan datos/mecánicas/UI. La optimización está terminada cuando el escenario A/B demuestra reducción del cuello de botella identificado sin introducir falsos golpes/cobros o regresiones visuales.

**Siguiente lote recomendado: A + cierre de pads/hitboxes de la fase 0.** Es necesario reconciliar primero los archivos nuevos de Gemini; ejecutar ahora el builder viejo sobrescribiría cambios recientes. Después extraer los módulos idénticos, comenzando con Flight servidor y shared puro, antes de tocar DataService.

Este plan no certifica el lanzamiento ni implica que se haya realizado la refactorización. Los originales nuevos se conservaron y no se publicaron cambios durante la preparación del plan.
