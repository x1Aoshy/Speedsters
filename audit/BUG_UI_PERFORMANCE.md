# Auditoría UI, consola y rendimiento — evidencia antes de cambios

Base revisada: `audit/merged/World1`, `audit/merged/World2` y binarios actuales `World1 Speedtercorrect.rbxl` / `world2 speedtster.rbxl`. Se conservan los fixes anteriores; esta auditoría amplía sus regresiones.

## Hallazgos comprobados en código / jerarquía

- **UI-A01, alta:** `RankRewardGui` sigue ausente de `StarterGui` de World1 en el binario actual. El cliente espera ese hijo indefinidamente. World2 sí lo contiene. El builder debe trasladar la plantilla authored de World1 desde ServerStorage.
- **UI-A02, media:** `ConsoleUiScale` controla modales solo por `ScreenGui.Enabled`. Hay paneles que permanecen ocultos (`Shop.Shop.Visible=false`, `Treadmill.TimeGift.Visible=false`). Al mostrarlos después de Enabled, la selección diferida inicial puede perderse; al destruir un modal la referencia activa queda obsoleta. No sigue Visible de las ramas del contenido ni cambios de botones.
- **UI-A03, media:** `ConsolePanelSupport` usa hardware conectado para seleccionar, incluso cuando se usa mouse; crea otro UIScale en paneles que ya tienen escala de layout/animación. Rank calcula tamaño fijo690x430 y solo escucha la cámara inicial, no sus reemplazos.
- **UI-A04, alta:** `World2SpeedForce.beginHold` y su callback demorado no comprueban menú/selección/chat; no cancelan el hold al abrir Roblox, desenfocar o desconectar el mando. Puede activar transición mientras el usuario navega UI.
- **UI-A05, media:** varios controladores conectan tanto Activated como MouseButton1Click a la misma acción. TimeGift envía el canje dos veces con mouse; Treadmill abre dos prompts y cierres de modales lanzan tweens duplicados. Activated cubre mouse/touch/gamepad.
- **UI-A06, media:** `RankRewardPanel` conserva referencias a partes streamed-out; vuelve a buscar solo si el array tiene longitud0. Si el pad se destruye y reaparece, puede quedar inaccesible localmente. Su `Touched` reabre el modal repetidamente al moverse dentro aunque el usuario lo cierre.

## Verificación previa de fixes preservados

- Rank ya pasa el nombre literal `RankRewardGui` a WaitForChild (error nil resuelto en fuente).
- Rebirth ya cambia exclusivamente Price; nombres/descripciones se conservan. Precio y conexiones se probarán contra las instancias reales.
- Sprint y Flight ya ignoran SelectedObject y CtrlShiftLock deja pasar D-pad con foco UI. Se amplía cobertura al resto de inputs.

## Pendiente

Inspeccionar geometría authored de Rank, corregir hallazgos, ejecutar mocks de eventos y compilar las fuentes. Las pruebas aisladas no prueban el render visual ni un mando real dentro de Roblox.

## Reanudación — 13 de septiembre, evidencia antes de cambios adicionales

Base correcta actual: snapshots `audit/incoming_20260913/{World1,World2}/input.rbxl`. UI-A01 está resuelto en el input actual de World1: RankRewardGui ya existe en StarterGui. El nombre anterior de World2 en las pruebas quedó obsoleto; las nuevas verificaciones usan los snapshots.

- **UI-A07, media:** DailyReward conecta tres veces el cierre (Activated, MouseButton1Click e InputBegan). Se conserva solo Activated. Shop tiene duplicación similar y se comunica al agente dueño de comercio.
- **UI-A08, alta:** Sprint y Flight cancelan al perder foco, pero el siguiente RenderStepped vuelve a leer botones mantenidos y puede reactivar; falta estado persistente de foco. Abrir un modal con mouse no crea SelectedObject, así que el bloqueo de habilidades no cubre esos menús. Se publicará el estado de modal visible desde ConsoleUiScale y los controles lo respetarán.
- **UI-A09, media:** ConsoleUiScale consume DPadUp para alternar el foco incluso cuando la selección ya está dentro de LeftSideBar. Eso impide navegar hacia arriba. Hay que dejar pasar DPadUp cuando ya se navega y reservar ButtonSelect para alternar.
- **UI-A10, media:** RankRewardPanel aplica cada respuesta Open del servidor como apertura nueva: repite tween/prompt y puede deshacer un cierre manual estando encima del pad. Se guardará el descarte hasta abandonar la zona, y Open será idempotente cuando ya esté abierto.
- **UI-A11, media:** ModalJuice añade su propia UIScale junto a escalas de layout/animación de los controladores, y vuelve a vincular al repetir WatchGui. Sus animaciones globales de cierre/icono también duplican las que ya tienen escala especializada. Debe respetar propietarios existentes, vincular una vez y reconocer Panel de Rank.
- **UI-A12, media:** MenuEvents determina abierto usando solo ScreenGui.Enabled antes de consultar MarkReady/isOpen. Un ScreenGui habilitado con contenido oculto se interpreta como abierto y el primer clic lo cierra. Se priorizará el callback del controlador y después el contenido visible.
