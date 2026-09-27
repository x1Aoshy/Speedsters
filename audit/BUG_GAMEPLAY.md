# Auditoría de gameplay y teletransportes

Fuentes autoritativas: `audit/merged/World1` y `audit/merged/World2`; mapas de entrada inspeccionados mediante Lune, sin editar perfiles reales.

## Hallazgos antes de editar

- **GP-02, crítico: reembolso multiplicado y destino equivocado de World2.** `Worlds/TeleportSystem.luau` cobra mediante `SpeedsterSpendWins` y, si falla `StageTeleportService.TeleportPlayer`, reembolsa mediante `SpeedsterAddWins`. Este último aplica `PermanentWinsMultiplier` a la recompensa. Con coste725000 y multiplicador16, una petición fallida crea10875000 Wins netos. El mapa real tiene SafeZone9.2 para Stage10 lógico y carece de SafeZone10.2; sin embargo el servicio genérico busca SafeZone10.2, mientras que `Gameplay/World2StageTeleportService` implementa la correspondencia correcta. Esto es una explicación concreta compatible con el reporte de111M en segundos, sin asumir identidad/saldo de un jugador.
- **GP-03, alto: premio antes de retorno y reentrada.** `World2ManualStagePads` concede Wins antes de comprobar el retorno al spawn, solo tiene cooldown por pad y carece de bloqueo durante yields. Fallo de retorno/reentradas de pads distintos permite más premios; World1 tiene bloqueo mientras ejecuta pero libera aun si el retorno falló. Ningún handler valida distancia real del HumanoidRootPart al pad además de Touched.
- **GP-04, alto: entrega fuera de ProcessReceipt.** Ambos pads conceden titularidad/multiplicador de producto en `PromptProductPurchaseFinished`. World1 además `checkPendingDoubleWins` concede una recompensa con x2 adicional antes de pasar por el mismo guard y flujo de retorno; puede acabar con x4. Un prompt cerrado no demuestra un recibo persistido.
- **GP-05, medio: rutas World2 sin rebase.** World2StageTeleportService no notifica MovementGuard, a diferencia del servicio genérico. MovementGuard usa la referencia genérica que no corresponde con Stage2=SafeZone1.2 en World2. La inspección encontró un único SpawnLocation de Workspace en el inicio correcto; no hay evidencia de spawn ausente en el archivo actual.
- **GP-06, rendimiento: búsqueda completa por teleport/sample.** Servicio genérico recorre Workspace completo para lava en cada salto y búsqueda case-insensitive por cada una de las once etapas en cada muestra de MovementGuard. Se debe cachear referencias y actualizar por eventos.

## Segunda inspección, antes de nuevas correcciones (2026-09-13)

- **GP-07, alto: fallback de RewardPadClaims evade la transacción.** Si falta handle, multiplica la recompensa y llama AddWins, que vuelve a multiplicar; además no toma el bloqueo por jugador. Se retirará esta ruta: DataLoaded no sustituye un handle válido.
- **GP-08, alto: reintento de premio compara tablas de handle por identidad.** DataService.GetHandle fabrica una tabla nueva por llamada; `== state.handle` nunca reconoce la misma sesión. Se compararán userId/sessionId/generation para preservar la operación incierta.
- **GP-09, alto: guard pierde etapas a velocidad legítima.** Solo reconoce el punto final de cada muestra y omite progreso durante tres segundos tras retorno. Un corredor rápido puede atravesar el radio de una etapa entre muestras o durante la gracia y quedar bloqueado 45 segundos. La corrección comprobará el segmento observado, manteniendo límites de desplazamiento y orden de etapas.
- **GP-10, alto: compra con Wins a premio amplificado.** El coste de salto es fijo (World2 Stage10=725000), pero el pad paga500000 x16=8000000. Aun arreglando el reembolso, saltar y reclamar crea7275000 Wins por ciclo; se requiere neutralizar el premio de la etapa comprada mientras se permite continuar corriendo a etapas posteriores. Esto se verificará con el equipo de economía antes de cambiar el comportamiento.

La corrección seguirá con pruebas de reembolso, fallo/reentrada y mapeo de etapas. Un mock no certifica física de Roblox ni conectividad entre places.
