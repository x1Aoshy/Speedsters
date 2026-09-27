# ASMR: red, efectos y ciclo de streaming

Hallazgos verificados antes del cambio (13 septiembre 2026):
- World2 contiene tres modelos con el mismo nombre ASMR; deben recorrerse todas las instancias. 9 generadores Bubble, 10 Keyboard, 6 Butter.
- Cada generador fabrica 30 piezas no sólidas (570 total) en servidor y les conecta Touched/TouchEnded; los tweens de presionado son cosméticos y replican cambios innecesarios.
- Cada generador crea 8 Parts para sonidos y omite CanCollide=false: hasta 152 colisiones invisibles junto a piezas presionadas.
- Las seis Butter son sólidas. No conviene eliminarlas ni convertir toda su física al cliente: conservar el cuerpo anclado y animar una copia visual local.
- TouchCount/Touched no limita por parte única y puede quedar presionado tras muerte/teleport. Butter crea conexiones Heartbeat independientes.

Cambio propuesto: desactivar exclusivamente esas 25 fuentes mediante migración por instancia, conservar originales como respaldo, identificar tipo por atributo y usar un único controlador cliente con descubrimiento/retirada de streaming, activación por distancia y detección visual local acotada. Plantillas ancladas, sin colisiones y ocultas; superficies originales quedan como respaldo. No modificar los pads ni las trampas mortales. Sin remotes ni replicación continua de estos efectos.

Las frecuencias/paquetes/ping del informe Gemini son hipótesis, no mediciones: Roblox agrupa/optimiza replicación; no se puede afirmar que 46 partes por sí solas saturen un servidor. Aquí sólo se valida reducción estructural de trabajo replicado. Falta Studio con streaming real y MicroProfiler.

Referencias: https://create.roblox.com/docs/scripting/locations ; https://devforum.roblox.com/t/live-script-runcontext/1938784/1 . Se elige LocalScript en StarterPlayerScripts con ciclo explícito, evitando reinicios de generadores Workspace al entrar/salir del streaming.
