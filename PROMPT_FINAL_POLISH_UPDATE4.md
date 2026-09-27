# MISSION: UPDATE 4 FINAL POLISH — BUGS, CONSOLE SUPPORT, DISCORD FEEDBACK & RACE FIXES

## WORKSPACE CONTEXT
- **Path:** `c:\Users\Aoshy´\Desktop\Update2`
- **Engine:** Roblox Luau (R6 avatar standard, mobile-first, console-friendly, zero-friction physics)
- **Status:** All core Update 4 systems & Super Sonic live event are implemented (43/43 tests passing). This prompt fixes the final gameplay, visual, shop, and console issues reported by QA and the owner before launch.

---

## 1. RACE TRACK INVISIBLE WALL FRICTION BUG (P0 FIX)
- **Location:** `src/common/ServerScriptService/Services/Race/RaceArenaBuilder.luau` (in `WallSegments()` and barrier generation).
- **Issue:** When players brush against the invisible side walls (`WallL_*`, `WallR_*`), track curbs, or lateral colliders at high speed, Roblox's default physics friction causes them to lose forward momentum and stop abruptly.
- **Solution:**
  - Apply custom frictionless physical properties to ALL race boundary walls, barriers, and colliders:
    ```luau
    local ZERO_FRICTION = PhysicalProperties.new(0.7, 0, 0, 100, 100) -- Density, Friction=0, Elasticity=0, FrictionWeight=100, ElasticityWeight=100
    part.CustomPhysicalProperties = ZERO_FRICTION
    ```
  - Ensure racers slide smoothly along the track boundaries without snagging or dropping velocity.

---

## 2. RACE AFTERIMAGE COLOR: PURE BLACK / DARK SHADOW
- **Locations:** `src/common/ReplicatedStorage/Shared/RaceVfx.luau` and `src/common/ReplicatedStorage/Shared/Update4Config.luau` (`feel.AfterImage`).
- **Issue:** Race after-images currently use bright neon/gold aura tints instead of the dark shadow silhouette of the sprint.
- **Requirement:** Change the race ghost silhouette to match the sprint afterimage from `R15SpeedsterRun.client.luau`:
  - **Color:** `Color3.fromRGB(28, 17, 38)` (Dark Shadow/Black).
  - **Material:** `Enum.Material.SmoothPlastic` or dark `Neon` with clean alpha fade `(0.3 -> 0.7 -> 1.0)`.

---

## 3. SHOP 2X STAMINA PASS PLACEMENT & RESPONSIVE ALIGNMENT
- **Locations:** `audit/u4_shop_card.luau` and `src/common/StarterPlayer/StarterPlayerScripts/UI/ShopController.client.luau`.
- **Issue:** The cloned "2X Stamina" pass card is misaligned, breaks row ordering, and looks awkward across Mobile, PC, Tablet, and Console.
- **Requirement:**
  - Assign an explicit `LayoutOrder` (e.g. directly after `Revive` or at the end of the `Pass` list).
  - Ensure its `Size`, `Padding`, and `AspectRatioConstraint` match the existing gamepass cards perfectly.
  - Dynamically recalculate `ScrollingFrame.CanvasSize` so the card is never clipped or left floating.

---

## 4. FULL CONSOLE / GAMEPAD CONTROLLER SUPPORT
Ensure Xbox / PlayStation gamepad players have a seamless, first-class experience:
- **Race Controls (`RaceInputClient.client.luau`):**
  - Accelerate / Hold Charge: `ButtonA` or `ButtonR2` (Right Trigger).
  - Steer: Left Thumbstick.
  - Drift / Quick Turn: `ButtonX` or `ButtonL2` (Left Trigger).
- **Super Sonic Live Event (`SuperSonicEventClient.client.luau`):**
  - Homing Attack: Press `ButtonX` or `ButtonA` while airborne and locked onto Eggman.
  - Display dynamic controller button prompt `(X)` on the lock-on reticle when `UserInputService:GetLastInputType()` is Gamepad.
- **UI & Shop Navigation (`ShopController.client.luau`, `TitlesController.client.luau`):**
  - Enable `GuiService.SelectedObject` on first opened element.
  - Support Bumpers (`ButtonL1` / `ButtonR1`) to switch Shop tabs (`Exclusive`, `Server`, `Passes`, `Treadmills`, etc.).
  - `ButtonB` closes modals and shop panels.

---

## 5. QA & DISCORD FEEDBACK RESOLUTIONS (SUNG & GEKKOH)

### A. Fix AFK Mode Sinking Player Into Ground
- **Location:** `src/common/ServerScriptService/Social/AfkZoneService.server.luau` (in `slotFrame` / `lift` calculation).
- **Issue:** When a player enters AFK mode, half their body sinks into the terrain/floor.
- **Fix:** Elevate the vertical CFrame offset:
  ```luau
  local lift = hip + root.Size.Y * 0.5 + 1.25 -- Add clearance so sit animation/root never clips into the floor
  ```
  Perform raycast from `targetFlat + Vector3.new(0, 30, 0)` down to find true floor surface and ensure the character stands/sits cleanly above ground.

### B. Equipped Title Display in TextChatService
- **Location:** `src/common/StarterPlayer/StarterPlayerScripts/UI/VipChatTag.client.luau`.
- **Requirement:** In `TextChatService.OnIncomingMessage`, check the sender's equipped title attribute:
  ```luau
  local title = sender and sender:GetAttribute("EquippedTitle")
  if title and title ~= "" then
      tagPrefix = string.format('<font color="#00FFAA"><b>[%s]</b></font> ', title) .. tagPrefix
  end
  ```
  Ensure chat messages show `[Title] [VIP] PlayerName: Message` cleanly.

### C. Dynamic Leaderboard Titles ("Top %d")
- **Location:** `src/common/ServerScriptService/Services/Titles/TitleService.luau` & `TitleSystem.server.luau`.
- **Requirement:** Instead of filling the UI with 100 individual titles, implement dynamic leaderboard titles for each category (`Top Speed`, `Top Wins`, `Top Races`):
  - Starts with Top 100.
  - Automatically updates the displayed title text in real time to match the player's live rank (e.g. if player moves from rank 100 to 93, the equipped title dynamically displays as `"Top 93 Speed"`).

### D. Race 5-Minute Cadence & Anti-Macro Economy Protection
- **Locations:** `src/common/ReplicatedStorage/Shared/RaceConfig.luau` and `src/common/ServerScriptService/Services/Race/RaceService.luau`.
- **Requirement:** Set race recurrence interval to 5 minutes (`IntervalSeconds = 300`).
- **Post-Race Teleport & Re-Queue:**
  - When a race ends or player clicks "Race Again", do NOT leave them stranded at the finish line.
  - Teleport player back to their original world/lobby.
  - Add them to the queue for the next 5-minute race, automatically pulling them into the starting grid when the countdown completes.

### E. New Promo Codes
- **Locations:** `src/common/ServerScriptService/Social/CodesSystemService.server.luau` and `Update4Config.luau`.
- **Add codes:**
  1. `RACERS`: Awards +250 Wins and 15m 2x Speed boost.
  2. `UPDATE4ISHERE`: Awards +500 Wins, +10,000 Speed, and 20m 2x Speed boost.
  3. `EGGMAN`: Awards +1,000 Wins and 30m 2x Stamina boost.
