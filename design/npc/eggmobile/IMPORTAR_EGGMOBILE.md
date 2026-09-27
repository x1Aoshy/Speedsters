# Egg Mobile corregido — faro centrado

Importa `C:/Users/Public/EggMobileKit/EggMobileKit.fbx` en Studio con **Scale Unit: Stud**, **Merge Meshes: OFF** y los ejes por defecto del flujo existente. Deben aparecer **19 mallas EM_***.

La medida nueva de **EM_HullWhite** es aproximadamente **7.8096 × 3.4179 × 7.8097 studs**. La indicación antigua de 2.44 studs de alto ya no corresponde a este casco. No reescales las piezas individualmente.

Guarda el resultado importado como `Update2/design/npc/EggMobileKit.rbxm`. El montaje debe usar el manifiesto nuevo `design/npc/eggmobile/eggmobile_manifest.json`, incluido en el mismo paquete. No mezcles el FBX corregido con el manifiesto anterior.

El `.blend` editable incluye la microtextura de rugosidad empaquetada. Este FBX usa los colores y materiales originales por pieza; los nodos de rugosidad de Blender no se transfieren automáticamente a Roblox.

Se verificaron la reimportación del FBX, sus 19 piezas, el centro del único faro y los ocho controles existentes de montaje, animaciones y hover. Las pruebas de los tres mundos fueron de lectura y montaje en memoria: todavía no se han subido los assets ni guardado el kit importado en Studio.

Consulta `GUIA_PARA_CLAUDE.md` para usar la conexión MCP, editar mediante bpy y regenerar el kit sin perder esta corrección.
