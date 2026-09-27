# PRIORIDAD P0 URGENTE — DIRECTIVA DE DIRECCIÓN (13/09/2026)

> **ATENCIÓN ASTRA / AGENTES:**
> Por instrucción directa del Lead Developer / Owner:
> **LA PRIORIDAD NÚMERO 1 ABSOLUTA (P0 BLOCKER) ES LA RESOLUCIÓN DE LA ASFIXIA DE RED (NETWORK CHOKE) Y EL ARREGLO DE HITBOXES.**
> Cualquier otra tarea en curso (cosméticos menores, pulido secundario de UI) DEBE PAUSARSE hasta que se ejecute la hoja de ruta de Red y Hitboxes documentada en:
> - `audit/INFORME_RED_Y_HITBOXES_PARA_ASTRA.md`
> - `audit/BUG_NETWORK_PERFORMANCE.md`
>
> **Acciones inmediatas requeridas:**
> 1. Anclar las 46 partes desancladas de World 2 (especialmente pads de etapa y árboles gigantes).
> 2. Purgar/desactivar `Workspace["ASMR kit -  by Agus_Fellini2"]` y bucles Heartbeat en servidor.
> 3. Resolver el "Stamina Attribute Flood" en `Bootstrap.luau` (detener la replicación de 5 atributos por frame a 60 FPS por jugador).
> 4. Redimensionar las hitboxes de pads de victoria/skip de `Y = 0.0` studs a `Y = 5.0` studs (`CanCollide = false`, `CanTouch = true`) para eliminar el efecto túnel.
> 5. Calibrar hitboxes de obstáculos de mallas 3D (`TreeSlammers`, martillos).

---

# Bug hunt Update 2 — World1 y World2

Estado: auditoría ampliada en curso. No es un certificado de ausencia de bugs ni autorización de publicación.

Base: `World1 Speedtercorrect.rbxl` (World1 real) y `world2 speedtster.rbxl` (World2). Se conservan cambios de Gemini. Fuentes de trabajo: `audit/merged/World1` y `audit/merged/World2`. Los scripts `audit/persistence/fix_*.luau` documentan las transformaciones iniciales; NO volver a ejecutarlos sobre el trabajo posterior de agentes.

Se leyó completo el archivo adjunto sobre «Rethinking skills and prompts for GPT-6 Astra». Se aplica su enfoque de límites claros, instrucciones pertinentes y verificación del resultado. No se instaló ni inventó una skill llamada «thinking».

## Requisitos y evidencia pendiente

- Investigar y corregir el reporte de World2: el pad entrega Wins repetidamente y no devuelve al jugador; 100M en aproximadamente 10 segundos. Reproducir con los scripts y geometría actuales, incluidas zonas superpuestas y fallo de destino.
- Auditar seguridad de remotes, concesión de recompensas, compras, límites y validación del servidor.
- Auditar DataStore: migración OG, escritura concurrente, leases, timeouts, salida/cierre, recibos, canjes y cambios de mundo.
- Auditar gameplay y rendimiento de ambos mundos.
- Auditar UI y consola: Rank, rebirth, zapatito, selección, D-pad, salto/vuelo, sprint y ShiftLock.
- Integrar fixes en dos nuevos `.rbxl`, conservar originales, compilar scripts y comprobar que el mapa/UI conservan sus propiedades salvo cambios identificados.
- Entregar reporte con hallazgos, cambios, pruebas reproducibles y límites de validación real en Roblox.

## Hallazgos registrados antes de delegar los cambios

| ID | Hallazgo | Estado inicial |
|---|---|---|
| GH-01 | Wins repetidos sin teletransporte en World2, reportado por jugador | Corrección integrada; RewardPadClaims cableado con teletransporte previo verificado, MovementGuard activo y empaquetado en ambos rbxl |
| DS-01 | Snapshot tras UpdateAsync puede borrar progreso ganado durante el yield | Corrección integrada; regresión de concurrencia pasa |
| DS-02 | Timeout aplicado puede sobrescribirse con memoria vieja al salir | Corrección integrada; timeout aplicado/no aplicado y reingreso pasan |
| DS-03 | Multiplicadores y premios modificaban copias de Inspect/valores proyectados | Migrados a comandos persistentes; revisión ampliada pendiente |
| DS-04 | Recibo y premio separados, Starter Pack/códigos/Rank/daily/playtime y compras con Wins con escrituras parciales | Transacciones integradas; ampliar regresiones |
| DS-05 | Destinatario de regalo solo en memoria; GamePass no regala titularidad | Ruta persistente y confirmación antes del prompt; GamePass gifting bloqueado por entrega no persistente |
| UI-01 | RankRewardPanel usa FindFirstChild con variable nil | Nombre corregido; World1 requiere mover plantilla de ServerStorage a StarterGui |
| UI-02 | Rebirth escribe precio en los dos labels Name y enlaza dos eventos por clic | Se conserva nombre/descripción, solo Price cambia; Activated único |
| GP-01 | Admin pagado World1 tiene BaseGain500 frente a100 OG | Config100 y exclusión del bonus de evento para cinta pagada |
| UI-03 | Prioridad Default inexistente, D-pad abajo consumido por ShiftLock, gatillos/vuelo activos sobre UI | Corregidos; mocks de eventos pasan; falta prueba real de mando |

No se han consultado ni modificado perfiles reales ni rankings. El comentario del jugador sobre quitar Wins no identifica de forma verificable el UserId, saldo legítimo ni versión previa; no se debe aplicar un recorte global o adivinar un saldo.

Cada auditor registra evidencia y archivos afectados antes de editar, luego documenta prueba y resultado. No publicar ni sobrescribir los `.rbxl` de entrada. La validación aislada no reemplaza una sesión multijugador publicada de prueba, un teletransporte entre places del mismo universo ni un mando real/emulado en Studio.
