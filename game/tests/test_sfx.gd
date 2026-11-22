extends RefCounted
## Ses efektleri (Sfx autoload) testleri.

const REQUIRED_SOUNDS: Array[StringName] = [
	&"ui_click",
	&"chat_send",
	&"chat_receive",
	&"emote",
	&"care_ok",
	&"care_fail",
	&"teleport",
	&"step",
]


func test_all_sound_names_exist_and_loadable() -> String:
	for name: StringName in REQUIRED_SOUNDS:
		if not Sfx.SOUNDS.has(name):
			return "Sfx.SOUNDS içinde '%s' tanımı eksik" % str(name)
		var path: String = str(Sfx.SOUNDS[name])
		if not ResourceLoader.exists(path):
			return "Ses dosyası mevcut değil: %s (%s)" % [path, str(name)]
		var stream: Resource = load(path)
		if stream == null or not (stream is AudioStream):
			return "Ses dosyası AudioStream olarak yüklenemedi: %s (%s)" % [path, str(name)]
	return ""


func test_unknown_name_does_not_crash() -> String:
	# Bilinmeyen isim ses çalmayı denediğinde çökmemeli ve sessizce geçmeli
	Sfx.play(&"bilinmeyen_ses_adi_xyz_123")
	Sfx.play(&"baska_bir_sahte_ses")
	return ""


func test_pool_size_does_not_exceed_six() -> String:
	# Havuz en çok 6 AudioStreamPlayer barındırmalı
	if Sfx.get_pool_size() > 6:
		return "Havuz boyutu 6'yı aşıyor: %d" % Sfx.get_pool_size()
	# Birçok ses peş peşe çalınsa da havuz 6'yı aşmamalı
	for i: int in range(20):
		var snd: StringName = REQUIRED_SOUNDS[i % REQUIRED_SOUNDS.size()]
		Sfx.play(snd)
		if Sfx.get_pool_size() > 6:
			return "Çoklu oynatma sonrasında havuz boyutu 6'yı aştı: %d" % Sfx.get_pool_size()
	return ""


func test_enabled_and_volume_db_settings() -> String:
	var prev_enabled: bool = Sfx.enabled
	var prev_volume: float = Sfx.volume_db

	Sfx.enabled = false
	var count_before: int = Sfx.play_count
	Sfx.play(&"ui_click")
	if Sfx.play_count != count_before:
		Sfx.enabled = prev_enabled
		return "Sfx devre dışıyken ses çalınmamalıydı"

	Sfx.enabled = true
	Sfx.volume_db = -6.0
	Sfx.play(&"ui_click")
	if Sfx.play_count == count_before:
		Sfx.volume_db = prev_volume
		return "Sfx etkinken ses çalınmalıydı"

	# Varsayılanlara dön
	Sfx.enabled = prev_enabled
	Sfx.volume_db = prev_volume
	return ""
