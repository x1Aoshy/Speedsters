# Loading screen: icono y rayos

Los tres `.rbxl` de este directorio y los archivos de la raíz incluyen la nueva pantalla de carga. Usa el icono `rbxassetid://92044769924002`, tres rayos animados, cinco tips cortos sobre el juego y un fondo azul marino con estelas discretas. Reemplaza el splash anterior `138327240966588`, la barra dorada y el porcentaje simulado.

La precarga del icono ocurre en segundo plano. La pantalla espera la carga del place y la aparición del personaje con límites de tiempo, muestra un estado de conexión lenta si tarda, y se desvanece al terminar. Mantiene un tiempo mínimo de 1,25 segundos para evitar parpadeo. No hay capturas de los tres mundos preparadas como assets locales; usar una presentación de fotos requeriría crearlas y subirlas, además de añadir tres descargas al inicio.

Pasó `audit/test_loading_screen_redesign.luau` en World 1, World 2 y World 3. También pasaron las regresiones de rueda, AFK x5 y árboles World 2. No se hizo una revisión visual interactiva en Roblox Studio ni se publicaron estos places. Backup: `output/Backup_LoadingScreen_20260920_125927`.
