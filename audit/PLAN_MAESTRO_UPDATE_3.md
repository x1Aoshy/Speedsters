# PLAN MAESTRO - UPDATE 3: SPEEDSTER ESCAPE
> **Documento de Especificación Técnica y Hoja de Ruta de Implementación**
> **Fecha:** Septiembre 2026
> **Estado del Proyecto:** Update 2 Finalizado, Verificado y Compilado (12 loops, 22 suites OK). Listo para inicio de Update 3.

---

## 1. RESUMEN DEL ESTADO ACTUAL (UPDATE 2 FINALIZADO)

Antes de arrancar con el Update 3, se han completado, testeado y compilado todas las peticiones críticas previas:

1. **Admin Panel Controller y Acceso:**
   - Reparado en `MenuEvents.luau` (`MenuEvents.Listen`) y `MENU_TO_GUI.Admin = "SpeedsterAdminPanelGui"`.
   - Vinculado al TopbarIcon y al panel visual existente.
   - Whitelist de administradores asegurada con UserIds: `5113549114`, `767108248`, `111827288`.

2. **Revive UI y Respawn Limpio:**
   - Eliminado el freeze delay de 20 segundos en `R6DeathRagdoll.server.luau`.
   - Respawn natural a los 2.5 segundos sin muertes fantasma.
   - `SpeedProductPurchases.server.luau`: El revive por producto o UI respawnea al jugador exactamente en la posición donde cayó (`deathCFrame + Vector3.new(0, 3.5, 0)`), con rescate seguro si cayó al vacío.

3. **Comandos de Chat de Administrador:**
   - Implementado en `src/common/ServerScriptService/Admin/ChatBoostCommands.server.luau`:
     - `/speed [jugador] [cantidad]` (admite sufijos k, m, b, t, qa; por defecto a uno mismo si no se pone jugador).
     - `/wins [jugador] [cantidad]`
     - `/rebirth [jugador] [cantidad]`
     - `/level [jugador] [nivel]` (calcula la curva de velocidad requerida y actualiza nivel y speed en DataService).
     - `/stage [jugador] [1-11]`
     - `/reset [jugador]`, `/kill [jugador]`, `/respawn [jugador]`
     - `/bring [jugador]`, `/goto [jugador]`, `/tp [jugador1] [jugador2]`
     - `/fly [jugador]`, `/unfly [jugador]`
     - `/geko [minutos]`, `/boost [speed|wins|all] [mult] [min]`
     - `/admin`, `/panel`, `;admin`, `;panel`, `/help`, `/cmds`

4. **Compilación de Builds:**
   - Lugares sincronizados y exportados:
     - `World1 Speedtercorrect.rbxl`
     - `World2Old has to be synced with world1updated the p[ad bug still.rbxl`
     - `output/Update2_core/World1.rbxl`
     - `output/Update2_core/World2.rbxl`

---

## 2. OBJETIVOS CLAVE DE RETENCIÓN PARA UPDATE 3

El análisis de analíticas (CSV de picos, retención y errores) demostró que para mantener el pico de jugadores y disparar el **Average Session Time (AST)** y la **Retención D1/D7**, el juego necesita:
- **Objetivos inmediatos al entrar** (Sistema de Misiones con popup).
- **Progresión pasiva que premia volver a entrar** (AFK Rewards).
- **Emoción y recompensas de alto valor** (Ruleta de la Suerte / Spin Wheel).
- **Contenido endgame continuo** (Mundo 3 Desierto + Nuevas Evoluciones).
- **Herramientas de viralidad y eventos en vivo** (Admin Abuse Rework con eventos globales).

---

## 3. ESPECIFICACIÓN DETALLADA DE SISTEMAS (UPDATE 3)

### FEATURE 1: SISTEMA DE RECOMPENSAS AFK (OFFLINE REWARDS)
Permite a los jugadores progresar incluso cuando no están jugando, incentivándolos a abrir el juego todos los días.

- **Datos requeridos (`ProfileSchema.luau` & `ProfileReducers.luau`):**
  - `LastLogoutTimestamp: number` (se guarda al desconectarse el jugador).
  - `LastAfkClaimTimestamp: number` (para evitar exploits).
- **Reglas del Sistema:**
  - Tiempo mínimo fuera: **10 minutos**.
  - Tiempo máximo acumulable: **24 horas** (1440 minutos).
- **Cálculo de Recompensas:**
  - `Speed`: `elapsedMinutes * (50 + (Level * 10))`
  - `Wins`: `elapsedMinutes * 2`
  - Chance de Poción (Speed o Wins de 15 min): `5%`
  - Chance de Spin Ticket: `10%`
- **Flujo de Usuario:**
  - Al entrar al juego, si `elapsedMinutes >= 10`, se abre automáticamente el modal de AFK Rewards.
  - Opción 1: **"Reclamar x1"** (Gratis).
  - Opción 2: **"Reclamar x5"** (VIP o compra de Robux mediante Developer Product).
- **Seguridad:**
  - El cálculo de recompensas se valida 100% en el servidor (`AfkRewardsService.server.luau`).
  - La transacción con `DataService` es atómica.

---

### FEATURE 2: SISTEMA DE MISIONES (QUEST SYSTEM)
Establece metas claras a corto plazo (diarias) y a medio plazo (semanales).

- **Estructura de Datos (`ProfileSchema.luau`):**
  - `Quests`:
    - `Daily`: `{ [questId: string]: { progress: number, completed: boolean, claimed: boolean } }`
    - `Weekly`: `{ [questId: string]: { progress: number, completed: boolean, claimed: boolean } }`
    - `LastDailyReset: number` (se reinicia cada 24 horas exactas).
    - `LastWeeklyReset: number` (se reinicia cada 7 días).
- **Misiones Diarias (Reset cada 24h):**
  1. *Speed Grind:* Conseguir 50,000 Speed $\rightarrow$ Recompensa: Wins proporcionales al nivel.
  2. *Stage Runner:* Completar 20 etapas acumuladas $\rightarrow$ Recompensa: Wins.
  3. *Winner:* Ganar 3 veces en cualquier mundo $\rightarrow$ Recompensa: 1 Poción 2x Wins (15 min).
  4. *Playtime:* Jugar durante 15 minutos en la sesión $\rightarrow$ Recompensa: 1 Poción 2x Speed (15 min).
  5. *Rebirth Push:* Realizar 1 Rebirth $\rightarrow$ Recompensa: 1 Spin Ticket.
- **Misiones Semanales (Reset cada 7 días):**
  1. *Weekly Speedster:* Conseguir 500,000 Speed $\rightarrow$ Recompensa: Gran paquete de Wins.
  2. *Stage Master:* Completar 100 etapas acumuladas $\rightarrow$ Recompensa: Bundle de Pociones (2x Speed + 2x Wins).
  3. *Champion:* Ganar 25 veces $\rightarrow$ Recompensa: 3 Spin Tickets.
  4. *Dedicated Player:* Jugar 2 horas acumuladas en la semana $\rightarrow$ Recompensa: Wins masivos + Poción 30 min.
  5. *Rebirth Master:* Realizar 5 Rebirths $\rightarrow$ Recompensa: Mega Recompensa (5 Spin Tickets + Título/Wins).
- **Flujo de UI:**
  - Popup automático no invasivo al unirse por primera vez al día para mostrar objetivos activos.
  - Indicadores visuales de progreso (barras de porcentaje) y botón "Reclamar".

---

### FEATURE 3: RULETA DE LA SUERTE (SPIN WHEEL SYSTEM)
Mecánica de alta retención que premia la fidelidad y la participación.

- **Moneda:** `SpinTickets` (guardado en el perfil de `DataService`).
  - Formas de obtención: Misiones diarias/semanales, Recompensas AFK, tiempo de juego y Robux.
- **Distribución y Probabilidades de los 8 Slots:**
  1. `750K Wins` $\rightarrow$ **25.0%**
  2. `1M Wins` $\rightarrow$ **18.0%**
  3. `Poción 2x Speed (15m)` $\rightarrow$ **20.0%**
  4. `Poción 2x Wins (15m)` $\rightarrow$ **20.0%**
  5. `Poción 2x Speed (30m)` $\rightarrow$ **8.0%**
  6. `3 Spin Tickets` $\rightarrow$ **5.0%**
  7. `Huge Wins Bundle (5M Wins)` $\rightarrow$ **3.9%**
  8. `Exclusive Evolution Skin (Desert Phoenix / Sand Phantom)` $\rightarrow$ **0.1%** (Ultra Raro)
- **Efecto de la Skin Exclusiva de Ruleta:**
  - Multiplicador pasivo permanente de **2x Speed** *únicamente mientras esté equipada* en el índice de evoluciones.
- **Seguridad en Servidor:**
  - El cliente solo pide girar (`SpinRequest`); el servidor descuenta el ticket, elige el resultado mediante pesos criptográficos (`Random.new()`), guarda en `DataService` y devuelve el índice ganador para la animación del UI.

---

### FEATURE 4: 3 NUEVAS EVOLUCIONES
- **Evolución 1 (Rebirth Tier N+1):** Desbloqueable al alcanzar el siguiente hito de Rebirths.
- **Evolución 2 (Rebirth Tier N+2):** Desbloqueable en el rango alto de Rebirths (Mundo 3).
- **Evolución 3 (Exclusiva de Ruleta 0.1%):** Desbloqueable únicamente en el Spin Wheel.
- **Multiplicadores:** Integrados en la fórmula de velocidad del personaje (`SpeedModifier` o `EvolveController`), garantizando que equipar/desequipar aplique y retire los boosts inmediatamente sin desincronizaciones.

---

### FEATURE 5: MUNDO 3 (DESERT / SAND WORLD)
- **Requisitos de Acceso:** Rebirth 15 + Nivel 200 (configurables en `Config.luau`).
- **Lógica de Teleport y Spawns:**
  - `WorldPortalService.server.luau` ampliado con el soporte del portal hacia World 3 (`World3PlaceId`).
  - Spawns y Checkpoints configurados de Etapa 1 a Etapa 11 en temática de desierto.
- **Persistencia Entre Mundos:**
  - Asegurar que `DataService` conserve intactos: Speed, Wins, Rebirths, Pociones activas, Boletos de Ruleta, Evoluciones y progreso de Misiones al teletransportarse entre World 1, World 2 y World 3.

---

### FEATURE 6: ADMIN ABUSE SYSTEM REWORK
Herramienta visual para que los administradores realicen eventos en vivo que enciendan la comunidad.

- **Diseño de UI:** El usuario proveerá los frames/mockups del UI; el backend queda 100% listo para conectarse.
- **Funcionalidades del Servidor (`AdminPanelService` + `MessagingService`):**
  - **Alcance:** Modos "Solo este Servidor" o "Global (Todos los Servidores)".
  - **Eventos Interactivos:**
    - *Disco Event:* Iluminación dinámica, cambio de colores de luces y música de fiesta.
    - *Confetti / Party Event:* Lluvia de partículas de confeti en todos los jugadores.
    - *Sandstorm Event:* Tormenta de arena visual y sonora temática de Mundo 3.
  - **Control de Música:** Selector de canciones, control de volumen, stop y reproducción global.
  - **Control de Boosts:** Activar 2x, 4x Speed o 2x, 5x Wins con multiplicador y duración personalizada.
  - **Treadmill de Administrador:** Cinta de correr exclusiva para administradores con velocidad y multiplicador customizable.

---

## 4. HOJA DE RUTA DE EJECUCIÓN (PASO A PASO EN EL NUEVO CHAT)

Cuando arranquemos el nuevo chat, la ejecución se dividirá en las siguientes fases ordenadas:

```
+-------------------------------------------------------------+
| FASE 1: Backend de Datos & Esquema (DataService)            |
| - ProfileSchema & ProfileReducers (AFK, Quests, Tickets)    |
| - Fallbacks seguros sin reset de datos existentes           |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
| FASE 2: Servicios de Retención (AFK & Quests)               |
| - AfkRewardsService (cálculos, timers, validación claim)    |
| - QuestService (catálogos diario/semanal, tracking eventos) |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
| FASE 3: Ruleta & Nuevas Evoluciones                         |
| - SpinWheelService (probabilidades, tiradas seguras)        |
| - Catálogo de 3 Evoluciones & lógica de multiplicador 2x    |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
| FASE 4: Mundo 3 & Transiciones Seguras                      |
| - WorldPortalService (World 3 PlaceId y requisitos)         |
| - Integración de pads, checkpoints y persistencia           |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
| FASE 5: Admin Abuse & Eventos Globales                      |
| - MessagingService para Disco, Confetti, Sandstorm y Boosts |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
| FASE 6: Integración de UI & Compilación Final               |
| - Conexión de los UIs provistos por el usuario              |
| - Loop de verificación de 22 suites y compilación .rbxl     |
+-------------------------------------------------------------+
```

---

## 5. COMANDOS RÁPIDOS PARA COMPILACIÓN Y TESTEO EN CUALQUIER MOMENTO

- **Sincronizar fuentes:** `lune run audit/export_compat_sources.luau`
- **Validar sintaxis:** `lune run audit/persistence/compile_merged.luau`
- **Construir lugares (.rbxl):** `lune run audit/build_core.luau`
- **Ejecutar las 22 suites de test:** `lune run audit/verify_all_loop.luau`

---
*Este documento queda archivado permanentemente en la raíz del proyecto para retomar de inmediato en el nuevo chat.*
