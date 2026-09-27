# Auditoría de seguridad y gameplay de servidor

Base inspeccionada: `audit/merged/World1` y `audit/merged/World2`. Hallazgos registrados antes de editar. No se modifican perfiles o rankings reales.

| ID | Evidencia inicial | Impacto / corrección prevista |
|---|---|---|
| SEC-01 | Ambos `Gameplay/World*FlightAbility`, `buyWithWins`: `wins.Value -= WINS_COST`, luego `grantAndEquipFlight` llama `_G.SpeedsterUnlockUpgrade`. `StatsProjection` repone el saldo desde el perfil. | Flight puede otorgarse sin débito persistente; compra y equipamiento se migran a un único commit con comprobación de propiedad dentro del reducer. |
| SEC-02 | Flight modifica `__AbilityEquipped_Flight` y llama Save, pero Bridge Save solo captura flags de tutorial/mundo/update log. Join fuerza grant+equip para cualquier dueño del pass. | Unequip no sobrevive proyección/reingreso; persisitir equip y respetar selección guardada al verificar un pass ya poseído. |
| SEC-03 | `AdminAbuseServer` crea siempre otro `AdminAbuseRemote` y su `WipeData` borra claves inventadas de **AdminAbuseCodes_v1**, luego informa borrado exitoso. | Eventos ambiguos si existe remote y falso éxito destructivo. Reusar remote; no fingir ni implementar un borrado de cuentas sin workflow validado. |
| SEC-04 | `AdminPanelService` y `GlobalAnnouncementService` retornan el texto original cuando falla TextService; AdminAbuse Broadcast no filtra y concatena RichText. | Texto sin filtrar y markup arbitrario para todos; fallar cerrado cuando filtro falla, escapar RichText, limitar tamaño y frecuencia. |
| SEC-05 | AdminPanel/AdminAbuse `tonumber`+`math.clamp` no rechazan NaN; múltiples remotes sin cooldown antes de yields (`GetRankInGroup`, DataStore, filtrado, efectos). | Un admin con UI rota puede contaminar atributos/efectos o saturar servicios; validación finita de payload y rate limit antes de operaciones costosas. Esto no representa bypass del allowlist: los handlers sí verifican UserId en servidor. |
| SEC-06 | AdminConfetti deja piezas sin anclar con network ownership automático y `ProximityPrompt.Triggered` concede premio sin validar distancia/vida/estado. | Un cliente puede mover piezas de las que posee física para recoger boosts. Forzar servidor como network owner y comprobar distancia contra la pieza en servidor antes de conceder. |
| SEC-07 | `/give <player> <stat> <amount>` en AdminCommands lee monto en `parts[3]`, que contiene el stat; AdminGiveCommands usa StarterGui:SetCore desde servidor y target vacío coincide con primer jugador. | Comando legítimo falla o elige objetivo incorrecto; parser exacto, rechazar objetivo vacío y feedback por remote ya existente. |
| SEC-08 | FlightAbilityState y AbilityShopAction carecen de límites; acciones equip esperan hasta 12 s por request; el heartbeat de stamina vive en Bootstrap. | Limitar peticiones antes de espera/consulta, exigir DataLoaded, propiedad real y personaje vivo para estado de vuelo. |

Coordinación: root edita ProfileReducers/StatsProjection, persistencia y economía; agente gameplay revisa MovementGuard, stages, pads y World2StageTeleport. Hallazgos fuera de ownership se remiten sin editar.

Pruebas pendientes: mocks que ejecutan handlers/funcciones reales y regresión de compra/equip con Actor, compilación Luau de archivos modificados. Límite: no hay sesión real de Roblox/Studio, perfiles publicados o validación de mando en este entorno.

## Retoma 2026-09-13 — evidencia adicional previa a corrección

| ID | Evidencia inspeccionada | Corrección prevista |
|---|---|---|
| SEC-09 | ownsFlight acepta temporal; buyWithWins y grantAndEquipFlight lo usan como propiedad permanente. isFlightEquipped retorna true cuando hay tiempo activo aunque usuario desequipe. | Distinguir licencia permanente de acceso temporal y respetar marcador. Root coordina reducer/proyección. |
| SEC-10 | AdminPanel applyPassToggle y UnlockWorld2 escriben atributos antes de confirmar Commit; stats y Geko ignoran resultado. Geko realiza grants separados y reporta éxito aunque falle. resolveTargets usa admin como fallback ante nombres inválidos. | Recompensa en un commit, feedback confirmado, rechazar targets desconocidos. |
| SEC-11 | AdminAbuse publica evento y ejecuta localmente, Subscribe no omite eco propio. AdminPanel force-code dedup solo 3s por presencia de sender. Redelivery puede repetir regalos. | Identidad de evento + origen y dedup acotado al recibir; validar payload. |
| SEC-12 | AdminAbuse CreateCode usa SetAsync sobrescribiendo, acepta stat arbitrario y montos no finitos; objetos como codeName rompen lower. | Definición immutable validada y error real; canje coordinado con root. |
| SEC-13 | AdminCommands busca TextChannel solo entre hijos directos de TextChatService y escucha MessageReceived; AdminGive espera globals indefinidamente. | TextChatCommand.Triggered con alias exactos, resolver APIs al ejecutar; rate limit compartido contra doble ejecución legado. |

## Revisión de anuncios, antes de editar

SEC-14: GlobalAnnouncementService conserva el texto original cuando falla cualquiera de las dos llamadas de filtrado (a diferencia de AdminPanelService, ya corregido). Su suscripción acepta cualquier tabla con Message y solo evita duplicados durante 3 segundos si el remitente está en el servidor. Se corregirá para fallar cerrado, validar contenido/timestamp e identificar cada evento, omitiendo eco propio y reentregas. Se limitarán peticiones antes de consultas de autorización que pueden ceder ejecución. Prueba prevista: filtro caído sin envío, evento repetido una vez, payload inválido/viejo descartado y anuncio válido entregado.

SEC-15: StarterGui/Messages/MessageHandler interpola remitente y mensaje sin escapar dentro de RichText. El filtro de texto no es un escape de markup: etiquetas podrían alterar formato/tamaño del anuncio. Se escaparán ambos campos al renderizar conservando el encabezado en negrita.

SEC-14/15 implementados en ambos mundos. `audit/test_announcements.luau` ejecuta el script real con filtro caído, publicación filtrada, eco propio, duplicados, payloads inválidos y viejos; también prueba el escape de markup del cliente. Pasó en ambos. Los binarios se reconstruyeron y todos sus scripts compilan, conservando mapas y propiedades. Falta validar render y MessagingService entre servidores reales.

SEC-06, revisión actual: las piezas ya usan SetNetworkOwner(nil) y el prompt comprueba DataLoaded, vida, distancia finita y un flag Claimed antes del premio. Falta una prueba funcional de ese handler.

PERF-16, antes de editar: fireConfetti limita cada llamada a 120 piezas pero no limita el total vivo; llamadas repetidas acumulan piezas durante hasta 120 segundos. Cada pieza agrega su propio Heartbeat que cambia color/CFrame cada frame. Se limitará el total simultáneo a 240 y se compartirá una actualización a 10 Hz, retirando las conexiones por pieza. Se verificará rechazo de claims remotos y duplicados y el límite bajo invocaciones repetidas.

SEC-06 y PERF-16: test_confetti.luau ejecuta las funciones reales de ambos mundos y verifica 10 activaciones consecutivas con máximo 240 piezas, una conexión Heartbeat, throttling a 10 Hz, propiedad física del servidor, rechazo por distancia/muerte/datos no cargados, un premio por pieza y capacidad liberada al expirar. Pasó en ambos mundos. No es una medición de FPS ni una validación de física en Roblox.
