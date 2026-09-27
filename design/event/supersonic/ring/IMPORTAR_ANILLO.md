# Evento Super Sonic vs Dr. Eggman: importar el ANILLO de oro en Studio

Cuando Dr. Eggman cae, suelta una lluvia de **anillos de oro** que los jugadores recogen. El anillo (como tu
referencia `reference/ring_reference.webp`: un toro redondo, liso y pulido) es ahora **1 malla de Blender**
(`EV_Ring`). Es un kit **aparte**: no toques `EventKit.rbxm` (sus 11 piezas ya están importadas y siguen igual).
Se importa **una sola vez**: el montaje lo pone en `ReplicatedStorage.SuperSonicEventAssets.Meshes.Ring` de los
tres mundos, dorado. Mientras no esté, el juego usa su anillo de respaldo.

Vista previa (`design/event/supersonic/ring/preview/`): `ring_closeup.png` (un anillo de cerca, oro pulido),
`rings_on_grass.png` (anillos sobre la hierba y cayendo, con un R6 para la escala), `ring_profile.png`
(de frente, de canto y cortado por la mitad) y `piece_EV_Ring.png`.

## Pasos

1. En Studio, **File > Import 3D** y elige **`C:\Users\Public\RingKit\RingKit.fbx`** (es la misma que
   `design/event/supersonic/ring/RingKit.fbx`; usa la de `C:\Users\Public`, cuya ruta no tiene acentos).
2. Ajustes del importador:
   - **Scale Unit: Stud**
   - **Merge Meshes: DESACTIVADO**
   - **Upload to Roblox: ACTIVADO**
   - World Forward / Up: los de por defecto. Si el anillo sale girado, no pasa nada: el montaje lo endereza.
3. Comprueba que hay **1 MeshPart** llamado **`EV_Ring`**.
   - Sale gris: es normal, el montaje lo pinta de oro.
   - **Prueba de escala:** `EV_Ring.Size` ≈ **(2.40, 2.40, 0.60)** (o **(0.60, 2.40, 2.40)**: X y Z pueden salir intercambiadas).
     Si sale 100 veces más grande o más pequeño, borra y repite con la otra unidad. Si sale **tumbado**
     (Y ≈ 0.60), repite la importación con World Forward / Up por defecto.
4. No cambies el nombre. Clic derecho en el Model importado (o en `EV_Ring`), **Save to File…** y guárdalo
   como **`RingKit.rbxm`** en la carpeta **`Update2`** (`Update2/RingKit.rbxm`; también vale
   `Update2/design/event/supersonic/ring/RingKit.rbxm`).
5. Avísanos. El siguiente montaje (`lune run audit/build_update4.luau`) pone el anillo en
   `SuperSonicEventAssets.Meshes.Ring` en los tres mundos.

**Si el FBX falla:** prueba `C:\Users\Public\RingKit\fbx\EV_Ring.fbx` y, si también falla,
`C:\Users\Public\RingKit\obj\EV_Ring.obj`. Pásanos el texto del error (ventana Import 3D u Output).

## Datos

- 3072 triángulos y 1536 vértices (límite de Roblox: 20.000 triángulos y 10.000 vértices por malla).
- 1 unidad = 1 stud. Diámetro exterior **2.40**, agujero **1.20**, tubo **0.60** (redondo, liso, sin facetas).
  De pie, con el agujero mirando a ±Z; el pivote en su centro.
- Color oro RGB (255, 196, 30), **SmoothPlastic** con Reflectance **0.35** (oro pulido; el material Metal de Roblox trae una textura
  cepillada), sin sombra, RenderFidelity Automatic. Salen de `ring_manifest.json`.
- Regenerar: `blender.exe -b --factory-startup --python audit/ring_kit_bpy.py`
