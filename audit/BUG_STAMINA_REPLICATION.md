# Estamina: publicación de atributos en ambos mundos

Estado inicial confirmado el 13/09/2026, antes de editar: Bootstrap llama a `syncBoostStaminaAttributes` desde Heartbeat (cinco SetAttribute) y vuelve a escribir los dos valores actuales al final. Drenaje y regeneración cambian los valores por frame. El informe de Gemini identifica correctamente este trabajo redundante; su equivalencia entre llamadas y paquetes UDP no está medida y no se adopta como dato de rendimiento.

La autoridad de estamina debe seguir calculándose cada Heartbeat. La corrección limitará la publicación periódica a 4 Hz, comparará cada atributo antes de escribir, y publicará inmediatamente el primer estado, cambios de máximo y llegada a cero/lleno. Se conservarán los cinco aliases: MainHUDController consume BoostStamina/BoostStaminaDisplayMax y los scripts Flight consumen TrueBoostStamina. PlayerStats legacy también los escribe, pero retorna al estar habilitado el backend modular.

Se expondrá un getter servidor de estamina actual para que Flight no autorice acciones con una muestra de UI atrasada. La integración de los consumidores Flight se coordina con el agente principal. No cambia el ritmo de drenaje, regeneración ni las condiciones de agotamiento.

Corrección integrada en los Bootstrap de World1 y World2: publicación con intervalo mínimo de 0,25 segundos, sin escrituras de máximos sin cambios, extremos y cambios de máximo inmediatos. La estamina sigue drenando/regenerándose por frame en la tabla del servidor. Cleanup también elimina la muestra de publicación. Los cinco aliases se conservan.

Los consumidores servidor Gameplay/World1FlightAbility y Gameplay/World2FlightAbility usan `_G.SpeedsterGetBoostStamina` para autorizar vuelo propulsado. El fallback al atributo existe solo para compatibilidad con el backend legacy; valores ausentes/no finitos fallan cerrados a cero. Los consumidores cliente siguen leyendo los mismos atributos, sin cambio de esquema.

Validación funcional aprobada: `lune run audit/test_stamina_replication.luau`. La prueba carga los bloques reales de estado, Heartbeat, cleanup y el handler remoto real de Flight de cada mundo. Simula diez segundos a 60 Hz, verifica drenaje exacto de 100 a 60 sin aumentar el ritmo, máximo 80 escrituras totales en los dos aliases variables, separación de muestras >= 0,25 s, cero escrituras de máximos inalterados y cero escrituras durante diez segundos de estamina llena. Comprueba cambio de máximo inmediato, agotamiento/llenado inmediato, parada de boost/vuelo y autorización de vuelo con muestra visual deliberadamente vieja tanto alta como baja. Ambos archivos completos también compilan.

Límite: estas pruebas miden llamadas al código con tiempo simulado; no equivalen a paquetes UDP, ancho de banda ni ping real dentro de Roblox. Queda medir el perfil de red y observar la barra en Studio. No se eliminan mecánicas ni aliases para justificar una mejora de rendimiento.
