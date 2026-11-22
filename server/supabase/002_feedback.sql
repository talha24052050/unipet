-- UniPet geri bildirim tablosu (6.3 kapalı test). Oyuncular sadece YAZAR, kimse okuyamaz (panelden/servis rolüyle okunur).
create table if not exists public.feedback (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  message text not null check (char_length(message) between 3 and 1000),
  app_version text check (char_length(app_version) <= 32),
  platform text check (char_length(platform) <= 32),
  created_at timestamptz not null default now()
);
create index if not exists feedback_user_time on public.feedback (user_id, created_at desc);

alter table public.feedback enable row level security;

drop policy if exists "kendi adına geri bildirim yazar" on public.feedback;
create policy "kendi adına geri bildirim yazar" on public.feedback
  for insert to authenticated with check ((select auth.uid()) = user_id);

revoke all on public.feedback from anon, authenticated;
grant insert on public.feedback to authenticated;

-- Saatte en çok 5 geri bildirim (spam koruması)
create or replace function public.feedback_rate_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.feedback f
      where f.user_id = new.user_id and f.created_at > now() - interval '1 hour') >= 5 then
    raise exception 'Çok fazla geri bildirim, biraz sonra tekrar dene.' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
revoke execute on function public.feedback_rate_limit() from public, anon, authenticated;

drop trigger if exists feedback_rate on public.feedback;
create trigger feedback_rate before insert on public.feedback
  for each row execute function public.feedback_rate_limit();
