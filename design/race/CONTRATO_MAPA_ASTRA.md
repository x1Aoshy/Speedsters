# Mapa de carreras: lo que el código necesita (para Astra)

El código de las carreras funciona con cualquier mapa si se respetan estos puntos. Todo lo demás
(estilo, decoración, modelos) es libre.

## 1. Dónde y cómo va la pista
- Modelo: `Workspace.RaceArena`, en los **3 places** (World1, World2, World3).
- **Origen:** `(6000, 12000, 0)`. Es el centro de la línea de salida, **a la altura de la superficie
  del piso**.
- **Dirección:** la carrera avanza hacia **-Z**, en línea recta.
- **Medidas:**
  - 2000 studs de pista más 120 de frenada después de la meta.
  - **72 studs de ancho**: 8 carriles de 9.
- **Zona de salida:** los corredores esperan en los 64 studs antes de la línea (Z de 0 a +64), en
  dos filas de parrilla (Z = +10 y Z = +22).
- **El piso de la pista debe estar exactamente a Y = 12000** en todo el recorrido. El anti-trampas
  mide la altura desde ahí: un piso más alto o más bajo hace que los corredores se "corrijan".
- **Paredes laterales:** dejar las paredes invisibles en X = 6000 ± 38.1. Dentro de ±44 studs de
  X no debe haber nada con colisión por encima del piso, salvo esas paredes.
- **Distancia:** a más de **1500 studs** (en X/Z) de cualquier otra parte del place, para que el
  lobby se descargue mientras se corre.

## 2. Nombres exactos que el código busca
Dentro de `Workspace.RaceArena`:

| Objeto | Qué hace el código |
|---|---|
| `Structure.StartGate` (Part) | Es la barrera de salida: deja de colisionar en el GO |
| `Structure.StopBar` (Part) | La barra "STOP" que cae en el GO |
| `Structure.StartGantry.Light1` … `Light5` (Parts) | Luces de salida que el cliente pinta de rojo a verde |
| `RaceOrb` (Part) | Marcador "ORB" al final de la pista |
| `FinishGate.ConfettiSpot_1..4` (Attachments, opcional) | Confeti en la meta |

En el lobby de cada place, `Workspace.RaceGate` necesita:

| Objeto | Qué hace el código |
|---|---|
| `RaceGatePad` (Part, puede ser invisible) | Al tocarlo, el jugador se inscribe en la carrera |
| `RaceGateSign` (Part con un BillboardGui con `Title`, `Status` y `Record`) | Muestra el estado, el temporizador y el récord semanal |
| `FlashSpot` (Part pequeña, opcional) | The Flash se para ahí. Su base marca el piso y su frente mira a los jugadores |

## 2b. Pista recta con subidas pequeñas y pads de velocidad (diseño acordado el 2026-09-25)
- **Recta, sin curvas:** el centro de la pista va siempre en X = 6000, de Z = 0 (salida) hacia -Z
  (meta en Z = -2000).
- **Subidas y bajadas suaves:** pendiente máxima de unos 10° y ningún escalón de más de 1 stud.
  La salida (los 64 studs de preparación y la línea) y la meta deben quedar planas, a Y = 12000.
- **Pads de velocidad:** Parts llamados `SpeedPad`, dentro de `RaceArena.SpeedPads`, planos sobre
  el suelo y con la flecha apuntando hacia -Z. Opcional: el atributo `Boost` (por defecto 1.25,
  es decir +25 %) y `Seconds` (por defecto 1.5). El servidor los lee al empezar cada carrera.
- **Sin agua ni cascadas:** debajo de las zonas elevadas va terreno o vegetación.
- **Palmeras con viento:** el movimiento debe ir en el cliente o en la malla, sin scripts por
  palmera en el servidor. En móvil, poca cantidad animada.

### Detalles técnicos que el código ya espera (2026-09-25)
1. **Superficie de carrera:** Parts visibles y con colisión (Transparency < 1, CanCollide y CanQuery
   activados) o Terrain. Un piso invisible no cuenta como suelo. Dentro de ±44 studs del centro no
   puede haber nada con colisión en los 25 studs por encima del suelo (salvo las paredes y
   `StartGate`).
2. **Dónde se mide la altura:** en X = 6000 − 31.5, 6000 y 6000 + 31.5, cada 4 studs, desde la zona de
   preparación (Z = +64) hasta el muro final (Z = −2120). Entre esas tres líneas se asume una
   inclinación lateral recta.
3. **Límites:** pendiente de 10° como máximo, nunca más de 1 stud de subida entre dos puntos
   separados 4 studs, y el suelo siempre dentro de ±60 studs de Y = 12000.
4. **Zonas planas a Y = 12000:** de Z = +64 a Z = −4 (preparación y línea de salida) y de Z = −1992
   a Z = −2008 (meta).
5. **Pinchos sobre las colinas:** las baldosas de pinchos deben apoyarse en el suelo. El choque se
   mide desde el suelo.
6. **Pads de velocidad:** Part `SpeedPad` dentro de `RaceArena.SpeedPads`, plana sobre el suelo, a
   20 studs o más de cualquier fila de pinchos, como máximo 24.
   - Su tamaño y orientación definen la zona que se pisa.
   - CanCollide desactivado.
   - `Boost` (opcional) de 1.5 como máximo; `Seconds` (opcional) de 3 como máximo.
   - No etiquetarlos `RaceDecorLowPower`.
7. **Comprobación:** al arrancar, el servidor imprime cualquier incumplimiento de estas reglas
   (pendiente, escalón, salida o meta no planas). Conviene revisar la salida después de colocar el
   mapa.

## 3. Pinchos
Los pinchos se calculan en el servidor por posición: filas en los campos a **300, 750, 1200 y 1650
studs** de la salida, con baldosas de 7 studs. Si el dibujo de los pinchos se mueve o se quita, los
choques no coincidirán con lo que se ve. Lo mejor es dejar las baldosas de pinchos donde están, o
avisarme para cambiar las posiciones en el código.

**2026-09-26 (dueño: pinchos espaciados y alternados):** cada campo tiene 2 o 3 filas separadas
90 studs: **300, 390 | 750, 840, 930 | 1200, 1290, 1380 | 1650, 1740**. Cada fila bloquea 4 de
los 8 carriles y deja 4 libres, y dos filas seguidas de un campo nunca dejan libre el mismo
carril (hay que esquivar). El build (`--greenhill`) genera las baldosas desde
`Update4Config` (Race.Track), así que el dibujo y el choque siempre coinciden. Los pads
(60, 480, 990, 1450, 1850) quedan a 60 studs o más de cualquier fila.

## 4. Rendimiento (el 63 % juega en móvil)
- Como máximo unas **600 partes** en la pista.
- Marcar la decoración con el tag **`RaceDecorLowPower`**, para que los móviles lentos la oculten.
- Pocas luces y partículas.

## 5. Cómo entregarlo
- El build **ya no reemplaza** `RaceArena` ni `RaceGate` si el place los tiene.
- **Opción A:** hacer el mapa en los 3 places.
- **Opción B (recomendada):** hacerlo en uno y guardarlo con clic derecho > Save to File como
  `design/race/RaceArena.rbxm` (y `RaceGate.rbxm` si cambia la entrada). Yo lo copio a los 3 places
  y reviso los nombres de este documento con los tests.
