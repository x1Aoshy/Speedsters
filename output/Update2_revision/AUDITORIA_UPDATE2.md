# Auditoría de Update 2 — 12 de septiembre de 2026

**Resultado: NO LISTA PARA PUBLICAR.** Se implementaron correcciones de la UI y protecciones puntuales, pero siguen existiendo pérdidas de progreso reproducibles en el backend modular. Los dos RBXL de esta carpeta son versiones de revisión, no una aprobación de lanzamiento.

Los tres archivos de entrada y los `.original_backup` se conservaron. No se accedió a DataStores reales, no se modificaron cuentas de jugadores y no se publicó ningún place. Un backup RBXL respalda el mapa y sus scripts; no respalda los DataStores de jugadores.

## Entrega

- `V2Speedsters.rbxl`: V2 con seis scripts corregidos.
- `World2.rbxl`: World2 con las mismas seis correcciones.
- Scripts extraídos, fuentes originales/corregidas, pruebas y registro de resultados: carpeta `audit` del proyecto.

## Zapatito, números y tween

El código original de ambos mundos todavía contiene `ShoeIcon`, la aparición con easing Back y el vuelo hacia `Mainhud.LevelProgressBar.Frame.Speed`. Al inyectar un evento correcto en una simulación, el código de entrada ya generaba el efecto. Por eso no atribuyo la desaparición a una causa única confirmada en Roblox Studio.

La revisión mantiene ese diseño y agrega lo siguiente:

- Si aumenta el atributo replicado `RawSpeed` y no llega `SpeedGainPopup`, genera el zapatito de respaldo después de 0,30 s.
- Evita duplicar el efecto cuando llegan el cambio de atributo y el RemoteEvent, incluido un aviso tardío con el mismo total.
- Respeta `HidePopups`, omite la carga inicial y las reducciones de velocidad del rebirth.
- Recrea inmediatamente la capa visual si falta. Un error al crear un popup ya no detiene para siempre la cola; la cola tiene un límite para evitar acumulaciones prolongadas.
- Un impacto antiguo no hace retroceder el número de velocidad ni restaura visualmente velocidad anterior a un rebirth.

**Validación disponible:** simulación de eventos, creación del zapatito, destino del tween, impacto, cinta, ocultar popups, rebirth y carga inicial. **Pendiente:** verificar visualmente la animación dentro de Roblox Studio y en dispositivos reales. La simulación no reproduce el renderizador, la red ni todas las posibles superposiciones de UI.

## Compatibilidad de datos OG → V2 / World2

| Elemento | Resultado |
| --- | --- |
| DataStore principal | Los tres usan `SpeedsterEscape_MainSave_v17`. |
| Clave por jugador | OG y el backend modular usan `Player_` + UserId. |
| Versión del perfil | 306 en ambos sistemas. |
| Escritor activo | OG usa PlayerStats; V2 y World2 tienen `UseModularDataService = true` y usan Bootstrap/DataService. PlayerStats legacy retorna para evitar dos escritores. |
| Perfil sintético con formato OG | Conservó velocidad, wins, rebirths, inventario, multiplicadores, recibos y daily al cargar/guardar en el mock. Esto no es una prueba sobre perfiles reales. |
| Bloqueo entre servidores | Una segunda sesión activa es rechazada; un propietario anterior no puede guardar después de que otro adquiere el perfil. |
| Universe/Experience publicados | No verificado con estos archivos. Ambos destinos deben pertenecer a la experiencia que contiene los datos existentes. |

Roblox comparte los DataStores entre places de una misma experiencia; conservar nombre y clave no traslada datos a una experiencia diferente. Referencia: [documentación oficial de DataStores](https://create.roblox.com/docs/cloud-services/data-stores).

El codec también normaliza y limita algunos valores. La conservación del perfil sintético no garantiza equivalencia para todos los registros históricos, valores extremos o campos no reconocidos. Volver a publicar el OG después de usar los campos nuevos también requiere revisar la compatibilidad del esquema.

## Correcciones de seguridad y lógica incluidas

1. **Registros corruptos:** `SessionActor.Open` validaba después de adquirir la sesión; ciertos valores no-table terminaban reemplazados por un perfil inicial. Ahora valida antes de escribir y conserva el registro original. Las versiones futuras tampoco se modifican.
2. **Contención en UpdateAsync:** se reinician las variables capturadas cada vez que Roblox ejecuta el callback de adquisición. Una ejecución anterior exitosa ya no permite aceptar un perfil perteneciente a otra sesión.
3. **DataStore inaccesible:** `CreateProduction` devolvía un mock en memoria cuando fallaba su inicialización. Ahora devuelve errores y no simula persistencia. El fallback explícito de Studio permanece separado.
4. **Carga fallida en producción:** se desconecta al jugador con un mensaje claro en vez de dejarlo jugando sin datos cargados.
5. **SettingsUpdate:** antes permitía asignar cualquier atributo del jugador enviado por el cliente. Ahora acepta únicamente ajustes conocidos, con tipo correcto y números finitos, mediante la validación del servicio.
6. **Confirmación de guardado:** un resultado `Pending` ya no equivale a guardado durable exitoso. `SpeedsterAddWins` tampoco devuelve éxito incondicional ante un rechazo.
7. **Multiplicador de wins:** el bridge modular había omitido el multiplicador permanente que aplicaba OG a las recompensas. Se restauró: una recompensa de 10 con x4 concede 40. Los grants exactos siguen su ruta separada.

## Bloqueos pendientes de lanzamiento

### P0 — Ganancias durante un Commit pueden perderse

`SessionActor.Commit` clona el perfil, espera el guardado y después reemplaza el perfil en memoria por ese borrador. Mientras espera, `AccrueSpeed`, preferencias u otro Commit pueden modificar el perfil. No existe exclusión efectiva por sesión alrededor de estas operaciones.

**Reproducción offline:** velocidad 100; empieza un Commit de wins; durante su escritura se ganan 25 de velocidad; el perfil llega a 125; al completar el Commit vuelve a 100. Reproducido también sobre la revisión entregada.

**Reparación necesaria:** serializar las operaciones por sesión y definir cómo se conservan las ganancias durante escrituras, sin perder ni duplicar cambios. Incluir Commit/Flush/Release y modificaciones en memoria en el contrato.

### P0 — Una operación aplicada con timeout se puede borrar al salir

Un timeout no significa que Roblox no haya escrito. El actor pasa a `Recovering`, pero no reconcilia el resultado de la operación con el registro durable antes de guardar/liberar el perfil anterior.

**Reproducción offline:** velocidad 100; grant de 500 que el mock aplica y luego responde timeout; el registro durable tiene 600; `Release` posterior vuelve a escribir 100. Reproducido también sobre la revisión entregada.

**Reparación necesaria:** registrar operaciones idempotentes de forma durable y resolver resultados inciertos antes de permitir un guardado del perfil antiguo. La liberación no debe sobrescribir una operación cuyo resultado todavía se desconoce.

### P0 — Compras y multiplicadores modifican copias en lugar del perfil

`Inspect` devuelve una copia profunda. `PlayerStatsBridge.SpeedsterSetPermanentBaseSpeedMultiplier` y `SpeedsterSetPermanentWinsMultiplier` modifican esa copia. `SpeedProductPurchases` también hace asignaciones a `inspect.value.profile.Speed`. Esos cambios no llegan al perfil que guarda DataService; las proyecciones siguientes pueden revertir el valor visible.

**Reproducción offline:** cambiar un multiplicador de 2 a 100 en el resultado de `Inspect`, y hacer Flush, deja el multiplicador real en 2. Las rutas citadas usan precisamente ese patrón.

**Reparación necesaria:** comandos explícitos para cada compra/multiplicador, entrega atómica e idempotente, y confirmación durable antes de reconocer la compra. No arreglarlo haciendo mutable `Inspect`, porque eliminaría la protección de lectura y agravaría la concurrencia.

### P1 — Desbloqueos y recibos no están completamente integrados

- `WorldPortalService` desbloquea World2 mediante `SetAttribute("World2Unlocked", true)`, pero el backend modular guarda el perfil y no ese atributo. La proyección puede volver a ponerlo en false. Se necesita una mutación persistente de desbloqueo.
- `ReceiptLedger` conserva sus nuevos marcadores en una tabla de memoria. Las funciones de compatibilidad consultan ese ledger, mientras `ProcessedReceipts` existe por separado en el perfil. Hay además un ReceiptStore externo en el sistema de compras. Falta demostrar entrega exactamente una vez entre esos sistemas después de reinicios y timeouts; no se debe asumir a partir del comentario que llama “durable” al ledger.
- `DataService.Shutdown` libera perfiles secuencialmente, aunque su comentario dice “en paralelo”. `Release` elimina el actor incluso si falla. Faltan reintentos/cierre con plazo y pruebas con múltiples jugadores ante throttling.
- Los ID de algunas operaciones usan segundos y aleatoriedad limitada, o solo segundos. Dos recompensas iguales en el mismo segundo pueden compartir ID. Hay que distinguir una nueva operación de un reintento.

Estos bloqueos requieren corregir y probar el flujo completo del backend y las compras; las protecciones puntuales incluidas no los resuelven.

## Cambios de mecánica encontrados respecto de OG

| Mecánica/configuración | OG | Update 2 |
| --- | --- | --- |
| Multiplicador de movimiento World2 | 1/3 | 1 |
| Ganancia base de correr World2 por tick | 0,25 | 1 |
| Flight disponible | Fuera de World2 | Activado en ambos |
| Flight, costo en wins | 1.000.000 | 25.000.000 |
| Oferta de revive | 5 s | 10 s |
| World2 PlaceId configurado | 116359653478954 | 96501592055150 |
| Recompensas multiplicadas de wins | Aplicaba multiplicador permanente | El bridge lo omitía; corregido en la revisión |

También cambian productos, precios, pociones y destinos de teleports de stages. Los productos legacy de multiplicadores sí tienen una tabla de compatibilidad en `SpeedProductPurchases`; no todos los cambios de ID implican automáticamente perder una compra. Su entrega persistente sigue afectada por los bloqueos anteriores.

No revertí decisiones de balance ni IDs del usuario. No hice una prueba completa de obstáculos, física, colisiones, bosses ni dispositivos.

## Pruebas y trazabilidad

- Se extrajeron y compilaron 546 scripts: OG 148, V2 175, World2 223. Compilar verifica sintaxis; no certifica funcionamiento en Roblox.
- La entrega modifica seis scripts por place. Se abrieron nuevamente los dos RBXL generados y se compilaron todos sus scripts.
- Se verificó igualdad binaria normalizada al revertir exclusivamente los Source modificados en la copia reabierta. No se detectaron cambios adicionales de instancias, mapa o propiedades en la serialización de Lune.
- Instancias conservadas: V2 26.869; World2 15.116.
- `audit/test_data.luau` incluye tanto protecciones aprobadas como reproducciones explícitas de bloqueos pendientes. Que el script termine correctamente **no significa** que el backend sea seguro para publicar.
- `audit/test_popup.luau` y `audit/test_guards.luau` verifican la UI simulada y las validaciones añadidas.
- `audit/test_results.txt`, `audit/build_results.json` y `audit/file_hashes.json` registran resultados y hashes.

Para repetir desde la carpeta del proyecto:

```powershell
lune run audit/test_data.luau patched/V2
lune run audit/test_data.luau patched/World2
lune run audit/test_popup.luau audit/patched/V2
lune run audit/test_popup.luau audit/patched/World2
lune run audit/test_guards.luau audit/patched/V2
lune run audit/test_guards.luau audit/patched/World2
lune run audit/build.luau
```

## Condiciones para aprobar publicación

Resolver los bloqueos del backend; probar compras, recompensas, guardado simultáneo, reconexiones y cierre con errores simulados; confirmar la experiencia y los dos PlaceId publicados; y verificar con perfiles de prueba representativos que velocidad, wins, rebirths, inventario y compras sobreviven V2 → World2 → V2. La UI requiere una revisión visual en Studio y móvil. No probar estas condiciones sobre datos reales sin un respaldo específico de esos datos.
