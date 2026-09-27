# Reparación de tacos y tutorial

Se actualizaron los tres archivos de la raíz del proyecto y se guardó una copia de cada resultado en esta carpeta. Los originales y las fuentes anteriores están en `backup/`.

## Cambios

- Corregido el error de alcance de `playMusic`, `boost` y `announce`: el evento se detenía al intentar llamar una función global inexistente antes de establecer su estado activo.
- El taco 3D y `StruckVFX` se extrajeron de `Outdated/V40 SAB by FaypleStudios.rbxl`. Se conservan en `src/ui/TacoEventAssets.rbxm` y están incluidos en ReplicatedStorage.Shared de los tres mundos. No se importaron scripts del juego de referencia.
- Lluvia 3D con límite de objetos para móvil, impactos contra suelo sólido, sonido posicional, VFX originales y onda de impacto. Los rayos ignoran personajes y partes sin colisión. No se eliminan tacos por estar debajo de Y = -50.
- Temblor de cámara breve y proporcional a la distancia, con amortiguación. Se retira el desplazamiento anterior para evitar acumulación.
- Tacos sobre las cabezas creados en el servidor, visibles para todos, con flotación y giro local. Se conserva la limpieza al terminar el evento o salir de la cinta de tacos.
- El mesh original se normaliza por tamaño. Hay geometría alternativa si el cliente informa un fallo al cargar los recursos.
- Se quitó la reproducción duplicada de música y la lluvia de imágenes sobre la interfaz.
- Tutorial con tres indicaciones cortas, colocación adaptable al espacio disponible y coordenadas relativas al área segura. El resaltado se recorta dentro de la lista de auras.
- Los botones reales reciben los clics. Se retiró la capa que interceptaba los controles, el falso `Activate()`, el cierre automático a los 10 segundos y las compras de aura/trail disparadas por la celebración.
- La finalización depende de que el aura aparezca equipada en el estado replicado. Cerrar el backpack permite volver al primer paso; omitir o reaparecer limpia la guía.
- Las tarjetas de ayuda de Backpack y Evolve conservan su escala móvil al abrirse.

## Verificación realizada

- Compilación Luau de las 9 fuentes modificadas/nuevas.
- 42 pruebas de posición en resoluciones de escritorio, tablet, móvil horizontal y vertical.
- Ejecución de las funciones reales de inicio/parada del evento con servicios simulados: efectos, boosts, reinicio, temporizador anterior, expiración y parada repetida.
- Construcción del taco original: clonación, tamaño, unión y colisiones desactivadas.
- Ejecución del bucle real de lluvia con raycast simulado a alturas 0, -120 y 500: impactos y eliminación del taco.
- Reapertura de los tres RBXL generados y comparación exacta de las fuentes integradas y del número de instancias.

Estas pruebas son locales con Lune. No se realizó una sesión Play en Roblox Studio ni se publicaron los juegos. La disponibilidad en vivo de audio/texturas y la apariencia final deben comprobarse en Studio.

## Prueba en Studio

1. Abrir el RBXL actualizado desde disco e iniciar Play. Una sesión que ya estaba abierta debe recargar el archivo para tomar los cambios.
2. Desde el panel admin activar Raining Tacos, o usar `/tacos` con una cuenta autorizada. Revisar lluvia, impacto, sonido y cámara. Reiniciar el evento antes de que termine y comprobar que no lo detiene el temporizador anterior.
3. Con dos jugadores, verificar los tacos sobre ambas cabezas, reaparecer y esperar la finalización.
4. En World1, con un perfil nuevo, completar la introducción y seguir Backpack → Auras → comprar/equipar Orange Aura. Probar en emulador móvil, rotar la pantalla, cerrar/reabrir el backpack y omitir la guía.
5. Abrir las ayudas de Backpack y Evolve en móvil horizontal y verificar que los botones de cierre permanezcan accesibles.

Pruebas reproducibles: `audit/test_tacos_tutorial_repair.luau`.
Integración reproducible: `audit/build_tacos_tutorial_repair.luau`.
