# MISSION: UPDATE 4 LIVE EVENT — "SUPER SONIC VS DR. EGGMAN" (BLENDER MCP + ASSET PIPELINE + LUAU)

## 0. ENVIRONMENT & MCP SETUP (ASTRA'S CONFIGURED PIPELINE)
- **Workspace:** `c:\Users\Aoshy´\Desktop\Update2`
- **Blender Executable:** `C:/Program Files/Blender Foundation/Blender 4.5/blender.exe`
- **Pre-configured Blender MCP Server:**
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
*(Alternative CLI batch path if MCP client is busy: `& 'C:/Program Files/Blender Foundation/Blender 4.5/blender.exe' -b --factory-startup --python <script.py>`)*

- **CRITICAL EXPORT RULE (ASCII PATH):**
  To avoid Blender export metadata bugs with the special character `´` in `Aoshy´`, always export `.fbx` models to `C:/Users/Public/` or an ASCII directory first, then copy to `Update2`.
- **ROBLOX SCALE CONVENTION:**
  1 Blender unit = 1 Roblox Stud.

---

## 1. 3D ASSET MODELING IN BLENDER (STRICTLY NO ROBLOX CSG / PRIMITIVES)

### A. Dr. Eggman's Aerial Bomb (Finish Astra's Cannon Work)
- **Geometry:** Heavy drop aerial bomb fired from the Egg Mobile cannon.
  - Spherical/teardrop aerodynamic body with beveled metal seams.
  - Tail fin stabilizer ring with 4 angled directional fins.
  - Front rounded nose cap with a small hazard/warning rim.
  - Small rear exhaust nozzle or fuse cap.
- **Materials & Textures:**
  - Check Astra's enamel microdetail texture (`design/npc/eggmobile/textures/Enamel_Microdetail.png`).
  - Paint body glossy dark gunmetal / Eggman yellow hazard stripes.
  - Export clean FBX mesh with centered pivot `(0, 0, 0)` at base/center.

### B. Chaos Emeralds (7 Gem Meshes)
- **Geometry:** Classic Sonic faceted brilliant-cut diamond gem.
  - Octagonal flat top table, faceted crown, sharp girdle, and multi-faceted pavilion converging to a bottom culet point.
  - Clean bevels, high-specular stylized toy geometry (around 1.5 studs high, 1.6 studs diameter).
  - 7 color variations applied via Roblox `Color3` / Materials (Green, Red, Blue, Yellow, Cyan, Purple, White).

### C. Sonic Spin Attack Ball Mesh
- **Geometry:** Streamlined spinning battle shell (spherical capsule with subtle aerodynamic ridges, optimized to encapsulate an R6 rig).
- Serves as the clean mesh core for the golden aura effects, wind rings, and flipbooks.

---

## 2. PRE-EXTRACTED BATTLE VFX (STEAL A HERO -> UPDATE 2)
The key battle VFX have already been extracted from Steal a Hero into `.rbxm` files ready in `c:\Users\Aoshy´\Desktop\Update2\assets\vfx_imported\`:
1. `BombExplodeVFX.rbxm` (from `Assets.VFX.ExclusiveEggs.Particles.Explode.Bomb`): Heavy bomb burst (`darkfire`, thick `smoke`, `sw` shockwave ring, flying `rock`, `Sparks`).
2. `FireTrailParticlesPart.rbxm` (from `Assets.VFX.FireTrailParticlesPart`): Ground fire emitter (`FireParticle`) that remains on impact craters.
3. `BurstHatchVFX.rbxm` (from `Assets.VFX.SAB.Burst_Hatch`): Mystic convergence burst (`Hitspark2`, `Circle`, `FireSpecs`, `Embers`, `shards`).
4. `EggImpactDefaultVFX.rbxm`: Ground shockwave and dust cracks (`crack`).

---

## 3. HOMING SPIN ATTACK TEXTURE ASSET IDS
Combine the Blender spin mesh with these 4 verified flipbooks & textures:
- **Animated Flipbook Lightning:** `rbxassetid://12376549723` (`Lightning343 2`)
- **Flipbook Lightning Globe:** `rbxassetid://127860061030425` (`LE Lightning Globe`)
- **Wind Rings Particle:** `rbxassetid://116579220922305` (`Wind22`)
- **Speed Trail / Beam:** `rbxassetid://110245787189599` (`Beam113`)

---

## 4. CAMERA PUNCH INTEGRATION
Use native module `src/common/ReplicatedStorage/Shared/CameraPunch.luau`:
- **Bomb Ground Hit:** `CameraPunch.Shake(0.35, 2.2)` + `CameraPunch.Fov(12)`
- **Homing Hit on Eggman:** `CameraPunch.Shake(0.18, 1.4)` + `CameraPunch.Fov(-6)`
- **Eggman Defeat:** `CameraPunch.Shake(0.60, 3.5)` + `CameraPunch.Fov(18)`

---

## 5. COMPLETE EVENT SCRIPTING SPECIFICATIONS

### PHASE 1: AERIAL BOMBARDMENT
- Eggman hovers at `(0, 85, 0)` above spawn in the Egg Mobile.
- Fires 3 salvos of the newly modeled bombs with physics drop/arc.
- Bomb detonates on ground:
  - Spawns `BombExplodeVFX` + `EggImpactDefaultVFX`.
  - Spawns burning `FireTrailParticlesPart` on ground for 5 seconds.
  - Triggers `CameraPunch.Shake(0.35, 2.2)`.
  - **R6 Ragdoll Blast:** Any player within 22 studs triggers `R6DeathRagdoll` velocity `(pos - bombPos).Unit * 55 + Vector3.new(0, 42, 0)` for 2 seconds (DO NOT kill the player).

### PHASE 2: CHAOS EMERALD ABSORPTION & SUPER SONIC
- The 7 Blender-modeled Chaos Emeralds appear from the sky with PointLights (`Range = 14`, `Brightness = 2.5`) matching their gem colors.
- Orbit around the player's torso in a sine wave ring (`radius = 6`, `Y = math.sin(t * 4) * 1.5`).
- The 7 gems converge into the player's chest (using Bezier curve from `OrbAbsorption.luau`).
- `BurstHatchVFX` bursts with a golden flash chime.
- **SUPER SONIC TRANSFORMATION:**
  - **CRITICAL CONSTRAINT:** DO NOT spawn or force an aura particle on Super Sonic! Players MUST keep their currently equipped user auras visible.
  - Body parts tint to radiant gold (`Color3.fromRGB(255, 215, 0)`), eyes turn ruby red (`Color3.fromRGB(255, 30, 30)`), flipbook sparks (`rbxassetid://12376549723`) emit from limbs.
  - `WalkSpeed = 120`, `JumpPower = 90`.

### PHASE 3: CO-OP HOMING ATTACK (SMOOTH KINEMATIC BEZIER ANIMATION)
- **STRICTLY NO CRUDE ROBLOX PHYSICS/ROLLING:** The ball attack is purely kinematic!
- **Auto-Aim Target System:**
  - Detects Eggman within 180 studs.
  - Displays lock-on target reticle.
  - **Mobile:** Large circular button "HOMING ATTACK" appears when airborne.
  - **PC:** Spacebar in mid-air or 'F' / Left Click.
- **Execution Animation:**
  - Player R6 model is made invisible and replaced with the Blender Spin Ball surrounded by `Lightning Globe`, `Wind Rings`, and `Beam Trail`.
  - **Kinematic Bezier Motion:** Moves at 180 studs/s along a curved arc towards Eggman while applying continuous high-speed rotation on the ball (`CFrame.Angles(spinAngle, 0, 0)`).
  - **On Impact:**
    - Plays metallic impact sound + `CameraPunch.Shake(0.18, 1.4)`.
    - Eggman flashes red, recoils with physics shake.
    - Player bounces backwards and upward smoothly (`AssemblyLinearVelocity = Vector3.new(0, 55, 0) - lookVector * 25`).
    - Spin ball despawns, player R6 unhides in aerial pose.
    - **Instant Reward:** Server awards **+1,000 Wins** and **+50,000 Speed** immediately per hit.
- **Boss Defeat:**
  - Egg Mobile HP reaches 0: huge chain explosions, `CameraPunch.Shake(0.60, 3.5)`, victory fanfare, chat announcement, and Eggman flees smoking.
