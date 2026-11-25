extends RefCounted
## Hesap silme akışı (Google Play şartı: hesap açılabilen uygulamada uygulama içinden hesap + veri silme).
## Sıra önemli: Nakama girişi Supabase oturumuyla yapıldığı için önce oyun sunucusu, sonra Supabase hesabı silinir.
## Sunucu adımı başarısız olursa Supabase'e dokunulmaz (oyuncu tekrar deneyebilsin).

## Hesaba bağlı, cihazda tutulan dosyalar (ayarlar — ses, sunucu adresi — kişisel değil, kalır).
const LOCAL_FILES: PackedStringArray = [
	"user://profile.cfg",
	"user://care.cfg",
	"user://wallet.cfg",
	"user://social.cfg",
	"user://minigames.cfg",
	"user://feedback.log",
	"user://blocked.cfg",
	"user://session.cfg",
	"user://mock_session.cfg",
]


## "" = her şey silindi; aksi halde kullanıcıya gösterilecek hata.
static func run() -> String:
	var token: String = Services.auth.get_access_token()
	var net_err: String = await Services.net.delete_account(token)
	if not net_err.is_empty():
		return net_err
	var auth_err: String = await Services.auth.delete_account()
	if not auth_err.is_empty():
		return auth_err
	wipe_local_files()
	return ""


static func wipe_local_files(paths: PackedStringArray = LOCAL_FILES) -> void:
	for p: String in paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
