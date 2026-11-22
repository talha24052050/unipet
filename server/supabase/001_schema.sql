-- UniPet Supabase şeması (Parça 3). Supabase SQL Editor'da bir kez çalıştırılır.
-- 1) Sadece @std.yildiz.edu.tr ile kayıt: Auth "Before User Created" hook'u
-- 2) Profil tablosu + RLS

-- ============ 1. Domain kısıtı (sunucu tarafı, asıl güvenlik burada) ============
create or replace function public.hook_restrict_signup_domain(event jsonb)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  email text := lower(coalesce(event->'user'->>'email', ''));
begin
  if email !~ '^[^@\s]+@std\.yildiz\.edu\.tr$' then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 403,
        'message', 'Sadece @std.yildiz.edu.tr mailleri kayıt olabilir.'
      )
    );
  end if;
  return '{}'::jsonb;
end;
$$;

grant execute on function public.hook_restrict_signup_domain(jsonb) to supabase_auth_admin;
revoke execute on function public.hook_restrict_signup_domain(jsonb) from authenticated, anon, public;

-- ============ 2. Profiller ============
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text unique check (username ~ '^[a-zA-Z0-9_çğıöşüÇĞİÖŞÜ]{3,20}$'),
  pet_id text not null default 'mushnub' check (length(pet_id) <= 32),
  accessories jsonb not null default '{}'::jsonb
    check (jsonb_typeof(accessories) = 'object' and pg_column_size(accessories) < 1024),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Herkes (giriş yapmış) diğerlerinin petini/aksesuarını görebilir (oyunda görünecek).
drop policy if exists "profiller okunabilir" on public.profiles;
create policy "profiller okunabilir" on public.profiles
  for select to authenticated using (true);

-- Sadece kendi profilini oluşturup değiştirebilir.
drop policy if exists "kendi profilini ekler" on public.profiles;
create policy "kendi profilini ekler" on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);

drop policy if exists "kendi profilini günceller" on public.profiles;
create policy "kendi profilini günceller" on public.profiles
  for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- updated_at otomatik
create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

-- Yeni Supabase projeleri tablolara varsayılan API izni vermiyor: açıkça ver (RLS yine satır bazında korur).
revoke all on public.profiles from anon, authenticated;
grant select, insert, update on public.profiles to authenticated;
