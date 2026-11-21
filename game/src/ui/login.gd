extends Control
## Giriş ekranı: öğrenci maili → maile gelen kod → (pet seçimi | oyun).
## Sadece Services.auth arayüzünü kullanır; mock ve Supabase ile aynı çalışır.
## Açılışta cihazda geçerli oturum varsa ekranı atlar.

const LocalProfile := preload("res://src/core/local_profile.gd")
const LocalSettings := preload("res://src/core/local_settings.gd")
const PET_SELECT_SCENE: String = "res://scenes/ui/pet_select.tscn"
const GAME_SCENE: String = "res://scenes/main.tscn"
## Yeni kod isteme bekleme süresi (saniye).
const RESEND_COOLDOWN_S: float = 60.0

enum Step { EMAIL, CODE, BUSY }

var step: Step = Step.EMAIL
var _email: String = ""
var _cooldown: float = 0.0

@onready var _email_box: Control = %EmailBox
@onready var _code_box: Control = %CodeBox
@onready var _email_input: LineEdit = %EmailInput
@onready var _code_input: LineEdit = %CodeInput
@onready var _send_btn: Button = %SendButton
@onready var _verify_btn: Button = %VerifyButton
@onready var _resend_btn: Button = %ResendButton
@onready var _back_btn: Button = %BackButton
@onready var _status: Label = %StatusLabel
@onready var _sent_to: Label = %SentToLabel
@onready var _server_input: LineEdit = %ServerInput


func _ready() -> void:
	Services.auth.code_sent.connect(_on_code_sent)
	Services.auth.signed_in.connect(_on_signed_in)
	Services.auth.auth_failed.connect(_on_failed)
	_send_btn.pressed.connect(submit_email)
	_email_input.text_submitted.connect(func(_t: String) -> void: submit_email())
	_verify_btn.pressed.connect(submit_code)
	_code_input.text_submitted.connect(func(_t: String) -> void: submit_code())
	_resend_btn.pressed.connect(_resend)
	_back_btn.pressed.connect(func() -> void: _show(Step.EMAIL))
	_server_input.text = LocalSettings.load_or_default().server_address
	_show(Step.BUSY)
	_status.text = "Oturum kontrol ediliyor..."
	if await Services.auth.restore_session():
		return  # signed_in sinyali sahneyi değiştirir
	_status.text = "Geliştirme modu: kod 000000" if Config.AUTH_BACKEND == "mock" else ""
	_show(Step.EMAIL)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)
		_resend_btn.disabled = _cooldown > 0.0
		_resend_btn.text = "Yeni kod (%d)" % ceili(_cooldown) if _cooldown > 0.0 else "Yeni kod gönder"


func submit_email() -> void:
	var e: String = _email_input.text.strip_edges().to_lower()
	if not Services.auth.is_allowed_email(e):
		_status.text = Services.auth.email_rejected_message()
		return
	var addr_text: String = _server_input.text.strip_edges()
	if not addr_text.is_empty() and LocalSettings.parse_server_address(addr_text).is_empty():
		_status.text = "Sunucu adresi geçersiz. Örnek: 192.168.1.5 ya da https://xxx.trycloudflare.com"
		return
	var settings: RefCounted = LocalSettings.new()
	settings.server_address = addr_text
	settings.save()
	_email = e
	_status.text = "Kod gönderiliyor..."
	_show(Step.BUSY)
	Services.auth.request_code(e)


func submit_code() -> void:
	var c: String = _code_input.text.strip_edges()
	if not is_valid_code(c):
		_status.text = "Maile gelen 6 haneli kodu gir."
		return
	_status.text = "Kontrol ediliyor..."
	_show(Step.BUSY)
	Services.auth.verify_code(_email, c)


static func is_valid_code(code: String) -> bool:
	return code.length() == 6 and code.is_valid_int()


## Girişten sonra nereye: kayıtlı pet seçimi yoksa seçim ekranı, varsa oyun.
static func next_scene_after_login(profile_saved: bool) -> String:
	return GAME_SCENE if profile_saved else PET_SELECT_SCENE


func _resend() -> void:
	if _cooldown > 0.0 or _email.is_empty():
		return
	_status.text = "Kod tekrar gönderiliyor..."
	Services.auth.request_code(_email)


func _on_code_sent(email: String) -> void:
	_sent_to.text = "%s adresine kod gönderdik." % email
	_status.text = "Geliştirme modu: kod 000000" if Config.AUTH_BACKEND == "mock" else ""
	_cooldown = RESEND_COOLDOWN_S
	_code_input.text = ""
	_show(Step.CODE)
	_code_input.grab_focus()


func _on_signed_in(_user_id: String, _token: String) -> void:
	_status.text = "Giriş yapıldı."
	Services.use_server(LocalSettings.parse_server_address(LocalSettings.load_or_default().server_address))
	var saved: bool = LocalProfile.new().has_saved()
	get_tree().change_scene_to_file.call_deferred(next_scene_after_login(saved))


func _on_failed(reason: String) -> void:
	_status.text = reason
	# Kod daha önce gönderildiyse kod adımında kal, yoksa maile dön.
	_show(Step.CODE if not _sent_to.text.is_empty() else Step.EMAIL)


func _show(s: Step) -> void:
	step = s
	_email_box.visible = s == Step.EMAIL
	_code_box.visible = s == Step.CODE
	_send_btn.disabled = s == Step.BUSY
	_verify_btn.disabled = s == Step.BUSY
