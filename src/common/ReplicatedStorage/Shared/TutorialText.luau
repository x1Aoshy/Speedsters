-- Every tutorial word in the players' own language (2026-09-22). The languages are the game's
-- monthly players by language (DataAnalysis, 2026-09-17): English 42.5%, Spanish 19.6%,
-- Portuguese 14.7%, Russian 7.3%, Arabic 3.9%, Indonesian 3.8%, French 3.2%, German 2.1%,
-- Thai 1.7%, Turkish 1.2%. Anything else reads English.
-- Pure data and functions: nothing here touches a service when it is required.
--   Shared/TutorialGuide      the HUD guides' cards (aura, Evolve, Rebirth) and the Skip button
--   UI/FirstTimeTutorial      the world-space step labels over the treadmill and the Win pad
-- Labels filled from here set AutoLocalize = false (TutorialText.Style), so Roblox's automatic
-- translation does not translate them a second time.
local TutorialText = {}

TutorialText.Languages = { "en", "es", "pt", "ru", "ar", "id", "fr", "de", "th", "tr" }

-- Card titles stay short (the title is one line), messages fit the navy plate; "\n" where the
-- English breaks the line. Numbers and multipliers ("x1.5", "2.5x", "10") are the same in every
-- language. The HUD buttons say "Rebirth", "Evolve" and "Wins" in English, so the Latin-script
-- languages (es pt id fr de tr) keep those three words as they are, which is also how their
-- simulator players say them; ru, ar and th use their own words (as their players and Roblox's
-- automatic translation of the buttons do), except that the currency stays "Wins" in ru and th.
-- French puts a no-break space (\u{00A0}) before "!" and ":" so TextWrapped never strands them.
TutorialText.Strings = {
	en = {
		Skip = "Skip guide",
		NiceJob = "NICE JOB!",
		AuraTitle1 = "YOUR FIRST AURA",
		AuraMsg1 = "Tap the backpack button",
		AuraTitle2 = "FIND YOUR AURA",
		AuraMsg2 = "Tap Auras to see your boosts",
		AuraTitle3 = "BOOST YOUR SPEED",
		AuraMsgEquip = "Tap Equip for 2.5x speed!",
		AuraMsgGet = "Get Orange Aura for 10 Wins",
		AuraOpen = "Open your backpack to continue",
		AuraDone = "Aura equipped!\nEnjoy your 2.5x speed!",
		EvolveTitle1 = "READY TO EVOLVE!",
		EvolveMsg1 = "Tap Evolve to unlock a faster suit!",
		EvolveTitle2 = "GET YOUR NEW SUIT",
		EvolveMsg2 = "Tap Evolve to get your new suit",
		EvolveOpen = "Open Evolve to continue",
		EvolveDone = "New suit unlocked!\nKeep training to get faster!",
		RebirthTitle1 = "READY TO REBIRTH!",
		RebirthMsg1 = "Tap Rebirth to get faster forever!",
		RebirthTitle2 = "REBIRTH NOW!",
		RebirthMsg2 = "Speed resets, but you get x1.5 Speed forever!",
		RebirthOpen = "Open Rebirth to continue",
		RebirthDone = "Rebirth done!\nx1.5 Speed forever!",
		StepTrain = "TRAIN HERE!",
		StepClaimWins = "CLAIM YOUR WINS!",
	},
	es = {
		Skip = "Saltar guía",
		NiceJob = "¡BUEN TRABAJO!",
		AuraTitle1 = "TU PRIMERA AURA",
		AuraMsg1 = "Toca el botón de la mochila",
		AuraTitle2 = "BUSCA TU AURA",
		AuraMsg2 = "Toca Auras para ver tus mejoras",
		AuraTitle3 = "¡MÁS VELOCIDAD!",
		AuraMsgEquip = "¡Toca Equipar para 2.5x de velocidad!",
		AuraMsgGet = "Consigue el Aura Naranja por 10 Wins",
		AuraOpen = "Abre tu mochila para continuar",
		AuraDone = "¡Aura equipada!\n¡Disfruta tu velocidad 2.5x!",
		EvolveTitle1 = "¡HORA DE EVOLUCIONAR!",
		EvolveMsg1 = "¡Toca Evolve para un traje más rápido!",
		EvolveTitle2 = "TU NUEVO TRAJE",
		EvolveMsg2 = "Toca Evolve para tu nuevo traje",
		EvolveOpen = "Abre Evolve para continuar",
		EvolveDone = "¡Nuevo traje desbloqueado!\n¡Entrena para ser más rápido!",
		RebirthTitle1 = "¡HORA DEL REBIRTH!",
		RebirthMsg1 = "¡Toca Rebirth y sé más rápido para siempre!",
		RebirthTitle2 = "¡HAZ REBIRTH YA!",
		RebirthMsg2 = "Pierdes tu velocidad, ¡pero ganas x1.5 para siempre!",
		RebirthOpen = "Abre Rebirth para continuar",
		RebirthDone = "¡Rebirth hecho!\n¡x1.5 de velocidad para siempre!",
		StepTrain = "¡ENTRENA AQUÍ!",
		StepClaimWins = "¡RECLAMA TUS WINS!",
	},
	pt = {
		Skip = "Pular guia",
		NiceJob = "MANDOU BEM!",
		AuraTitle1 = "SUA PRIMEIRA AURA",
		AuraMsg1 = "Toque no botão da mochila",
		AuraTitle2 = "ACHE SUA AURA",
		AuraMsg2 = "Toque em Auras para ver seus bônus",
		AuraTitle3 = "MAIS VELOCIDADE!",
		AuraMsgEquip = "Toque em Equipar para 2.5x de velocidade!",
		AuraMsgGet = "Pegue a Aura Laranja por 10 Wins",
		AuraOpen = "Abra sua mochila para continuar",
		AuraDone = "Aura equipada!\nAproveite sua velocidade 2.5x!",
		EvolveTitle1 = "HORA DE EVOLUIR!",
		EvolveMsg1 = "Toque em Evolve para um traje mais rápido!",
		EvolveTitle2 = "SEU NOVO TRAJE",
		EvolveMsg2 = "Toque em Evolve para pegar seu traje",
		EvolveOpen = "Abra o Evolve para continuar",
		EvolveDone = "Traje novo liberado!\nTreine para ficar mais rápido!",
		RebirthTitle1 = "HORA DO REBIRTH!",
		RebirthMsg1 = "Toque em Rebirth: fique mais rápido pra sempre!",
		RebirthTitle2 = "FAÇA REBIRTH!",
		RebirthMsg2 = "Sua velocidade zera, mas você ganha x1.5 pra sempre!",
		RebirthOpen = "Abra o Rebirth para continuar",
		RebirthDone = "Rebirth feito!\nx1.5 de velocidade pra sempre!",
		StepTrain = "TREINE AQUI!",
		StepClaimWins = "PEGUE SUAS WINS!",
	},
	ru = {
		Skip = "Пропустить",
		NiceJob = "ОТЛИЧНО!",
		AuraTitle1 = "ТВОЯ ПЕРВАЯ АУРА",
		AuraMsg1 = "Нажми на кнопку рюкзака",
		AuraTitle2 = "НАЙДИ СВОЮ АУРУ",
		AuraMsg2 = "Нажми «Ауры», чтобы увидеть бусты",
		AuraTitle3 = "УСКОРЬСЯ!",
		AuraMsgEquip = "Нажми «Надеть» для скорости 2.5x!",
		AuraMsgGet = "Получи Оранжевую ауру за 10 Wins",
		AuraOpen = "Открой рюкзак, чтобы продолжить",
		AuraDone = "Аура надета!\nНаслаждайся скоростью 2.5x!",
		EvolveTitle1 = "ВРЕМЯ ЭВОЛЮЦИИ!",
		EvolveMsg1 = "Нажми «Эволюция» — костюм станет быстрее!",
		EvolveTitle2 = "НОВЫЙ КОСТЮМ",
		EvolveMsg2 = "Нажми «Эволюция», чтобы получить костюм",
		EvolveOpen = "Открой «Эволюцию», чтобы продолжить",
		EvolveDone = "Новый костюм открыт!\nТренируйся, чтобы стать быстрее!",
		RebirthTitle1 = "ВРЕМЯ ПЕРЕРОЖДЕНИЯ!",
		RebirthMsg1 = "Нажми «Перерождение» — ускорься навсегда!",
		RebirthTitle2 = "ПЕРЕРОДИСЬ!",
		RebirthMsg2 = "Скорость сбросится, но ты получишь x1.5 навсегда!",
		RebirthOpen = "Открой «Перерождение», чтобы продолжить",
		RebirthDone = "Перерождение готово!\nСкорость x1.5 навсегда!",
		StepTrain = "ТРЕНИРУЙСЯ ТУТ!",
		StepClaimWins = "ЗАБЕРИ СВОИ WINS!",
	},
	ar = {
		Skip = "تخطي الدليل",
		NiceJob = "أحسنت!",
		AuraTitle1 = "أول هالة لك",
		AuraMsg1 = "اضغط على زر الحقيبة",
		AuraTitle2 = "ابحث عن هالتك",
		AuraMsg2 = "اضغط على الهالات لترى التعزيزات",
		AuraTitle3 = "زِد سرعتك!",
		AuraMsgEquip = "اضغط على «تجهيز» لتصبح أسرع 2.5x!",
		AuraMsgGet = "احصل على الهالة البرتقالية مقابل 10 انتصارات",
		AuraOpen = "افتح حقيبتك للمتابعة",
		AuraDone = "تم تجهيز الهالة!\nاستمتع بسرعة 2.5x!",
		EvolveTitle1 = "جاهز للتطور!",
		EvolveMsg1 = "اضغط على «تطوّر» لتحصل على بدلة أسرع!",
		EvolveTitle2 = "بدلتك الجديدة",
		EvolveMsg2 = "اضغط على «تطوّر» لتحصل على بدلتك الجديدة",
		EvolveOpen = "افتح التطور للمتابعة",
		EvolveDone = "تم فتح بدلة جديدة!\nواصل التدريب لتصبح أسرع!",
		RebirthTitle1 = "وقت إعادة الميلاد!",
		RebirthMsg1 = "اضغط على «إعادة الميلاد» لتصبح أسرع للأبد!",
		RebirthTitle2 = "إعادة الميلاد الآن!",
		RebirthMsg2 = "تعود سرعتك للبداية، لكنك تحصل على x1.5 للأبد!",
		RebirthOpen = "افتح إعادة الميلاد للمتابعة",
		RebirthDone = "تمت إعادة الميلاد!\nسرعة x1.5 للأبد!",
		StepTrain = "تدرّب هنا!",
		StepClaimWins = "اجمع انتصاراتك!",
	},
	id = {
		Skip = "Lewati",
		NiceJob = "MANTAP!",
		AuraTitle1 = "AURA PERTAMAMU",
		AuraMsg1 = "Ketuk tombol tas",
		AuraTitle2 = "CARI AURAMU",
		AuraMsg2 = "Ketuk Aura untuk lihat boost-mu",
		AuraTitle3 = "TAMBAH KECEPATAN",
		AuraMsgEquip = "Ketuk Pakai untuk kecepatan 2.5x!",
		AuraMsgGet = "Beli Aura Oranye seharga 10 Wins",
		AuraOpen = "Buka tasmu untuk lanjut",
		AuraDone = "Aura dipakai!\nNikmati kecepatan 2.5x!",
		EvolveTitle1 = "SIAP EVOLVE!",
		EvolveMsg1 = "Ketuk Evolve untuk kostum lebih cepat!",
		EvolveTitle2 = "AMBIL KOSTUM BARU",
		EvolveMsg2 = "Ketuk Evolve untuk kostum barumu",
		EvolveOpen = "Buka Evolve untuk lanjut",
		EvolveDone = "Kostum baru terbuka!\nTerus latihan biar makin cepat!",
		RebirthTitle1 = "SIAP REBIRTH!",
		RebirthMsg1 = "Ketuk Rebirth biar makin cepat selamanya!",
		RebirthTitle2 = "REBIRTH SEKARANG!",
		RebirthMsg2 = "Kecepatan direset, tapi dapat x1.5 selamanya!",
		RebirthOpen = "Buka Rebirth untuk lanjut",
		RebirthDone = "Rebirth berhasil!\nKecepatan x1.5 selamanya!",
		StepTrain = "LATIHAN DI SINI!",
		StepClaimWins = "AMBIL WINS-MU!",
	},
	fr = {
		Skip = "Passer",
		NiceJob = "BIEN JOUÉ\u{00A0}!",
		AuraTitle1 = "TA PREMIÈRE AURA",
		AuraMsg1 = "Appuie sur le bouton du sac",
		AuraTitle2 = "TROUVE TON AURA",
		AuraMsg2 = "Appuie sur Auras pour voir tes boosts",
		AuraTitle3 = "PLUS DE VITESSE\u{00A0}!",
		AuraMsgEquip = "Appuie sur Équiper\u{00A0}: vitesse 2.5x\u{00A0}!",
		AuraMsgGet = "Obtiens l'Aura Orange pour 10 Wins",
		AuraOpen = "Ouvre ton sac pour continuer",
		AuraDone = "Aura équipée\u{00A0}!\nProfite de ta vitesse 2.5x\u{00A0}!",
		EvolveTitle1 = "PRÊT À ÉVOLUER\u{00A0}!",
		EvolveMsg1 = "Appuie sur Evolve\u{00A0}: costume plus rapide\u{00A0}!",
		EvolveTitle2 = "TON NOUVEAU COSTUME",
		EvolveMsg2 = "Appuie sur Evolve pour ton costume",
		EvolveOpen = "Ouvre Evolve pour continuer",
		EvolveDone = "Nouveau costume\u{00A0}!\nEntraîne-toi pour aller plus vite\u{00A0}!",
		RebirthTitle1 = "PRÊT POUR LE REBIRTH\u{00A0}!",
		RebirthMsg1 = "Appuie sur Rebirth\u{00A0}: plus rapide pour toujours\u{00A0}!",
		RebirthTitle2 = "FAIS UN REBIRTH\u{00A0}!",
		RebirthMsg2 = "Ta vitesse repart à zéro, mais tu gagnes x1.5 à vie\u{00A0}!",
		RebirthOpen = "Ouvre Rebirth pour continuer",
		RebirthDone = "Rebirth réussi\u{00A0}!\nVitesse x1.5 à vie\u{00A0}!",
		StepTrain = "ENTRAÎNE-TOI ICI\u{00A0}!",
		StepClaimWins = "RÉCUPÈRE TES WINS\u{00A0}!",
	},
	de = {
		Skip = "Überspringen",
		NiceJob = "GUT GEMACHT!",
		AuraTitle1 = "DEINE ERSTE AURA",
		AuraMsg1 = "Tippe auf den Rucksack",
		AuraTitle2 = "FINDE DEINE AURA",
		AuraMsg2 = "Tippe auf Auras für deine Boosts",
		AuraTitle3 = "MEHR TEMPO!",
		AuraMsgEquip = "Tippe auf Ausrüsten für 2.5x Tempo!",
		AuraMsgGet = "Hol dir die Orange Aura für 10 Wins",
		AuraOpen = "Öffne deinen Rucksack zum Weitermachen",
		AuraDone = "Aura ausgerüstet!\nGenieß dein 2.5x Tempo!",
		EvolveTitle1 = "BEREIT FÜR EVOLVE!",
		EvolveMsg1 = "Tippe auf Evolve: schnellerer Anzug!",
		EvolveTitle2 = "DEIN NEUER ANZUG",
		EvolveMsg2 = "Tippe auf Evolve für deinen Anzug",
		EvolveOpen = "Öffne Evolve zum Weitermachen",
		EvolveDone = "Neuer Anzug frei!\nTrainiere weiter für mehr Tempo!",
		RebirthTitle1 = "BEREIT FÜR REBIRTH!",
		RebirthMsg1 = "Tippe auf Rebirth: für immer schneller!",
		RebirthTitle2 = "JETZT REBIRTH!",
		RebirthMsg2 = "Tempo wird zurückgesetzt, aber x1.5 für immer!",
		RebirthOpen = "Öffne Rebirth zum Weitermachen",
		RebirthDone = "Rebirth geschafft!\nx1.5 Tempo für immer!",
		StepTrain = "HIER TRAINIEREN!",
		StepClaimWins = "HOL DIR DEINE WINS!",
	},
	th = {
		Skip = "ข้ามคำแนะนำ",
		NiceJob = "เยี่ยมมาก!",
		AuraTitle1 = "ออร่าแรกของคุณ",
		AuraMsg1 = "แตะปุ่มกระเป๋า",
		AuraTitle2 = "หาออร่าของคุณ",
		AuraMsg2 = "แตะออร่า เพื่อดูบูสต์ของคุณ",
		AuraTitle3 = "เพิ่มความเร็ว!",
		AuraMsgEquip = "แตะสวมใส่ เพื่อความเร็ว 2.5x!",
		AuraMsgGet = "รับออร่าสีส้มด้วย 10 Wins",
		AuraOpen = "เปิดกระเป๋า เพื่อไปต่อ",
		AuraDone = "ใส่ออร่าแล้ว!\nสนุกกับความเร็ว 2.5x!",
		EvolveTitle1 = "พร้อมวิวัฒนาการ!",
		EvolveMsg1 = "แตะวิวัฒนาการ เพื่อชุดที่เร็วขึ้น!",
		EvolveTitle2 = "รับชุดใหม่ของคุณ",
		EvolveMsg2 = "แตะวิวัฒนาการ เพื่อรับชุดใหม่",
		EvolveOpen = "เปิดวิวัฒนาการ เพื่อไปต่อ",
		EvolveDone = "ปลดล็อกชุดใหม่แล้ว!\nฝึกต่อเพื่อให้เร็วขึ้น!",
		RebirthTitle1 = "พร้อมรีเบิร์ธ!",
		RebirthMsg1 = "แตะรีเบิร์ธ เพื่อเร็วขึ้นตลอดไป!",
		RebirthTitle2 = "รีเบิร์ธเลย!",
		RebirthMsg2 = "ความเร็วจะรีเซ็ต แต่ได้ x1.5 ตลอดไป!",
		RebirthOpen = "เปิดรีเบิร์ธ เพื่อไปต่อ",
		RebirthDone = "รีเบิร์ธสำเร็จ!\nความเร็ว x1.5 ตลอดไป!",
		StepTrain = "ฝึกที่นี่!",
		StepClaimWins = "รับ Wins ของคุณ!",
	},
	tr = {
		Skip = "Rehberi geç",
		NiceJob = "HARİKA!",
		AuraTitle1 = "İLK AURAN",
		AuraMsg1 = "Çanta butonuna dokun",
		AuraTitle2 = "AURANI BUL",
		AuraMsg2 = "Güçlendirmeler için Auralar'a dokun",
		AuraTitle3 = "HIZINI ARTIR!",
		AuraMsgEquip = "2.5x hız için Kuşan'a dokun!",
		AuraMsgGet = "Turuncu Aura'yı 10 Wins'e al",
		AuraOpen = "Devam etmek için çantanı aç",
		AuraDone = "Aura kuşanıldı!\n2.5x hızın tadını çıkar!",
		EvolveTitle1 = "EVRİME HAZIR!",
		EvolveMsg1 = "Daha hızlı kostüm için Evolve'a dokun!",
		EvolveTitle2 = "YENİ KOSTÜMÜNÜ AL",
		EvolveMsg2 = "Yeni kostümün için Evolve'a dokun",
		EvolveOpen = "Devam etmek için Evolve'u aç",
		EvolveDone = "Yeni kostüm açıldı!\nHızlanmak için antrenman yap!",
		RebirthTitle1 = "REBIRTH ZAMANI!",
		RebirthMsg1 = "Sonsuza dek hızlanmak için Rebirth'e dokun!",
		RebirthTitle2 = "ŞİMDİ REBIRTH AT!",
		RebirthMsg2 = "Hızın sıfırlanır ama sonsuza dek x1.5 kazanırsın!",
		RebirthOpen = "Devam etmek için Rebirth'ü aç",
		RebirthDone = "Rebirth tamam!\nSonsuza dek x1.5 hız!",
		StepTrain = "BURADA ANTRENMAN!",
		StepClaimWins = "WINS'LERİNİ AL!",
	},
}

local KNOWN = {}
for _, lang in TutorialText.Languages do
	KNOWN[lang] = true
end

-- A Roblox locale id ("es-mx", "pt-br", "ar-001", "zh-cn", "en-us"...) to one of the languages
-- above by its prefix; anything else, or nothing, is English.
function TutorialText.LanguageFor(localeId)
	if type(localeId) ~= "string" then
		return "en"
	end
	local prefix = string.lower(string.match(localeId, "^%s*(%a%a)") or "")
	return if KNOWN[prefix] then prefix else "en"
end

-- The player's Roblox language (LocalizationService.RobloxLocaleId, readable on the client),
-- else their Player.LocaleId, else English. Worked out once per player per session.
local cache = setmetatable({}, { __mode = "k" })
function TutorialText.ForPlayer(player)
	if player ~= nil and cache[player] then
		return cache[player]
	end
	local locale = nil
	pcall(function()
		if game:GetService("RunService"):IsClient() then
			locale = game:GetService("LocalizationService").RobloxLocaleId
		end
	end)
	if type(locale) ~= "string" or locale == "" then
		locale = nil
		pcall(function()
			locale = player.LocaleId
		end)
	end
	local lang = TutorialText.LanguageFor(locale)
	if player ~= nil then
		pcall(function()
			cache[player] = lang
		end)
	end
	return lang
end

-- For the tests: forget the languages worked out so far.
function TutorialText._ClearCache()
	table.clear(cache)
end

-- The text for `key` in `lang`: English when that language lacks it, the key itself when even
-- English does. Never errors.
function TutorialText.Get(key, lang)
	local strings = TutorialText.Strings[lang]
	local text = strings and strings[key]
	if type(text) == "string" and text ~= "" then
		return text
	end
	text = TutorialText.Strings.en[key]
	if type(text) == "string" then
		return text
	end
	return tostring(key)
end

-- FredokaOne has no Cyrillic, Arabic or Thai letters: Roblox would draw those from a fallback
-- font next to FredokaOne digits. Those three languages get Builder Sans ExtraBold on the whole
-- label. For ru that is the real fix (Builder Sans has Cyrillic, so the whole line is one heavy
-- font). Arabic and Thai letters still come from Roblox's missing-glyph fallback, and nothing
-- promises that fallback follows the requested weight: for ar/th the switch only moves the digits
-- and Latin tokens ("x1.5", "Wins") to Builder Sans. Unverified: check in Studio emulation.
-- nil: keep FredokaOne.
local OWN_FONT = { ru = true, ar = true, th = true }
function TutorialText.FontFor(lang)
	if not OWN_FONT[lang] then
		return nil
	end
	local ok, face = pcall(function()
		return Font.fromEnum(Enum.Font.BuilderSansExtraBold)
	end)
	return if ok then face else nil
end

-- Marks a label filled from this module: no automatic translation on top, and the font above.
function TutorialText.Style(label, lang)
	pcall(function()
		label.AutoLocalize = false
	end)
	local face = TutorialText.FontFor(lang)
	if face then
		pcall(function()
			label.FontFace = face
		end)
	end
	return label
end

return TutorialText
