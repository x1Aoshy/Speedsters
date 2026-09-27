-- ReplicatedStorage/Shared/LobbyNpcText.luau — Update 4 (2026-09-25): every word of the two lobby
-- NPCs (Dr. Eggman, the daily quests; The Flash, the race sign-up): their prompts, name tags,
-- speech bubbles and Flash's sign-up window, in the 10 languages of Shared/TutorialText
-- (en es pt ru ar id fr de th tr; anything else reads English). Spanish and Portuguese are a
-- third of the players, so they are written as those players talk. French puts a no-break
-- space (\u{00A0}) before "!", "?" and ":".
-- The race words the window shares with the race panel (next race, racers ready, in queue...)
-- come from Shared/RaceText, so both always say the same.
-- Placeholders are {1}, {2}; Format fills them. Caps is the longest a line may be (characters,
-- each placeholder counted as 3), checked by audit/test_u4_npcs.
-- Pure data and functions: nothing here touches a service when it is required.
local TutorialText = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("TutorialText", 10))
	else require("./TutorialText")

local LobbyNpcText = {}

LobbyNpcText.Languages = TutorialText.Languages

-- Every key must exist in these (the test fails otherwise); the other languages fall back to
-- English key by key.
LobbyNpcText.Required = { "en", "es", "pt" }

LobbyNpcText.Caps = {
	-- Eggman
	EggmanName = 18, EggmanRole = 20, EggmanPrompt = 26, EggmanPromptObject = 20,
	EggmanLine = 72, EggmanReward = 72,
	-- Flash
	FlashName = 16, FlashRole = 18, FlashPrompt = 22, FlashPromptObject = 16,
	FlashTitle = 18, FlashLine = 60, FlashGo = 40, FlashLater = 44,
	Beginner = 14, BeginnerSub = 30, Rank = 14, RankSub = 30, Open = 14, OpenSub = 30,
	BeginnerLocked = 30, Records = 20, Queued = 30,
}

LobbyNpcText.Strings = {
	en = {
		EggmanName = "Dr. Eggman", EggmanRole = "Daily Quests",
		EggmanPrompt = "Talk to Dr. Eggman", EggmanPromptObject = "Daily Quests",
		EggmanLine = "Ho ho ho! Think you're fast enough for my daily challenges?",
		EggmanReward = "Ho ho! You beat my challenge... Come get your reward!",
		FlashName = "The Flash", FlashRole = "Race Host",
		FlashPrompt = "Sign up to race", FlashPromptObject = "The Flash",
		FlashTitle = "RACE SIGN-UP", FlashLine = "Think you can keep up with me? Pick your race!",
		FlashGo = "See you at the start line!", FlashLater = "Come back when you're ready to run!",
		Beginner = "BEGINNERS", BeginnerSub = "New runners, few rebirths",
		Rank = "MY RANK", RankSub = "Racers at your speed",
		Open = "OPEN", OpenSub = "Everyone can join",
		BeginnerLocked = "You're too fast for this one!", Records = "WEEKLY RECORDS",
		Queued = "You're in the queue!",
	},
	es = {
		EggmanName = "Dr. Eggman", EggmanRole = "Misiones diarias",
		EggmanPrompt = "Hablar con Dr. Eggman", EggmanPromptObject = "Misiones diarias",
		EggmanLine = "¡Jo jo jo! ¿Te crees tan rápido como para mis retos diarios?",
		EggmanReward = "¡Jo jo! Superaste mi reto... ¡Ven por tu premio!",
		FlashName = "Flash", FlashRole = "Jefe de carreras",
		FlashPrompt = "Apuntarme a correr", FlashPromptObject = "Flash",
		FlashTitle = "INSCRIPCIÓN", FlashLine = "¿Crees que puedes seguirme el ritmo? ¡Elige tu carrera!",
		FlashGo = "¡Nos vemos en la salida!", FlashLater = "¡Vuelve cuando quieras correr!",
		Beginner = "NOVATOS", BeginnerSub = "Nuevos, pocos renacimientos",
		Rank = "MI NIVEL", RankSub = "Rivales de tu velocidad",
		Open = "ABIERTA", OpenSub = "Puede entrar cualquiera",
		BeginnerLocked = "¡Eres muy rápido para esta!", Records = "RÉCORDS SEMANALES",
		Queued = "¡Ya estás en la cola!",
	},
	pt = {
		EggmanName = "Dr. Eggman", EggmanRole = "Missões diárias",
		EggmanPrompt = "Falar com Dr. Eggman", EggmanPromptObject = "Missões diárias",
		EggmanLine = "Ho ho ho! Acha que é rápido o bastante pros meus desafios diários?",
		EggmanReward = "Ho ho! Você venceu meu desafio... Vem pegar seu prêmio!",
		FlashName = "Flash", FlashRole = "Chefe das corridas",
		FlashPrompt = "Entrar na corrida", FlashPromptObject = "Flash",
		FlashTitle = "INSCRIÇÃO", FlashLine = "Acha que consegue me acompanhar? Escolha sua corrida!",
		FlashGo = "Te vejo na largada!", FlashLater = "Volta quando quiser correr!",
		Beginner = "INICIANTES", BeginnerSub = "Novatos, poucos renascimentos",
		Rank = "MEU NÍVEL", RankSub = "Rivais da sua velocidade",
		Open = "ABERTA", OpenSub = "Todo mundo pode entrar",
		BeginnerLocked = "Você é rápido demais pra essa!", Records = "RECORDES DA SEMANA",
		Queued = "Você já está na fila!",
	},
	ru = {
		EggmanName = "Доктор Эггман", EggmanRole = "Задания дня",
		EggmanPrompt = "Поговорить с Эггманом", EggmanPromptObject = "Задания дня",
		EggmanLine = "Хо-хо-хо! Думаешь, ты достаточно быстр для моих испытаний?",
		EggmanReward = "Хо-хо! Ты прошёл моё испытание... Забирай награду!",
		FlashName = "Флэш", FlashRole = "Ведущий гонок",
		FlashPrompt = "Записаться в гонку", FlashPromptObject = "Флэш",
		FlashTitle = "ЗАПИСЬ", FlashLine = "Думаешь, угонишься за мной? Выбирай гонку!",
		FlashGo = "Увидимся на старте!", FlashLater = "Возвращайся, когда будешь готов!",
		Beginner = "НОВИЧКИ", BeginnerSub = "Новые, мало перерождений",
		Rank = "МОЙ УРОВЕНЬ", RankSub = "Соперники твоей скорости",
		Open = "ОТКРЫТАЯ", OpenSub = "Для всех",
		BeginnerLocked = "Ты слишком быстр для неё!", Records = "РЕКОРДЫ НЕДЕЛИ",
		Queued = "Ты уже в очереди!",
	},
	ar = {
		EggmanName = "د. إيغمان", EggmanRole = "المهام اليومية",
		EggmanPrompt = "تحدّث مع د. إيغمان", EggmanPromptObject = "المهام اليومية",
		EggmanLine = "هو هو هو! هل تظن أنك سريع بما يكفي لتحدياتي اليومية؟",
		EggmanReward = "هو هو! تغلّبت على تحدّيّ... تعال خذ جائزتك!",
		FlashName = "فلاش", FlashRole = "مضيف السباقات",
		FlashPrompt = "سجّل في السباق", FlashPromptObject = "فلاش",
		FlashTitle = "التسجيل", FlashLine = "تظن أنك تستطيع مجاراتي؟ اختر سباقك!",
		FlashGo = "أراك عند خط البداية!", FlashLater = "عد عندما تكون جاهزًا للركض!",
		Beginner = "المبتدئون", BeginnerSub = "لاعبون جدد وولادات قليلة",
		Rank = "مستواي", RankSub = "منافسون بسرعتك",
		Open = "مفتوح", OpenSub = "الجميع يمكنهم الانضمام",
		BeginnerLocked = "أنت أسرع من هذا السباق!", Records = "أرقام الأسبوع",
		Queued = "أنت في الطابور!",
	},
	id = {
		EggmanName = "Dr. Eggman", EggmanRole = "Misi Harian",
		EggmanPrompt = "Bicara dengan Dr. Eggman", EggmanPromptObject = "Misi Harian",
		EggmanLine = "Ho ho ho! Kamu pikir cukup cepat untuk tantangan harianku?",
		EggmanReward = "Ho ho! Kamu lolos tantanganku... Ambil hadiahmu!",
		FlashName = "The Flash", FlashRole = "Tuan Rumah Balapan",
		FlashPrompt = "Daftar balapan", FlashPromptObject = "The Flash",
		FlashTitle = "PENDAFTARAN", FlashLine = "Yakin bisa mengejarku? Pilih balapanmu!",
		FlashGo = "Sampai jumpa di garis start!", FlashLater = "Kembali saat kamu siap lari!",
		Beginner = "PEMULA", BeginnerSub = "Pemain baru, sedikit rebirth",
		Rank = "LEVELKU", RankSub = "Lawan secepat kamu",
		Open = "TERBUKA", OpenSub = "Semua boleh ikut",
		BeginnerLocked = "Kamu terlalu cepat untuk ini!", Records = "REKOR MINGGUAN",
		Queued = "Kamu sudah di antrean!",
	},
	fr = {
		EggmanName = "Dr Eggman", EggmanRole = "Quêtes du jour",
		EggmanPrompt = "Parler au Dr Eggman", EggmanPromptObject = "Quêtes du jour",
		EggmanLine = "Ho ho ho\u{00A0}! Tu te crois assez rapide pour mes défis du jour\u{00A0}?",
		EggmanReward = "Ho ho\u{00A0}! Tu as réussi mon défi... Viens chercher ta récompense\u{00A0}!",
		FlashName = "Flash", FlashRole = "Chef des courses",
		FlashPrompt = "S'inscrire à la course", FlashPromptObject = "Flash",
		FlashTitle = "INSCRIPTION", FlashLine = "Tu crois pouvoir me suivre\u{00A0}? Choisis ta course\u{00A0}!",
		FlashGo = "On se voit au départ\u{00A0}!", FlashLater = "Reviens quand tu veux courir\u{00A0}!",
		Beginner = "DÉBUTANTS", BeginnerSub = "Nouveaux, peu de renaissances",
		Rank = "MON NIVEAU", RankSub = "Rivaux de ta vitesse",
		Open = "OUVERTE", OpenSub = "Tout le monde peut jouer",
		BeginnerLocked = "Trop rapide pour celle-ci\u{00A0}!", Records = "RECORDS HEBDO",
		Queued = "Tu es dans la file\u{00A0}!",
	},
	de = {
		EggmanName = "Dr. Eggman", EggmanRole = "Tagesquests",
		EggmanPrompt = "Mit Dr. Eggman reden", EggmanPromptObject = "Tagesquests",
		EggmanLine = "Ho ho ho! Glaubst du, du bist schnell genug für meine Tagesaufgaben?",
		EggmanReward = "Ho ho! Du hast meine Aufgabe geschafft... Hol dir deine Belohnung!",
		FlashName = "The Flash", FlashRole = "Rennleiter",
		FlashPrompt = "Zum Rennen anmelden", FlashPromptObject = "The Flash",
		FlashTitle = "ANMELDUNG", FlashLine = "Glaubst du, du hältst mit mir mit? Wähl dein Rennen!",
		FlashGo = "Wir sehen uns am Start!", FlashLater = "Komm wieder, wenn du rennen willst!",
		Beginner = "ANFÄNGER", BeginnerSub = "Neue, wenige Rebirths",
		Rank = "MEIN RANG", RankSub = "Gegner mit deinem Tempo",
		Open = "OFFEN", OpenSub = "Alle dürfen mitmachen",
		BeginnerLocked = "Du bist zu schnell dafür!", Records = "WOCHENREKORDE",
		Queued = "Du bist in der Warteschlange!",
	},
	th = {
		EggmanName = "ดร.เอ้กแมน", EggmanRole = "เควสรายวัน",
		EggmanPrompt = "คุยกับ ดร.เอ้กแมน", EggmanPromptObject = "เควสรายวัน",
		EggmanLine = "โฮ่ โฮ่ โฮ่! คิดว่าเร็วพอสำหรับภารกิจรายวันของข้าไหม?",
		EggmanReward = "โฮ่ โฮ่! เจ้าผ่านภารกิจของข้าแล้ว... มารับรางวัลสิ!",
		FlashName = "แฟลช", FlashRole = "ผู้จัดการแข่ง",
		FlashPrompt = "สมัครแข่ง", FlashPromptObject = "แฟลช",
		FlashTitle = "สมัครแข่ง", FlashLine = "คิดว่าตามข้าทันไหม? เลือกการแข่งเลย!",
		FlashGo = "เจอกันที่เส้นสตาร์ท!", FlashLater = "พร้อมวิ่งเมื่อไหร่ก็กลับมานะ!",
		Beginner = "มือใหม่", BeginnerSub = "ผู้เล่นใหม่ รีเบิร์ธน้อย",
		Rank = "ระดับฉัน", RankSub = "คู่แข่งความเร็วเท่าคุณ",
		Open = "เปิด", OpenSub = "ทุกคนเข้าร่วมได้",
		BeginnerLocked = "คุณเร็วเกินไปสำหรับรอบนี้!", Records = "สถิติประจำสัปดาห์",
		Queued = "คุณอยู่ในคิวแล้ว!",
	},
	tr = {
		EggmanName = "Dr. Eggman", EggmanRole = "Günlük Görevler",
		EggmanPrompt = "Dr. Eggman ile konuş", EggmanPromptObject = "Günlük Görevler",
		EggmanLine = "Ho ho ho! Günlük görevlerim için yeterince hızlı mısın sence?",
		EggmanReward = "Ho ho! Görevimi geçtin... Gel ödülünü al!",
		FlashName = "Flash", FlashRole = "Yarış Sunucusu",
		FlashPrompt = "Yarışa kaydol", FlashPromptObject = "Flash",
		FlashTitle = "YARIŞ KAYDI", FlashLine = "Bana yetişebilir misin? Yarışını seç!",
		FlashGo = "Başlangıç çizgisinde görüşürüz!", FlashLater = "Koşmaya hazır olunca gel!",
		Beginner = "ACEMİLER", BeginnerSub = "Yeniler, az rebirth",
		Rank = "SEVİYEM", RankSub = "Senin hızındaki rakipler",
		Open = "AÇIK", OpenSub = "Herkes katılabilir",
		BeginnerLocked = "Bunun için fazla hızlısın!", Records = "HAFTALIK REKORLAR",
		Queued = "Zaten sıradasın!",
	},
}

-- The sign-up window's category keys, in the order of its tiles.
LobbyNpcText.CategoryKeys = {
	Beginner = { Title = "Beginner", Sub = "BeginnerSub" },
	Rank = { Title = "Rank", Sub = "RankSub" },
	Open = { Title = "Open", Sub = "OpenSub" },
}

function LobbyNpcText.LanguageFor(localeId: any): string
	return TutorialText.LanguageFor(localeId)
end

function LobbyNpcText.ForPlayer(player: any): string
	return TutorialText.ForPlayer(player)
end

-- The text for `key` in `lang`: English when that language lacks it, the key itself when even
-- English does. Never errors.
function LobbyNpcText.Get(key: string, lang: string?): string
	local strings = LobbyNpcText.Strings[lang or "en"]
	local text = strings and strings[key]
	if type(text) == "string" and text ~= "" then
		return text
	end
	text = LobbyNpcText.Strings.en[key]
	return if type(text) == "string" then text else tostring(key)
end

-- Get with {1}, {2}... filled from the arguments (tostring'd; a missing one stays empty).
function LobbyNpcText.Format(key: string, lang: string?, ...: any): string
	local args = table.pack(...)
	local text = LobbyNpcText.Get(key, lang)
	return (string.gsub(text, "{(%d)}", function(index)
		local value = args[tonumber(index) :: number]
		return if value == nil then "" else tostring(value)
	end))
end

-- A label filled from here: no automatic translation on top, and the language's font.
function LobbyNpcText.Style(label: any, lang: string?): any
	return TutorialText.Style(label, lang)
end

-- The length a line is checked against: characters, each placeholder counted as 3.
function LobbyNpcText.MeasuredLength(text: string): number
	local counted = string.gsub(text, "{%d}", "###")
	return utf8.len(counted) or #counted
end

return LobbyNpcText
