-- ReplicatedStorage/Shared/RaceText.luau — Update 4 (2026-09-25): every word of the race HUD,
-- the results window, the lobby button, the invite, the Race panel, the gate sign and the race
-- toasts, in the 10 languages of Shared/TutorialText (en es pt ru ar id fr de th tr; anything
-- else reads English). Spanish and Portuguese are a third of the players, so they are written
-- as those players talk, not word for word. "Wins" stays "Wins" where TutorialText keeps it
-- (every language but Arabic); French puts a no-break space (\u{00A0}) before "!", ":" and "%".
-- Placeholders are {1}, {2}; Format fills them. Caps is the longest a line may be (characters,
-- with each placeholder counted as 3), checked by audit/test_u4_race_ui.
-- Pure data and functions: nothing here touches a service when it is required.
local TutorialText = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("TutorialText", 10))
	else require("./TutorialText")

local RaceText = {}

RaceText.Languages = TutorialText.Languages

RaceText.Caps = {
	-- HUD
	Starting = 22, Go = 10, GetReady = 22, InProgress = 30, FinishedStatus = 26, Waiting = 30,
	Mph = 20, Multiplier = 24, Accel = 14, Stamina = 20, You = 6, YouPlace = 18, Orb = 12, Studs = 16,
	HoldKey = 32, HoldPad = 26, HoldTouch = 22, StayGreen = 26, EasyZone = 18,
	StartPerfect = 30, StartGood = 26, StartStall = 18, Spikes = 18, FinishedBig = 24, NewBest = 18,
	Charge = 9, Boost = 9,
	-- Results
	ResultsTitle = 22, PlaceTop = 20, Time = 18, Best = 20, Dnf = 22, Dq = 22,
	Wins = 18, Speed = 20, Ticket = 26, FirstToday = 30, CapNote = 48, Pending = 30,
	RaceAgain = 16, Lobby = 10, LobbyIn = 14,
	-- Lobby button and invite
	Race = 10, Join = 12, InQueue = 14, Live = 16, Mega = 14, NextIn = 16, StartingSoon = 20,
	InviteTitle = 22, InviteBody = 40, InviteJoin = 10,
	-- Race panel
	NextRace = 20, Ready = 30, JoinRace = 20, LeaveQueue = 20, Rewards = 14, Finish = 14,
	FirstRaceToday = 48, Fastest = 22, Weekly = 14, AllTime = 16, YourBest = 34, YourBestNoRank = 28,
	NoTime = 22, Loading = 16, Empty = 40, Now = 12,
	-- Gate sign
	GateRecord = 36, GateStep = 24,
	-- Toasts (RaceEvent Toast keys and Unqueued reasons)
	RaceLockedTutorial = 48, StreamTimeout = 48, RaceOff = 48, RaceLoading = 48, RaceAfk = 48,
	RaceAlreadyQueued = 48, RaceDead = 48, RaceFalseStart = 48, RaceDisqualified = 48,
	Unavailable = 48, LeftRace = 48, RaceCooldown = 48,
	-- 2026-09-25: the Beginner queue refused (RaceService; the NPC greys it out too)
	RaceBracketLocked = 48,
	-- 2026-09-26 (owner): the races are closed while the Super Sonic vs Eggman event runs (RaceService.Close)
	RaceEventClosed = 48,
	-- 2026-09-25: a speed pad's boost (the HUD's feedback line)
	PadBoost = 14,
	-- Race HUD
	LeaveRace = 10, LeaveConfirm = 12,
}

local NBSP = "\u{00A0}"

RaceText.Strings = {
	en = {
		Starting = "STARTING: {1}s", Go = "GO!", GetReady = "Get ready!", InProgress = "Race in progress: {1}",
		FinishedStatus = "Finished! {1}", Waiting = "Waiting for racers...",
		Mph = "MPH: {1} / {2}", Multiplier = "Multiplier: x{1}", Accel = "MPH/s: {1}", Stamina = "STAMINA {1}%",
		You = "YOU", YouPlace = "You · {1}/{2}", Orb = "▼ ORB", Studs = "{1} studs",
		HoldKey = "HOLD [SHIFT] TO CHARGE", HoldPad = "HOLD TO CHARGE", HoldTouch = "HOLD CHARGE",
		StayGreen = "STAY IN THE GREEN!", EasyZone = "EASY ZONE",
		StartPerfect = "PERFECT START! +{1}%", StartGood = "GOOD START! +{1}%", StartStall = "STALLED!",
		Spikes = "OUCH! SPIKES", FinishedBig = "FINISHED {1}!", NewBest = "NEW BEST!",
		Charge = "CHARGE", Boost = "BOOST",
		ResultsTitle = "RACE RESULTS", PlaceTop = "{1} PLACE!", Time = "TIME {1}", Best = "BEST {1}",
		Dnf = "DID NOT FINISH", Dq = "DISQUALIFIED",
		Wins = "+{1} Wins", Speed = "+{1} Speed", Ticket = "+{1} Spin Ticket", FirstToday = "x2 FIRST RACE TODAY",
		CapNote = "Rewards reduced after 30 races an hour", Pending = "Counting rewards...",
		RaceAgain = "RACE AGAIN", Lobby = "LOBBY", LobbyIn = "LOBBY ({1})",
		Race = "RACE", Join = "JOIN!", InQueue = "IN QUEUE ✓", Live = "LIVE {1}", Mega = "MEGA RACE!",
		NextIn = "NEXT {1}", StartingSoon = "STARTING!",
		InviteTitle = "RACE IN {1}!", InviteBody = "{1} racers · up to +{2} Wins", InviteJoin = "JOIN",
		NextRace = "NEXT RACE", Ready = "{1} / {2} racers ready", JoinRace = "JOIN RACE", LeaveQueue = "LEAVE QUEUE",
		Rewards = "REWARDS", Finish = "Finish", FirstRaceToday = "First race today: x2 + Spin Ticket",
		Fastest = "FASTEST RACERS", Weekly = "WEEKLY", AllTime = "ALL-TIME",
		YourBest = "Your best: {1} · #{2}", YourBestNoRank = "Your best: {1}", NoTime = "No time yet",
		Loading = "Loading...", Empty = "No times yet. Be the first!", Now = "NOW",
		GateRecord = "Weekly record {1} by {2}", GateStep = "Step in to race!",
		RaceLockedTutorial = "Finish the tutorial first to race!", StreamTimeout = "Couldn't reach the track. Try again!",
		RaceOff = "Races are paused right now", RaceLoading = "Still loading, try again in a moment",
		RaceAfk = "Leave AFK Mode to race", RaceAlreadyQueued = "You're already in the race queue",
		RaceDead = "You can't join while respawning", RaceFalseStart = "False start! Wait for GO",
		RaceDisqualified = "Disqualified", Unavailable = "Couldn't join this race", LeftRace = "You left the race",
		-- 2026-09-25 (final fix): the race HUD's LEAVE (two taps) and the rejoin cooldown.
		LeaveRace = "LEAVE", LeaveConfirm = "SURE?", RaceCooldown = "Wait a moment before joining again",
		RaceBracketLocked = "Beginner races are for new racers!",
		RaceEventClosed = "Races are closed during the event",
		PadBoost = "BOOST!",
	},
	es = {
		Starting = "EMPIEZA EN: {1}s", Go = "¡YA!", GetReady = "¡Prepárate!", InProgress = "Carrera en curso: {1}",
		FinishedStatus = "¡Terminaste! {1}", Waiting = "Esperando corredores...",
		Mph = "MPH: {1} / {2}", Multiplier = "Multiplicador: x{1}", Accel = "MPH/s: {1}", Stamina = "ENERGÍA {1}%",
		You = "TÚ", YouPlace = "Tú · {1}/{2}", Orb = "▼ ORBE", Studs = "{1} studs",
		HoldKey = "MANTÉN [SHIFT] PARA CARGAR", HoldPad = "MANTÉN PARA CARGAR", HoldTouch = "MANTÉN CARGAR",
		StayGreen = "¡QUÉDATE EN EL VERDE!", EasyZone = "ZONA FÁCIL",
		StartPerfect = "¡SALIDA PERFECTA! +{1}%", StartGood = "¡BUENA SALIDA! +{1}%", StartStall = "¡MALA SALIDA!",
		Spikes = "¡AY! PINCHOS", FinishedBig = "¡LLEGASTE {1}!", NewBest = "¡NUEVO RÉCORD!",
		Charge = "CARGAR", Boost = "TURBO",
		ResultsTitle = "RESULTADOS", PlaceTop = "¡{1} LUGAR!", Time = "TIEMPO {1}", Best = "RÉCORD {1}",
		Dnf = "NO TERMINASTE", Dq = "DESCALIFICADO",
		Wins = "+{1} Wins", Speed = "+{1} Velocidad", Ticket = "+{1} Giro gratis", FirstToday = "x2 PRIMERA CARRERA DEL DÍA",
		CapNote = "Premios reducidos tras 30 carreras por hora", Pending = "Contando premios...",
		RaceAgain = "OTRA VEZ", Lobby = "LOBBY", LobbyIn = "LOBBY ({1})",
		Race = "CARRERA", Join = "¡ÚNETE!", InQueue = "EN COLA ✓", Live = "EN VIVO {1}", Mega = "¡MEGA CARRERA!",
		NextIn = "PRÓXIMA {1}", StartingSoon = "¡YA EMPIEZA!",
		InviteTitle = "¡CARRERA EN {1}!", InviteBody = "{1} corredores · hasta +{2} Wins", InviteJoin = "UNIRME",
		NextRace = "PRÓXIMA CARRERA", Ready = "{1} / {2} corredores listos", JoinRace = "UNIRME", LeaveQueue = "SALIR DE LA COLA",
		Rewards = "PREMIOS", Finish = "Llegar", FirstRaceToday = "Primera carrera del día: x2 + Giro gratis",
		Fastest = "LOS MÁS RÁPIDOS", Weekly = "SEMANAL", AllTime = "HISTÓRICO",
		YourBest = "Tu récord: {1} · #{2}", YourBestNoRank = "Tu récord: {1}", NoTime = "Aún sin tiempo",
		Loading = "Cargando...", Empty = "Aún no hay tiempos. ¡Sé el primero!", Now = "YA",
		GateRecord = "Récord semanal {1} de {2}", GateStep = "¡Entra para correr!",
		RaceLockedTutorial = "¡Termina el tutorial para poder correr!", StreamTimeout = "No se pudo llegar a la pista. ¡Prueba otra vez!",
		RaceOff = "Las carreras están en pausa", RaceLoading = "Todavía cargando, prueba en un momento",
		RaceAfk = "Sal del modo AFK para correr", RaceAlreadyQueued = "Ya estás en la cola de la carrera",
		RaceDead = "No puedes unirte mientras reapareces", RaceFalseStart = "¡Salida en falso! Espera al ¡YA!",
		RaceDisqualified = "Descalificado", Unavailable = "No pudiste entrar a esta carrera", LeftRace = "Saliste de la carrera",
		-- 2026-09-25 (final fix): the race HUD's LEAVE (two taps) and the rejoin cooldown.
		LeaveRace = "SALIR", LeaveConfirm = "¿SEGURO?", RaceCooldown = "Espera un momento para volver a unirte",
		RaceBracketLocked = "¡Las carreras de novatos son para nuevos!",
		RaceEventClosed = "Las carreras están cerradas durante el evento",
		PadBoost = "¡TURBO!",
	},
	pt = {
		Starting = "COMEÇA EM: {1}s", Go = "JÁ!", GetReady = "Prepare-se!", InProgress = "Corrida rolando: {1}",
		FinishedStatus = "Terminou! {1}", Waiting = "Esperando corredores...",
		Mph = "MPH: {1} / {2}", Multiplier = "Multiplicador: x{1}", Accel = "MPH/s: {1}", Stamina = "ENERGIA {1}%",
		You = "VOCÊ", YouPlace = "Você · {1}/{2}", Orb = "▼ ORBE", Studs = "{1} studs",
		HoldKey = "SEGURE [SHIFT] PRA CARREGAR", HoldPad = "SEGURE PRA CARREGAR", HoldTouch = "SEGURE CARREGAR",
		StayGreen = "FIQUE NO VERDE!", EasyZone = "ZONA FÁCIL",
		StartPerfect = "LARGADA PERFEITA! +{1}%", StartGood = "BOA LARGADA! +{1}%", StartStall = "LARGADA RUIM!",
		Spikes = "AI! ESPINHOS", FinishedBig = "CHEGOU EM {1}!", NewBest = "NOVO RECORDE!",
		Charge = "CARREGAR", Boost = "TURBO",
		ResultsTitle = "RESULTADOS", PlaceTop = "{1} LUGAR!", Time = "TEMPO {1}", Best = "RECORDE {1}",
		Dnf = "NÃO TERMINOU", Dq = "DESCLASSIFICADO",
		Wins = "+{1} Wins", Speed = "+{1} Velocidade", Ticket = "+{1} Giro grátis", FirstToday = "x2 PRIMEIRA CORRIDA DO DIA",
		CapNote = "Prêmios menores depois de 30 corridas por hora", Pending = "Contando prêmios...",
		RaceAgain = "DE NOVO", Lobby = "LOBBY", LobbyIn = "LOBBY ({1})",
		Race = "CORRIDA", Join = "ENTRAR!", InQueue = "NA FILA ✓", Live = "AO VIVO {1}", Mega = "MEGA CORRIDA!",
		NextIn = "PRÓXIMA {1}", StartingSoon = "JÁ VAI COMEÇAR!",
		InviteTitle = "CORRIDA EM {1}!", InviteBody = "{1} corredores · até +{2} Wins", InviteJoin = "ENTRAR",
		NextRace = "PRÓXIMA CORRIDA", Ready = "{1} / {2} corredores prontos", JoinRace = "ENTRAR NA CORRIDA", LeaveQueue = "SAIR DA FILA",
		Rewards = "PRÊMIOS", Finish = "Chegar", FirstRaceToday = "Primeira corrida do dia: x2 + Giro grátis",
		Fastest = "MAIS RÁPIDOS", Weekly = "SEMANAL", AllTime = "GERAL",
		YourBest = "Seu recorde: {1} · #{2}", YourBestNoRank = "Seu recorde: {1}", NoTime = "Sem tempo ainda",
		Loading = "Carregando...", Empty = "Nenhum tempo ainda. Seja o primeiro!", Now = "JÁ",
		GateRecord = "Recorde semanal {1} de {2}", GateStep = "Entre pra correr!",
		RaceLockedTutorial = "Termine o tutorial pra poder correr!", StreamTimeout = "Não deu pra chegar na pista. Tenta de novo!",
		RaceOff = "As corridas estão pausadas agora", RaceLoading = "Ainda carregando, tenta daqui a pouco",
		RaceAfk = "Saia do modo AFK pra correr", RaceAlreadyQueued = "Você já está na fila da corrida",
		RaceDead = "Não dá pra entrar enquanto renasce", RaceFalseStart = "Largada queimada! Espere o JÁ",
		RaceDisqualified = "Desclassificado", Unavailable = "Não deu pra entrar nesta corrida", LeftRace = "Você saiu da corrida",
		-- 2026-09-25 (final fix): the race HUD's LEAVE (two taps) and the rejoin cooldown.
		LeaveRace = "SAIR", LeaveConfirm = "CERTEZA?", RaceCooldown = "Espere um pouco pra entrar de novo",
		RaceBracketLocked = "Corrida de iniciante é só pra quem é novo!",
		RaceEventClosed = "As corridas estão fechadas durante o evento",
		PadBoost = "TURBO!",
	},
	ru = {
		Starting = "СТАРТ ЧЕРЕЗ: {1}с", Go = "ВПЕРЁД!", GetReady = "Приготовься!", InProgress = "Гонка идёт: {1}",
		FinishedStatus = "Финиш! {1}", Waiting = "Ждём гонщиков...",
		Mph = "MPH: {1} / {2}", Multiplier = "Множитель: x{1}", Accel = "MPH/с: {1}", Stamina = "ВЫНОСЛИВОСТЬ {1}%",
		You = "ТЫ", YouPlace = "Ты · {1}/{2}", Orb = "▼ СФЕРА", Studs = "{1} studs",
		HoldKey = "ДЕРЖИ [SHIFT] ДЛЯ ЗАРЯДА", HoldPad = "ДЕРЖИ ДЛЯ ЗАРЯДА", HoldTouch = "ДЕРЖИ ЗАРЯД",
		StayGreen = "ДЕРЖИСЬ В ЗЕЛЁНОМ!", EasyZone = "ЛЁГКАЯ ЗОНА",
		StartPerfect = "ИДЕАЛЬНЫЙ СТАРТ! +{1}%", StartGood = "ХОРОШИЙ СТАРТ! +{1}%", StartStall = "ЗАГЛОХ!",
		Spikes = "АЙ! ШИПЫ", FinishedBig = "ФИНИШ: {1}!", NewBest = "НОВЫЙ РЕКОРД!",
		Charge = "ЗАРЯД", Boost = "БУСТ",
		ResultsTitle = "ИТОГИ ГОНКИ", PlaceTop = "{1} МЕСТО!", Time = "ВРЕМЯ {1}", Best = "РЕКОРД {1}",
		Dnf = "НЕ ФИНИШИРОВАЛ", Dq = "ДИСКВАЛИФИКАЦИЯ",
		Wins = "+{1} Wins", Speed = "+{1} Скорости", Ticket = "+{1} Спин", FirstToday = "x2 ПЕРВАЯ ГОНКА ЗА ДЕНЬ",
		CapNote = "Награды меньше после 30 гонок в час", Pending = "Считаем награды...",
		RaceAgain = "ЕЩЁ РАЗ", Lobby = "ЛОББИ", LobbyIn = "ЛОББИ ({1})",
		Race = "ГОНКА", Join = "ВОЙТИ!", InQueue = "В ОЧЕРЕДИ ✓", Live = "ИДЁТ {1}", Mega = "МЕГА-ГОНКА!",
		NextIn = "ЧЕРЕЗ {1}", StartingSoon = "СТАРТУЕМ!",
		InviteTitle = "ГОНКА ЧЕРЕЗ {1}!", InviteBody = "{1} гонщиков · до +{2} Wins", InviteJoin = "ВОЙТИ",
		NextRace = "СЛЕДУЮЩАЯ ГОНКА", Ready = "Готовы: {1} / {2}", JoinRace = "В ГОНКУ", LeaveQueue = "ВЫЙТИ ИЗ ОЧЕРЕДИ",
		Rewards = "НАГРАДЫ", Finish = "Финиш", FirstRaceToday = "Первая гонка за день: x2 + Спин",
		Fastest = "САМЫЕ БЫСТРЫЕ", Weekly = "НЕДЕЛЯ", AllTime = "ВСЁ ВРЕМЯ",
		YourBest = "Твой рекорд: {1} · #{2}", YourBestNoRank = "Твой рекорд: {1}", NoTime = "Пока без времени",
		Loading = "Загрузка...", Empty = "Пока нет времён. Будь первым!", Now = "СЕЙЧАС",
		GateRecord = "Рекорд недели {1}: {2}", GateStep = "Заходи и беги!",
		RaceLockedTutorial = "Пройди обучение, чтобы участвовать!", StreamTimeout = "Не удалось попасть на трассу. Попробуй ещё!",
		RaceOff = "Гонки сейчас на паузе", RaceLoading = "Ещё загружается, попробуй чуть позже",
		RaceAfk = "Выйди из режима AFK, чтобы участвовать", RaceAlreadyQueued = "Ты уже в очереди на гонку",
		RaceDead = "Нельзя войти во время возрождения", RaceFalseStart = "Фальстарт! Жди команды",
		RaceDisqualified = "Дисквалификация", Unavailable = "Не удалось войти в эту гонку", LeftRace = "Ты покинул гонку",
		-- 2026-09-25 (final fix): the race HUD's LEAVE (two taps) and the rejoin cooldown.
		LeaveRace = "ВЫЙТИ", LeaveConfirm = "ТОЧНО?", RaceCooldown = "Подожди немного перед новым входом",
		RaceBracketLocked = "Гонки новичков — только для новичков!",
		RaceEventClosed = "Во время события гонки закрыты",
		PadBoost = "УСКОРЕНИЕ!",
	},
	ar = {
		Starting = "البداية بعد: {1}ث", Go = "انطلق!", GetReady = "استعد!", InProgress = "السباق جارٍ: {1}",
		FinishedStatus = "أنهيت! {1}", Waiting = "بانتظار المتسابقين...",
		Mph = "MPH: {1} / {2}", Multiplier = "المضاعف: x{1}", Accel = "MPH/ث: {1}", Stamina = "الطاقة {1}%",
		You = "أنت", YouPlace = "أنت · {1}/{2}", Orb = "▼ الكرة", Studs = "{1} studs",
		HoldKey = "اضغط [SHIFT] مطولًا للشحن", HoldPad = "اضغط مطولًا للشحن", HoldTouch = "اضغط مطولًا للشحن",
		StayGreen = "ابقَ في الأخضر!", EasyZone = "منطقة سهلة",
		StartPerfect = "انطلاقة مثالية! +{1}%", StartGood = "انطلاقة جيدة! +{1}%", StartStall = "تعثّرت!",
		Spikes = "آخ! أشواك", FinishedBig = "أنهيت {1}!", NewBest = "رقم قياسي جديد!",
		Charge = "شحن", Boost = "تعزيز",
		ResultsTitle = "نتائج السباق", PlaceTop = "المركز {1}!", Time = "الوقت {1}", Best = "الأفضل {1}",
		Dnf = "لم تُكمل السباق", Dq = "مُستبعَد",
		Wins = "+{1} انتصارات", Speed = "+{1} سرعة", Ticket = "+{1} دورة عجلة", FirstToday = "x2 أول سباق اليوم",
		CapNote = "تقل الجوائز بعد 30 سباقًا في الساعة", Pending = "جارٍ حساب الجوائز...",
		RaceAgain = "سباق آخر", Lobby = "الردهة", LobbyIn = "الردهة ({1})",
		Race = "سباق", Join = "انضم!", InQueue = "في الطابور ✓", Live = "مباشر {1}", Mega = "سباق ضخم!",
		NextIn = "التالي {1}", StartingSoon = "يبدأ الآن!",
		InviteTitle = "سباق بعد {1}!", InviteBody = "{1} متسابقين · حتى +{2} انتصارات", InviteJoin = "انضم",
		NextRace = "السباق التالي", Ready = "{1} / {2} متسابقين جاهزون", JoinRace = "انضم للسباق", LeaveQueue = "غادر الطابور",
		Rewards = "الجوائز", Finish = "إنهاء", FirstRaceToday = "أول سباق اليوم: x2 + دورة عجلة",
		Fastest = "الأسرع", Weekly = "أسبوعي", AllTime = "كل الأوقات",
		YourBest = "أفضل وقت لك: {1} · #{2}", YourBestNoRank = "أفضل وقت لك: {1}", NoTime = "لا وقت بعد",
		Loading = "جارٍ التحميل...", Empty = "لا أوقات بعد. كن الأول!", Now = "الآن",
		GateRecord = "الرقم الأسبوعي {1} لـ {2}", GateStep = "ادخل لتتسابق!",
		RaceLockedTutorial = "أكمل الشرح أولًا لتتسابق!", StreamTimeout = "تعذّر الوصول إلى المضمار. حاول مجددًا!",
		RaceOff = "السباقات متوقفة الآن", RaceLoading = "ما زال التحميل جاريًا، حاول بعد قليل",
		RaceAfk = "اخرج من وضع AFK لتتسابق", RaceAlreadyQueued = "أنت في طابور السباق بالفعل",
		RaceDead = "لا يمكنك الانضمام أثناء العودة", RaceFalseStart = "انطلاقة خاطئة! انتظر الإشارة",
		RaceDisqualified = "مُستبعَد", Unavailable = "تعذّر الانضمام لهذا السباق", LeftRace = "غادرت السباق",
		-- 2026-09-25 (final fix): the race HUD's LEAVE (two taps) and the rejoin cooldown.
		LeaveRace = "خروج", LeaveConfirm = "متأكد؟", RaceCooldown = "انتظر قليلًا قبل الانضمام مجددًا",
		RaceBracketLocked = "سباقات المبتدئين للاعبين الجدد فقط!",
		RaceEventClosed = "السباقات مغلقة أثناء الحدث",
		PadBoost = "تسريع!",
	},
	id = {
		Starting = "MULAI DALAM: {1}d", Go = "GO!", GetReady = "Bersiap!", InProgress = "Balapan berlangsung: {1}",
		FinishedStatus = "Finis! {1}", Waiting = "Menunggu pembalap...",
		Mph = "MPH: {1} / {2}", Multiplier = "Pengali: x{1}", Accel = "MPH/d: {1}", Stamina = "STAMINA {1}%",
		You = "KAMU", YouPlace = "Kamu · {1}/{2}", Orb = "▼ ORB", Studs = "{1} studs",
		HoldKey = "TAHAN [SHIFT] UNTUK MENGISI", HoldPad = "TAHAN UNTUK MENGISI", HoldTouch = "TAHAN ISI",
		StayGreen = "TETAP DI HIJAU!", EasyZone = "ZONA MUDAH",
		StartPerfect = "START SEMPURNA! +{1}%", StartGood = "START BAGUS! +{1}%", StartStall = "MOGOK!",
		Spikes = "ADUH! DURI", FinishedBig = "FINIS {1}!", NewBest = "REKOR BARU!",
		Charge = "ISI", Boost = "BOOST",
		ResultsTitle = "HASIL BALAPAN", PlaceTop = "PERINGKAT {1}!", Time = "WAKTU {1}", Best = "TERBAIK {1}",
		Dnf = "TIDAK FINIS", Dq = "DIDISKUALIFIKASI",
		Wins = "+{1} Wins", Speed = "+{1} Kecepatan", Ticket = "+{1} Putaran Gratis", FirstToday = "x2 BALAPAN PERTAMA HARI INI",
		CapNote = "Hadiah berkurang setelah 30 balapan per jam", Pending = "Menghitung hadiah...",
		RaceAgain = "BALAP LAGI", Lobby = "LOBI", LobbyIn = "LOBI ({1})",
		Race = "BALAP", Join = "IKUT!", InQueue = "ANTRE ✓", Live = "LIVE {1}", Mega = "MEGA BALAP!",
		NextIn = "BERIKUT {1}", StartingSoon = "SEGERA MULAI!",
		InviteTitle = "BALAPAN DALAM {1}!", InviteBody = "{1} pembalap · hingga +{2} Wins", InviteJoin = "IKUT",
		NextRace = "BALAPAN BERIKUTNYA", Ready = "{1} / {2} pembalap siap", JoinRace = "IKUT BALAPAN", LeaveQueue = "KELUAR ANTREAN",
		Rewards = "HADIAH", Finish = "Finis", FirstRaceToday = "Balapan pertama hari ini: x2 + Putaran Gratis",
		Fastest = "PALING CEPAT", Weekly = "MINGGUAN", AllTime = "SEPANJANG MASA",
		YourBest = "Terbaikmu: {1} · #{2}", YourBestNoRank = "Terbaikmu: {1}", NoTime = "Belum ada waktu",
		Loading = "Memuat...", Empty = "Belum ada waktu. Jadilah yang pertama!", Now = "SEKARANG",
		GateRecord = "Rekor mingguan {1} oleh {2}", GateStep = "Masuk untuk balapan!",
		RaceLockedTutorial = "Selesaikan tutorial dulu untuk balapan!", StreamTimeout = "Gagal mencapai lintasan. Coba lagi!",
		RaceOff = "Balapan sedang dijeda", RaceLoading = "Masih memuat, coba sebentar lagi",
		RaceAfk = "Keluar dari Mode AFK untuk balapan", RaceAlreadyQueued = "Kamu sudah dalam antrean balapan",
		RaceDead = "Tidak bisa ikut saat respawn", RaceFalseStart = "Start curi! Tunggu aba-aba",
		RaceDisqualified = "Didiskualifikasi", Unavailable = "Tidak bisa ikut balapan ini", LeftRace = "Kamu keluar dari balapan",
		-- 2026-09-25 (final fix): the race HUD's LEAVE (two taps) and the rejoin cooldown.
		LeaveRace = "KELUAR", LeaveConfirm = "YAKIN?", RaceCooldown = "Tunggu sebentar sebelum ikut lagi",
		RaceBracketLocked = "Balapan pemula hanya untuk pemain baru!",
		RaceEventClosed = "Balapan ditutup selama event",
		PadBoost = "NGEBUT!",
	},
	fr = {
		Starting = "DÉPART DANS" .. NBSP .. ": {1}s", Go = "PARTEZ" .. NBSP .. "!", GetReady = "Prépare-toi" .. NBSP .. "!",
		InProgress = "Course en cours" .. NBSP .. ": {1}", FinishedStatus = "Arrivé" .. NBSP .. "! {1}", Waiting = "En attente de coureurs...",
		Mph = "MPH" .. NBSP .. ": {1} / {2}", Multiplier = "Multiplicateur" .. NBSP .. ": x{1}", Accel = "MPH/s" .. NBSP .. ": {1}",
		Stamina = "ÉNERGIE {1}" .. NBSP .. "%",
		You = "TOI", YouPlace = "Toi · {1}/{2}", Orb = "▼ ORBE", Studs = "{1} studs",
		HoldKey = "MAINTIENS [SHIFT] POUR CHARGER", HoldPad = "MAINTIENS POUR CHARGER", HoldTouch = "MAINTIENS CHARGER",
		StayGreen = "RESTE DANS LE VERT" .. NBSP .. "!", EasyZone = "ZONE FACILE",
		StartPerfect = "DÉPART PARFAIT" .. NBSP .. "! +{1}" .. NBSP .. "%", StartGood = "BON DÉPART" .. NBSP .. "! +{1}" .. NBSP .. "%",
		StartStall = "CALÉ" .. NBSP .. "!",
		Spikes = "AÏE" .. NBSP .. "! PIQUES", FinishedBig = "ARRIVÉ {1}" .. NBSP .. "!", NewBest = "NOUVEAU RECORD" .. NBSP .. "!",
		Charge = "CHARGER", Boost = "TURBO",
		ResultsTitle = "RÉSULTATS", PlaceTop = "{1} PLACE" .. NBSP .. "!", Time = "TEMPS {1}", Best = "RECORD {1}",
		Dnf = "NON CLASSÉ", Dq = "DISQUALIFIÉ",
		Wins = "+{1} Wins", Speed = "+{1} Vitesse", Ticket = "+{1} Tour de roue", FirstToday = "x2 PREMIÈRE COURSE DU JOUR",
		CapNote = "Récompenses réduites après 30 courses par heure", Pending = "Calcul des récompenses...",
		RaceAgain = "REJOUER", Lobby = "LOBBY", LobbyIn = "LOBBY ({1})",
		Race = "COURSE", Join = "REJOINS" .. NBSP .. "!", InQueue = "EN FILE ✓", Live = "EN COURS {1}", Mega = "MÉGA COURSE" .. NBSP .. "!",
		NextIn = "PROCHAINE {1}", StartingSoon = "ÇA COMMENCE" .. NBSP .. "!",
		InviteTitle = "COURSE DANS {1}" .. NBSP .. "!", InviteBody = "{1} coureurs · jusqu'à +{2} Wins", InviteJoin = "REJOINDRE",
		NextRace = "PROCHAINE COURSE", Ready = "{1} / {2} coureurs prêts", JoinRace = "REJOINDRE", LeaveQueue = "QUITTER LA FILE",
		Rewards = "RÉCOMPENSES", Finish = "Arrivée", FirstRaceToday = "Première course du jour" .. NBSP .. ": x2 + Tour de roue",
		Fastest = "LES PLUS RAPIDES", Weekly = "SEMAINE", AllTime = "GÉNÉRAL",
		YourBest = "Ton record" .. NBSP .. ": {1} · #{2}", YourBestNoRank = "Ton record" .. NBSP .. ": {1}", NoTime = "Pas encore de temps",
		Loading = "Chargement...", Empty = "Aucun temps. Sois le premier" .. NBSP .. "!", Now = "MAINTENANT",
		GateRecord = "Record de la semaine {1} par {2}", GateStep = "Entre pour courir" .. NBSP .. "!",
		RaceLockedTutorial = "Termine le tutoriel pour courir" .. NBSP .. "!", StreamTimeout = "Piste inaccessible. Réessaie" .. NBSP .. "!",
		RaceOff = "Les courses sont en pause", RaceLoading = "Chargement en cours, réessaie bientôt",
		RaceAfk = "Quitte le mode AFK pour courir", RaceAlreadyQueued = "Tu es déjà dans la file de la course",
		RaceDead = "Impossible de rejoindre en réapparaissant", RaceFalseStart = "Faux départ" .. NBSP .. "! Attends le signal",
		RaceDisqualified = "Disqualifié", Unavailable = "Impossible de rejoindre cette course", LeftRace = "Tu as quitté la course",
		-- 2026-09-25 (final fix): the race HUD's LEAVE (two taps) and the rejoin cooldown.
		LeaveRace = "QUITTER", LeaveConfirm = "SÛR" .. NBSP .. "?", RaceCooldown = "Attends un instant avant de rejoindre",
		RaceBracketLocked = "Courses débutants réservées aux nouveaux" .. NBSP .. "!",
		RaceEventClosed = "Les courses sont fermées pendant l'événement",
		PadBoost = "TURBO" .. NBSP .. "!",
	},
	de = {
		Starting = "START IN: {1}s", Go = "LOS!", GetReady = "Mach dich bereit!", InProgress = "Rennen läuft: {1}",
		FinishedStatus = "Im Ziel! {1}", Waiting = "Warte auf Läufer...",
		Mph = "MPH: {1} / {2}", Multiplier = "Multiplikator: x{1}", Accel = "MPH/s: {1}", Stamina = "AUSDAUER {1}%",
		You = "DU", YouPlace = "Du · {1}/{2}", Orb = "▼ ORB", Studs = "{1} Studs",
		HoldKey = "[SHIFT] HALTEN ZUM AUFLADEN", HoldPad = "HALTEN ZUM AUFLADEN", HoldTouch = "AUFLADEN HALTEN",
		StayGreen = "BLEIB IM GRÜNEN!", EasyZone = "LEICHTE ZONE",
		StartPerfect = "PERFEKTER START! +{1}%", StartGood = "GUTER START! +{1}%", StartStall = "ABGEWÜRGT!",
		Spikes = "AUA! STACHELN", FinishedBig = "IM ZIEL: {1}!", NewBest = "NEUE BESTZEIT!",
		Charge = "LADEN", Boost = "BOOST",
		ResultsTitle = "ERGEBNISSE", PlaceTop = "{1} PLATZ!", Time = "ZEIT {1}", Best = "BESTZEIT {1}",
		Dnf = "NICHT IM ZIEL", Dq = "DISQUALIFIZIERT",
		Wins = "+{1} Wins", Speed = "+{1} Tempo", Ticket = "+{1} Glücksrad-Dreh", FirstToday = "x2 ERSTES RENNEN HEUTE",
		CapNote = "Weniger Belohnung nach 30 Rennen pro Stunde", Pending = "Belohnungen zählen...",
		RaceAgain = "NOCHMAL", Lobby = "LOBBY", LobbyIn = "LOBBY ({1})",
		Race = "RENNEN", Join = "MACH MIT!", InQueue = "WARTET ✓", Live = "LÄUFT {1}", Mega = "MEGA-RENNEN!",
		NextIn = "NÄCHSTES {1}", StartingSoon = "GLEICH GEHT'S LOS!",
		InviteTitle = "RENNEN IN {1}!", InviteBody = "{1} Läufer · bis zu +{2} Wins", InviteJoin = "MITMACHEN",
		NextRace = "NÄCHSTES RENNEN", Ready = "{1} / {2} Läufer bereit", JoinRace = "MITMACHEN", LeaveQueue = "AUSSTEIGEN",
		Rewards = "BELOHNUNGEN", Finish = "Im Ziel", FirstRaceToday = "Erstes Rennen heute: x2 + Glücksrad-Dreh",
		Fastest = "SCHNELLSTE LÄUFER", Weekly = "WOCHE", AllTime = "ALLZEIT",
		YourBest = "Deine Bestzeit: {1} · #{2}", YourBestNoRank = "Deine Bestzeit: {1}", NoTime = "Noch keine Zeit",
		Loading = "Lädt...", Empty = "Noch keine Zeiten. Sei der Erste!", Now = "JETZT",
		GateRecord = "Wochenrekord {1} von {2}", GateStep = "Tritt ein zum Rennen!",
		RaceLockedTutorial = "Schließ erst das Tutorial ab!", StreamTimeout = "Strecke nicht erreicht. Versuch's nochmal!",
		RaceOff = "Rennen sind gerade pausiert", RaceLoading = "Lädt noch, versuch es gleich nochmal",
		RaceAfk = "Verlass den AFK-Modus zum Rennen", RaceAlreadyQueued = "Du wartest schon auf das Rennen",
		RaceDead = "Beim Respawn kannst du nicht beitreten", RaceFalseStart = "Fehlstart! Warte auf LOS",
		RaceDisqualified = "Disqualifiziert", Unavailable = "Beitritt zum Rennen fehlgeschlagen", LeftRace = "Du hast das Rennen verlassen",
		-- 2026-09-25 (final fix): the race HUD's LEAVE (two taps) and the rejoin cooldown.
		LeaveRace = "VERLASSEN", LeaveConfirm = "SICHER?", RaceCooldown = "Warte kurz, bevor du wieder beitrittst",
		RaceBracketLocked = "Anfängerrennen sind nur für Neue!",
		RaceEventClosed = "Rennen sind während des Events geschlossen",
		PadBoost = "TURBO!",
	},
	th = {
		Starting = "เริ่มใน: {1} วิ", Go = "ไป!", GetReady = "เตรียมตัว!", InProgress = "กำลังแข่ง: {1}",
		FinishedStatus = "เข้าเส้นชัย! {1}", Waiting = "รอผู้แข่ง...",
		Mph = "MPH: {1} / {2}", Multiplier = "ตัวคูณ: x{1}", Accel = "MPH/วิ: {1}", Stamina = "สตามินา {1}%",
		You = "คุณ", YouPlace = "คุณ · {1}/{2}", Orb = "▼ ลูกแก้ว", Studs = "{1} สตั๊ด",
		HoldKey = "กด [SHIFT] ค้างเพื่อชาร์จ", HoldPad = "กดค้างเพื่อชาร์จ", HoldTouch = "กดค้างเพื่อชาร์จ",
		StayGreen = "อยู่ในโซนเขียว!", EasyZone = "โซนง่าย",
		StartPerfect = "ออกตัวเพอร์เฟกต์! +{1}%", StartGood = "ออกตัวดี! +{1}%", StartStall = "ออกตัวพลาด!",
		Spikes = "โอ๊ย! หนาม", FinishedBig = "เข้าเส้นชัยที่ {1}!", NewBest = "สถิติใหม่!",
		Charge = "ชาร์จ", Boost = "บูสต์",
		ResultsTitle = "ผลการแข่ง", PlaceTop = "อันดับ {1}!", Time = "เวลา {1}", Best = "ดีที่สุด {1}",
		Dnf = "ไม่เข้าเส้นชัย", Dq = "ถูกตัดสิทธิ์",
		Wins = "+{1} Wins", Speed = "+{1} ความเร็ว", Ticket = "+{1} สิทธิ์หมุนวงล้อ", FirstToday = "x2 การแข่งแรกของวัน",
		CapNote = "รางวัลลดลงหลังแข่ง 30 ครั้งต่อชั่วโมง", Pending = "กำลังนับรางวัล...",
		RaceAgain = "แข่งอีกครั้ง", Lobby = "ล็อบบี้", LobbyIn = "ล็อบบี้ ({1})",
		Race = "แข่ง", Join = "เข้าร่วม!", InQueue = "อยู่ในคิว ✓", Live = "กำลังแข่ง {1}", Mega = "เมกะเรซ!",
		NextIn = "ถัดไป {1}", StartingSoon = "กำลังเริ่ม!",
		InviteTitle = "แข่งใน {1}!", InviteBody = "{1} คน · สูงสุด +{2} Wins", InviteJoin = "เข้าร่วม",
		NextRace = "การแข่งถัดไป", Ready = "พร้อม {1} / {2} คน", JoinRace = "เข้าร่วมแข่ง", LeaveQueue = "ออกจากคิว",
		Rewards = "รางวัล", Finish = "เข้าเส้นชัย", FirstRaceToday = "การแข่งแรกของวัน: x2 + สิทธิ์หมุน",
		Fastest = "นักวิ่งที่เร็วที่สุด", Weekly = "รายสัปดาห์", AllTime = "ตลอดกาล",
		YourBest = "สถิติคุณ: {1} · #{2}", YourBestNoRank = "สถิติคุณ: {1}", NoTime = "ยังไม่มีเวลา",
		Loading = "กำลังโหลด...", Empty = "ยังไม่มีเวลา มาเป็นคนแรก!", Now = "ตอนนี้",
		GateRecord = "สถิติสัปดาห์ {1} โดย {2}", GateStep = "เดินเข้ามาเพื่อแข่ง!",
		RaceLockedTutorial = "ผ่านบทสอนก่อนจึงจะแข่งได้!", StreamTimeout = "ไปสนามไม่ได้ ลองอีกครั้ง!",
		RaceOff = "การแข่งหยุดชั่วคราว", RaceLoading = "ยังโหลดอยู่ ลองใหม่อีกสักครู่",
		RaceAfk = "ออกจากโหมด AFK ก่อนแข่ง", RaceAlreadyQueued = "คุณอยู่ในคิวแข่งแล้ว",
		RaceDead = "เข้าร่วมไม่ได้ระหว่างเกิดใหม่", RaceFalseStart = "ออกตัวก่อน! รอสัญญาณ",
		RaceDisqualified = "ถูกตัดสิทธิ์", Unavailable = "เข้าร่วมการแข่งนี้ไม่ได้", LeftRace = "คุณออกจากการแข่งแล้ว",
		-- 2026-09-25 (final fix): the race HUD's LEAVE (two taps) and the rejoin cooldown.
		LeaveRace = "ออก", LeaveConfirm = "แน่ใจ?", RaceCooldown = "รอสักครู่ก่อนเข้าร่วมอีกครั้ง",
		RaceBracketLocked = "การแข่งมือใหม่สำหรับผู้เล่นใหม่เท่านั้น!",
		RaceEventClosed = "ปิดการแข่งระหว่างอีเวนต์",
		PadBoost = "เร่งความเร็ว!",
	},
	tr = {
		Starting = "BAŞLIYOR: {1}sn", Go = "BAŞLA!", GetReady = "Hazırlan!", InProgress = "Yarış sürüyor: {1}",
		FinishedStatus = "Bitirdin! {1}", Waiting = "Yarışçılar bekleniyor...",
		Mph = "MPH: {1} / {2}", Multiplier = "Çarpan: x{1}", Accel = "MPH/sn: {1}", Stamina = "ENERJİ %{1}",
		You = "SEN", YouPlace = "Sen · {1}/{2}", Orb = "▼ KÜRE", Studs = "{1} stud",
		HoldKey = "ŞARJ İÇİN [SHIFT] BASILI TUT", HoldPad = "ŞARJ İÇİN BASILI TUT", HoldTouch = "ŞARJI BASILI TUT",
		StayGreen = "YEŞİLDE KAL!", EasyZone = "KOLAY BÖLGE",
		StartPerfect = "MÜKEMMEL ÇIKIŞ! +%{1}", StartGood = "İYİ ÇIKIŞ! +%{1}", StartStall = "ÇIKIŞ KAÇTI!",
		Spikes = "AH! DİKENLER", FinishedBig = "{1} BİTİRDİN!", NewBest = "YENİ REKOR!",
		Charge = "ŞARJ", Boost = "TURBO",
		ResultsTitle = "YARIŞ SONUÇLARI", PlaceTop = "{1} OLDUN!", Time = "SÜRE {1}", Best = "EN İYİ {1}",
		Dnf = "BİTİREMEDİN", Dq = "DİSKALİFİYE",
		Wins = "+{1} Wins", Speed = "+{1} Hız", Ticket = "+{1} Çark Hakkı", FirstToday = "x2 GÜNÜN İLK YARIŞI",
		CapNote = "Saatte 30 yarıştan sonra ödüller azalır", Pending = "Ödüller hesaplanıyor...",
		RaceAgain = "TEKRAR", Lobby = "LOBİ", LobbyIn = "LOBİ ({1})",
		Race = "YARIŞ", Join = "KATIL!", InQueue = "SIRADA ✓", Live = "CANLI {1}", Mega = "MEGA YARIŞ!",
		NextIn = "SONRAKİ {1}", StartingSoon = "BAŞLIYOR!",
		InviteTitle = "{1} SONRA YARIŞ!", InviteBody = "{1} yarışçı · +{2} Wins'e kadar", InviteJoin = "KATIL",
		NextRace = "SONRAKİ YARIŞ", Ready = "{1} / {2} yarışçı hazır", JoinRace = "YARIŞA KATIL", LeaveQueue = "SIRADAN ÇIK",
		Rewards = "ÖDÜLLER", Finish = "Bitiş", FirstRaceToday = "Günün ilk yarışı: x2 + Çark Hakkı",
		Fastest = "EN HIZLILAR", Weekly = "HAFTALIK", AllTime = "TÜM ZAMANLAR",
		YourBest = "En iyin: {1} · #{2}", YourBestNoRank = "En iyin: {1}", NoTime = "Henüz süre yok",
		Loading = "Yükleniyor...", Empty = "Henüz süre yok. İlk sen ol!", Now = "ŞİMDİ",
		GateRecord = "Haftalık rekor {1}, {2}", GateStep = "Yarışmak için gir!",
		RaceLockedTutorial = "Yarışmak için önce eğitimi bitir!", StreamTimeout = "Piste ulaşılamadı. Tekrar dene!",
		RaceOff = "Yarışlar şu an durduruldu", RaceLoading = "Hâlâ yükleniyor, birazdan tekrar dene",
		RaceAfk = "Yarışmak için AFK Modundan çık", RaceAlreadyQueued = "Zaten yarış sırasındasın",
		RaceDead = "Yeniden doğarken katılamazsın", RaceFalseStart = "Erken çıkış! BAŞLA'yı bekle",
		RaceDisqualified = "Diskalifiye edildin", Unavailable = "Bu yarışa katılamadın", LeftRace = "Yarıştan ayrıldın",
		-- 2026-09-25 (final fix): the race HUD's LEAVE (two taps) and the rejoin cooldown.
		LeaveRace = "ÇIK", LeaveConfirm = "EMİN MİSİN?", RaceCooldown = "Tekrar katılmadan önce biraz bekle",
		RaceBracketLocked = "Acemi yarışları sadece yeni oyuncular için!",
		RaceEventClosed = "Etkinlik sırasında yarışlar kapalı",
		PadBoost = "HIZLAN!",
	},
}

-- Unqueued reasons (RaceService) -> toast keys; nil = no toast (the player's own Leave, a death).
RaceText.UnqueuedToast = {
	StreamTimeout = "StreamTimeout",
	Unavailable = "Unavailable",
	Left = "LeftRace",
	RaceOff = "RaceOff",
	Afk = "RaceAfk",
	Saving = "RaceLoading", -- H3: a save being retried (RaceService staging)
	Event = "RaceEventClosed", -- 2026-09-26 (owner): pulled out when a live event closed the races
}

function RaceText.LanguageFor(localeId: any): string
	return TutorialText.LanguageFor(localeId)
end

function RaceText.ForPlayer(player: any): string
	return TutorialText.ForPlayer(player)
end

-- The text for `key` in `lang`: English when that language lacks it, the key itself when even
-- English does. Never errors.
function RaceText.Get(key: string, lang: string?): string
	local strings = RaceText.Strings[lang or "en"]
	local text = strings and strings[key]
	if type(text) == "string" and text ~= "" then
		return text
	end
	text = RaceText.Strings.en[key]
	return if type(text) == "string" then text else tostring(key)
end

-- Get with {1}, {2}... filled from the arguments (tostring'd; a missing one stays empty).
function RaceText.Format(key: string, lang: string?, ...: any): string
	local args = table.pack(...)
	local text = RaceText.Get(key, lang)
	return (string.gsub(text, "{(%d)}", function(index)
		local value = args[tonumber(index) :: number]
		return if value == nil then "" else tostring(value)
	end))
end

-- 1 -> "1st" (en), "1.º" (es), "1º" (pt), "1-е" (ru), "1re" (fr), "1." (de, tr), else "1".
function RaceText.Ordinal(n: number, lang: string?): string
	local value = math.max(0, math.floor(tonumber(n) or 0))
	local l = lang or "en"
	if l == "en" then
		local tens = value % 100
		local suffix = "th"
		if tens < 11 or tens > 13 then
			local last = value % 10
			suffix = if last == 1 then "st" elseif last == 2 then "nd" elseif last == 3 then "rd" else "th"
		end
		return value .. suffix
	elseif l == "es" then
		return value .. ".º"
	elseif l == "pt" then
		return value .. "º"
	elseif l == "ru" then
		return value .. "-е"
	elseif l == "fr" then
		return value .. (if value == 1 then "re" else "e")
	elseif l == "de" or l == "tr" then
		return value .. "."
	end
	return tostring(value)
end

-- 31200 -> "31.20s"; 0 or nil -> "--".
function RaceText.Seconds(ms: number?): string
	local value = tonumber(ms)
	if not value or value <= 0 or value ~= value then
		return "--"
	end
	return string.format("%.2fs", value / 1000)
end

-- 75 -> "1:15" (a countdown).
function RaceText.Clock(seconds: number?): string
	local s = math.max(0, math.ceil(tonumber(seconds) or 0))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

-- 27.43 -> "0:27.4" (a race clock).
function RaceText.Elapsed(seconds: number?): string
	local s = math.max(0, tonumber(seconds) or 0)
	local tenths = math.floor(s * 10)
	return string.format("%d:%02d.%d", math.floor(tenths / 600), math.floor(tenths / 10) % 60, tenths % 10)
end

-- A label filled from here: no automatic translation on top, and the language's font.
function RaceText.Style(label: any, lang: string?): any
	return TutorialText.Style(label, lang)
end

-- The length a line is checked against: characters, each placeholder counted as 3.
function RaceText.MeasuredLength(text: string): number
	local counted = string.gsub(text, "{%d}", "###")
	return utf8.len(counted) or #counted
end

return RaceText
