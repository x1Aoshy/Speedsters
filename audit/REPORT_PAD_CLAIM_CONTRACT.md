# Fase 0: contrato único de contacto de pads

Implementado el 13 septiembre 2026 en fuentes `audit/merged`; no se construyeron places ni se cambió economía/perfil.

## Hallazgos y cambios

- El trigger de Gemini tenía altura 14 y borde 4, pero `Intersects` lo expandía otra vez 2.5 studs horizontal / 2 vertical. Touched además admitía un radio independiente +18, mientras RewardPadClaims usaba +14. Ahora detector y claim consultan la misma geometría. Se conservan altura 14 y borde 4; no se alteran CFrame, Size o UI authored. Altura configurable por atributo de servidor `PadTriggerHeight` (1–24).
- Un corredor puede cruzar enteramente el pad en una muestra. El servidor conserva evidencia para **ese pad, ese root, esa muestra y esa geometría**, consumible una vez y durante un máximo de 1 segundo, siempre que el root siga en el endpoint observado. RewardPadClaims la acepta cuando el endpoint ya quedó fuera. No hay token/remoto controlado por cliente. MovementGuard sigue comprobando progresión y anomalías.
- Se invalida continuidad al cambiar root, serial de teleport o entrar/salir de gracia. El sweep tiene techo 256 y además un límite según WalkSpeed de servidor, intervalo acotado y tolerancia de replicación. Un salto de posición de 60 studs a velocidad 16 no genera recorrido ficticio.
- Se conserva un único índice espacial compartido; no hay GetDescendants/GetPartsInPart por frame. El volumen invisible no genera eventos físicos Touched duplicados. Un orden por primer cruce/distancia/registro selecciona solo un pad por muestra en solapamientos. La esfera que registra celdas incluye pads inclinados.
- La gracia de llegada no arma el latch. Callbacks que devuelven false habilitan un reintento cada 0.5 s mientras se permanece dentro; true o nil conserva latch hasta salir para no repetir prompts completados. Se corrigieron returns en los dos callbacks manuales de recompensas y precondiciones temporales de skip. No había tercer caller PadTouch activo en las fuentes.
- Se conserva retorno comprobado antes de premio, lock por jugador y retry idempotente de Commit. `IsAtPad` posterior al retorno **no usa evidencia antigua**.

## Archivos de producción editados

En ambos mundos: `ServerScriptService/Services/PadTouchService.luau` y `RewardPadClaims.luau`.
Además (autorizado por root, solo protocolo de returns):
- World1 `ServerScriptService/Gameplay/NewWorld1ManualStagePads.luau`.
- World2 `ServerScriptService/Gameplay/World2ManualStagePads.luau`.

## Pruebas ejecutadas

- `lune run audit/test_pad_claim_contract.luau`: carga ambos módulos reales de cada mundo con motor simulado. Paso rápido con endpoint fuera paga x16 una vez; prueba consumida invalidada por retorno; teletransporte corto a baja velocidad no genera sweep; geometría horizontal/vertical consistente; expiración de gracia sin salir; respawn sin barrido antiguo; retry limitado; solapamiento sin dos callbacks; limpieza al desconectar.
- `lune run audit/test_pad_volumes.luau`: entrada compatible ahora apunta a la prueba actual; deja de verificar la copia vieja `audit/PadTouchService.luau` y su altura obsoleta 5.
- `lune run audit/test_stage_transactions.luau World1` y `World2`: handlers reales y DataService/Adapter real con store simulado; precios x16, rechazo cotización antigua, 11 reembolsos exactos, timeout idempotente, retorno fallido/sin movimiento no paga, premio una vez con timeout y persistencia tras rejoin. Fixture usa nuevo módulo real de geometría.
- `lune run audit/persistence/compile_merged.luau`: PASS.

No son medidas de ping/CPU ni validación de física real. Falta Studio: correr a velocidades extremas con replicación retrasada, medir pads cercanos/inclinados y comparar visualmente la altura 14 con el salto autorizado. Una caja alta puede hacer intencionalmente más fácil activar el pad saltando; se mantuvo el diseño Gemini en lugar de inventar otro tamaño. El límite de sweep conserva falsos negativos ante gaps mayores a 256; una muestra extremadamente discontinua debe tratarse como endpoint y no como recorrido premiable.
