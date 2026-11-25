-- Hesap silme (Google Play şartı: uygulama içinden hesap + veri silme).
-- Oyuncu kendi Supabase hesabını siler; profiles ve feedback satırları "on delete cascade" ile birlikte gider.
-- Oyun önce Nakama tarafını (rpc delete_account) siler, sonra bunu çağırır: POST /rest/v1/rpc/delete_my_account
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'giriş gerekli' using errcode = '28000';
  end if;
  delete from auth.users where id = uid;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
