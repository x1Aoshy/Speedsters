# DataStore y economía — auditoría ampliada

## Evidencia antes de la segunda ronda de edición

- Las pruebas `audit/persistence/test_merged_core.luau` y `test_regression.luau` reproducen snapshots concurrentes, timeout aplicado/no aplicado, recuperación y recibos repetidos sobre los módulos reales. Las correcciones previas pasan.
- `ProfileReducers` conserva premios/recibos de forma atómica. `World1/World2FlightAbility` todavía descuenta Wins en leaderstats antes de conceder Flight (hallazgo del agente security_hunt): se necesita `PurchaseUpgrade` con comprobación de propiedad dentro del reducer y estado de equipamiento compatible con marcadores OG.
- `_notifySubscribers` libera el bloqueo antes de la proyección; sus callbacks pueden ceder ejecución. Una proyección vieja no debería sobreescribir una más nueva si un subscriber ejecuta otra mutación. Revisar currentRevision/sessionId y guard de proyección.
- `SpeedProductPurchases` mantiene ruta persistente de regalo, pero `ShopController` debe permitir cancelar/preparar otra ruta con confirmación del servidor; no borrar contextos si hay un recibo pendiente. GamePass gifting no entrega ownership real, está bloqueado en cliente y servidor.
- `DataService.Release` retiene snapshot no confirmado y reintenta. `Bootstrap` reintenta salida en background. Debe probarse que una salida tardía no libera una nueva sesión del mismo UserId y que Shutdown trabaja en paralelo.
- `ProfileCodec` preserva extensiones desconocidas y ya no trunca recibos a200; no modifica registros corruptos/futuros. Verificar size/finiteness y daily day30/31 con catálogo actual.
- Aura/Trail compras con Wins, códigos, Rank, Starter Pack y daily/playtime tienen lotes atómicos integrados; faltan escenarios de doble solicitud/timeout y comprobar su integración real con los handlers.

Los archivos `.rbxl` se generarán desde los originales actuales y las fuentes audit/merged. No se tocarán datos reales de usuarios. Publicación y pruebas en Roblox quedan fuera de la evidencia aislada disponible.
