# Corrección de Spin Wheel y Admin Abuse global — archivos New

Se modificaron directamente World1Update3New.rbxl, World2Update3new.rbxl y World3Update3New.rbxl. Copias finales en esta carpeta; originales completos en audit/new_spin_global/World1.rbxl, World2.rbxl y World3.rbxl.

## Causa raíz de la ruleta

1. El cliente cancelaba su espera a los 12 segundos. Si el guardado terminaba después, el servidor podía haber concedido el premio y gastado el giro, pero el cliente descartaba la animación porque solo aceptaba resultados durante la espera.
2. Una petición durante una compra en curso o dentro del límite compartido de 0.35 segundos se ignoraba sin respuesta.
3. Un mensaje de una compra/actualización ajena al giro podía cancelar la espera. Si la lectura del perfil fallaba después de confirmar el guardado, no se enviaba el resultado.
4. Al agotarse los intentos de un guardado pendiente se afirmaba que no se había gastado nada, aunque el estado todavía era incierto.

Ahora cada giro tiene un identificador; el cliente espera y reintenta esa misma petición cada cuatro segundos. El servidor conserva la tirada y la transacción pendientes, y devuelve el resultado ya confirmado sin gastar otro ticket. Las respuestas se asocian a su petición; los mensajes de otras acciones no cancelan el giro. Se conserva la configuración de acceso preview existente.

## Admin Abuse

- All Servers ya publicaba los cinco eventos y boosts, pero no caminadoras, limpieza de caminadoras ni música. Ahora esas acciones también respetan el selector.
- Las acciones sobre un jugador conservan su UserId al propagarse; All conserva la selección de todos.
- Una suscripción fallida antes dejaba ese servidor sin escuchar permanentemente. Ahora reintenta con espera creciente hasta 30 segundos y expone AdminGlobalSubscribed.
- Una publicación fallida reintenta hasta cuatro veces con el mismo EventId. Un timeout después de aceptar el mensaje no duplica efectos. Se informa al administrador si la publicación termina fallando.
- Se conserva la protección de permisos, antigüedad de mensajes, duplicados y exclusión del servidor de origen.
- Esto no convierte moderación ni cambios de estadísticas en operaciones masivas entre servidores.

## Verificación

- 878 scripts compilados en los tres places finales: 281 + 328 + 269.
- Comparación de cada archivo serializado contra su New original: solo cambian SpinWheelController, SpinWheelService y AdminAbusePanelService. Mapas, UI, assets y demás fuentes permanecen iguales; la comparación omite UniqueId regenerados por el serializador.
- test_spin_retry_regression: guardado Pending, mismo operationId y premio al reintentar, consumo de un solo ticket, respuesta tardía después de 16 segundos, mensajes ajenos, duplicado de resultado y fin de reintentos.
- test_admin_global_regression: tres servidores simulados; suscripción temporalmente fallida, publicación aceptada seguida de timeout, reintento sin duplicados; cinco eventos, apagar evento, targets individuales/todos, boosts, anuncios, caminadoras/reveal/limpieza y música.
- El handler real de solicitudes se probó con 10 acciones: This Server no publica; All Servers publica todas. Se verificó el valor que envía el selector de UI.
- Pasan también test_spin_wheel, test_runtime_panels, test_admin_treadmill_reveal y test_admin_panel_and_spin_hud. Los dos últimos se adaptaron para identificar el handler local frente al nuevo handler global y leer los archivos New.

## Prueba pendiente en servidores reales

No se publicó nada ni se ejecutaron servidores Roblox reales desde esta sesión. Para cerrar la validación: publicar cada New en su place correspondiente, entrar con cuentas en dos servidores distintos, activar/apagar cada evento en All Servers y luego comprobar que This Server queda local; probar giro durante carga/compra y con conexión lenta.

MessagingService es de entrega de mejor esfuerzo, no garantiza cada mensaje. Los reintentos corrigen fallos transitorios detectados, pero no prueban recepción universal ni recuperan eventos para servidores que nacen después del envío. Fuente oficial: https://create.roblox.com/docs/reference/engine/classes/MessagingService/SubscribeAsync

Si Studio sigue abierto con estos lugares, volver a abrir los archivos New para cargar el código actualizado antes de publicar. No guardar encima desde una sesión que conserve el código anterior.
