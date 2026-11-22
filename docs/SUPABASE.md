# Supabase kurulumu (Parça 3)

> **Durum (2026-11-22):** Proje kuruldu, şema+izinler uygulandı (Supabase MCP ile), mail Gmail SMTP üzerinden
> (smtp.gmail.com **465**, uygulama şifresi; 587 zaman aşımı verdi), Magic Link + Confirm signup şablonları kodlu.
> Kod **8 hane** (oyun 6–10 kabul eder). Yeni projelerde tablo izinleri varsayılan kapalı → şemadaki `grant` satırları şart.
> Kalan: GitHub secret'ları (aşağıda 4. bölüm).

Kod hazır (`game/src/auth/supabase_auth_service.gd`, `server/supabase/001_schema.sql`).
Aşağıdakiler senin hesabınla yapılır; ~10 dakika. Bitince bana sadece **Project URL** ve **anon public key**'i ver
(ikisi de gizli değil ama repo'ya girmiyor; GitHub secret olarak eklenecek).

## 1. Proje
1. https://supabase.com → giriş → **New project**. Ad: `unipet`. Bölge: **Frankfurt (eu-central-1)** (Türkiye'ye en yakın).
   Veritabanı şifresini bir yere kaydet (bize lazım değil).
2. **Project Settings → API**: `Project URL` ve `anon public` anahtarını kopyala.

## 2. Mail ile kod girişi
1. **Authentication → Sign In / Providers → Email**: açık. "Confirm email" açık.
2. **Authentication → Emails → Templates → Magic Link** şablonunu şöyle değiştir (link yerine 6 haneli kod):
   - Konu: `UniPet giriş kodun`
   - Gövde: `<h2>UniPet</h2><p>Giriş kodun: <b>{{ .Token }}</b></p><p>10 dakika geçerli.</p>`
   Aynısını **Confirm signup** şablonuna da uygula.
3. **Authentication → Rate Limits**: varsayılanlar yeterli.
4. Not: Supabase'in ücretsiz mail sunucusu saatte birkaç maille sınırlı. Kapalı testte (6.3) yetmezse
   **Authentication → SMTP** ile ücretsiz bir SMTP (ör. Brevo, günde 300 mail) bağlanır.

## 3. Veritabanı
1. **SQL Editor → New query** → `server/supabase/001_schema.sql` içeriğini yapıştır → **Run**.
2. **(Şimdilik ATLA — okul maili zorunluluğu kapalı.)** Açılacağı zaman: **Authentication → Hooks → Before User Created**
   → **Postgres function** → `public.hook_restrict_signup_domain` → Kaydet. Bu, `@std.yildiz.edu.tr` dışındaki kayıtları
   SUNUCUDA reddeder. Aynı anda oyunda `Config.REQUIRE_SCHOOL_EMAIL = true` ve Nakama'da `UNIPET_REQUIRE_SCHOOL_EMAIL=true`.

## 4. GitHub (APK'nın Supabase'i bilmesi için)
Repo → **Settings → Secrets and variables → Actions → New repository secret**:
- `SUPABASE_URL` = Project URL
- `SUPABASE_ANON_KEY` = anon public key
CI bunları `game/secrets.cfg` olarak yazar. Yerelde de aynı dosyayı oluştururum:
```ini
[supabase]
url="https://xxxx.supabase.co"
anon_key="eyJ..."
```

## Doğrulama (ben yapacağım)
- `Config.AUTH_BACKEND = "supabase"` → giriş ekranında öğrenci mailine kod gelir, kodla giriş olur.
- Gmail adresiyle kayıt denemesi 403 döner (hook çalışıyor).
- Başka kullanıcının profilini güncelleme denemesi RLS'e takılır.
