-- =============================================
-- Math Kangaroo · Supabase 数据库初始化脚本
-- 在 Supabase → SQL Editor 里运行这段代码
-- =============================================

-- 1. 用户信息表
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  name text not null,
  email text,
  role text default 'student',  -- 'student' | 'admin'
  created_at timestamptz default now(),
  -- 统计汇总字段（快速查询用）
  total_answered int default 0,
  total_correct int default 0,
  total_time int default 0
);

-- 2. 答题记录表
create table if not exists public.answers (
  id bigserial primary key,
  user_id uuid references public.profiles(id) on delete cascade,
  question_id int not null,
  year int not null,
  difficulty text not null,
  is_correct boolean not null,
  attempt_number int default 1,  -- 1=第1次对, 2=第2次对/错
  time_taken int default 0,
  created_at timestamptz default now()
);

-- 3. 开启 Row Level Security
alter table public.profiles enable row level security;
alter table public.answers enable row level security;

-- 4. profiles 策略
-- 用户只能读写自己的数据
create policy "users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

create policy "users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

-- admin 可以读所有人的数据
create policy "admin can view all profiles"
  on public.profiles for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- 5. answers 策略
create policy "users can view own answers"
  on public.answers for select
  using (auth.uid() = user_id);

create policy "users can insert own answers"
  on public.answers for insert
  with check (auth.uid() = user_id);

create policy "admin can view all answers"
  on public.answers for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- 6. 自动创建 profile（注册时触发）
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.email
  );
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ✅ 完成！运行后去 Authentication → Providers 开启 Email 登录
