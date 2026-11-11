-- WASHGO Mobile : base de données
-- Supabase > SQL Editor > New query > coller tout ce fichier > Run.
-- AVANT de lancer: remplacez TON_EMAIL@EXEMPLE.COM (tout en bas) par l'email de votre compte admin.

create table if not exists public.admins (
  email text primary key
);

create table if not exists public.professionals (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text not null,
  phone text not null,
  city text not null,
  zones text,
  services text[] not null default '{}',
  hours text,
  has_equipment boolean not null default true,
  has_water boolean not null default true,
  availability text not null default 'available' check (availability in ('available', 'busy', 'unavailable')),
  commission_pct numeric(5,2) not null default 15 check (commission_pct between 0 and 100),
  notes text
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  ref text not null unique check (ref ~ '^WG-[0-9A-Z]{4,6}-[A-Z0-9]{4}$'),
  created_at timestamptz not null default now(),
  city text not null,
  service text not null,
  vehicle text not null,
  address text not null,
  scheduled_date date not null,
  scheduled_time text not null,
  phone text not null,
  customer_name text,
  notes text,
  status text not null default 'New'
    check (status in ('New', 'Assigned', 'Accepted', 'On the way', 'In progress', 'Completed', 'Cancelled')),
  professional_id uuid references public.professionals(id) on delete set null,
  price numeric(10,2) check (price is null or price >= 0),
  admin_notes text,
  completed_at timestamptz,
  commission_settled boolean not null default false
);

-- Repère sur la carte (facultatif)
alter table public.bookings add column if not exists latitude double precision;
alter table public.bookings add column if not exists longitude double precision;
-- Preuve du consentement du client (case cochée avant l'envoi)
alter table public.bookings add column if not exists consent_at timestamptz;
-- Compte client qui a fait la réservation (vide si réservation sans compte)
alter table public.bookings add column if not exists user_id uuid references auth.users(id) on delete set null;
create index if not exists bookings_user_idx on public.bookings (user_id);

-- Comptes clients : informations enregistrées une fois, reprises à chaque réservation
create table if not exists public.customers (
  id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  email text,
  full_name text check (char_length(coalesce(full_name, '')) <= 100),
  phone text check (char_length(coalesce(phone, '')) <= 30),
  city text check (city is null or city in ('Rabat', 'Salé', 'Salé Al Jadida')),
  vehicle text check (vehicle is null or vehicle in ('Citadine', 'Berline', 'SUV / 4x4', 'Utilitaire')),
  address text check (char_length(coalesce(address, '')) <= 300),
  latitude double precision check (latitude is null or latitude between 20 and 37),
  longitude double precision check (longitude is null or longitude between -18 and 0),
  consent_at timestamptz
);

create index if not exists bookings_created_idx on public.bookings (created_at desc);
create index if not exists bookings_status_idx on public.bookings (status);

-- Qui est admin ? (utilisé par les règles et par la page admin)
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admins a
    where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- Sécurité (RLS): le public peut seulement CRÉER une réservation, jamais la lire.
alter table public.admins enable row level security;
alter table public.professionals enable row level security;
alter table public.bookings enable row level security;

revoke all on public.admins from anon, authenticated;
revoke all on public.professionals from anon, authenticated;
revoke all on public.bookings from anon, authenticated;

grant insert on public.bookings to anon;
grant select, insert, update, delete on public.bookings to authenticated;
grant select, insert, update, delete on public.professionals to authenticated;

drop policy if exists "site: creer une reservation" on public.bookings;
create policy "site: creer une reservation" on public.bookings
  for insert to anon, authenticated
  with check (
    -- sans compte : user_id vide ; avec compte : seulement son propre identifiant
    (user_id is null or user_id = auth.uid())
    and status = 'New'
    and professional_id is null
    and price is null
    and admin_notes is null
    and completed_at is null
    and commission_settled = false
    and consent_at is not null
    and city in ('Rabat', 'Salé', 'Salé Al Jadida')
    and service in ('Lavage extérieur', 'Lavage intérieur', 'Lavage complet', 'Nettoyage premium')
    and vehicle in ('Citadine', 'Berline', 'SUV / 4x4', 'Utilitaire')
    and char_length(address) between 3 and 300
    and char_length(phone) between 6 and 30
    and char_length(coalesce(notes, '')) <= 600
    and char_length(coalesce(customer_name, '')) <= 100
    and scheduled_date between current_date - 1 and current_date + 365
    and (
      (latitude is null and longitude is null)
      or (latitude between 20 and 37 and longitude between -18 and 0)
    )
  );

drop policy if exists "admin: tout sur les reservations" on public.bookings;
create policy "admin: tout sur les reservations" on public.bookings
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Un client connecté voit seulement SES réservations (jamais celles des autres)
drop policy if exists "client: voir ses reservations" on public.bookings;
create policy "client: voir ses reservations" on public.bookings
  for select to authenticated
  using (user_id = auth.uid());

-- Comptes clients : chacun lit et modifie seulement son propre profil ; l'admin peut tout lire
alter table public.customers enable row level security;
revoke all on public.customers from anon, authenticated;
grant select, insert, update on public.customers to authenticated;

drop policy if exists "client: son profil" on public.customers;
create policy "client: son profil" on public.customers
  for all to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists "admin: lire les clients" on public.customers;
create policy "admin: lire les clients" on public.customers
  for select to authenticated
  using (public.is_admin());

drop policy if exists "admin: tout sur les professionnels" on public.professionals;
create policy "admin: tout sur les professionnels" on public.professionals
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Votre compte admin (même email que l'utilisateur créé dans Authentication > Users)
insert into public.admins (email) values ('TON_EMAIL@EXEMPLE.COM')
on conflict (email) do nothing;
