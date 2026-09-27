# 🦸 MASTER PROMPT PARA ASTRA: 3D MODELING "STAGE 1: THE AVENGERS" (BLENDER MCP)

> **Misión:** Modelar en 3D el escenario completo de **Stage 1: The Avengers** para *Steal a Hero* en Blender (usando el servidor MCP o scripts bpy).  
> **Estilo:** Roblox Stud Low-Poly Toy Aesthetic (superficies con studs de juguete, biselados limpios, colores vibrantes, proporción estilo lego/roblox).  
> **Libertad Creativa:** Tienes **total libertad** para generar imágenes conceptuales, texturas alusivas y agregar todos los easter eggs y props icónicos de los Avengers que quieras.

---

## 0. ESPECIFICACIONES TÉCNICAS Y ENTORNO
- **Área del Stage:** ~94 studs de ancho × 152 studs de largo (1 unidad en Blender = 1 stud de Roblox).
- **Ruta de Exportación (Limpia ASCII):** `C:/Users/Public/AvengersStage/`
  - Modelos FBX: `C:/Users/Public/AvengersStage/fbx/`
  - Renders / Previews: `C:/Users/Public/AvengersStage/previews/`
- **Blender Executable:** `C:/Program Files/Blender Foundation/Blender 4.5/blender.exe`
- **Conexión Blender MCP:**
  - Host: `127.0.0.1` | Puerto: `9876`
  - *(Alternativa por consola batch si prefieres: `& 'C:/Program Files/Blender Foundation/Blender 4.5/blender.exe' -b --factory-startup --python script.py`)*

---

## 1. ESTILO VISUAL: ROBLOX STUD LOW-POLY TOY
- **Superficies con Studs:** Las aceras, techos planos, remates de edificios y bordes de carreteras deben lucir el clásico relieve de studs/cilindros tipo juguete de Roblox.
- **Geometría Limpia:** Bloques sólidos biselados (Bevel sutil), sin saturación de polígonos innecesarios ni photogrammetry ruidosa.
- **Colores y Emisivos:** Paleta viva estilo cómic (rojo Iron Man, dorado Stark, azul Capitán América, verde Hulk, violeta Thanos). Materiales emisivos con `Emission Strength` en neones y pantallas holográficas.

---

## 2. ELEMENTOS Y PROPS ALUSIVOS (TOTAL LIBERTAD CREATIVA)
Eres libre de generar imágenes de referencia para diseñar e incorporar detalles temáticos:

### A. Fondo y Edificios (Skyline de Nueva York / Stark):
- **Torre de los Avengers (Pieza Central de Fondo):**
  - Fachada estilizada con el logo gigante **"A"** iluminado en cian/azul neón.
  - Balcón / plataforma voladiza estilo helipuerto de armaduras Stark.
  - Vallas publicitarias holográficas o pantallas con la silueta de Jarvis / Stark Industries.
- **Edificios Modulares de Manhattan:**
  - Rascacielos Art Deco / modernos con ventanas en cuadrícula.
  - Edificios de ladrillo marrón tipo "Brownstone" con tanques de agua de madera en el techo y salidas de escape de incendios.

### B. Props de Calle y Batalla (Destrucción Cómic Toy):
- **Taxis Amarillos de Nueva York:** Modelos low-poly de taxis clásicos (algunos estacionados, otros volcados cómicamente o abollados por la batalla).
- **Coches de Policía & Camiones:** Vehículos low-poly estilo NYPD.
- **Detalles Alusivos a los Héroes:**
  - Grieta o cráter con huellas gigantes de **Hulk Smash** en el asfalto.
  - Marca de impacto o emblema del escudo del **Capitán América** en una pared.
  - Suelo quemado / marcas de impacto de rayos de **Thor**.
  - Puestos callejeros neoyorquinos (carrito de Hot Dogs / Pretzels) con piezas derribadas.
  - Semáforos, bocas de incendio rojas, cubos de basura metálicos y barreras de concreto tipo Jersey.

### C. Guarida de Thanos & Nidos de Huevos (Centro del Stage):
- **Plataforma del Boss (Thanos):**
  - Plataforma central o cráter con líneas de energía cósmica púrpura/dorada inspirada en las Gemas del Infinito.
  - Pilares o escombros ordenados donde descansan los nidos de huevos que los jugadores deben robar.

---

## 3. ENTREGABLES REQUERIDOS
1. **Archivo Master Blender:** `C:/Users/Public/AvengersStage/AvengersStageKit.blend`
   - Colecciones organizadas: `Skyline_Buildings`, `Roads_Sidewalks`, `Vehicles_Taxis`, `Avengers_Props`, `Thanos_Centerpad`.
2. **Archivos FBX individuales y modulares en `C:/Users/Public/AvengersStage/fbx/`:**
   - `Avengers_Skyline.fbx` (Edificios perimetrales y Torre Stark)
   - `Avengers_Road_Floor.fbx` (Carretera, aceras con studs y cráteres)
   - `Avengers_Vehicles_Taxis.fbx` (Taxis y patrullas de policía)
   - `Avengers_Props_Kit.fbx` (Semáforos, hidrantes, vallas, carritos de hot dogs, farolas)
   - `Avengers_ThanosPlatform.fbx` (Plataforma y nidos centrales)
   - *Opcional:* `Avengers_Stage_Complete.fbx` (Todo el escenario combinado a escala exacta 94×152).
3. **Imágenes / Renders en `C:/Users/Public/AvengersStage/previews/`:**
   - Renders o capturas del viewport en perspectiva y vista superior para verificar la estética y escala.
