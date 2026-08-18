-- 風力人員統計系統：Supabase 資料庫與權限設定
-- 請在 Supabase > SQL Editor 執行整份 SQL。

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  role text not null default 'viewer' check (role in ('admin','viewer')),
  created_at timestamptz not null default now()
);

create table if not exists public.employees (
  employee_no text primary key,
  name text not null,
  shift text,
  job_title text,
  group_name text,
  level text,
  nationality text,
  area text not null default '本部',
  hire_date date,
  status text not null default '在職',
  resigned_at date,
  note text,
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.personnel_changes (
  id bigint generated always as identity primary key,
  employee_no text,
  employee_name text,
  change_type text not null,
  old_group text,
  new_group text,
  detail text,
  change_date date not null default current_date,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name, role)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'display_name',''), 'viewer')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

grant execute on function public.is_admin() to authenticated;

-- 外籍合約到期資料：獨立敏感資料表，只允許 admin 讀寫
create table if not exists public.foreign_contracts (
  employee_no text primary key references public.employees(employee_no) on delete cascade,
  contract_end_date date not null,
  note text,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

alter table public.foreign_contracts enable row level security;

DROP POLICY IF EXISTS "foreign contracts admin read" ON public.foreign_contracts;
create policy "foreign contracts admin read" on public.foreign_contracts
for select to authenticated using (public.is_admin());

DROP POLICY IF EXISTS "foreign contracts admin insert" ON public.foreign_contracts;
create policy "foreign contracts admin insert" on public.foreign_contracts
for insert to authenticated with check (public.is_admin());

DROP POLICY IF EXISTS "foreign contracts admin update" ON public.foreign_contracts;
create policy "foreign contracts admin update" on public.foreign_contracts
for update to authenticated using (public.is_admin()) with check (public.is_admin());

DROP POLICY IF EXISTS "foreign contracts admin delete" ON public.foreign_contracts;
create policy "foreign contracts admin delete" on public.foreign_contracts
for delete to authenticated using (public.is_admin());

-- 班別統一為 日 / 中 / 夜
update public.employees
set shift = case
  when shift like '%中%' then '中'
  when shift like '%夜%' or shift like '%晚%' then '夜'
  else '日'
end;

alter table public.employees drop constraint if exists employees_shift_check;
alter table public.employees
add constraint employees_shift_check check (shift in ('日','中','夜'));


alter table public.profiles enable row level security;
alter table public.employees enable row level security;
alter table public.personnel_changes enable row level security;

-- profiles：每個登入者只能讀自己的角色
DROP POLICY IF EXISTS "profile read own" ON public.profiles;
create policy "profile read own" on public.profiles
for select to authenticated
using (id = auth.uid());

-- employees：所有登入同事可檢視；只有 admin 可增修刪
DROP POLICY IF EXISTS "employees read authenticated" ON public.employees;
create policy "employees read authenticated" on public.employees
for select to authenticated
using (true);

DROP POLICY IF EXISTS "employees insert admin" ON public.employees;
create policy "employees insert admin" on public.employees
for insert to authenticated
with check (public.is_admin());

DROP POLICY IF EXISTS "employees update admin" ON public.employees;
create policy "employees update admin" on public.employees
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

DROP POLICY IF EXISTS "employees delete admin" ON public.employees;
create policy "employees delete admin" on public.employees
for delete to authenticated
using (public.is_admin());

-- personnel_changes：所有登入者可看；只有 admin 可寫
DROP POLICY IF EXISTS "changes read authenticated" ON public.personnel_changes;
create policy "changes read authenticated" on public.personnel_changes
for select to authenticated
using (true);

DROP POLICY IF EXISTS "changes insert admin" ON public.personnel_changes;
create policy "changes insert admin" on public.personnel_changes
for insert to authenticated
with check (public.is_admin());

DROP POLICY IF EXISTS "changes update admin" ON public.personnel_changes;
create policy "changes update admin" on public.personnel_changes
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

DROP POLICY IF EXISTS "changes delete admin" ON public.personnel_changes;
create policy "changes delete admin" on public.personnel_changes
for delete to authenticated
using (public.is_admin());

-- 如果你是在建立資料表前就已建立第一個帳號，可補上 profile：
-- insert into public.profiles(id,email,role)
-- select id,email,'viewer' from auth.users
-- on conflict (id) do nothing;

-- 最後，把自己的帳號升級成管理員（請替換 EMAIL）：
-- update public.profiles set role='admin' where email='YOUR_EMAIL@example.com';


-- V3 使用者權限設定：
-- 到 Authentication > Users 建立：
-- 1. 共用 viewer 帳號，例如 viewer@your-company.local
-- 2. 你的管理員帳號
--
-- 建立後執行（請換成實際 Email）：
-- update public.profiles set role='viewer' where email='viewer@your-company.local';
-- update public.profiles set role='admin' where email='YOUR_ADMIN_EMAIL@example.com';
--
-- 注意：共用檢視密碼與管理員密碼都不要寫進 SQL、config.js 或 GitHub。
