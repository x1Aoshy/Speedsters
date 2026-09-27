# Auditoría de Update3 — 23 de septiembre de 2026

**Dictamen: la actualización contiene mejoras reales, pero todavía no considero resueltos el rendimiento, la entrega de compras ni el balance de progresión.** Hay fallos reproducibles fuera de la batería existente. La prioridad es reparar integridad de recompensas y compras, y después calibrar la economía completa.

**Alcance y evidencia.** Inventario y compilación de los 400 archivos Luau de `src` (154.869 líneas según conteo de saltos de línea); revisión manual de las rutas activas de arranque, persistencia, compras, pads, movimiento, niveles, rebirths, trajes, cintas, cosméticos, ruleta, AFK, misiones, portales y optimización visual. Los 307/348/289 scripts rastreados en los tres `.rbxl` coinciden con sus fuentes. No equivale a haber probado cada rama de las 154.869 líneas en Roblox ni a una certificación de producción.

La batería `run_fable_checks` termina **45/45**, y también pasan las pruebas adicionales existentes de revives, regalos, ruleta con reintento y AFK. Los casos nuevos de esta auditoría reproducen defectos pese a esos resultados. No se modificó código de juego ni se publicó nada. Los scripts nuevos solamente leen fuentes y ejecutan pruebas locales con servicios simulados.

No se midieron FPS, memoria, latencia ni ingresos de la versión publicada. Los datos e informes históricos del directorio no prueban el resultado de esta compilación. Los precios mencionados abajo son valores de configuración, no precios verificados en Creator Hub.

## 1. Fallos que arreglaría primero

### 1 — Alta: los propios pads desactivan la validación del recorrido

Antes de validar la recompensa, los pads llaman a `VortexMovementGuardRebase(player, stage)`. Esa función borra la sospecha de movimiento, concede tres segundos de tolerancia y establece el progreso solicitado. Después se consulta `CanClaim`: el contacto que debería comprobarse acaba de ser autorizado por el propio pad.

Además, el guard admite avanzar al checkpoint más cercano sin exigir el anterior. Los límites de 150.000 studs/s y 2.500 studs por muestra no representan el movimiento permitido a un jugador concreto.

**Reproducción:** con WalkSpeed 8, cinco desplazamientos no autorizados de aproximadamente 1.000 studs alcanzan la etapa 11 en 0,5 segundos y permiten cobrar. El control rechaza un único desplazamiento completo; al llamar a `Rebase`, como hacen los pads reales, ese mismo desplazamiento queda admitido. Prueba local del validador con posiciones del mapa real; no es un ensayo de explotación en un servidor publicado.

**Efecto:** se puede saltar el esfuerzo que sostiene los Wins, las compras de atajos y las recompensas finales. Bajar cooldowns agrava la repetición una vez sorteado el recorrido.

**Cambio recomendado:** reservar `Rebase` para teletransportes iniciados y registrados por el servidor; validar antes de modificar progreso; hacer que los límites dependan de velocidad, habilidades y tolerancia de red autorizadas. Validar el trayecto con checkpoints ordenados y no solamente la proximidad final.

Fuentes: [pad Mundo 1:522](C:/Users/Aoshy´/Desktop/Update2/src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ManualStagePads.server.luau:522), [pad Mundo 2:459](C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/ServerScriptService/Gameplay/World2ManualStagePads.server.luau:459), [pad Mundo 3:377](C:/Users/Aoshy´/Desktop/Update2/src/worlds/World3/ServerScriptService/Gameplay/World3ManualStagePads.server.luau:377), [MovementGuard:199](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/MovementGuard.luau:199).

### 2 — Alta: las ganancias AFK desaparecen al desconectarse o reconectar

El tick suma Speed y tickets en `sessions[player]`. No los escribe en el perfil hasta reclamar o salir mediante `exit()`. `PlayerRemoving` simplemente elimina esa sesión. El cliente tiene una reconexión por inactividad desde los 16 minutos que teletransporta directamente sin reclamar antes. Reanudar AFK crea una sesión vacía.

**Reproducción:** 960 ticks, recompensa mínima de 500 por minuto y un ticket cada diez minutos: quedan 8.000 Speed y un ticket. Ejecutar el manejador real de salida borra ambos sin guardado. Una desconexión normal tiene el mismo problema; el caso de reconexión automática depende de que se active ese mecanismo.

**Cambio recomendado:** mantener un saldo AFK pendiente y persistente, incluido el progreso parcial hacia el siguiente ticket. Reclamar x1/x5 debe consumir ese saldo atómicamente. Reclamar antes del teleport mejora el caso normal, pero por sí solo no protege contra una caída o cierre del servidor.

Fuentes: [acumulación:247](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Social/AfkZoneService.server.luau:247), [salida:458](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Social/AfkZoneService.server.luau:458), [reconexión:146](C:/Users/Aoshy´/Desktop/Update2/src/common/StarterPlayer/StarterPlayerScripts/UI/AfkZoneController.client.luau:146).

### 3 — Alta: Dark Zonic pierde su multiplicador en Mundos 2 y 3

La tabla de trajes de Mundo 1 contiene `DarkZonicSuit = 300`. La tabla usada en Mundos 2 y 3 no incluye ese traje. La ruta activa `SpeedsterGetSuitSpeedGainMultiplierForSkin` devuelve el valor por defecto, **1**. `SpeedsterAddSpeed` usa esa función directamente.

**Reproducción:** cargar Config para los tres mundos devuelve **300 / 1 / 1**. El beneficio de entrenamiento del traje comprado cae 300 veces respecto a sí mismo; incluso Flash conserva ×5.

**Cambio recomendado:** un catálogo común de beneficios de trajes y excepciones por mundo explícitas. Una prueba debe recorrer todos los trajes comprables y exclusivos en los tres mundos, además de verificar su aspecto.

Fuentes: [Config:863](C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/Config.luau:863), [resolución:164](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Progression/PlayerStatsBridge.luau:164), [aplicación:110](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Progression/PlayerStatsBridge.luau:110).

### 4 — Alta: algunas compras aplican el efecto antes de guardar el recibo

La ruta de productos con efectos inmediatos llama a `grantProductTransaction` antes de `commitPersistentReceipt`. Si el segundo falla, devuelve reintento sin ejecutar `transaction.Rollback`. Por ejemplo, `GrantServerBoost` ya extendió el boost y modificó Workspace antes de guardar. Teletransportes y revives también tienen efectos anteriores a esa confirmación.

**Reproducción:** ejecutar dos veces esa rama real con fallos definitivos de persistencia produce dos concesiones y cero rollbacks. En un timeout que sí escribió el recibo, la deduplicación puede evitar la segunda concesión; el caso problemático incluye el fallo que no escribió nada. **Esto demuestra duplicación de beneficios, no cobros duplicados de Robux.**

**Cambio recomendado:** registrar una entrega pendiente identificada por PurchaseId y hacer su ejecución idempotente. Para boosts, guardar la concesión o vencimiento específico del recibo, en lugar de volver a sumar duración al reintentarlo. Para servicios inmediatos, definir recuperación/compensación si el contexto original ya no existe.

Fuentes: [ruta:1922](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau:1922), [boost:267](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/PotionServer.luau:267). Roblox requiere diseñar la entrega para recibos pendientes y reintentos: [documentación oficial de developer products](https://create.roblox.com/docs/production/monetization/developer-products).

### 5 — Alta: un regalo pagado depende de que ambos jugadores sigan en el mismo servidor

Después de fijar el destinatario, `processReceipt` lo busca con `Players:GetPlayerByUserId`. Si se fue o cambió de mundo, devuelve `NotProcessedYet`. Para confirmar el regalo necesita también el perfil del comprador en ese servidor. Tener la intención persistida evita enviarlo a otra persona, pero no proporciona entrega al destinatario ausente.

**Escenario derivado del código:** el destinatario cambia de mundo mientras el comprador confirma. El regalo queda pendiente; no existe aquí un buzón persistente que el destinatario pueda consumir en su siguiente sesión. No probé una compra real ni afirmo que ocurra en todas las compras.

**Cambio recomendado:** cola durable de regalos por destinatario, con PurchaseId y estado de entrega. Consumirla bajo el bloqueo de sesión del destinatario; permitir al comprador ver pendiente/entregado. No escribir directamente sobre un perfil que pertenece a otro servidor.

Fuente: [SpeedProductPurchases:1856](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau:1856).

### 6 — Alta: se anuncia victoria antes de que exista una recompensa durable

`RewardPadClaims` devuelve al jugador al inicio, suma Wins visuales, consume el cooldown y llama a `onGranted` antes de `DataService.Commit`. Si el commit se rechaza, solamente libera el bloqueo y emite un warning. No revierte la presentación ni permite retomar el mismo recorrido. En Mundo 3, `onGranted` además dispara la concesión de Silver Surfer en otra transacción.

**Reproducción:** un commit simulado devuelve `Rejected/SessionLost`; aun así, el módulo devuelve `true`, teletransportó al inicio y ejecutó una vez el callback de premio. No significa que esos Wins se hayan persistido: ese es precisamente el desacuerdo.

**Cambio recomendado:** separar animación inmediata de confirmación de recompensa. Registrar una reclamación recuperable, conservar su identidad y ejecutar las consecuencias económicas/finales después de confirmarla. Wins y desbloqueo final deben compartir transacción cuando sea posible.

Fuentes: [RewardPadClaims:54](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/RewardPadClaims.luau:54), [recompensa Mundo 3:397](C:/Users/Aoshy´/Desktop/Update2/src/worlds/World3/ServerScriptService/Gameplay/World3ManualStagePads.server.luau:397).

## 2. Rendimiento: queda un bloqueo entre jugadores

### 7 — Alta: esperar el guardado de uno retrasa las ganancias de otros

Los actores serializan sus mutaciones mediante `while self.mutationOwner do scheduler.wait()`. Es útil para integridad, pero un commit mantiene ese bloqueo durante `UpdateAsync`. El bucle de carrera de Bootstrap llama a `SpeedsterAddSpeed` secuencialmente para todos los jugadores; esa llamada acaba en `AccrueSpeed`, que también espera el bloqueo. La inspección global de cintas llama sin desacoplar a `tryGrantTreadmillSpeed`.

**Reproducción con SessionActor real:** al retrasar 250 ms el almacenamiento del jugador A, un bucle que acumula Speed para A y luego B retrasa a B aproximadamente 280 ms, aunque su perfil no tiene ningún problema. La duración medida pertenece a la prueba simulada, no a un servidor real. Esto pausa la distribución de entrenamiento; no implica que el motor entero deje de renderizar.

Hay un amplificador: cada tick de cinta de administrador llama a `SpeedsterAddWins`, que hace un commit durable. A la cadencia configurada puede intentar hasta dos escrituras por segundo por jugador cuando el almacenamiento responde rápido. Si responde lento, la propia espera reduce el ritmo y atasca la inspección global. Las misiones también hacen guardados periódicos cada diez segundos.

**Cambio recomendado:** acumular ganancias ordinarias por jugador sin hacer esperar al bucle global; un consumidor por perfil, con cola acotada y combinación de deltas. Mantener durables y prioritarias las compras, canjes y transiciones que lo requieren. No solucionar esto creando una tarea sin límite por cada tick. Combinar los Wins ordinarios de las cintas con el guardado periódico y registrar tiempos/cola de almacenamiento.

Fuentes: [bloqueo:764](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/Data/SessionActor.luau:764), [carrera:593](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Bootstrap.server.luau:593), [cintas:519](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Progression/TreadmillTraining.server.luau:519), [Wins de admin:1047](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Progression/TreadmillTraining.server.luau:1047), [commit Wins:290](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Progression/PlayerStatsBridge.luau:290).

**Lo que sí mejoró:** menor publicación de stamina, menos copias de perfil en ganancias ordinarias, caché de búsquedas ausentes, límites visuales de cintas cercanas en teléfonos, reducción de sombras/postefectos y correcciones de los errores de ASMR/cámara/ruleta cubiertos por los tests. Son mejoras comprobables del código; falta medir su impacto real.

**Siguiente medición:** mismo móvil, misma escena y población antes/después; lobby lleno, carrera, jefe y evento de admin. Registrar tiempo de frame p50/p95/p99, memoria, tráfico y latencia de concesiones. El modo ligero depende de `TouchEnabled and not KeyboardEnabled`; conviene añadir un ajuste manual y degradación por rendimiento para cubrir también dispositivos lentos con teclado. [Guía oficial de MicroProfiler](https://create.roblox.com/docs/performance-optimization/microprofiler/use-microprofiler).

## 3. Progresión y economía que no encajan

### 8 — El balance depende enormemente de aura × trail

El acceso actual a Mundo 2 es **6 rebirths + nivel 50**; Mundo 3 mantiene **15 + nivel 200**. El entrenamiento multiplica cinta, traje, rebirth, aura, trail y otros bonos. Un aura ×1.000 y un trail ×1.000 producen **×1.000.000**, no ×2.000. El primer aura y trail de 10 Wins cada uno ya producen ×6,25 juntos.

Modelo analítico con las fórmulas reales: mejor cinta gratuita disponible, evolución inmediata al poder desbloquearla, trajes conservados entre rebirths, sin VIP, pociones, eventos, ruleta ni compras. Son tiempos ideales de entrenamiento; excluyen recorridos, conseguir los cosméticos, decisiones y cuantización de ticks. No son tiempos observados de jugadores.

| Hito | Sin aura/trail | Con aura ×1.000 y trail ×1.000 ya disponibles |
|---|---:|---:|
| Llegar a Mundo 2 | ~38,0 min | El entrenamiento deja de ser el límite; el modelo continuo baja de un tick en varios ciclos |
| Siguiente rebirth en Mundo 2, desde nivel 50 | ~131,2 min | Menos de un tick en el modelo continuo |
| Rebirth 14 → 15, nivel requerido 215 | ~164,6 años de entrenamiento continuo | ~86,5 min |
| Tras rebirth 15, volver a nivel 200 | ~10 años | ~5,25 min |

Los años de la primera columna son una demostración matemática de que el entrenamiento sin cosméticos deja de ser una ruta viable; **no una predicción de cuánto tarda un usuario**, que puede adquirir cosméticos, recibir recompensas porcentuales o usar otras rutas. La segunda columna tampoco incluye el coste de conseguir esos objetos.

Los requisitos tardíos crecen aproximadamente ×10,13 cada 15 niveles, mientras un rebirth da ×1,5. Sin una mejora externa muy grande, cada ciclo cuesta aproximadamente ×6,76 más antes de considerar mejoras de traje/cinta. El rebirth 15 exige nivel 215, por encima del nivel 200 anunciado para Mundo 3, y después resetea Speed para volver a subir.

**Qué mejoraría:** definir un presupuesto de tiempo por ciclo y simular una ruta completa de adquisición de Wins, aura, trail, evolución y rebirth. Enseñar y exigir suavemente las primeras mejoras en el tutorial. Hacer visible la ganancia total y su siguiente mejora más útil. Reducir los saltos extremos entre pares de cosméticos y asegurar una ruta gratuita razonable. No bajaría el gate aislado sin rehacer esa simulación.

Fuentes: [curva de niveles:25](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Progression/LevelProgress.server.luau:25), [catálogo de cosméticos](C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/CosmeticCatalog.luau), [rebirth:67](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Progression/RebirthSystem.server.luau:67). Cifras completas en [pacing.json](C:/Users/Aoshy´/Desktop/Update2/output/review_20260923/pacing.json).

### 9 — Mundo 2 reduce movimiento y ganancia por correr sin mejorar inmediatamente la cinta gratuita

Entrar con seis rebirths deja la mejor cinta gratuita en ×10, igual que Diamond de Mundo 1. Candy ×15 requiere nueve y Diamond ×30 requiere once. A la vez, caminar se multiplica por 0,5 y correr genera 0,25 por tick en lugar de 1. Con ticks iguales, entrenar en la cinta inicial de Mundo 2 da **40 veces** la base de correr y ~13,3 veces la de sprintar, antes de los bonos comunes y del tiempo de recarga del sprint.

Se premia llegar al mundo nuevo con menos movilidad, menos ganancia activa y sin una mejora de entrenamiento inmediata. Los Wins mayores pueden compensarlo si el jugador los convierte en aura/trail, pero esa conexión debe quedar clara.

**Qué mejoraría:** recompensar la llegada con una mejora gratuita inmediata y orientar a su compra de aura/trail. Ajustar las ganancias de completar etapas y el entrenamiento activo para que salir del lobby sea una decisión valiosa. Probar los saltos y habilidades en móvil con la velocidad de entrada real.

Fuente: [Config:480](C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/Config.luau:480), [ganancia por correr:800](C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/Config.luau:800).

### 10 — La ruleta usa una “vuelta” que suma pads mutuamente excluyentes

`LapWins` suma todos los pads más la meta. Sin embargo, cobrar un pad devuelve al inicio: no se cobra toda esa suma en una sola vuelta directa. Mundo 3 usa **41 millones** como referencia, frente a **10 millones** del premio final normal. El premio grande de ruleta resulta en **25 millones**, 2,5 metas sin multiplicadores.

Solo las casillas de Wins pagan en promedio 5,05 millones por giro en Mundo 3; seis tickets AFK por hora equivalen a 30,3 millones esperados si todos se cobran y giran allí, sin contar reemplazos por premios duplicados. Es un promedio probabilístico, no una garantía individual, y los multiplicadores de pads cambian la comparación. Las ganancias de ruleta usan `GrantExact`, por lo que no reciben esos multiplicadores de Wins.

**Qué mejoraría:** decidir explícitamente cuántas metas o minutos de juego vale un giro; usar una referencia que represente un recorrido cobrable. Calibrar conjuntamente giros gratis, tickets AFK, misiones, packs pagados y premios duplicados. El precio fijo de 50 millones de Wins evita una ruta fácil de beneficio esperado por compra de giros en los casos examinados, pero no calibra la emisión gratuita.

Fuentes: [LapWins:462](C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/Config.luau:462), [premios:139](C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/SpinWheelCatalog.luau:139), [concesión exacta:249](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Economy/SpinWheelService.server.luau:249).

### 11 — Misiones largas pagan Wins pequeños respecto al mundo donde se hacen

Los objetivos crecen con nivel/Speed; los Wins pagados dependen del nivel, sin una referencia al mundo. Por ejemplo, Explorer a nivel 200 pide 75 etapas, 27 pads y 30 minutos; su componente de Wins es 500.000. El primer pad normal de Mundo 3 paga 750.000. Los otros premios de la misión, como tickets y pociones, tienen valor y deben contarse: precisamente por eso conviene mostrar y balancear el paquete completo, no solamente inflar el número de tareas.

**Qué mejoraría:** misiones de 5–10 minutos y metas opcionales largas, recompensas basadas en tiempo/esfuerzo y mundo, y objetivos que favorezcan variedad. Evitar que reclamar muchos pads pequeños sea mejor que terminar el circuito. La misión Sprinter garantizada es una mejora existente.

Fuente: [QuestCatalog](C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/QuestCatalog.luau).

### 12 — Comprar ×Wins también encarece habilidades y viajes

Flight y Sonic Burst usan precio base × raíz del multiplicador permanente: Flight pasa de 25 millones a aproximadamente 141,4 millones con ×32. La ventaja efectiva en tiempo de farmeo es ~×5,66 bajo condiciones comparables, aunque el ingreso bruto sí sea ×32. Los viajes escalan con todos los bonos de pago y con el pase de pads dobles para cerrar el arbitraje.

No lo clasifico como error aritmético: es una decisión de diseño documentada. Pero el comprador puede experimentar que la meta se alejó inmediatamente tras pagar. Además, tener pads dobles aumenta el precio de un viaje aunque su intención no sea cobrar el pad doble.

**Qué mejoraría:** explicar antes de comprar qué escala y qué permanece fijo. Considerar precios estables para habilidades permanentes y un sistema de viajes que no habilite recompensas repetibles por arbitraje; mantener el cierre actual hasta tener un reemplazo probado.

Fuente: [WinsMath:192](C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/WinsMath.luau:192).

## 4. Medición y coherencia entre mundos

### 13 — Media: el embudo de onboarding pierde a quienes progresan entre sesiones

El estado de pasos completados y la pertenencia a onboarding viven en tablas por Player. Al entrar, solamente se considera newcomer a quien tiene cero rebirths y Mundo 2 bloqueado. Un jugador que hizo su primer rebirth, sale y vuelve mañana queda fuera del seguimiento. Tampoco se registran normalmente los mismos pasos por la ruta de rebirth comprado; el embudo secuencial se corta si falta un escalón.

**Efecto:** el embudo representa mejor la conversión en una sesión ininterrumpida que el recorrido completo de una cohorte nueva. Puede subestimar Mundo 2 o sesgar comparaciones entre compradores y gratuitos. No usaría esa métrica sola para declarar que el balance mejoró o empeoró.

**Cambio recomendado:** identidad de cohorte y primer cumplimiento de hitos persistentes, seguimiento entre servidores/sesiones y distinción entre rebirth ganado, comprado o concedido. Si se quiere medir solo la primera sesión, nombrarlo así y crear otro embudo de progresión acumulada.

Fuentes: [estado:129](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/FunnelAnalytics.luau:129), [elegibilidad:321](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/FunnelAnalytics.luau:321).

### 14 — Media: los viajes persistentes confunden Mundo 1 con Mundo 3

`TeleportSystem` guarda `WORLD = IsWorld2Place and 2 or 1`. Mundo 3 queda con valor 1. Hay una mitigación que compara el coste pagado con el precio del servidor actual, pero el precio no identifica el mundo. Un viaje pendiente caro de Mundo 3 puede superar la comprobación de Mundo 1 y cumplirse allí en vez de reembolsarse por destino incorrecto.

**Cambio recomendado:** guardar WorldId/PlaceId explícito y versionar los viajes antiguos. La recuperación debe reconocer el destino contratado; no deducirlo por el precio. Tampoco recalcular la validez de una compra ya pagada usando los boosts actuales.

Fuente: [TeleportSystem:10](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Worlds/TeleportSystem.server.luau:10), [mitigación:90](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Worlds/TeleportSystem.server.luau:90).

## 5. Orden de trabajo recomendado

1. **Integridad:** pads/MovementGuard, saldo AFK persistente, Dark Zonic y entrega idempotente de compras/regalos. Añadir los casos adversos reproducidos a la batería de regresión.
2. **Rendimiento del servidor:** sacar las esperas de persistencia del recorrido secuencial de jugadores; combinar ganancias ordinarias. Medir bajo carga y durante eventos de admin.
3. **Medición válida:** registrar versión, mundo, plataforma y hitos entre sesiones. Separar progreso gratuito, compras, eventos y recompensas aleatorias.
4. **Balance completo:** simular desde cuenta nueva, pasando por la adquisición real de cosméticos, hasta Mundo 3. Comparar jugador casual, conocedor del sistema y comprador. Evitar calibrar usando solamente la cinta o solamente el gate.
5. **Prueba de experiencia:** sesiones observadas en móvil, volver tras AFK, desconexión al cobrar, regalo con cambio de mundo, recibo pendiente y compra seguida de rebirth. Establecer objetivos de tiempo y rendimiento antes de tocar otra cifra.

**Mantenimiento:** existen rutas antiguas desactivadas, módulos de monetización de ejemplo y fachadas `_G` conviviendo con el backend activo. Por ejemplo, el módulo `MonetizationService` tiene un ledger en memoria y SKUs de ejemplo, pero el callback real de Marketplace está en `SpeedProductPurchases`; no atribuí ese ledger de ejemplo al procesamiento real. Conviene retirar o aislar estos restos para que nuevas correcciones se hagan sobre la ruta que efectivamente corre.

## Evidencias locales

- [Batería existente: 45/45](C:/Users/Aoshy´/Desktop/Update2/output/audit_review_20260923_checks.txt).
- [Pruebas adicionales de esta auditoría](C:/Users/Aoshy´/Desktop/Update2/output/review_20260923/probes.luau) y [resultados](C:/Users/Aoshy´/Desktop/Update2/output/review_20260923/probes.txt).
- [Reproducción del guard y Rebase](C:/Users/Aoshy´/Desktop/Update2/output/review_20260923/guard_rebase.luau) y [resultados](C:/Users/Aoshy´/Desktop/Update2/output/review_20260923/movement_guard.txt).
- [Modelo de entrenamiento](C:/Users/Aoshy´/Desktop/Update2/output/review_20260923/pacing.json).

Estas pruebas usan entradas controladas para demostrar comportamiento y limitaciones. El siguiente paso de validación es Roblox Studio/servidor privado y dispositivos reales; no deben presentarse los tiempos simulados como telemetría de producción.
