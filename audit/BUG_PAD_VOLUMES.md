# Pads: revisión antes de editar

Los inputs de Gemini actuales tienen fuentes idénticas a merged y ajustes de mapa más nuevos que el snapshot inicial. Se conservarán como nueva base. En World2 hay 46 partes desancladas, incluidas 28 marcadores de pads; sus alturas no son exactamente cero sino 0.00390625 studs. Sin embargo, el código oculta esos marcadores y crea pads runtime anclados de 0.5 studs. Engordar los marcadores alteraría getTopY y desplazaría los pads/UI; no resuelve por sí solo la detección runtime.

Corrección prevista: anclar marcadores authored sin cambiar CFrame/Size, conservar pad visual y billboard; crear volumen independiente invisible de 5 studs hacia arriba en runtime y detector servidor de segmentos para pasos rápidos. Compartir consulta con índice espacial, sin GetDescendants/GetPartsInPart por frame. Mantener Distance/MovementGuard/return/Commit en RewardPadClaims. No aumentar tolerancia de premios para aceptar teleports falsos.

El informe Gemini contiene hipótesis de saturación, no mediciones: llamadas SetAttribute no equivalen una por una a paquetes y no se ha medido ping/KB/s. Conveyor.Script configura una velocidad una vez; FadingScript cambia transparencia por pasos y colisión funcional. No se desactivarán indiscriminadamente.
