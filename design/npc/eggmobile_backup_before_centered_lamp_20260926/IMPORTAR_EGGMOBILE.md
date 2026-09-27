# Egg Mobile: importar el kit en Studio

El Egg Mobile clásico (casco blanco sobre una gran esfera negra, burbuja de cristal, banco azul, un solo faro amarillo, tobera octogonal) está hecho
en Blender (`audit/egg_mobile_bpy.py`) como **19 piezas de un solo color** (`EM_*`). Se importa **una vez**;
el montaje del juego las coloca, les pone color y material y anima el ventilador y las dos palancas.
**Sin el archivo `design/npc/EggMobileKit.rbxm` no hay nave:** Eggman sale de pie en su sitio.

## Pasos

1. En Studio: **File > Import 3D** (no uses la *Import Queue* del Asset Manager).
   Abre **`C:\Users\Public\EggMobileKit\EggMobileKit.fbx`** (una ruta sin caracteres especiales).
2. En la ventana del importador:
   - **Scale Unit: Stud**
   - **Merge Meshes: DESACTIVADO** (cada pieza tiene que ser su propia MeshPart)
   - **Upload to Roblox: ACTIVADO**
   - World Forward / World Up: los valores por defecto. Anchored: activado.
3. **Comprueba:** tienen que salir **19 MeshParts** que empiezan por `EM_`: `EM_HullWhite`, `EM_HullBlack`, `EM_Metal`,
   `EM_MetalDark`, `EM_Black`, `EM_TrimYellow`, `EM_Seat`, `EM_Glass`, `EM_Chrome`, `EM_LogoRed`, `EM_Lamp`,
   `EM_DashRed`, `EM_Screen`, `EM_GlowPlasma`, `EM_GlowPlasmaCore`, `EM_GlowExhaust`, `EM_FanRear`, `EM_StickL` y `EM_StickR`.
   - **Prueba de escala:** `EM_HullWhite.Size` ≈ **(7.81, 2.44, 7.81)** y `EM_StickL.Size` ≈ **(0.26, 1.21, 0.26)**.
     Si sale 100 veces más grande o más pequeño, bórralo y repite con la otra unidad.
   - Da igual si Studio la gira o no le pone los colores: el montaje la coloca, la endereza y le pone color y
     material (Neon en las luces y Glass en la burbuja).
4. Mete las 19 MeshParts en una **Folder llamada `EggMobileKit`** (o deja el Model que crea Studio), clic derecho,
   **Save to File…** y guárdala como **`design/npc/EggMobileKit.rbxm`** (dentro del proyecto, junto a
   `LobbyCharacters.rbxm`).
5. Avísanos: el siguiente build pone la nave en los tres lobbies con Eggman sentado.

**Si falla la importación**, prueba las piezas sueltas de `fbx/EM_<Nombre>.fbx` (o `obj/EM_<Nombre>.obj`) con los
mismos ajustes y dinos qué archivo falló y el texto del error (ventana de Import 3D o *View > Output*).

## Qué hay aquí

| Archivo | Para qué |
|---|---|
| `EggMobileKit.fbx` | El kit: las 19 piezas, sin texturas |
| `fbx/`, `obj/` | Reserva: una pieza por archivo |
| `eggmobile_manifest.json` | Tamaño, posición, color, material y papel de cada pieza (lo lee el montaje) |
| `preview/` | Renders: comparación con las referencias y vistas en el lobby con Eggman |
| `reference/` | Las imágenes del dueño (nave de lado y por detrás, el logo de Eggman) |

Regenerar: `blender.exe -b --factory-startup --python audit/egg_mobile_bpy.py` (vuelve a escribir todo, también la
copia de `C:\Users\Public\EggMobileKit\`). Si cambian las piezas hay que importar y guardar el `.rbxm` otra vez.
