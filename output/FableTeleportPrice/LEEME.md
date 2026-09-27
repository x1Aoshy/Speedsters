# Exploit del teleport a stages (2026-09-20)

Verificar: `lune run audit/test_fable_teleport_price.luau places` (o toda la suite: `lune run audit/run_fable_checks.luau`, 19 suites). **Sin probar en Studio.**

## Qué pasaba
- El teleport a Stage N te deja junto a los pads Win y x2 de ese stage; pisar el pad paga y te devuelve al lobby, listo para comprar otro teleport.
- El **pad paga** `premio × todos los multiplicadores` (escalera x2…x32 × VIP × poción × confetti × boost del servidor) y el pad x2 el doble.
- El **teleport costaba** `base × raíz(escalera)` (la fórmula amortiguada de Flight, exponente 0,5): ni VIP, ni poción, ni boost, ni pad x2.
- Resultado: desde x4 en la escalera, o solo con el pase 2x Wins Pads, VIP, una poción o un boost, el pad pagaba más que el viaje. Bucle teleport → pad → teleport = Wins gratis.
- Ejemplo real (World 3, Stage 10, x32): el viaje costaba **65,6 M** y el pad pagaba **256 M** (512 M en el x2): +190 M por vuelta, en segundos.
- **Pasaba en los tres mundos** (mismo `TeleportSystem`): con la fórmula vieja, 254 de 324 combinaciones stage/escalera/pase x2 daban ganancia antes de contar VIP, pociones o boosts. World 3 era el peor por el tamaño de sus premios; World 1 también (sus viajes cuestan 2× el premio base, así que bastaba x4 + pase x2, o x8).

## El arreglo
- `Shared/WinsMath.GetStageTripPrice(base, multiplicador, tienePadsX2)`: el viaje escala con **exactamente el mismo multiplicador con el que paga el pad** (`_G.SpeedsterGetWinsMultiplier`, el mismo que usa `RewardPadClaims`) y se duplica para quien tiene el pase de pads x2.
- Como el costo base ya está por encima del premio base (×1,45 en World 2 y 3, redondeado a 25.000; ×2 en World 1), **el pad de llegada siempre devuelve menos de lo que costó el viaje**: mínimo 1,33 veces (World 2 Stage 3), comprobado en 3.888 combinaciones (3 mundos × 9 stages × 6 escalones × VIP × boosts temporales × pads x2).
- En términos de vueltas el teleport cuesta lo mismo para todos los jugadores; sigue sirviendo para lo que es: pagar por saltarte stages y seguir corriendo.
- El panel recibe el precio del servidor; el servidor le manda una cotización nueva cuando cambia cualquier multiplicador (poción, VIP, confetti, pads x2, boost del servidor) y rechaza un precio viejo con "Price updated".
- **Flight y Sonic Burst no cambian**: se compran una sola vez y no abren ningún bucle, así que conservan el precio amortiguado de la escalera.
- Extra: un viaje que quedó pendiente al desconectarse solo se completa si se pagó al precio de este mundo o más; si no, se devuelve su costo exacto. (World 3 comparte el código de mundo 1 con World 1 en el registro guardado, y un viaje de World 1 cuesta una fracción.) No toqué el formato guardado para no arriesgar perfiles con servidores viejos.

## Lo que NO hice
- No toqué las Wins que ya se farmearon con el bug: desde aquí no hay forma fiable de saber quién lo hizo. Si quieres, se puede registrar un evento de economía por viaje y por pad para detectarlo en Creator Hub.
- Los teleports por Robux siguen igual (pagan Robux cada vez, no hay bucle gratis).

Archivos: `Shared/WinsMath.luau`, `Worlds/TeleportSystem.server.luau`, `UI/TeleportController.client.luau`, comentarios de `Shared/Config.luau`. Copias de lo anterior en `output/FableTeleportPrice/backup_src`. `audit/test_wins_economy.luau` afirmaba la regla vieja ("x32 paga menos vueltas por el teleport") y ahora afirma la nueva.
