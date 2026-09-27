# Evento Super Sonic vs Dr. Eggman: importar las mallas en Studio

La bomba de Eggman, la Esmeralda del Caos, la bola de spin de Sonic y el cañón del Egg Mobile son ahora
**11 mallas de Blender** de un solo color. Se importan **una sola vez**: el montaje las pone en
`ReplicatedStorage.SuperSonicEventAssets.Meshes` de los tres mundos con su color y material. Mientras no
estén, el evento usa sus formas simples.

Vista previa (`preview/`): `kit_overview.png`, `bomb_standing.png`, `emeralds_ring.png`, `spinball_r6.png`,
`cannon_on_eggmobile_front34.png` y una imagen por pieza (`piece_EV_*.png`).

## Pasos

1. En Studio, **File > Import 3D** y elige **`C:\Users\Public\EventKit\EventKit.fbx`** (es la misma que
   `design/event/supersonic/EventKit.fbx`; usa la de `C:\Users\Public`, cuya ruta no tiene acentos).
2. Ajustes del importador:
   - **Scale Unit: Stud**
   - **Merge Meshes: DESACTIVADO** (cada pieza, su MeshPart)
   - **Upload to Roblox: ACTIVADO**
   - World Forward / Up: los de por defecto. Si el kit sale girado, no pasa nada: el montaje lo endereza.
3. Comprueba que hay **11 MeshParts**: `EV_Bomb`, `EV_BombStripe`, `EV_BombFins`, `EV_BombNose`, `EV_ChaosEmerald`, `EV_SpinBall`, `EV_Cannon`, `EV_CannonMetal`, `EV_CannonDark`, `EV_CannonStripe`, `EV_CannonGlow`.
   - Salen grises y unas encima de otras (cada objeto en su origen): es normal, el montaje las pinta y las separa.
   - **Prueba de escala:** `EV_Bomb.Size` ≈ **(1.52, 2.20, 1.52)** y `EV_SpinBall.Size` ≈ **(6.10, 6.33, 6.29)**
     (X y Z pueden salir intercambiadas). Si sale 100 veces más grande o más pequeño, borra y repite con la otra unidad.
4. No cambies los nombres. Clic derecho en el Model importado, **Save to File…** y guárdalo como
   **`Update2/design/event/supersonic/EventKit.rbxm`**.
5. Avísanos. El siguiente montaje (`lune run audit/build_update4.luau`) llena `SuperSonicEventAssets.Meshes`
   (Bomb, ChaosEmerald, SpinBall y Cannon) en los tres mundos.

**Si el FBX falla:** prueba las piezas sueltas de `C:\Users\Public\EventKit\fbx\` y, si alguna falla, su `.obj`
de `design/event/supersonic/obj/`. Pásanos el texto del error (ventana Import 3D u Output).

## Datos

- 30400 triángulos en total (bomba 6676, esmeralda 78, bola 14384, cañón 9262); la malla mayor, `EV_SpinBall`, tiene 14384
  (límite de Roblox: 20.000 triángulos y 10.000 vértices por malla).
- 1 unidad = 1 stud. Cada pieza tiene el pivote en el origen de su objeto: la bomba, la esmeralda y la bola en su
  centro (la bomba de pie, con la punta hacia abajo); el cañón en su punto de montaje sobre la esfera negra del
  Egg Mobile, (0.00, 1.95, -3.11) en el espacio del barco, apuntando 20° hacia abajo.
- Colores, materiales, los 7 colores de las esmeraldas, la boca del cañón y los puntos de enganche salen de
  `event_manifest.json`.
- Regenerar: `blender.exe -b --factory-startup --python audit/event_kit_bpy.py`
