# Get x5 AFK: producto activado

Los tres places de este directorio y los archivos `.rbxl` de la raíz incluyen `Config.AfkZone.ClaimX5.ProductId = 3713742489` y un precio de referencia de 19 Robux. El precio que cobra Roblox lo determina el developer product en Creator Hub; la interfaz consulta su precio vivo y usa 19 como respaldo.

El botón **Get x5** para jugadores sin VIP abre este developer product. El recibo entrega el reclamo x5 una vez por compra, sin duplicarlo en reintentos; VIP conserva el x5 gratuito. El ID no coincide con ningún otro producto configurado en `src`.

Pasaron las pruebas `audit/test_afk_offline_x5.luau`, `audit/test_afk_zone.luau`, `audit/test_quests_afk_persistence.luau` y `audit/test_spinwheel_streaming.luau`. La compra real debe probarse en la experiencia publicada. Los places aún no se han publicado desde esta carpeta.

Las copias anteriores están en `output/Backup_AFK_GetX5_20260920_031936`.
