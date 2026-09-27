# Regalos — revisión adicional antes de editar

2026-09-13. Fuentes: Economy/SpeedProductPurchases, ProfileReducers, ProfileCodec y ShopController en ambos mundos.

- GIFT-01: al cancelar el prompt, Update2GiftContexts conserva el destinatario. La siguiente compra del mismo producto puede enviarse allí. Hace falta un ciclo de prompt identificado y cancelación comprobada en servidor; no usar una señal del cliente como prueba de compra/cancelación.
- GIFT-02: todos los caminos de recibo confirmado ejecutan SetGiftContext(targetUserId=0) sin comparar la identidad del intento. Un recibo antiguo repetido puede borrar un regalo nuevo, incluso dirigido a la misma persona. Añadir identidad persistente del intento; congelarla en el ledger del recibo y limpiar mediante comparación dentro del reducer.
- GIFT-03: requestId carece de límite de longitud y un intento pendiente se puede sobrescribir si tiene el mismo destinatario. Validar antes de consultar jugadores/datastore y conservar el intento existente hasta resolverlo.

Primera corrección: GIFT-02/03. Pruebas: recibo antiguo contra nuevo intento (mismo/diferente destinatario), roundtrip de identidad, retry del mismo request, callback repetido del ledger. GIFT-01 sigue pendiente hasta integrar y probar el ciclo completo de prompts.

## Corrección integrada y verificación local

GIFT-02/03: identidad persistente `Update2GiftContextIds`, congelada por el ledger; `ClearGiftContext` compara identidad y destinatario dentro de la transacción. Un intento diferente no sustituye al pendiente. requestId limitado a 128 caracteres, IDs numéricos comprobados antes de consultar servicios.

GIFT-01: el servidor abre el prompt después del commit; el cliente ya no abre un segundo prompt. Solo un cierre con isPurchased=false del producto activo inicia la limpieza condicional. Las respuestas inciertas reintentan la misma operación y los cierres repetidos no crean más cancelaciones. isPurchased=true no entrega nada ni limpia el contexto: se espera al recibo.

`test_gift_identity.luau` y `test_gift_cancel.luau` pasan en ambos mundos con reducers, Actor y handlers reales bajo servicios simulados. Falta la prueba del prompt dentro de Roblox. Una desconexión/exception antes de observar el cierre puede dejar un contexto conservado: no se borra automáticamente porque podría existir un recibo pendiente. La recuperación de esos intentos sin señal de cierre sigue abierta.

Referencia: https://create.roblox.com/docs/reference/engine/classes/MarketplaceService — PromptProductPurchaseFinished no certifica la entrega; ProcessReceipt sigue siendo la autoridad de compra.
