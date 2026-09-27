# RaceArena recta — entrega de Astra

## Archivos

- `RaceArena.rbxm`: modelo `RaceArena`, listo para insertar en Workspace de los tres places conservando sus coordenadas.
- `RaceArena_Recta.rbxl`: place de revisión con el modelo, iluminación, cámara y spawn de prueba.
- `RaceArena_Recta.blend`: escena editable, texturas GPT Image empaquetadas, cámaras y viento mediante shape keys con drivers. Reproduce la línea de tiempo 1–240.
- `RacePalmWind.client.luau` / `RacePalmWind.rbxm`: un solo LocalScript para StarterPlayerScripts, fuera del modelo del mapa.
- `RaceArena_Visuals.fbx`: las mallas para importación y subida online.
- `Referencias/`: tres conceptos GPT Image. Los archivos `Render_*.png` son renders del modelo real.
- `Generar_Mapa_bpy.py`: generador reproducible; lee las cuatro imágenes de `textures/` y escribe en `Regenerated/`.

## Contrato aplicado

Centro X=6000. Origen de la superficie (6000,12000,0), avance hacia -Z. 2000 studs de carrera, 72 de ancho, preparación de Z=0 a +64 y frenada hasta Z=-2120. Salida y meta completamente planas en Y=12000. Cuatro elevaciones suaves, altura máxima 6 studs, pendiente máxima 3.083 grados.

520 BaseParts en RaceArena. Toda la decoración carece de colisión y de consulta de raycast. El suelo está en `TrackFloor`: Parts visibles (Transparency=0), CanCollide=true, CanQuery=true. Las mallas de textura quedan 0.05 studs encima, sin colisión/consulta. Las paredes invisibles están en X=6000±38.1. El raycast del perfil debe incluir `TrackFloor` o las partes colisionables del modelo, no depender del nombre de una sola pieza.

Objetos preservados: `Structure.StartGate`, `Structure.StopBar`, `Structure.StartGantry.Light1..Light5`, `RaceOrb`, `FinishGate.ConfettiSpot_1..4`. Los elementos auxiliares de salida/meta están ocultos excepto las cinco luces: no hay cartel START. StartGate viene sin colisión para la revisión; el controlador de carreras debe activar/desactivar la barrera según su estado.

5 Parts `SpeedPad` dentro de `SpeedPads`, en s=60,480,990,1450,1850; todos planos, orientación frontal -Z. `Boost=1.25`, `Seconds=1.5`, sin colisión. No incluyo un script de boost ni cambio la física/anti-cheat: el servidor de carreras que está preparando Opus debe aplicar y validar el efecto.

32 `SpikeTile_field_row_lane` en los campos s=300,750,1200,1650; segunda fila a +40. Huellas de 7 studs, carriles bloqueados exactamente como Update4Config. Los visuales siguen la altura del terreno. Sin scripts de daño adicionales.

22 palmeras, con tag `RacePalmWind`, atributos WindBase, WindCrown, WindKind, WindTree, WindPhase. El controlador de cliente limita a 6 árboles cercanos / 20 actualizaciones por segundo en dispositivos táctiles; en escritorio a 14 / 30. Las piezas de plantas tienen `RaceDecorLowPower` y el viento respeta piezas ocultas. No hay scripts de servidor por palmera.

No hay agua, cascadas, monedas, loops ni curvas horizontales. No he modificado RaceGate ni el código de las carreras de los tres worlds.

## Recursos: revisión local frente a publicación

**Las mallas/texturas aún no están subidas a Roblox.** El rbxm/rbxl usa `rbxasset://raceastra_straight_20260925/` y los recursos se encuentran en `Roblox_LocalAssets/`. Ya están instalados para la versión actual de Studio en este equipo. `Instalar_Recursos.ps1` reinstala la carpeta tras actualizar Studio o cambiar de equipo.

Antes de publicar los places para jugadores, importa `RaceArena_Visuals.fbx`, con escala en studs, sube los assets al propietario correcto y sustituye los recursos locales por IDs de Roblox. El FBX mantiene coordenadas locales: aplica desplazamiento `(6000,12000,0)` una sola vez al insertarlo. Las mallas tienen los mismos nombres que `RaceArena.Visuals`; conserva sus nombres, los tags/atributos de viento y las colisiones nativas. No sustituir TrackFloor, Walls, SpeedPads, Structure ni Spikes por colisiones de malla.

La validación entregada cubre estructura, nombres, coordenadas, límite de partes, archivos de malla, orientación de pads, sintaxis del controlador y deformación de Blender. **No es una prueba de juego en Studio ni de los tres places**; quedan las pruebas de integración, raycast del perfil y anti-cheat al conectar el servidor de Opus.

Texturas creadas con GPT Image integrado: atlas de tierra ocre, césped, acantilado marrón a cuadros y corteza; extraídas como cuatro mapas repetibles. No se usó CLI de generación de imágenes.
