# Core loop: implementación local y salida a producción

Los tres archivos de la carpeta raíz están actualizados: `World1Update3New.rbxl`, `World2Update3new.rbxl` y `World3Update3New.rbxl`. Este directorio contiene copias finales y `validation.json`. Las copias anteriores están en `output/Backup_CoreLoop_20260920_025554`. Todavía no se han publicado en Roblox.

## Cambios incluidos

- Se conserva el fix previo de treadmills y popups. En W2, Golden pasa de base 3 a 10; los multiplicadores de trajes mantienen el poder de W1. En W3, Basic pasa a 10 y Diamond a 30, igualando el mejor treadmill gratis de W2. Los treadmills de pago conservan su base.
- Los regalos de días 1–14 ahora progresan gradualmente: día 1, 250 Speed; día 7, 100,000; día 14, 1,000,000. Los premios ya cobrados no se modifican. Starter Pack conserva 100,000 Speed, 100 Wins y Trail02.
- La misión Sprinter requiere al inicio 250 Speed, tres etapas y tres minutos. A partir del período UTC 20717 (21/09/2026) se ofrece diariamente junto a otras dos misiones. Las elecciones de los días 19 y 20 mantienen el orden anterior. Si la publicación sucede después del 20/09 UTC, revisar esta fecha antes de publicar para que una elección ya guardada no cambie de misión a mitad de día.
- Al terminar el tutorial de W1 en la primera etapa, aparece una pista para comprar Orange Aura/Trail en Backpack. El aviso se muestra una vez por sesión y no obliga a comprar.
- Los funnels secuenciales tienen nombres `_v2`. Los resultados alternativos y los hitos independientes se envían como eventos personalizados: cerrar o agotar revive ya no cuenta como compra. El Starter Pack registra oferta visible solo después de cargar los datos del jugador y la propiedad del pase. Misiones comparten ID de sesión por día UTC para poder cruzar reconexiones. Se dejan de emitir los funnels antiguos.

Roblox admite hasta **10 nombres de funnel por día** y eventos personalizados separados. Esta versión usa nueve nombres nuevos de funnel. Los eventos AnalyticsService solo funcionan en juegos **publicados**, no en Studio; tras publicar, comprobar `Analytics > Funnels > View Events` y `Analytics > Explore > View Events`. Los gráficos suelen tardar hasta 24 horas. Si los funnels antiguos ya generaron eventos el mismo día del lanzamiento, algunos nombres nuevos pueden esperar al siguiente día UTC por el límite diario. Fuente: [Funnel events](https://create.roblox.com/docs/production/analytics/funnel-events), [Event types](https://create.roblox.com/docs/production/analytics/event-types).

## Verificación antes de publicar

1. En Studio, jugador sin progreso en W1: cinta concede Speed cada 0.5 segundos, popups móviles y de escritorio visibles, primer regalo de 250 Speed, primera etapa y pista de Backpack, cosmético comprado/equipado con Wins, Sprinter reclamable tras tres minutos y tres etapas.
2. Con perfil de 7 rebirths y nivel 100: entrar en W2, confirmar Golden x10 y que Mobius mantiene x110; revisar sensación de movimiento y dificultad de carrera. Con 15 rebirths y nivel 200: W3 Basic x10 y Diamond x30.
3. En juego publicado o servidor de prueba real, comprar y reclamar Starter Pack y revive; comprobar entrega, posesión persistida y un solo registro de compra. Verificar giros gratis, con Wins y pagos en rutas distintas. Studio no emite los eventos de AnalyticsService.
4. Esperar cohortes maduras para evaluar D1/D7, duración, ventas por usuario elegible y errores de compra. No se puede garantizar más retención o ingreso sin observar esas cohortes.

Se compilaron los ocho scripts modificados, se verificaron las fuentes reabriendo los tres `.rbxl`, se preservó el conteo de objetos y pasaron las pruebas de funnel, quests/AFK, economía, onboarding, monetización y treadmills. No se hizo un playtest interactivo en Studio ni una prueba de compras reales.

## Cambios manuales en Creator Hub

**Ningún cambio de precio es requisito para publicar este loop.** Los precios de catálogo siguen como estaban. El juego consulta el precio vivo de las ofertas principales; editar `PriceRobux` en el código no cambia lo que cobra Roblox. Para evaluar precio con grupos aleatorios, primero comprobar en `Monetization > Managed Pricing > Dynamic Price Check` que las tarjetas muestran el precio dinámico. Managed Pricing puede probar precios si la experiencia cumple sus requisitos de transacciones (Roblox indica que normalmente hacen falta unas 60,000 transacciones en 30 días). [Documentación oficial](https://create.roblox.com/docs/production/monetization/price-optimization).

| Cuándo | Producto | ID | Actual de referencia | Acción manual sugerida |
|---|---|---:|---:|---|
| Primero, después de verificar compras y medición | Starter Pack (gamepass) | 1941169289 | 50 R$ | Test de 29 frente a control de 50, si Managed Pricing permite hacerlo. Si no hay test aleatorio, no declarar ganador por comparación antes/después. |
| Después, en prueba separada | Primer x2 Speed permanente (developer product) | 3710622733 | 20 R$ | Test de 9 frente a 20; no cambiar toda la escalera a la vez. |
| Corrección de valor del paquete | x2 Wins 30 min (developer product) | 3710906741 | 119 R$ | Poner como máximo 117 R$, pues 3 × 10 min cuestan 117. Probar 99 R$ solo con medición. |
| Opcional, después | x2 Wins 60 min (developer product) | 3710906762 | 219 R$ | Candidato de prueba: 179 R$; 219 ya es menor que 2 × 119. |
| Para activar la oferta de 29 R$ | Offline Get x5 (developer product nuevo) | Falta ID | Configuración local 29 R$ | Crear el producto en Creator Hub y pegar el ID en `Config.AfkZone.ClaimX5.ProductId`. Mientras sea `nil`, la interfaz ofrece VIP x5 al precio vivo de VIP, no un cobro de 29 R$. |

Confirmar el precio regional visible en móvil y desktop después de cualquier ajuste. No editar varias ofertas al mismo tiempo si se pretende atribuir un cambio de ingreso a una sola causa. Los pases premium de treadmills y el revive de 7 R$ se mantienen; los CSV no permiten estimar su elasticidad.
