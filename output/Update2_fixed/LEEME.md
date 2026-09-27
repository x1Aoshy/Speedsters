# Update 2 — copias corregidas para probar

Entrega del 13 de septiembre de 2026. Abrir **World1.rbxl** y **World2.rbxl** de esta carpeta. Los originales subidos permanecen intactos. Estas copias incluyen los cambios guardados de Gemini y la integración posterior; reemplazan la entrega antigua de `output/Update2_revision` para esta revisión.

## Cambios principales

- Guardado: se conservan nombre de DataStore y claves (`SpeedsterEscape_MainSave_v17`, `Player_<UserId>`). Las escrituras económicas quedan serializadas; una respuesta incierta conserva la misma operación para reintentar. Un fallo de carga en producción no crea un perfil vacío para guardarlo encima. Se preservan campos antiguos, extensiones y recibos durante la migración.
- Compras, recompensas y propiedad: comandos persistentes para saldo/recompensa/recibo, compras de Flight, equipamiento, regalos, Starter Pack, rank, códigos y recompensas diarias. Se eliminó la entrega de x2 desde el cierre de prompts de productos de los pads. Después de comprar x2 hay que volver a tocar el pad para reclamar por el flujo validado.
- Saltos con Wins: el servidor calcula el precio usando el mismo multiplicador permanente de Wins del premio y la UI muestra ese precio. Un cambio de precio exige volver a seleccionar. Si falla el destino, se devuelve exactamente el débito almacenado. Un viaje pendiente sobrevive a una reconexión.
- Ejemplo World2, etapa 10, x16: coste 725.000 ×16 = **11.600.000**; premio del pad 500.000 ×16 = **8.000.000**. Un fallo devuelve 11.600.000. Se cierra el ciclo de comprar esa etapa y cobrar su pad; continuar recorriendo etapas posteriores mantiene sus recompensas. Los precios en Robux permanecen iguales.
- Pads: comprobación de personaje vivo y distancia; una operación en curso por jugador; retorno al inicio comprobado antes de conceder Wins. El servicio genérico de World2 utiliza la correspondencia del mapa manual (`Stage10 → SafeZone9.2`).
- UI: restauración del zapatito y tween hacia la barra; Rank espera `RankRewardGui`; Rebirth actualiza solo el precio. Se integran las correcciones de menús, foco, sprint, Shift Lock y navegación con mando, y se eliminan cierres duplicados del Shop.
- Cinta Admin: configuración base y etiqueta x100; Candy de World1 requiere 3 rebirths. Se conservan los códigos y vuelo temporal de Gemini y el panel/topbar Admin desactivado.
- Integración: los saltos del panel administrativo usan el flujo de guardado del portal. Se añaden los módulos que faltaban en las copias. Los scripts con rutas duplicadas del mapa se preservan individualmente.

## Evidencia ejecutada

`pruebas.txt` registra 11 ejecuciones satisfactorias con Lune. Se ejecutaron los módulos de persistencia y handlers de salto/premio con servicios simulados; no son solo búsquedas de texto.

Casos cubiertos: cambios concurrentes, escritura aplicada con timeout, fallo sin aplicar, reintento de recibo, cierre/reingreso, sesión antigua contra sesión nueva, perfil corrupto/futuro sin sobrescritura, 252 recibos y campos antiguos conservados; once reembolsos sin crear Wins; precio desactualizado sin cobro; débito y premio únicos durante timeout; fallo de regreso sin premio; viaje pendiente persistido; Flight temporal y compra permanente; validación de códigos y bloqueo de reentrada de remotes; precio de Rebirth, referencia de Rank y controles aislados; zapatito/tween.

El constructor deserializa nuevamente cada `.rbxl`, compila todos sus scripts y comprueba que, al revertir exclusivamente las fuentes editadas y quitar las instancias nuevas declaradas, el archivo coincide con un roundtrip del original. Así se comprueba la preservación del mapa y otras propiedades. `manifest.json` enumera cambios y adiciones; `SHA256.txt` identifica las copias.

## Estado de publicación y límites

**Candidatas para prueba; todavía no certificadas para publicar.** No hubo sesión de Roblox Studio ni cliente Roblox disponible para ejecutar física, streaming, compras reales, teleports entre places o un mando. Las pruebas anteriores no demuestran ausencia total de bugs ni garantizan que una caída nunca pierda progreso sin guardar. No se leyeron, borraron ni restauraron perfiles reales; estos fixes previenen rutas identificadas, no recuperan pérdidas históricas automáticamente.

Antes de publicar, en una experiencia de prueba con datos separados:

1. Abrir ambas copias, Play, revisar Output y probar correr/cintas, zapatito, Rank, Rebirth y abrir/cerrar menús con teclado, touch y mando.
2. Probar etapas y retorno de ambos mapas, especialmente World2 Stage10; medir saldo con x1 y x16 y repetir durante lag. Comprobar progreso legítimo a velocidad alta y Flight.
3. Probar compra/cancelación/reintento de productos y regalos, x2 en pads, reclamar recompensas y reconectar. La cancelación observada por el servidor ahora limpia únicamente ese intento; el prompt lo abre el servidor después de guardar el destinatario. Los recibos antiguos no pueden borrar un intento nuevo. Falta validar el prompt real y resolver recuperación tras desconexión sin señal de cierre: el contexto se conserva ante esa incertidumbre. Los regalos de GamePass están bloqueados porque el prompt ordinario no transfiere propiedad a otro usuario.
4. En Roblox publicado de prueba, cambiar World1 ↔ World2, simular fallo del teleport y verificar que se pueda seguir jugando y que saldo/inventario sobrevivan. Studio no valida teleports entre places.

Los informes `audit/BUG_*.md` contienen el historial de hallazgos; algunos apartados son propuestas previas y no equivalen a validación final. Seguridad de mensajes administrativos, efectos temporales de recibos y rendimiento en servidor poblado requieren completar pruebas de integración. No se ha certificado la auditoría integral como terminada.

Revisión adicional de regalos: `pruebas_regalos.txt` registra las pruebas de identidad persistente, limpieza de recibo antiguo y cancelación con timeout en ambos mundos. Consultar `audit/BUG_GIFT_LIFECYCLE.md` para los límites y evidencia.

Revisión adicional de anuncios: GlobalAnnouncementService ya no envía texto original si falla el filtro. Los eventos tienen identidad, se omite el eco del servidor y se rechazan reentregas, mensajes malformados y timestamps fuera de ventana. MessageHandler escapa remitente y mensaje antes de insertarlos en RichText. `pruebas_anuncios.txt` registra la ejecución de los handlers reales con servicios simulados en ambos mundos. Esto cubre anuncios; no certifica todos los efectos administrativos.

Revisión adicional de confeti: máximo 240 piezas vivas por servidor y una actualización compartida a 10 Hz. `pruebas_confeti.txt` verifica ese límite con activaciones repetidas y las comprobaciones de recogida (propiedad del servidor, distancia, vida, DataLoaded y premio único). La física y el rendimiento con jugadores reales siguen pendientes.
