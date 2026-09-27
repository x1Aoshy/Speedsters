# Admin, Quests, AFK y GlassShatter — 14 septiembre 2026

## Instalación manual en Roblox Studio

Aplicar los 16 archivos juntos en World 1 y World 2; los paneles dependen del módulo nuevo y las recompensas de los cambios de persistencia.
1. Abre el lugar y detén Play antes de editar.
2. Reemplaza TODO el código de cada script existente en la ruta indicada. Mantén su nombre y tipo; no agregues duplicados.
3. Crea el ModuleScript nuevo `ReplicatedStorage > Shared > GamePanelStyle` y pega su archivo.
4. Guarda y prueba cada mundo. Los archivos World1NewestStable.rbxl y World2NewestStable.rbxl ya incluyen todo.

| Ruta en Explorer | Tipo | Acción |
|---|---|---|
| ReplicatedStorage > Shared > GamePanelStyle | ModuleScript | Crear |
| ReplicatedStorage > Shared > GlassShatter | ModuleScript | Reemplazar código |
| ServerScriptService > Admin > AdminPanelService | Script | Reemplazar código |
| ServerScriptService > Admin > ChatBoostCommands | Script | Reemplazar código |
| ServerScriptService > Services > Data > ProfileCodec | ModuleScript | Reemplazar código |
| ServerScriptService > Services > Data > ProfileReducers | ModuleScript | Reemplazar código |
| ServerScriptService > Services > Data > SessionActor | ModuleScript | Reemplazar código |
| ServerScriptService > Services > RewardPadClaims | ModuleScript | Reemplazar código |
| ServerScriptService > Services > Stats > StatsProjection | ModuleScript | Reemplazar código |
| ServerScriptService > Social > AfkRewardsService | Script | Reemplazar código |
| ServerScriptService > Social > QuestService | Script | Reemplazar código |
| StarterPlayer > StarterPlayerScripts > Movement > CtrlShiftLock | LocalScript | Reemplazar código |
| StarterPlayer > StarterPlayerScripts > Movement > InstantMovementController | LocalScript | Reemplazar código |
| StarterPlayer > StarterPlayerScripts > UI > AdminPanelController | LocalScript | Reemplazar código |
| StarterPlayer > StarterPlayerScripts > UI > AfkRewardsController | LocalScript | Reemplazar código |
| StarterPlayer > StarterPlayerScripts > UI > QuestController | LocalScript | Reemplazar código |

## Cambios

- Admin: pestañas, fondo de Settings, selección de jugador, controles sin recortes, +1 Rebirth correcto y estado de permisos del servidor.
- Quests: progreso persistente, etapas reales, carreras completas en vez de cantidad de monedas Wins, recompensas y reclamos atómicos, reinicio diario/semanal y tickets persistentes.
- AFK: cuenta únicamente el tiempo offline (10 minutos–24 horas); entrega una sola recompensa, valida VIP y conserva la misma operación al reintentar un guardado. /afk de admin prepara una recompensa real de prueba.
- GlassShatter: cristales blancos siguiendo la cámara y shake breve; se activa después de 0.65 segundos de sprint en el suelo y en movimiento. /shatter mantiene la vista previa. Shift queda para sprint y Ctrl para bloqueo de cámara.

## Verificación realizada

- Compilación de 306 scripts canónicos; construcción estructural de ambos lugares.
- Pruebas con el actor real de persistencia: progreso, reclamos duplicados, recompensas, tickets, pociones, reconexión y reinicio diario.
- Controladores y servicios ejecutados en un entorno de pruebas con APIs de Roblox simuladas: eventos de UI, AFK, quests, cámara y tamaños de pantalla.
- Pruebas del bloque real de sprint: caminar, quieto y aire no disparan el efecto; una activación por sprint.
- Regresión de persistencia de ambos mundos: migraciones, sesiones, regalos, compras y recibos.

No se ejecutó un playtest ni revisión visual dentro de Roblox Studio desde esta sesión.

## Prueba final en Studio

1. Abre Admin con F2 o el icono. Cambia de pestaña y selecciona tu jugador; comprueba +1 Rebirth y las acciones.
2. Corre/usa treadmill y mira la barra de la quest; completa y reclama. Reconecta para verificar progreso y estado reclamado.
3. Como admin usa /afk 60: comprueba que el panel permite reclamar y que no paga otra vez al repetir clic.
4. Comprueba AFK real dejando una sesión al menos 10 minutos y reconectando.
5. Camina sin sprint: sin shatter. Corre con sprint: shatter blanco y shake. Prueba /shatter para comparar.
6. Revisa teléfono vertical/horizontal y mando en Studio; los controles se han comprobado con simulación, no con el renderizador real.
