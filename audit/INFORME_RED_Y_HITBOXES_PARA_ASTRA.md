# Auditoría de Red, Replicación y Hitboxes — Update 2 (World 1 y World 2)

**Para:** Astra / Equipo de Desarrollo  
**Fecha:** 13 de Septiembre de 2026  
**Objetivo:** Diagnóstico técnico exhaustivo de la degradación severa de red (*network choking / high ping / packet drop*) en World 2 y World 1, y causas fundamentales de los fallos en las hitboxes.

---

## 1. Diagnóstico de Red: ¿Por qué la red se está muriendo?

### Causa 1.1: 46 Partes Físicas Desancladas (`Anchored = false`) en World 2
* **Evidencia:**
  * En **World 1**: Hay exactamente **0 partes desancladas** en Workspace.
  * En **World 2**: Hay **46 partes desancladas** simulando física activa en el servidor.
  * Entre las partes desancladas se encuentran **28 pads de etapas de victoria y salto**:
    * `Workspace.X22`, `Workspace.X23`, `Workspace.X24`, `Workspace.X25`, `Workspace.X26`, `Workspace.X27`, `Workspace.X28`, `Workspace.X29`, `Workspace.X210`, `Workspace.WinStageX2`
    * Subpartes: `Win2`, `Win3`, `Win4`, `Win5`, `Win6`, `Win7`, `Win8`, `Win9`, `Win10`, `Skip2`, `Skip3`, `Skip4`, etc.
    * Partes de mallas gigantescas: `Workspace.Tree4.MeshPart` (dimensiones: **39 × 83.1 × 40.7 studs**).
    * Burbujas: `Workspace["ASMR kit -  by Agus_Fellini2"].Bubble.Script.Bubble` (9 partes).
* **Impacto en Red:** El motor de físicas de Roblox (*Distributed Physics*) calcula la velocidad, momento y contactos de cada parte desanclada y **replica sus coordenadas por red a todos los clientes a 60 Hz**. 46 partes libres multiplicadas por 20 jugadores saturan los canales de replicación UDP del servidor.
* **Acción requerida:** Anclar todas las partes (`Anchored = true`) en World 2.

### Causa 1.2: 61 Scripts en Workspace de World 2 con Loops en Servidor
* **Evidencia:**
  * **World 1**: Solo 9 scripts en Workspace.
  * **World 2**: **61 scripts** corriendo dentro de `Workspace`.
  * Presencia de un modelo invasivo: `Workspace["ASMR kit -  by Agus_Fellini2"]` (180 descendientes):
    * 10 scripts de teclado (`Keyboard.Script`).
    * 9 scripts de burbujas (`Bubble.Script`).
    * 6 scripts de mantequilla (`Butters.Butter.Script`): cada uno ejecuta `RunService.Heartbeat:Connect(function(dt))` en el servidor con operaciones trigonométricas y `Lerp` de CFrame en tiempo real.
  * 11 scripts de `FadingPart.FadingScript` y 10 de `Conveyor.Script` modificando propiedades en el servidor.
* **Impacto en Red:** Cuando un script del servidor modifica `CFrame`, `Transparency` o `Size` de una parte cada frame, Roblox empaqueta y difunde paquetes de cambio de propiedad a todos los clientes en la experiencia.
* **Acción requerida:** Eliminar o desactivar `ASMR kit - by Agus_Fellini2` y consolidar/pasar a cliente los efectos visuales de cintas/fading.

### Causa 1.3: "Stamina Attribute Flood" en `ServerScriptService.Bootstrap` (Afecta World 1 y World 2)
* **Evidencia:**
  * En `Bootstrap.luau` (línea 399):
    ```lua
    RunService.Heartbeat:Connect(function(dt: number)
        for _, player in ipairs(Players:GetPlayers()) do
            if player:GetAttribute("DataLoaded") == true then
                syncBoostStaminaAttributes(player)
                ...
    ```
  * En `syncBoostStaminaAttributes(player)` (líneas 89-104):
    ```lua
    player:SetAttribute("TrueBoostStaminaMax", maxStamina)
    player:SetAttribute("TrueBoostStamina", stamina)
    player:SetAttribute("BoostStaminaMaxInternal", maxStamina)
    player:SetAttribute("BoostStaminaDisplayMax", maxStamina)
    player:SetAttribute("BoostStamina", stamina)
    ```
* **Impacto en Red:**
  * Se escriben **5 atributos en cada objeto Player 60 veces por segundo**.
  * En Roblox, los cambios de atributos del servidor replican inmediatamente a la totalidad de clientes conectados.
  * En un servidor con 15 jugadores:
    $$\text{15 jugadores} \times \text{5 atributos} \times \text{60 FPS} = \mathbf{4,500\text{ paquetes de atributos por segundo}}$$
  * Los clientes se inundan de eventos `GetAttributeChangedSignal`, colapsando el buffer de entrada de red (`NetworkReceive KB/s`) y disparando el ping por encima de 400ms.
* **Acción requerida:**
  1. No replicar estamina continua en Heartbeat por atributos del Player. La barra de estamina debe calcularse predictivamente en el cliente (`LocalScript`), o bien actualizar los atributos únicamente cuando el valor entero cambie, o throttled a 4 Hz.
  2. Eliminar atributos redundantes (`TrueBoostStamina`, `BoostStaminaMaxInternal`, `BoostStaminaDisplayMax`, etc.). Mantener solo uno canónico.

### Causa 1.4: Densidad de Mapa y Streaming Memory Choke
* **Evidencia:**
  * World 1: 4,655 partes, 9 meshes.
  * World 2: **8,034 partes, 91 meshes de alta geometría**.
* **Impacto:** Con velocidades de vuelo y sprint de cientos de studs por segundo, `StreamingEnabled` envía ráfagas masivas de instancias a los clientes conforme atraviesan las 10 etapas, copando el ancho de banda del cliente.

---

## 2. Diagnóstico de Hitboxes: ¿Por qué son un desastre?

### Causa 2.1: Grosor Cero de los Pads (`Y = 0.0 studs`) y Efecto Túnel
* **Evidencia:**
  * En ambos mundos, los pads de victoria y saltos (`X1.Win1`, `X22.Win2`, `WinStageX2`, etc.) tienen dimensiones de tipo:
    $$\text{Size} = (7.0, \mathbf{0.0}, 7.0)\text{ o }(7.6, \mathbf{0.0}, 7.6)$$
* **Mecánica del Fallo:**
  * Los jugadores corren a 150 – 500+ studs/segundo.
  * El motor de físicas de Roblox opera a 60 Hz ($\Delta t \approx 16.6\text{ ms}$).
  * A 300 studs/s, el personaje avanza **5 studs por frame**. A 600 studs/s, avanza **10 studs por frame**.
  * Si el pad tiene una altura vertical de $0.0$ studs, y el personaje realiza la animación de correr (donde las piernas y el torso oscilan verticalmente de 0.5 a 1 stud), el volumen del personaje pasa por encima o por delante del plano en un solo frame **sin que el AABB llegue a intersectar**.
  * **Resultado:** El evento nativo `pad.Touched` **nunca se dispara**; el jugador atraviesa el pad como un fantasma.
* **Acción requerida:**
  * Dar altura real a las hitboxes de los pads: mínimo `Y = 4.0 studs` (o usar una hitbox invisible de volumen `10 × 6 × 10` studs).
  * Implementar detección complementaria de proximidad en el servidor o cliente mediante `Workspace:GetPartsInPart` / `OverlapParams`.

### Causa 2.2: Bounding Boxes Invisibles Desproporcionadas en Obstáculos (Árboles, Lava, Martillos)
* **Evidencia:**
  * En World 2, `Workspace.Tree4.MeshPart` mide `(39.0, 83.1, 40.7)` studs.
  * `World2TreeSlammers` en el cliente chequea:
    ```lua
    local contacts = Workspace:GetPartsInPart(bodyPart, treeOverlap)
    ```
* **Mecánica del Fallo:**
  * Cuando un `MeshPart` tiene `CollisionFidelity = Box` o `Default`, Roblox genera una caja envolvente rectangular que abarca las dimensiones máximas extremas.
  * Un jugador que salta a 8 studs de distancia de las ramas visuales del árbol entra en contacto con la esquina invisible de la caja de 83 studs, provocando muerte instantánea inexplicable para el jugador (*"¡Ni siquiera lo toqué!"*).
* **Acción requerida:**
  * En trampas con MeshParts, configurar `CanTouch = false` en la malla visual y crear hitboxes dedicadas invisibles (`CanCollide = false`, `CanTouch = true`, `Transparency = 1`) calibradas con precisión al grosor real del obstáculo peligroso.
  * Establecer `CollisionFidelity = PreciseConvexDecomposition` si la geometría es cóncava.

### Causa 2.3: Desfase por Latencia (Server vs Client Hit Validation)
* **Evidencia:**
  * En `World1ClientHazardAuthority.luau`, el servidor reconstruye la rotación virtual del martillo basada en un timestamp reportado:
    $$\text{phase} = \text{phaseOffset} + (\text{timestamp} - \text{epoch}) \times (\pi / \text{halfTime})$$
  * Debido a la saturación de red documentada en la Sección 1, los timestamps llegan retrasados o desfasados entre 100 ms y 400 ms.
  * El jugador ve que el martillo ya subió en su pantalla local, cruza la plataforma, pero la validación tardía del servidor determina que en ese instante virtual el martillo aún estaba abajo, matando al jugador con retardo.
* **Acción requerida:** Aliviar la red (Sección 1) para que el ping retorne a valores sanos (<60ms), y ampliar las tolerancias de tiempo de gracia en la validación de peligros sincronizados.

---

## 3. Hoja de Ruta de Implementación para Astra

1. **Paso 1 (Físicas):** Ejecutar script de anclaje para fijar todas las 46 partes desancladas de World 2 (`Anchored = true`).
2. **Paso 2 (Limpieza Workspace):** Desactivar o purgar `Workspace["ASMR kit -  by Agus_Fellini2"]` de World 2.
3. **Paso 3 (Red / Atributos):** Reemplazar el bucle Heartbeat de replicación de estamina en `Bootstrap.luau`. Actualizar solo por evento o limitar a 4 Hz con tolerancia de cambio.
4. **Paso 4 (Pads Hitboxes):** Modificar la altura de los pads de `0.0` studs a `4.0` studs con `CanCollide = false` y `CanTouch = true`, o posicionar hitboxes de volumen dedicadas.
5. **Paso 5 (Mesh Hazard Hitboxes):** Ajustar las hitboxes de `TreeSlammers` y martillos para usar cajas delimitadoras reducidas que coincidan con la apariencia visual.
