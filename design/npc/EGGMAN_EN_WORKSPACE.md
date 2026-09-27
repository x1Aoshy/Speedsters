# Dr. Eggman (y Flash) en el Workspace

Guía corta para poner tus propios NPC en el lobby. Lo demás lo hace el juego
(`ServerScriptService/Gameplay/LobbyNpcs` y `StarterPlayerScripts/Gameplay/LobbyNpcsClient`).

## Eggman: qué tienes que hacer

1. Mete tu modelo de Eggman en el **Workspace** de cada world (`World1Update3New`,
   `World2Update3new`, `World3Update3New`), en cualquier sitio del lobby. Puede ir dentro de una
   carpeta.
2. **Nombre**: `Eggman`, `DrEggman`, `Dr. Eggman`, `Dr Eggman` o `Robotnik` (da igual si va en
   mayúsculas o minúsculas).
   **O** ponle el **tag** `LobbyNpcEggman` (Properties → Tags). Con el tag el nombre da igual.
3. Tiene que ser un **Model** con un **Humanoid** (o un AnimationController) y un
   **HumanoidRootPart** (o una PrimaryPart).
4. **Nada más.** No hace falta anclarlo, ni ponerle scripts, ProximityPrompt ni animaciones. Si ya
   trae alguno, el juego lo apaga.

Hazlo después del build y guarda el place.

## R6 (mejor) o R15

- **R6 es lo preferido**: `Torso` con `Neck`, `Left Shoulder`, `Right Shoulder`, `Left Hip` y
  `Right Hip`, y el `HumanoidRootPart` con `RootJoint`. Es el rig normal de Roblox.
- **R15 también sirve**: se usan `Root`, `Neck`, `LeftShoulder`, `RightShoulder`, `LeftHip` y
  `RightHip`.
- Si el modelo no tiene hombros y caderas, **habla pero no se mueve**, y sale un aviso en la
  consola.

## Qué hace el juego con tu modelo

- Ancla **solo** su `HumanoidRootPart` y lo deja **donde lo pusiste**, con su rotación.
- El cuerpo unido por juntas se desancla para poder moverse, y se le quitan la colisión, el touch
  y el query: se puede pasar a través y no bloquea clics ni la cámara.
- Las piezas sueltas (por ejemplo un pedestal) se quedan tal cual.
- Apaga los scripts que traiga dentro (`Animate`, etc.), quita el `Animator` y oculta el nombre y
  la vida del Humanoid (el juego pone su propio cartel).
- Le pone el **ProximityPrompt** en su root: *"Hablar con Dr. Eggman"* (E, toque o botón X del
  mando). Al usarlo, Eggman se ríe, dice su frase en un globo y se abre el panel de **Misiones**.
- Muestra un **"!" dorado** sobre su cabeza cuando el jugador tiene una recompensa o una misión
  por elegir.
- **Animación de reposo**: manos en la cadera, respira, mira a un lado, levanta la barbilla y se
  ríe cuando le hablan. Cada jugador la ve en su pantalla y solo cerca (en móviles lentos, menos).

El prompt va en su root y el cartel y el "!" se colocan sobre lo más alto del modelo, así que
**cualquier tamaño vale**.

## Dónde ponerlo (sitios probados)

Estos puntos pasan `audit/test_u4_npcs`: suelo libre, a la vista del spawn, fuera de la pista de
baile, de las cintas, de la Race Gate y de la cinemática del portal. Son puntos del suelo; pon ahí
los pies y hazle mirar al spawn.

| World | Posición de los pies |
|---|---|
| World 1 | (219, 37468.04, -1820), sobre la alfombra de las cintas |
| World 2 | (-844, 36626.65, -1046), esquina oeste de la fila de cintas |
| World 3 | (339, 95.84, 564), sobre la alfombra de las cintas |

Puedes ponerlo en otro sitio del lobby si prefieres.

## Flash

- **Si no pones ninguno**, el juego crea un Flash **R6** con el traje **FlashSuit** del juego
  (camiseta, pantalón y máscara) junto a la Race Gate, o en el kiosco del booth de carreras si está.
  Tiene su animación de reposo (estiramientos, mira el reloj) y el prompt *"Apuntarme a correr"*.
- **Si prefieres tu propio Flash**, ponlo como a Eggman: nombre `Flash`, `The Flash` o `TheFlash`,
  o el tag `LobbyNpcFlash`. Sustituye al que crea el juego.
- **El Flash de Steal a Hero** (R15, cabeza y máscara propias) está guardado en
  `design/npc/Flash.rbxm`. Para usarlo: en Studio, clic derecho en Workspace → *Insert from File…* →
  `design/npc/Flash.rbxm`, y muévelo junto a la Race Gate. Ya se llama `Flash`, así que no hace
  falta nada más.

## Apagarlos

- En Workspace, el atributo `U4Off_Npcs = true`: se apagan los prompts, dejan de moverse y
  desaparecen los carteles. Tus modelos se quedan como estatuas; el Flash que crea el juego
  desaparece.
- El Eggman hecho de piezas (el de antes) solo sale con `LobbyNpcConfig.SpawnPartsEggman = true`,
  y solo si no hay ningún Eggman tuyo.
