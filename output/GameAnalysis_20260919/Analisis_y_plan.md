# Speedster Escape: retención, economía y crecimiento

Análisis al 19 de septiembre de 2026. Se revisaron los 48 CSV de DataAnalysis, las dos capturas proporcionadas y la configuración/código local. Los CSV principales llegan hasta el 18/09. Los funnels solo contienen valores distintos de cero para el 19/09. La configuración local no demuestra qué versión ni qué precios estaban publicados durante el período.

**Estado posterior:** las recomendaciones de balance, recompensas, misión corta, guía inicial y medición ya se incorporaron a los tres archivos locales del juego. Este informe conserva los valores observados antes del cambio; los detalles de implementación y las tareas de Creator Hub están en [LEEME_IMPLEMENTACION.md](C:/Users/Aoshy´/Desktop/Update2/output/CoreLoop_Final_20260920_030028/LEEME_IMPLEMENTACION.md).

**Recomendación:** recuperar el funcionamiento y la sensación de progreso, reparar la medición y probar una entrada de compra más accesible. Mantener inicialmente los precios de las treadmills premium. La caída reciente se concentra en conversión, productos de desarrollador y duración de juego; aumentar precios de forma general no está respaldado por estos datos.

## 1. Qué está pasando

Comparación de semanas completas con los mismos días de la semana:

| Métrica | 5–11 septiembre | 12–18 septiembre | Cambio |
|---|---:|---:|---:|
| DAU promedio | 269,407 | 218,223 | −19.0% |
| Robux reportados por semana | 873,724 | 549,750 | −37.1% |
| Pagadores diarios promedio | 3,144 | 1,115 | −64.5% |
| Pagadores / usuarios-día | 1.167% | 0.511% | −56.2% |
| Robux / usuario-día | 0.463 | 0.360 | −22.3% |
| Robux / pagador-día | 39.70 | 70.43 | +77.4% |
| Minutos / sesión, ponderados | 11.87 | 9.76 | −17.8% |
| Minutos / usuario-día, ponderados | 16.98 | 12.80 | −24.7% |

“Usuarios-día” y “pagadores-día” son sumas de conteos diarios, no personas únicas semanales. Los ratios se calculan con esas sumas. Los Robux son los ingresos reportados por los archivos: no equivalen a beneficio, dólares ni saldo DevEx. No se añadieron ingresos realtime a ingresos diarios.

La retención D1 media de las cohortes del **6–11/09 es 15.03%**, frente a **9.64% para 12–17/09**: −5.39 puntos porcentuales. Son promedios simples de seis cohortes en cada período; no hay tamaños de cohorte para ponderarlos. La D7 media más reciente disponible, cohortes 5–11/09, es **1.09%**. No hay D7 madura para la última semana ni D30 de las últimas actualizaciones.

El 13/09 destaca: DAU sube de 308,685 a 332,192, pero la sesión media baja de 11.36 a 9.02 minutos, los pagadores de 3,112 a 1,446 y D1 de 13.46% a 6.67%. Es una fecha prioritaria para revisar publicaciones, cambios de tienda y errores. La coincidencia temporal no identifica una causa por sí sola.

Existe una señal positiva: en el agregado de 28 días, **67.0% de los usuarios nuevos sigue jugando a los cinco minutos y 49.5% a los diez**. La serie “previous” muestra 49.8% y 31.5%, respectivamente, aunque no incluye las fechas originales de comparación. El juego sí consigue enganchar; ese agregado no descarta el deterioro de los últimos días.

Fuentes: CSV “Daily active users”, “Daily Robux spent”, “Paying users”, “Sessions”, “Total playtime”, “Day 1 retention”, “Day 7 retention” y “New user first session retention”, en [DataAnalysis](C:/Users/Aoshy´/Desktop/Update2/DataAnalysis).

## 2. Los funnels actuales no permiten leer conversiones literalmente

Roblox completa automáticamente los pasos anteriores cuando recibe un paso posterior. Esto está documentado en [Funnel events — Skipped steps](https://create.roblox.com/docs/production/analytics/funnel-events#skipped-steps).

| Funnel | Problema observado en el código | Medición recomendada |
|---|---|---|
| Revive | Shown → Purchased → Dismissed → TimedOut mezcla resultados alternativos. Cerrar o expirar completa artificialmente Purchased. | Oferta vista → pulsó comprar → recibo confirmado → revive aplicado. Cierre y expiración como eventos separados. Un ID por oferta. |
| Onboarding | Primer rebirth puede ocurrir sin terminar una vuelta y completa artificialmente FirstLap. La condición “newcomer” se pierde al reconectar después de rebirthear. | Separar hitos independientes del recorrido guiado. Persistir la cohorte de onboarding. Medir World 2 en progresión, a través de sesiones. |
| Rebirths | Funnel de una sola vez con World 3 al final; no describe el abandono entre rebirth 1, 2, 3, etc. | Un recorrido por número de rebirth, con elegibilidad, ejecución y progreso posterior. |
| SpinWheel | FreeSpin, PaidSpin y WinsSpin aparecen en la misma secuencia aunque son rutas alternativas. | Separar giro gratis, compra de tickets y gasto de Wins. Compra final solo tras receipt. |
| AFK | Salir es el último paso y puede completar artificialmente RewardEarned. El panel offline comparte recorrido con AFK activo. | Separar cobro offline y AFK activo. Salida como resultado con duración/recompensas reales. |
| Quests | Se inicia sesión de funnel al abrir el panel; una misión puede continuar entre aperturas y sesiones. | Mantener identidad por jugador + día + misión, registrar tareas y reclamo real. |
| Starter Pack | La secuencia compra es razonable, pero comienza en el clic del icono, no en quienes vieron la oferta. | Añadir oferta elegible/vista y atribuir compra al precio y variante realmente mostrados. |

Consecuencias para tus capturas:

- **93.88% de “Purchased” en revive no es conversión de pago.** No usarlo para subir el precio.
- **99.93% de FirstLap → FirstRebirth no demuestra que casi todos los que corren hagan rebirth.** Puede ser efecto del autocompletado.
- **1.54% de World2_Unlocked no demuestra 98.46% de abandono real.** Hay una cohorte del día todavía inmadura y el código excluye de onboarding a quien regresa con rebirths. El 533 registrado merece seguimiento, pero no determina un precio o requisito óptimo.
- Todos los CSV de funnels tienen 27 días en cero y datos distintos de cero solo el 19/09. El 0.06% promedio mostrado coincide aproximadamente con 1.54% dividido entre 28. No interpretar ese promedio como conversión madura del mes.
- Los CSV omiten nombres de funnel y de eventos: solo conservan “1.”, “2.”, etc. Las asociaciones de los archivos numerados con los demás funnels serían inferencias. No utilicé esas asociaciones como conversiones verificadas.

Crear funnels nuevos con sufijo de versión, sin mezclar el histórico contaminado. Conservar eventos de resultados independientes para auditoría. Registrar versión, mundo, plataforma, rebirth, precio mostrado, productId y tiempo desde entrada según los campos disponibles.

Evidencia: [FunnelAnalytics](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/FunnelAnalytics.luau:31), especialmente la definición de pasos, el filtro de newcomers y su cálculo al cargar datos. Los eventos de World 2 se emiten en [WorldPortalService](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Worlds/WorldPortalService.server.luau:620).

## 3. Dónde se está perdiendo ingreso

Los productos de desarrollador caen **48.4%** semanal, contra **20.1%** en pases. Normalizado por DAU, la caída es **36.3% en productos** y solo **1.4% en pases**. Esto favorece conservar inicialmente los precios premium mientras se revisa la compra de entrada.

En el desglose realtime por producto, los antiguos **x2, x4 y x10 Speed tienen cero ingresos desde el 13/09**. Entre las semanas comparadas pierden juntos **123,954 Robux**, alrededor del 38% de la caída total semanal, como contribución aritmética aproximada entre fuentes con pequeñas diferencias de actualización. “Other” de productos solo crece de 160,232 a 161,927. No hay compensación agregada equivalente visible en esa categoría.

El código confirma una migración de IDs: la OG tenía x2/x4/x10 y la configuración actual x2/x4/x8/x16/x32. Sus precios locales de referencia también cambian: primeras etapas 3/7/19 en OG frente a 20/40/80/160/320 actuales. **Son referencias de código, no prueba del precio histórico cobrado.** Los CSV por nombre no muestran IDs, ventas, exposición ni precios por transacción; un producto nuevo puede estar oculto en “Other”.

Prioridad comercial: cruzar los nuevos IDs con ventas reales, verificar que el botón se ve en móvil, que abre el producto correcto y que el recibo concede el multiplicador. No volver a ofrecer un ID retirado sin revisar sus derechos y su balance.

Las tres treadmills pagadas suman **239,426 Robux** en el detalle del 12–18/09, aproximadamente 43.6% del ingreso semanal reportado. Hacker es la mayor. Deben funcionar impecablemente; un fallo de entrenamiento afecta el producto principal del juego.

Starter Pack baja 48.0% y Revive 50.6% en el detalle semanal. Flight desaparece como developer product y aparece como pase desde el 13/09: no clasificar automáticamente ese cero como una compra rota. Hay una migración de formato.

Fuentes: los dos CSV “Universe-10447471170- Robux Spent (Realtime)” y “Robux sources”. Los totales realtime difieren ligeramente de la serie cerrada; se usó esta última para los indicadores principales. Configuración: [productos y multiplicadores](C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/Config.luau:923), y [OG](C:/Users/Aoshy´/Desktop/Update2/audit/treadmill_regression/OG/Config.luau:405).

## 4. Qué precios probaría

Precios actuales de esta tabla = configuración local, sujetos al precio vivo/regional mostrado por Roblox. No se pudo confirmar el catálogo vivo con los CSV. Ningún precio se modificó durante este análisis.

| Oferta | Referencia local actual | Acción propuesta | Motivo |
|---|---|---|---|
| Starter Pack | 50 R$ | Probar 29 contra 50, con el mismo contenido durante la prueba de precio. Evaluar el contenido en una prueba aparte. | Compra de entrada más accesible, pero primero verificar visibilidad y entrega. |
| Primera mejora permanente x2 Speed | 20 R$ | Probar 9 contra 20, solo después de comprobar los nuevos IDs. Mantener las etapas posteriores durante ese test. | Recuperar primeras compras sin rebajar todo el catálogo. |
| Revive | 7 R$ | Mantener inicialmente. Reparar funnel y revisar recuperación gratuita/claridad de la oferta. | No hay evidencia suficiente de elasticidad para bajar o subir. |
| Hacker, Admin y Valentine | Precio vivo no verificado | Mantener inicialmente. | Los pases resisten mucho mejor por usuario y concentran ingresos. |
| Poción x2 Wins: 10/30/60 min | 39 / 119 / 219 R$ | Corregir primero 30 min para que no cueste más que 3 × 10 min. Candidatos posteriores: 39 / 99 / 179. | 3 × 39 = 117, más barato que el paquete de 119; el tiempo se acumula. |
| Poción x2 Speed: 10/30/60 min | 9 / 27 / 42 R$ | Aclarar que se acumula con el permanente y priorizar permanente para quien no lo tiene. Probar paquetes después. | Un temporal de 27 compite con un permanente de 20 para un comprador nuevo. |
| Wins permanentes | 249 / 349 / 649 / 1199 / 2199 R$ | No aplicar rebaja masiva. Diferenciar “todos los Wins” del pase “pads x2” y medir la primera etapa. | Son cinco compras sucesivas y dos productos distintos con nombres parecidos. |
| Spin packs | 29 / 69 / 199 R$ | Mantener hasta separar giros gratuitos, de Wins y pagos. | El funnel actual no estima conversión real de cada ruta. |
| Offline x5 | 29 R$, ProductId = nil | Completar el producto de 29 si se conserva la propuesta. | Actualmente la ruta recurre a VIP; la configuración local de VIP es 499. No es la misma compra. |

Una rebaja no garantiza más ingresos: **50 → 29 requiere 72.4% más compras** para igualar ingreso directo, y **20 → 9 requiere 122.2% más**, si comisión y mezcla regional no cambian. Medir Robux netos por usuario elegible a 7 días, retención y devoluciones/entrega; no declarar ganador por conversión sola.

Verificar precios dinámicos de cada tarjeta y la configuración regional, dada la audiencia internacional. Roblox documenta [precios regionales](https://create.roblox.com/docs/production/monetization/regional-pricing) y [optimización de precios](https://create.roblox.com/docs/production/monetization/price-optimization). Estos CSV no contienen conteos de transacciones suficientes para confirmar elegibilidad o calcular elasticidad.

## 5. Cambios al core loop que priorizaría

El loop actual es: entrenar/correr → ganar speed y niveles → superar etapas → ganar Wins → equipar aura/trail y traje → ganar speed más rápido → rebirth → nueva treadmill/mundo. La retención necesita que el siguiente objetivo sea visible y que el jugador conserve una sensación tangible de avance.

**A. Resolver el corte del entrenamiento.** El fix anterior corrige el error local de `addSpeed` y el recorte de popups. Hay que confirmar que esa versión está publicada y funcionando en los tres mundos, con un jugador normal y en móvil. Los CSV históricos no pueden medir el efecto de ese fix de hoy. No asociar toda la caída del 13/09 a ese bug sin fechas de publicación.

**B. Evitar que World 2 se sienta como castigo.** Se exige 7 rebirths y nivel 100. A ese punto, la Diamond gratuita de W1 da base 10; al llegar, Golden de W2 da base 3 y Candy necesita 9 rebirths. Para el mismo traje Mobius Wally West, el multiplicador baja de 110 a 40. Manteniendo los demás factores, la ganancia de treadmill pasa a `(3 × 40)/(10 × 110) = 10.9%` de la anterior. Además, W2 aplica un factor de velocidad de movimiento de un tercio. Es un ejemplo calculado de configuración, no una tasa observada de todos los jugadores.

Primera variante de balance: Golden W2 al menos base 10, conservar el poder del traje al viajar y ajustar la dificultad mediante objetivos y distancias. Medir tiempo hasta la primera recompensa de W2 y regreso al día siguiente. Revisar el efecto sobre ventajas compradas. No bajar a ciegas el requisito de 7 rebirths solo por el 1.54% del funnel.

**C. Hacer que los Wins se conviertan pronto en progreso visible.** Una aura naranja y un trail naranja cuestan 10 Wins cada uno y multiplican ×2.5 cada uno: juntos ×6.25. Quien desconoce esto y solo farmea treadmill vive una curva radicalmente más lenta. Guiar hacia una primera mejora asequible, mostrar el aumento antes/después y ofrecer equiparla con un toque. Instrumentar compra y equipamiento, no solo apertura de Backpack.

**D. Resolver la contradicción entre regalo y compra.** El día 1 entrega 1,000,000 de speed base y encima aplica multiplicadores. Starter Pack ofrece 100,000 speed + 100 Wins + Trail02. Su speed base es diez veces menor que el regalo inmediato; la entrega del starter en DataService es exacta. La curva local sitúa 100,000 speed en nivel 41 y 1,000,000 en 57, sin contar multiplicadores. Es un salto grande frente al primer rebirth en nivel 5.

Probar una recompensa diaria proporcional a unos minutos de progreso, con límites por etapa, más un premio visible de regreso; dar valor permanente o exclusivo al starter. No retirar recompensas ya reclamadas ni degradar compras existentes. Evitar que el rebirth inmediatamente borre el principal beneficio percibido de la compra.

**E. Dar una recompensa corta antes de las misiones largas.** Las rutas actuales exigen varias tareas y contienen tiempos base de 10–30 minutos; con el ajuste de nivel la ruta corta empieza alrededor de 8 minutos. La sesión reciente ponderada dura 9.76 minutos. Añadir un primer objetivo reclamable en 2–3 minutos, una mejora clara en 5–8 y una misión larga opcional. Mantener el progreso diario entre sesiones. No usar AFK como sustituto del juego activo.

**F. Hacer visible el motivo para volver.** Ya existen login de 30 días, giro cada 12 horas y recompensas offline. Antes de añadir sistemas, unirlos a un objetivo: preview del premio de mañana y próximo desbloqueo, una misión diaria corta y colección cosmética semanal. Evitar pérdida de progreso por no mantener una racha. Medir D1 y D7 de quienes ven, reclaman y usan la recompensa.

Evidencia: [perfiles de treadmill](C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/Config.luau:461), [trajes](C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/Config.luau:831), [cosméticos](C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/CosmeticCatalog.luau:39), [login diario](C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/DailyRewardsData.luau:24), [curva de niveles](C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Progression/LevelProgress.server.luau:25), [quests](C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/QuestCatalog.luau:51).

## 6. Usuarios diarios, rendimiento y alcance

- Home Recommendation pasa de 1,011,365 a 827,149 en la suma semanal de usuarios diarios atribuidos (−18.2%). Friends cae 34.7%. Son sumas diarias del export de adquisición, no DAU total ni únicos semanales. No hay impresiones, CTR ni gasto publicitario suficientes para atribuir la caída a las miniaturas o calcular ROAS.
- Los intervalos de rendimiento del 18–19/09 muestran **26.3 FPS medios en teléfono**, 30.8 en tablet y 36.6 en computadora. Son promedios simples de intervalos, no ponderados por sesiones. Teléfono + tablet representan aproximadamente 85% de las observaciones de concurrencia exportadas; eso no equivale a 85% del DAU. Optimizar gameplay/UI/VFX en móvil es prioritario y se debe probar después de restaurar los popups.
- Inglés, español y portugués dominan los idiomas exportados. Español + portugués suman 1.25 millones en esa tabla. Localizar objetivo inicial, rebirth, beneficios de compra y portal. La tabla solo incluye diez idiomas y no cuadra exactamente con MAU, así que no se trató como desglose exhaustivo.
- Los ratings del período suman 9,958 positivos y 1,160 negativos: 89.6% positivos entre votos exportados. No es prueba de satisfacción de todos los usuarios, pero indica que conviene preservar lo que ya gusta.
- Priorizar primer juego sin frustración, días de regreso y juego voluntario con amigos. La documentación actual de [Discovery](https://create.roblox.com/docs/discovery) enfatiza rebote temprano y días de juego, y distingue usuarios de Home de otras fuentes para su ranking. Mejorar estas métricas no garantiza distribución; cambios de tráfico también pueden tener causas externas.

No empezaría comprando más tráfico para compensar esta caída. Primero comprobaría que una cohorte nueva completa el loop, vuelve y puede comprar correctamente. Para marketing, separar resultados orgánicos de Home, Friends y anuncios.

## 7. Orden de trabajo y criterios de decisión

1. **Ahora:** confirmar versión publicada, entrenamiento y entrega de compras; reconstruir funnels; auditar los IDs que sustituyeron los multiplicadores antiguos. Incluir errores y versión en la telemetría. Validar en jugador normal, no solo admin/Studio.
2. **Siguiente cambio de producto:** primera mejora con Wins y primer objetivo reclamable en 2–3 minutos. Prueba separada del salto W1 → W2, con la misma elegibilidad inicial.
3. **Después de instrumentar:** test de primer x2 Speed (20 contra 9) o Starter Pack (50 contra 29), uno a la vez en la misma superficie. Aleatorizar usuarios elegibles, conservar su variante y registrar el precio real. Si se usa la optimización nativa, comprobar primero su elegibilidad y requisitos.
4. **Después:** coordinar recompensa de mañana, misión corta y colección semanal. Probar un incentivo de jugar con un amigo que beneficie a ambos sin obligar a invitar.

Metas iniciales internas, no benchmarks de Roblox ni promesas: recuperar sesión ponderada a 11–12 minutos, D1 hacia 13–15%, conversión diaria hacia 0.8–1.0% y ARPDAU por encima de 0.40 sin dañar retención. Evaluar D7 solo cuando las cohortes maduren; una meta de prueba de 2% exige observar mejora real frente al control.

No declarar un precio ganador tras un día. Cubrir al menos un ciclo semanal, esperar siete días para el resultado a 7 días y comprobar volumen/variabilidad de cada grupo. El criterio primario comercial es ingreso por usuario elegible; las protecciones son D1/D7, minutos activos, tasa de receipt sin entrega y satisfacción. Cambios de funnel no reparan retroactivamente el histórico.

Escenario ilustrativo: con el tráfico de 12–18/09, recuperar el ARPDAU de 5–11/09 equivaldría a unos **157,977 Robux adicionales por semana**. Es una multiplicación a tráfico constante, no un pronóstico ni el impacto atribuido a una rebaja.

## 8. Alcance y límites

No se cambiaron precios, configuración del juego ni archivos de mundo en este análisis. Se leyeron CSV y código y se generó este informe.

Los CSV con prefijo Universe de DAU y sesión contienen series distintas de los exports generales (p. ej., 90,750 frente a 131,275 para 18/09). No se combinaron sus poblaciones ni se asumió que “current” equivale al DAU global. Se usaron los exports generales para la tabla principal, consistentes con la escala de monetización. El detalle de adquisición se analizó por separado.

Se comprobaron encabezados especiales, valores nulos, fechas, series de benchmark y reconciliación: las fuentes de ingreso suman el total diario en los 28 días. Los ratios recalculados difieren ligeramente de los ratios ya exportados por procesamiento/población; se declara la fórmula empleada. No se sumaron porcentajes de retención ni MAU. No se usó el día parcial 19/09 para la comparación semanal financiera.

Faltan el calendario de publicaciones, el catálogo vivo con precios regionales, transacciones por ID, impresiones por oferta, cohortes por versión/plataforma y tiempos entre hitos. Por ello los cambios sugeridos son hipótesis de prueba, salvo los errores de medición y las contradicciones de configuración demostrados.
