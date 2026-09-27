# Arco de The Flash: importar el kit en Studio

El arco de carrera (arco rojo, franja dorada, medallón con el rayo y el pad de anillos) ahora son
**11 mallas de Blender**, lisas y biseladas, en lugar de piezas. Se importan **una sola vez**; el
montaje las coloca en los tres mundos, les pone color y material y sustituye el arco de piezas.

Vista previa: `preview/00_compare_front.png` (la referencia a la izquierda, el arco a la derecha) y
`01`–`05` (frente, lobby con Flash en su sitio, 3/4, medallón y espalda).

## Pasos

1. En Studio, **File > Import 3D** y elige
   **`C:\Users\Public\FlashGateKit\FlashGateKit.fbx`** (es la misma que `design/race/flashgate/FlashGateKit.fbx`;
   usa la de `C:\Users\Public`, cuya ruta no tiene acentos).
2. Ajustes del importador:
   - **Scale Unit: Stud**
   - **Merge Meshes: DESACTIVADO** (cada pieza, su MeshPart)
   - **Upload to Roblox: ACTIVADO**
   - World Forward / Up: los de por defecto. Si el kit sale girado, no pasa nada: el montaje lo endereza.
3. Comprueba que hay **11 MeshParts**: `FG_ArchRed`, `FG_LegL`, `FG_LegR`, `FG_BandGold`,
   `FG_MedallionRim`, `FG_MedallionFace`, `FG_BoltEdge`, `FG_Bolt`, `FG_PadDisc`, `FG_PadRingCyan` y
   `FG_PadRingGold`.
   - **Prueba de escala:** `FG_PadDisc.Size` ≈ **(13.2, 0.22, 13.2)** y `FG_ArchRed.Size` ≈ **(23.5, 9.3, 3.0)**.
     Si sale 100 veces más grande o más pequeño, borra y repite con la otra unidad.
   - Salen grises: es normal (no llevan textura; el montaje las pinta).
4. Selecciona las 11 y pon **RenderFidelity = Precise** (sin facetas de lejos).
   **CollisionFidelity = Hull** en `FG_LegL` y `FG_LegR` (son las únicas que chocan) y **Box** en el resto.
5. No cambies los nombres. Clic derecho en el Model importado, **Save to File…** y guárdalo como
   **`design/race/flashgate/FlashGateKit.rbxm`**.
6. Avísanos. El siguiente montaje (`lune run audit/build_update4.luau`) cambia solo nuestro arco de
   piezas (v2) por el de mallas (v3) en los tres mundos. Un `RaceGate` hecho por ti (sin la marca
   `U4Asset`) no se toca.

**Si el FBX falla:** prueba las piezas sueltas de `C:\Users\Public\FlashGateKit\fbx\` y, si alguna
falla, su `.obj` de `design/race/flashgate/obj/`. Pásanos el texto del error (ventana Import 3D u Output).

## Datos

- 23.140 triángulos en total; ninguna malla pasa de 5.300 (límite de Roblox: 20.000 y 10.000 vértices).
- Mismo tamaño que el arco de piezas: 25 de ancho, 13,5 de alto, hueco de 18,6.
- Todas las piezas tienen el pivote en el suelo, en el centro del arco. Colores, materiales y colisión
  salen de `flashgate_manifest.json`.
- Regenerar: `blender.exe -b --factory-startup --python audit/flash_gate_bpy.py`
