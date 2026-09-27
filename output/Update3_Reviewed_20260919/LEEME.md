# Update 3 — revisión del 19 de septiembre de 2026

Archivos finales: World1.rbxl, World2.rbxl y World3.rbxl en esta carpeta. También se actualizaron World1Update3.rbxl, World2Update3.rbxl y World3Update3.rbxl en la raíz del proyecto.
Respaldos originales: audit/review_20260919/World1.rbxl, World2.rbxl y World3.rbxl.

## Cambios

- Quests: contorno fijo de 1.2 píxeles, texto separado del icono, sin restricción de aspecto que comprimía las filas. Prefab guardado y módulo de ejecución corregidos.
- Hide Popups: cola con índice final explícito. Antes se calculaba la longitud de una tabla con huecos, lo que podía perder solicitudes; ahora no encola ganancias mientras está oculto. Prueba real del trabajador con ocho ciclos de ocultar/mostrar.
- Caminadoras: desactivar emisores ya no destruye su Rate; volver a subir restaura la emisión. Respeta EventEffects.
- V40 SAB: conservados los 70 elementos de VfxTemplates en cada mundo, incluidas las plantillas de lanzamiento, explosión y caminadora. Verificado que no contienen scripts; copia en src/assets/VfxTemplates.rbxm.
- Fuegos artificiales: partículas emitidas después de colocar el objeto en Workspace, emisores de ráfaga sin emisión continua, límites de partículas y menor frecuencia de lanzamiento, especialmente en móviles. Los sonidos respetan Muted/SoundEffects. El audio de explosiones tiene soporte separado de las partículas para no cortarse al desaparecer estas.
- Sonidos: lanzamiento 75964117535029; explosiones 126237860088652. Se conserva una secuencia visual de seis explosiones por cohete. La sincronización exacta con cada golpe del audio requiere escucharlo en Studio.
- Frío: conservados temblor, vaho y boosts. Se restaura la pose antes del descarte por distancia. Nieve ya no borra un boost anterior al empezar ni uno más fuerte/nuevo al terminar.
- Update log: Update 3 con evolves, rebirths, auras, trails, mundo, Sonic Burst, Admin Abuse, jugabilidad, correcciones y rendimiento.

## Códigos

Todos mantienen marcador de reclamo único y usan la ruta transaccional existente.

| Código | Recompensa |
|---|---|
| UPDATE3 | x2 Speed 15 minutos + x2 Wins 10 minutos |
| NEWWORLD | x2 Speed 20 minutos |
| ADMINPARTY | x2 Wins 15 minutos |
| BOOST (existente) | x2 Speed y x2 Wins 15 minutos |

Se eliminó de BOOST la entrega proporcional de Speed/Wins, que añadía al menos 500,000 Speed y 15,000 Wins además de sus pociones. Conserva sus boosts y su marcador anterior; no vuelve a habilitar reclamos usados.

## Verificación

- Compilación de los lugares finales: World1 281 scripts, World2 328, World3 269; total 878.
- Siete fuentes modificadas verificadas después de serializar cada lugar.
- Comparación del grafo completo tras revertir los cambios declarados: mapas y demás propiedades conservados. Se excluyen únicamente UniqueId regenerados por el lector y el prefab QuestGui reemplazado.
- Pasaron 12 suites distintas: requested_fixes, update3_audit, quests_afk_persistence, designer_ui, runtime_panels, vfx_and_admin_events, new_persistence, guards, mobile_performance, sonic_burst, launch_polish y promo_codes.
- Las pruebas ejecutan lógica con simulación de APIs y revisan estructura; no sustituyen un playtest en Roblox Studio.

## Pendientes encontrados en la revisión anterior de Gemini

Tres suites NO pasan; los mismos fallos se reprodujeron en los archivos originales respaldados:

1. test_admin_trolls: su entorno de fuegos artificiales no proporciona ReplicatedStorage y falla al usar FindFirstChild. Hay que actualizar el simulador antes de certificar esa prueba completa.
2. test_admin_abuse_panel: el piso de Disco de World2 pasa 464/480 puntos (96.67%), por debajo del requisito de 97%. Revisar visualmente la ubicación/cobertura de la pista.
3. test_world3_place: comparación estricta de ServerStorage con World2 falla. Hace falta reconciliar las diferencias antes de certificar igualdad completa entre mundos.

No se afirma que todo el trabajo previo de Gemini esté libre de errores. Estos tres pendientes no son regresiones de este parche. Logs y pruebas de referencia en audit/review_20260919.

## Comprobación final en Studio

Abrir cada mundo y verificar Quests en teléfono/PC; alternar Hide Popups mientras se corre; bajar/subir a caminadoras; activar nieve, confeti y fuegos artificiales; escuchar ambos audios completos; canjear cada código dos veces y reconectar (el segundo reclamo debe rechazarse).

Construcción reproducible: audit/build_requested_fixes.luau usa los respaldos de esta revisión y conserva los cambios anteriores que ya estaban en los lugares. No reemplaza los mapas por bases antiguas.

## IDs de producción confirmados por el usuario

- World1: 85065221510105
- World2: 116359653478954
- World3: 128432111599629

Config, WorldPortalService y WorldsController apuntan a estos destinos. El Update Log guardado incluye los cuatro códigos y sus recompensas exactas. Los IDs antiguos permanecen únicamente para reconocer los mundos de prueba y sus permisos de preview. Estos archivos son locales; no se publicaron al servicio de Roblox desde esta sesión.
