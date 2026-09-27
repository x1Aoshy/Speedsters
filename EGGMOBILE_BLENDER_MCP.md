# Egg Mobile: continuar con Blender MCP y bpy

Estado: revisión del 26 de septiembre de 2026. El modelo fue editado mediante llamadas MCP reales a Blender 4.5.3, con geometría producida mediante bpy. La escena y el FBX se revisaron visualmente desde frente, tres cuartos y atrás.

## La última indicación del dueño tiene prioridad

- **UN solo faro amarillo, circular y CENTRADO al frente: X = 0.** No devolverlo al costado aunque lo muestre una referencia antigua.
- Bisel exterior gris octagonal, abertura interior circular. Conservar los remates metálicos y pinchos delanteros.
- La cubierta amarilla sobre el escape trasero es otra pieza visual: conservarla.
- Conservar casco blanco brillante, base negra redondeada, cristal transparente centrado, asiento azul, logo rojo, flecha y franja de peligro.
- El personaje de las imágenes antiguas era un sustituto. No exportarlo junto al vehículo. El juego utiliza el Eggman R6 del dueño.

## Archivos de trabajo en Update2

- `design/npc/eggmobile/EggMobile_Corrected.blend`: escena editable con materiales, microtextura empaquetada y cámaras.
- `design/npc/eggmobile/EggMobileKit.fbx`: 19 mallas para Studio.
- `design/npc/eggmobile/eggmobile_manifest.json`: posiciones, dimensiones y materiales actuales.
- `audit/egg_mobile_bpy.py`: generador actualizado, incluida la lámpara centrada.
- `audit/egg_mobile_finish.py`: materiales de presentación y renders reproducibles.
- `design/npc/eggmobile/preview/front.png`, `rear.png`, `centered_lamp.png`: vistas de esta revisión. Otros renders antiguos de la carpeta NO documentan esta revisión.
- `design/npc/eggmobile_backup_before_centered_lamp_20260926/`: respaldo de la versión anterior.
- `C:/Users/Public/EggMobileKit/`: copia de importación con ruta ASCII.

## Conexión MCP instalada y comprobada

Proveedor: [MCP for Blender](https://github.com/ahujasid/mcp-for-blender), servidor Python `mcp-for-blender` 2.1.0, addon instalado y habilitado. Usa localhost:9876. Telemetría desactivada. Codex ya tiene una entrada `mcp_servers.blender`; un chat ya abierto puede necesitar recargar herramientas para verla. La comunicación de esta revisión se verificó mediante un cliente MCP stdio independiente.

Para Claude, registra este servidor stdio con la configuración equivalente de su cliente:

```json
{
  "mcpServers": {
    "blender": {
      "command": "C:/Users/Aoshy´/Documents/Codex/2026-09-26/i-passed-it-on-just-one/work/mcp-env/Scripts/mcp-for-blender.exe",
      "env": {
        "BLENDER_HOST": "127.0.0.1",
        "BLENDER_PORT": "9876",
        "DISABLE_TELEMETRY": "true"
      }
    }
  }
}
```

No borres ese entorno de Python mientras la configuración lo utilice. Si se mueve, instala `mcp-for-blender==2.1.0` en otro entorno persistente y cambia la ruta del ejecutable.

Abre Blender. El addon habilitado inicia su conexión automáticamente; si no aparece, abre el panel lateral N → MCP for Blender → Connect. No abras dos instancias que compitan por el mismo puerto. Primero llama `get_scene_info`; después utiliza `execute_blender_code` para cambios bpy pequeños. El campo `user_prompt`, cuando lo pida la herramienta, debe contener la petición real del dueño. No habilites servicios externos de generación para este modelo.

```python
# Dentro de execute_blender_code. Inspeccionar antes de modificar.
import bpy
print(bpy.data.filepath)
print([(o.name, tuple(o.dimensions)) for o in bpy.data.objects if o.name.startswith('EM_')])
```

Para renders largos, programa una función con `bpy.app.timers.register(funcion, first_interval=1)` y devuelve el control a MCP; consulta después el archivo generado. Esto evita agotar el tiempo de la llamada mientras Blender renderiza. Si tienes que usar la vía sin interfaz, usa el generador directamente; no simules una conexión MCP cuando no esté disponible.

## Procedimiento de edición

1. Abre el `.blend` corregido; guarda un respaldo antes de cambios grandes.
2. Lee el manifiesto y las referencias, distinguiendo los documentos históricos de las últimas instrucciones del dueño.
3. Mantén los 19 nombres `EM_*`. Varias piezas visuales están agrupadas por material: **no traslades todo `EM_Metal` para mover sólo un bisel**, porque también moverías tablero, marco y escape. Cambia la geometría correspondiente en el generador o selecciona sus islas de vértices.
4. Para cambios repetibles, modifica el generador y usa MCP/bpy para inspeccionar el resultado. Cambiar sólo la escena deja el próximo regenerado desactualizado.
5. Haz un render frontal que demuestre que el faro está en X=0, una vista lateral para silueta y una trasera para tablero, asiento y escape. Abre e inspecciona los PNG; que el render termine no demuestra que el diseño esté bien.
6. Exporta solamente la colección EggMobileKit, nunca suelo, luces, cámaras o un personaje de muestra.
7. Reimporta el FBX en otra escena o proceso y compara nombres, centros y tamaños con el manifiesto. Conserva pivotes comunes y transformaciones identidad. Actualiza el manifiesto en el mismo pase.

## Contrato con el juego

Ejes de nave/Roblox: X derecha, Y arriba, -Z frente. Blender: `(X, -Z, Y)`. Una unidad equivale a un stud en la importación acordada.

Los anclajes existentes se conservaron: asiento `(0, 5.55, 0.45)`, palancas `(±1.7, 5.12, -0.63)`, ventilador `(0, 3.3, 3.87)`, borde superior `5.44`, suelo interior `4.9`. `kitVersion` sigue en 2 porque el contrato de montaje conserva sus nombres y roles; el campo `revision` identifica este diseño.

**El casco blanco ya NO mide 7.81 × 2.44 × 7.81.** Su falda ahora baja sobre la esfera, y mide aproximadamente **7.8096 × 3.4179 × 7.8097 studs**. No fuerces el tamaño antiguo: deformaría el modelo. Lee siempre `size` y `bboxCenterOffset` del manifiesto nuevo.

Validación de exportación: 19 piezas, 35 120 triángulos totales, sin piezas faltantes o añadidas, error máximo de reimportación inferior a 0.00005 studs. Una sola isla de geometría en EM_Lamp, centro X=0, diámetro aproximado 1.38 studs.

Para regenerar desde la raíz de Update2:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 4.5/blender.exe' -b --factory-startup --python audit/egg_mobile_bpy.py
lune run audit/test_u4_egg_mobile.luau
```

La exportación guarda primero una fuente temporal con ruta ASCII: Blender incluye el nombre del `.blend` en el FBX; exportar directamente desde una ruta con `´` introducía caracteres problemáticos en sus metadatos.

## Materiales y textura generada

El kit original no contenía imágenes de textura; utilizaba colores por malla. Esos colores se conservaron. La imagen nueva `textures/Enamel_Microdetail.png` sólo modula la rugosidad en el `.blend`, entre 0.10 y 0.24 para pintura/metal y entre 0.23 y 0.37 para el asiento. Está empaquetada en el archivo, sin cambiar logos ni colores.

**Los nodos de rugosidad de Blender no se transfieren automáticamente a Roblox mediante este FBX.** El FBX conserva el contrato original de materiales por color. Para incorporar microtextura al juego haría falta hornear mapas a UV, subirlos y configurar SurfaceAppearance. No afirmar que esa subida o integración ya ocurrió. Cristal y emisiones dependen también del material y la iluminación de Studio.

Se utilizó la herramienta integrada de generación de imágenes; no se seleccionó un modelo llamado GPT 2.5 Image. Prompt usado:

> Create a square seamless grayscale PBR roughness texture for clean painted enamel and finely machined metal on a stylized Sonic Egg Mobile prop. This is a raw texture map, not a render, no objects, no lighting, no shadows, no gradients, no borders, no text. Full frame uniform neutral medium gray with extremely fine subtle isotropic micrograin and very sparse hairline manufacturing scratches, low contrast. Seamless tiling in both directions. Mostly immaculate polished finish, no rust, no dirt, no panels. 1024x1024 texture.

## Importación pendiente en Studio

Importar `C:/Users/Public/EggMobileKit/EggMobileKit.fbx` con Scale Unit Stud, Merge Meshes OFF, los ejes acordados y las opciones de subida del proyecto. Comprobar 19 mallas y los tamaños nuevos. Guardar el kit importado como `design/npc/EggMobileKit.rbxm` y usar el manifiesto nuevo en el montaje. Esta revisión no subió assets a Roblox ni reconstruyó los tres mundos.

Documentación de conexión: [MCP for Blender](https://github.com/ahujasid/mcp-for-blender) y [MCP en Codex](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).
