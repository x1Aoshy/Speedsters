# Correcciones de los logs de World 2

Los tres `.rbxl` de este directorio también están en la raíz del workspace. Conservan el developer product AFK Get x5 (`3713742489`, 19 R$) y la rueda persistente. Todavía no están publicados en Roblox.

- `World2TreeSlammers`: el render llamaba `nearestTreeDistance` antes de que Luau la declarara local; por eso fallaba en cada `RenderStepped` y no alcanzaba la detección de contacto. La declaración ahora está en el alcance correcto. La prueba ejecuta el cliente con un `Workspace` vacío y dispara un frame.
- `HudErgonomics`: durante el arranque, un viewport de 1 px podía hacer que el máximo de `math.clamp` fuese menor que el mínimo y romper el layout de Heat Vision. El rango ahora siempre es válido.
- El letrero Golden de World 2 decía x3 aunque el servidor otorgaba +10 Speed; ahora muestra x10.
- Dark Zonic no tiene el antiguo dummy `Workspace.DarkZonic` en ninguno de los tres places ni en OG. Los dueños ahora pueden equipar la máscara y ropa del catálogo como respaldo. El stand de venta exacto sigue sin modelo fuente.

Pasaron `audit/test_tree_slam_motion.luau`, `audit/test_hud_ergonomics_startup.luau`, `audit/test_heat_vision.luau`, `audit/test_ui_ergonomics.luau`, `audit/test_treadmill_loop_regression.luau`, `audit/test_dark_zonic_catalog_fallback.luau` y `audit/test_world3_cosmetics.luau`. `audit/test_new_skins.luau` conserva una aserción anterior sobre la configuración World 2 y falla sin relación con estos cambios. Falta una prueba interactiva en Studio y en una versión publicada.

El log también muestra permisos denegados para la animación `137493859009439` y los sonidos `71911088386355` y `77131850715240`. Compartir acceso con la experiencia o sustituirlos por assets autorizados requiere una acción en Creator Hub. Los seis treadmills de World 2 sí se registraron; los avisos de nombres genéricos faltantes corresponden a modelos de World 1.

Backup previo: `output/Backup_World2_RuntimeLogs_20260920_124607`.
