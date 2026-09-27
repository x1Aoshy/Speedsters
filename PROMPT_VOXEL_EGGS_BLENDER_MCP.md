# MISSION: MODEL VOXEL-STYLED HERO EGGS IN BLENDER (MCP / BPY) FOR "STEAL A HERO"

## 0. PIPELINE & MCP CONFIGURATION
- **Workspace:** `C:\Users\Aoshy´\Desktop\StealaHero` (and `Update2`)
- **Blender Executable:** `C:/Program Files/Blender Foundation/Blender 4.5/blender.exe`
- **Blender MCP Server:**
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
*(CLI Batch alternative: `& 'C:/Program Files/Blender Foundation/Blender 4.5/blender.exe' -b --factory-startup --python <script.py>`)*
- **CRITICAL EXPORT PATH (ASCII):** Export FBX files to `C:/Users/Public/HeroEggs/` first to prevent character encoding issues with `´` in `Aoshy´`, then copy into `assets/eggs/fbx/`.
- **Scale:** 1 Blender unit = 1 Roblox Stud. (Egg dimensions: approx 2.4 studs wide, 3.2 studs high, 2.4 studs deep).

---

## 1. VISUAL STYLE BENCHMARK (FROM USER IN-GAME REFERENCES)
Inspect the user references (`media_1790472782743.jpg` and `media_1790472802802.jpg`):
- **Core Geometry:** Stepped cubic voxel egg (approx 20×28×20 voxel grid with rounded stepping).
- **Iconic Character Additions (Voxel Extrusions):**
  - **Luffy Egg:** Voxel straw hat with yellow brim and red ribbon, black messy hair, red open vest revealing skin-toned chest, blue shorts rim, and a black Haki punching fist projecting outward.
  - **Zoro Egg:** Dark green voxel hair, purple haramaki sash, white bandana, and 3 miniature voxel katanas mounted on the sides/bottom.
  - **Inosuke Egg:** Boar mask with pink snout, white tusks, and wide blue eyes.
  - **Zenitsu Egg:** Yellow/orange hair with triangular stepped tips and yellow triangle-patterned haori.
  - **Nezuko Egg:** Pink kimono pattern with green bamboo muzzle attached across the mouth.
- **Surface & Shading:** Sharp voxel edges with subtle beveled corners. Clean solid color materials per voxel cluster (Plastic / SmoothPlastic, with Neon on glowing eyes and energy cores).

---

## 2. COMPLETE HERO ROSTER (ALL 38 HEROES + 6 VILLAINS)

### STAGE 1: THE AVENGERS (Forest / Stark Lab)
1. **Hawkeye (Common):** Purple and dark charcoal tactical shell, quiver strap across chest, purple archer mask brow.
2. **Black Widow (Common):** Matte black stealth suit, red hourglass belt buckle, auburn-red voxel hair rim.
3. **Captain America (Rare):** Royal blue helmet with white 'A' on forehead, red/white vertical torso stripes, star emblem.
4. **Hulk (Epic):** Bulging jade-green muscular voxel shell, ragged purple shorts rim, dark green disheveled hair.
5. **Thor (Legendary):** Silver winged helmet, red flowing cape on back, blue glowing chest discs, miniature Mjolnir hammer.
6. **Iron Man (Mythic):** Hot-rod crimson red and polished gold faceplate, glowing cyan unibeam arc reactor on chest, glowing slit eyes.
* **Villain Boss: Thanos (Scale 1.6):** Massive purple armored egg, gold helmet, Infinity Gauntlet with 6 glowing colored gems.

### STAGE 2: JUSTICE LEAGUE (Lake / Hall of Justice)
7. **Aquaman (Common):** Scaled orange/gold upper chest, dark emerald green legs, golden trident motif.
8. **Green Lantern (Common):** Emerald green and black suit, glowing green lantern power ring symbol on chest.
9. **The Flash (Rare):** Crimson red speedster shell, golden lightning bolt ear-wings, yellow lightning belt and chest emblem.
10. **Wonder Woman (Epic):** Red bustier, blue star-patterned lower rim, golden eagle chest emblem and golden tiara with red star.
11. **Batman (Legendary):** Dark graphite cowl with pointed bat-ears, yellow utility belt, black bat symbol on chest.
12. **Superman (Mythic):** Classic blue suit, red cape, yellow belt, bold 'S' shield on chest, black curl on forehead.
* **Villain Boss: Darkseid (Scale 1.5):** Cracked stony gray rocky texture, blue armor plates, glowing fiery red Omega eyes.

### STAGE 3: SPIDER-VERSE (Desert / Brooklyn Rooftop)
13. **Peter Parker (Common):** Classic red and blue suit with black spiderweb lines and expressive white spider-eyes.
14. **Spider-Gwen (Common):** White hooded shell with teal/magenta interior lining, black torso, pink web accents.
15. **Miles Morales (Rare):** Matte black shell, red graffiti spray-painted spider emblem, sharp white eyes, red webbing.
16. **Spider-Man 2099 (Epic):** Dark navy blue armor, red skull-spider spike motif, arm blades.
17. **Agent Venom (Legendary):** Black tactical armor plates, white spider logo, white military shoulder pads.
18. **Venom (Mythic):** Glossy pitch-black alien symbiote shell, jagged white spider eyes, giant mouth with sharp white fangs and red tongue.
* **Villain Boss: Carnage (Scale 1.2):** Crimson red and black tendril shell, white crazed eyes, sharp black jagged teeth.

### STAGE 4: MY HERO ACADEMIA (Jungle / UA Hero Arena)
19. **Uraraka (Common):** Pink and black hero suit, pink cheek pads, oversized white/pink wrist gauntlets.
20. **Bakugo (Common):** Orange X chest harness, black spiky mask with massive black/orange explosion head fins, green grenade gauntlets.
21. **Todoroki (Rare):** Split half-and-half egg (right side white hair, left side red hair with turquoise burn scar), cyan/red accents.
22. **Hawks (Epic):** Tan aviator jacket with white fur collar, headphones, large crimson-red voxel feather wings on back.
23. **Deku (Legendary):** Teal-green suit with black lines, red utility belt, white mouth guard, green rabbit-ear hood.
24. **All Might (Mythic):** Yellow signature V-shaped antenna hair bangs, American-flag red/white/blue hero suit, giant heroic grin.
* **Villain Boss: Shigaraki (Scale 1.1):** Gray messy hair, disembodied pale voxel hands clutching the face and shoulders.

### STAGE 5: DRAGON BALL (Snow / Capsule Corp)
25. **Krillin (Common):** Orange monk gi, blue undershirt/belt, bald head with 6 forehead dots.
26. **Trunks (Common):** Purple/lavender parted hair, Capsule Corp blue denim jacket, brown sword sheath strap on back.
27. **Piccolo (Rare):** Green Namekian skin with pink arm patches, white heavy cape and turban, purple gi.
28. **Gohan (Epic):** Purple Piccolo-style gi, red belt, spiky black Super Saiyan 2 hair.
29. **Vegeta (Legendary):** Blue bodysuit with white/gold Saiyan battle armor chestplate, massive black flame-shaped spiky hair.
30. **Goku (Mythic):** Orange gi with blue sash and wristbands, Kanji chest symbol, iconic multi-point black Saiyan hair spikes.
* **Villain Boss: Frieza (Scale 1.0):** White bio-armor body with smooth glossy purple gemstone plates on head, shoulders, and chest.

### STAGE 6: ONE PIECE (Volcano / Sunny Pirate Wharf)
31. **Usopp (Common):** Long pointed nose, brown overalls, yellow bandana and sniper goggles on forehead.
32. **Nami (Common):** Bright orange voxel hair, blue/white striped bikini top, Log Pose compass on wrist.
33. **Brook (Rare):** White skeleton face, giant black afro sphere, tall gentleman top hat with pink ascot.
34. **Sanji (Rare):** Blonde hair covering one eye, curly spiral eyebrow, black formal suit with blue tie and cigarette.
35. **Zoro (Epic):** Green haramaki sash, green cropped hair, black bandana on arm, 3 side-mounted voxel katanas.
36. **Shanks (Legendary):** Red swept hair, 3 diagonal scar lines over left eye, black captain's cape, brown sword sheath.
37. **Luffy (Mythic):** Yellow straw hat with red ribbon, red open vest, blue shorts, black Haki boxing fist.
38. **Joy Boy (Secret):** Pure pearl-white Gear 5 body, floating swirling white cloud ribbon halo, gold-rimmed straw hat, wide sun-god smile.
* **Villain Boss: Kaido (Scale 1.9):** Massive muscular purple/gray egg, giant curved bull horns, dragon scales tattoo on arm, spiky kanabo club.

---

## 3. DELIVERABLES & GENERATION SCRIPT
1. `audit/generate_voxel_eggs_bpy.py`: Complete Python script using `bpy` that builds the voxel egg base and constructs each hero's signature accessories and materials.
2. Individual FBX exports: `assets/eggs/fbx/<HeroId>_Egg.fbx` for every hero.
3. Master library: `assets/eggs/HeroEggsKit.blend` containing all 38 heroes + 6 villains organized in Collections by Stage.
4. Auto-validation: Re-import and check scale (height = ~3.2 studs), verify zero non-ASCII metadata, and save a copy in `C:/Users/Public/HeroEggs/`.
