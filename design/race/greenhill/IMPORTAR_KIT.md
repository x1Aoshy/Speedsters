# Green Hill: importar el kit en Studio

El kit sustituye a la decoración de Astra (palmeras, arbustos, mesas y pads visuales) por **23 piezas
detalladas** que se importan **una sola vez** y se colocan muchas veces desde `layout.json`.

> **Kit congelado.** `GreenHillKit.fbx` es el archivo que ya importaste bien en Studio. Sus 23 piezas
> (nombres, tamaños, pivotes y geometría), `kit_manifest.json` y `layout.json` no cambian: el montaje usa
> esos tres archivos juntos. Los archivos de `fbx/`, `obj/` y `GreenHillKit_all.fbx` son solo de
> **reserva**.

## Qué hay en esta carpeta

| Archivo | Para qué sirve |
|---|---|
| `GreenHillKit.fbx` | **El kit oficial.** Las 23 piezas `Kit_<Nombre>` con la textura incrustada |
| `textures/GreenHillAtlas.png` | La única textura del kit (1024x1024) |
| `layout.json` | 1.390 colocaciones: 365 siempre visibles y 1.025 `lowPower` |
| `kit_manifest.json` | Tamaño, triángulos, desplazamiento del centro y color de respaldo de cada pieza |
| `GreenHillKit_all.fbx` | Reserva: las 23 piezas en un FBX "import-safe" |
| `fbx/Kit_<Nombre>.fbx` | Reserva: un FBX por pieza (23 archivos) |
| `obj/Kit_<Nombre>.obj` + `.mtl` | Reserva: un OBJ por pieza, por si el FBX falla |
| `GreenHillAtlas.png`, `fbx/GreenHillAtlas.png`, `obj/GreenHillAtlas.png` | Copias de la textura junto a cada archivo |
| `fbx/import_safe_report.json` | Validación de las reservas frente a los límites de Roblox |
| `preview/*.png` | Renders de referencia y `kit_sheet.png`, con todas las piezas |

### En qué se diferencian las reservas del kit oficial
- **Mismos 23 nombres, tamaños (bounding box), pivotes y textura**, así que `kit_manifest.json` y
  `layout.json` sirven igual.
- **Geometría:** en las tres palmeras (`Kit_PalmA/B/C`) la base del tronco se corrigió para que no haya
  caras dobladas hacia dentro: el anillo del ensanche baja 0,25 studs y los anillos del tronco se
  reparten un 3,5 % distinto. No afecta al tamaño. En el resto de piezas solo se quitaron vértices
  sueltos que no se ven.
- **Unidades:** el kit oficial guarda 1 unidad = 1 cm (UnitScaleFactor 1). Las reservas guardan
  1 unidad = 1 m (UnitScaleFactor 100). En ambos casos las coordenadas son studs, con -Z hacia delante
  e Y hacia arriba.
- Las reservas no llevan rutas con caracteres especiales dentro del archivo. El kit oficial sí lleva la
  ruta de la carpeta del PC (`Aoshy´`), pero ya se importó bien.
- **Todas las reservas cumplen los límites de Roblox:** solo triángulos, sin caras degeneradas ni
  vértices sueltos, como mucho 2.720 triángulos y 2.139 vértices por malla (los límites son 20.000 y
  10.000), ningún eje por encima de 2.048 studs, 1 UV, 1 material y normales coherentes.

## Pasos en Studio

**Usa Import 3D, no la cola del Asset Manager.** Ábrelo desde *File > Import 3D* o *Avatar > Import 3D*.
Esa ventana muestra el error exacto de cada malla. La *Import Queue* del Asset Manager solo dice
"Import Failed".

1. **Import 3D** con `GreenHillKit.fbx`, el oficial. Si ya lo importaste, sigue en el paso 3.
2. En la ventana del importador:
   - **Scale Unit (unidad): Stud**
   - **Merge Meshes: DESACTIVADO**, para que cada pieza sea su propia MeshPart.
   - **Upload to Roblox: ACTIVADO**, para que suba las mallas y la textura.
   - World Forward y World Up: deja los valores por defecto (Front -Z, Top +Y).
   - Anchored: activado.
3. **Comprueba el resultado.** Debe haber **23 MeshParts** con estos nombres:
   `Kit_PalmA`, `Kit_PalmB`, `Kit_PalmC`, `Kit_Fern`, `Kit_Sunflower`, `Kit_Bromeliad`, `Kit_BushA`,
   `Kit_BushB`, `Kit_RockA`, `Kit_RockB`, `Kit_GrassTuft`, `Kit_FlowerPatch`, `Kit_TerraceS`,
   `Kit_TerraceM`, `Kit_TerraceL`, `Kit_TerraceCorner`, `Kit_TerraceRound`, `Kit_MesaTall`,
   `Kit_MesaWide`, `Kit_MesaSpire`, `Kit_FenceSection`, `Kit_SpeedPad` y `Kit_Cloud`.
   - **Prueba de escala:** `Kit_SpeedPad.Size` debe ser aproximadamente **(18, 0.5, 16)** y una terraza,
     por ejemplo `Kit_TerraceL`, debe medir aproximadamente **(30.8, 49, 58.8)**.
   - Si sale 100 veces más grande o más pequeña, borra lo importado y repite cambiando la unidad
     (Stud o Meter) hasta que el pad mida 18 x 0.5 x 16.
   - **Prueba de orientación:** las flechas amarillas del pad deben apuntar hacia **-Z**.
4. **Si el archivo oficial falla**, prueba este orden:
   1. `GreenHillKit_all.fbx`
   2. Si también falla, las 23 piezas sueltas de `fbx/`. Puedes seleccionarlas todas en Import 3D o ir
      de una en una.
   3. Si alguna pieza de `fbx/` falla, su `.obj` de `obj/`, con los mismos ajustes.

   **Avísanos de qué archivo falló y con qué texto de error.** El error aparece en:
   - la propia ventana de Import 3D, con un aviso rojo o amarillo junto a cada malla;
   - la ventana **Output** (*View > Output*);
   - en la *Import Queue* del Asset Manager, el **tooltip del icono rojo** (pasa el ratón por encima).
5. **Si la textura no llega** y las piezas salen grises o blancas:
   1. En el Asset Manager, sube `textures/GreenHillAtlas.png` como **imagen o decal**.
   2. **Pásanos su ID.** Nuestro montaje la pondrá como `TextureID` en todas las piezas `Kit_*`.
6. **Propiedades de las 23 piezas.** Selecciónalas todas y ajusta:
   - `Anchored = true`
   - `CanCollide = false`, `CanQuery = false` y `CanTouch = false`
   - `CollisionFidelity = Box` y `RenderFidelity = Automatic`
   - `CastShadow = false` solo en `Kit_GrassTuft`, `Kit_FlowerPatch` y `Kit_Cloud`.
7. Crea una **Folder llamada `GreenHillKit`**, por ejemplo en ServerStorage. Mete dentro las 23
   MeshParts sin cambiarles el nombre y borra el Model vacío.
8. Haz clic derecho en la carpeta, elige **Save to File…** y guárdala como
   **`design/race/greenhill/GreenHillKit.rbxm`**.

## Cómo se colocan las piezas

Esta parte la hace el integrador; la dejo aquí como referencia.

- Coordenadas locales de la pista: el origen es el centro de la línea de salida sobre el suelo
  (`RaceArena` en 6000, 12000, 0), la carrera avanza hacia -Z y la tierra ocupa x de -36 a 36.
- Fórmula para cada colocación:
  `CFrame = CFrame.new(ORIGEN + pos) * CFrame.Angles(0, math.rad(rotY), 0) * CFrame.new(bboxCenterOffset * scale)`
  y `Size = size * scale`. Los valores `size` y `bboxCenterOffset` salen de `kit_manifest.json`.
  No uses el Pivot ni la posición con la que Studio importó cada pieza.
- Las colocaciones con `lowPower: true` llevan la etiqueta **`RaceDecorLowPower`**.
- **Agua:** Terrain Water con la superficie en **y = -8**, en capa fina. La zona sugerida está en
  `layout.json > waterRegionSuggestion`.
- **De Astra se conservan** `Road_*`, `Verge_*` y `Embankment_*`, además de TrackFloor, Walls,
  SpeedPads, Structure y Spikes. **Se quitan** `Mesa_*`, `Palm_*`, `Bushes_*`, `Ferns_*`, `Flower*`,
  `Rocks_*` y `Pad_*_*`.
- **SpeedPad:** el visual mide 18x16 y va sobre los pads de juego (s = 60, 480, 990, 1450 y 1850;
  x = 0). El Part `SpeedPad` de Astra mide 16x20: ocúltalo o dale el mismo tamaño, 18x16.
- **Franja libre:** dentro de |x| < 38,1 solo están los pads. Las vallas ocupan de 38,4 a 39,6 y todo lo
  demás empieza en |x| ≥ 40.

## Regenerar

- Kit oficial, manifest, layout y previews:
  `blender.exe -b --factory-startup --python audit/greenhill_kit_bpy.py`
- Solo las reservas, sin tocar lo anterior:
  `blender.exe -b --factory-startup --python audit/greenhill_kit_bpy.py -- --stage safe`
