-- SKINCAR Mobile : base de données
-- Supabase > SQL Editor > New query > coller tout ce fichier > Run.
-- Pour donner l'accès admin : voir la toute fin du fichier (une seule fois suffit).

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
  commission_pct numeric(5,2) not null default 20 check (commission_pct between 0 and 100),
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

-- Un professionnel peut travailler dans plusieurs villes (city garde la première, pour compatibilité)
alter table public.professionals add column if not exists cities text[] not null default '{}';
update public.professionals set cities = array[city] where cardinality(cities) = 0 and city is not null;
alter table public.professionals drop constraint if exists professionals_cities_check;
alter table public.professionals add constraint professionals_cities_check
  check (cities <@ array['Rabat', 'Salé', 'Salé Al Jadida']::text[]);

-- Repère sur la carte (facultatif)
alter table public.bookings add column if not exists latitude double precision;
alter table public.bookings add column if not exists longitude double precision;
-- Preuve du consentement du client (case cochée avant l'envoi)
alter table public.bookings add column if not exists consent_at timestamptz;
-- Compte client qui a fait la réservation (vide si réservation sans compte)
alter table public.bookings add column if not exists user_id uuid references auth.users(id) on delete set null;
-- Nom du professionnel tapé à la main dans le tableau de bord
alter table public.bookings add column if not exists professional_name text check (char_length(coalesce(professional_name, '')) <= 100);
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
    and professional_name is null
    -- le prix est calculé par la base (déclencheur bookings_set_price), jamais celui envoyé par le navigateur
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

-- Candidatures des professionnels (page « Devenir partenaire » : rejoindre.html)
create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text not null check (char_length(name) between 2 and 100),
  phone text not null check (char_length(phone) between 6 and 30),
  email text check (char_length(coalesce(email, '')) <= 200),
  city text not null check (city in ('Rabat', 'Salé', 'Salé Al Jadida', 'Autre')),
  zones text check (char_length(coalesce(zones, '')) <= 300),
  services text[] not null default '{}' check (cardinality(services) <= 4),
  experience text,
  has_equipment boolean not null default false,
  has_water boolean not null default false,
  has_transport boolean not null default false,
  availability text check (char_length(coalesce(availability, '')) <= 200),
  message text check (char_length(coalesce(message, '')) <= 1000),
  consent_at timestamptz not null,
  status text not null default 'new' check (status in ('new', 'contacted', 'accepted', 'rejected')),
  admin_notes text
);
create index if not exists applications_created_idx on public.applications (created_at desc);
-- expérience : « oui » / « non » (les anciennes valeurs restent acceptées)
alter table public.applications drop constraint if exists applications_experience_check;
alter table public.applications add constraint applications_experience_check
  check (experience is null or experience in ('oui', 'non', 'moins_1', '1_3', 'plus_3'));
-- plusieurs villes possibles par candidature (city garde la première, pour compatibilité)
alter table public.applications add column if not exists cities text[] not null default '{}';
alter table public.applications drop constraint if exists applications_cities_check;
alter table public.applications add constraint applications_cities_check
  check (cardinality(cities) <= 4 and cities <@ array['Rabat', 'Salé', 'Salé Al Jadida', 'Autre']::text[]);

alter table public.applications enable row level security;
revoke all on public.applications from anon, authenticated;
grant insert on public.applications to anon, authenticated;
grant select, update, delete on public.applications to authenticated;

-- Le public peut seulement ENVOYER une candidature, jamais la lire
drop policy if exists "site: envoyer une candidature" on public.applications;
create policy "site: envoyer une candidature" on public.applications
  for insert to anon, authenticated
  with check (status = 'new' and admin_notes is null and consent_at is not null);

drop policy if exists "admin: tout sur les candidatures" on public.applications;
create policy "admin: tout sur les candidatures" on public.applications
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Prix automatique : à chaque nouvelle réservation, la base met le prix du site dans « price » (prix final modifiable dans l'admin).
-- Gardez ces prix identiques à ceux de index.html (objet PRICES).
create or replace function public.default_price(p_vehicle text, p_service text)
returns numeric
language sql
immutable
as $$
  select (case
    when p_vehicle in ('SUV / 4x4', 'Utilitaire') then
      case p_service when 'Lavage extérieur' then 99 when 'Lavage intérieur' then 120 when 'Lavage complet' then 199 when 'Nettoyage premium' then 349 end
    else
      case p_service when 'Lavage extérieur' then 80 when 'Lavage intérieur' then 100 when 'Lavage complet' then 120 when 'Nettoyage premium' then 180 end
  end)::numeric;
$$;

create or replace function public.bookings_set_price()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- le public ne peut pas choisir son prix : on applique toujours le tarif du site
  if not public.is_admin() or new.price is null then
    new.price := public.default_price(new.vehicle, new.service);
  end if;
  return new;
end;
$$;

drop trigger if exists bookings_set_price on public.bookings;
create trigger bookings_set_price
  before insert on public.bookings
  for each row execute function public.bookings_set_price();

-- réservations déjà reçues sans prix : on leur met le tarif du site
update public.bookings set price = public.default_price(vehicle, service) where price is null;

-- ===== Notifications par email (Resend) : un email à chaque nouvelle réservation / candidature =====
-- La clé Resend et votre email sont rangés dans une table que personne ne peut lire depuis le site.
-- Pour les enregistrer (une seule fois, dans SQL Editor, PAS dans ce fichier) : voir notifications.local.sql.
-- Facultatif : site_url (ex. https://skincar.ma) ajoute un bouton « Ouvrir le tableau de bord » dans les emails.
create extension if not exists pg_net with schema extensions;

create table if not exists public.notify_settings (
  id int primary key default 1 check (id = 1),
  resend_api_key text,
  notify_email text,
  from_email text not null default 'SKINCAR <onboarding@resend.dev>',
  site_url text
);
alter table public.notify_settings add column if not exists resend_api_key text;
alter table public.notify_settings add column if not exists notify_email text;
alter table public.notify_settings add column if not exists from_email text not null default 'SKINCAR <onboarding@resend.dev>';
alter table public.notify_settings add column if not exists site_url text;
alter table public.notify_settings enable row level security;
revoke all on public.notify_settings from anon, authenticated;

-- ---------- petits outils pour écrire les emails ----------
-- protège le texte envoyé par les visiteurs avant de le mettre dans l'email
create or replace function public.html_esc(t text)
returns text language sql immutable as $$
  select replace(replace(replace(replace(coalesce(t, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;');
$$;

-- texte dans une adresse web (Google Maps, WhatsApp)
create or replace function public.url_q(t text)
returns text language sql immutable as $$
  select replace(replace(replace(replace(replace(replace(coalesce(t, ''), '%', '%25'), '&', '%26'), '#', '%23'), '?', '%3F'), '+', '%2B'), ' ', '+');
$$;

-- 0612345678 -> 212612345678 (pour wa.me)
create or replace function public.wa_digits(p text)
returns text language sql immutable as $$
  select case when d ~ '^0[0-9]{9}$' then '212' || substr(d, 2) else d end
  from (select regexp_replace(coalesce(p, ''), '\D', '', 'g') as d) x;
$$;

-- 199.00 -> 199
create or replace function public.dh(n numeric)
returns text language sql immutable as $$
  select case when n is null then '—' else regexp_replace(regexp_replace(n::text, '(\.\d*?)0+$', '\1'), '\.$', '') || ' DH' end;
$$;

-- 2026-11-29 -> samedi 29 novembre 2026
create or replace function public.fr_date(d date)
returns text language sql immutable as $$
  select (array['dimanche','lundi','mardi','mercredi','jeudi','vendredi','samedi'])[extract(dow from d)::int + 1]
         || ' ' || extract(day from d)::int || ' '
         || (array['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'])[extract(month from d)::int]
         || ' ' || extract(year from d)::int;
$$;

create or replace function public.email_btn(label text, url text, bg text, fg text)
returns text language sql immutable as $$
  select '<a href="' || public.html_esc(url) || '" style="display:inline-block;margin:0 8px 10px 0;padding:12px 18px;border-radius:10px;background:' || bg
         || ';color:' || fg || ';font-weight:bold;font-size:14px;text-decoration:none;border:1px solid ' || case when bg = '#ffffff' then '#d6d6d6' else bg end || '">'
         || public.html_esc(label) || '</a>';
$$;

create or replace function public.email_row(label text, value_html text)
returns text language sql immutable as $$
  select '<tr><td style="padding:14px 0;border-top:1px solid #eeeeee;width:118px;vertical-align:top;color:#777777;font-size:13px">' || public.html_esc(label)
         || '</td><td style="padding:14px 0;border-top:1px solid #eeeeee;vertical-align:top;font-size:15px;color:#111111">' || value_html || '</td></tr>';
$$;

-- cadre commun : en-tête noir SKINCAR, titre, contenu, pied
create or replace function public.email_shell(badge text, kicker text, title text, preheader text, body_html text)
returns text language sql immutable as $$
  select '<!doctype html><html><body style="margin:0;padding:0;background:#eeeeee">'
    || '<span style="display:none;max-height:0;overflow:hidden;opacity:0;color:#eeeeee">' || public.html_esc(preheader) || '</span>'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#eeeeee;padding:24px 12px"><tr><td align="center">'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:580px;background:#ffffff;border-radius:16px;overflow:hidden;font-family:Arial,Helvetica,sans-serif;color:#111111">'
    || '<tr><td style="background:#000000;padding:20px 26px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>'
    ||   '<td style="font-size:22px;font-weight:bold;letter-spacing:1px;color:#ffffff">SKINCAR<span style="display:block;font-size:10px;letter-spacing:4px;color:#9a9a9a;font-weight:normal;margin-top:2px">MOBILE</span></td>'
    ||   '<td align="right"><span style="display:inline-block;background:#B7F36B;color:#000000;font-size:12px;font-weight:bold;padding:7px 13px;border-radius:999px">' || public.html_esc(badge) || '</span></td>'
    || '</tr></table></td></tr>'
    || '<tr><td style="padding:28px 26px 6px"><div style="font-size:12px;color:#777777;text-transform:uppercase;letter-spacing:1.5px">' || public.html_esc(kicker) || '</div>'
    ||   '<h1 style="margin:6px 0 0;font-size:24px;line-height:1.25;color:#111111">' || public.html_esc(title) || '</h1></td></tr>'
    || '<tr><td style="padding:16px 26px 10px">' || body_html || '</td></tr>'
    || '<tr><td style="padding:18px 26px;background:#f7f7f7;color:#888888;font-size:12px;line-height:1.5">Email automatique envoyé par SKINCAR. Vous le recevez parce que votre adresse est enregistrée pour les notifications du site.</td></tr>'
    || '</table></td></tr></table></body></html>';
$$;

-- envoi par Resend (ne bloque jamais l'enregistrement si l'email échoue)
drop function if exists public.notify_email(text, text[][]);
create or replace function public.send_email(subject text, html text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare s record;
begin
  select * into s from public.notify_settings where id = 1;
  if s is null or coalesce(s.resend_api_key, '') = '' or coalesce(s.notify_email, '') = '' then return; end if;
  perform net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object('Authorization', 'Bearer ' || s.resend_api_key, 'Content-Type', 'application/json'),
    body := jsonb_build_object('from', s.from_email, 'to', jsonb_build_array(s.notify_email), 'subject', subject, 'html', html)
  );
exception when others then
  raise warning 'send_email : %', sqlerrm;
end;
$$;
revoke all on function public.send_email(text, text) from public, anon, authenticated;

create or replace function public.site_url()
returns text language sql stable security definer set search_path = public as $$
  select nullif(rtrim(coalesce((select site_url from public.notify_settings where id = 1), ''), '/'), '');
$$;
revoke all on function public.site_url() from public, anon, authenticated;

-- ---------- nouvelle réservation ----------
create or replace function public.bookings_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  maps text; wa text; site text; body_html text;
begin
  maps := case when new.latitude is not null and new.longitude is not null
            then 'https://www.google.com/maps/search/?api=1&query=' || new.latitude || ',' || new.longitude
            else 'https://www.google.com/maps/search/?api=1&query=' || public.url_q(new.address || ', ' || new.city || ', Maroc') end;
  wa := 'https://wa.me/' || public.wa_digits(new.phone) || '?text='
        || public.url_q('Bonjour ' || coalesce(new.customer_name, '') || ', ici SKINCAR. Nous confirmons votre réservation ' || new.ref || ' du ' || public.fr_date(new.scheduled_date) || ' à ' || new.scheduled_time || '.');
  site := public.site_url();

  body_html :=
       '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f3fde6;border:1px solid #d7f3b0;border-radius:14px"><tr>'
    || '<td style="padding:18px 20px"><div style="font-size:12px;color:#4d6b1f;text-transform:uppercase;letter-spacing:1px">Rendez-vous</div>'
    ||   '<div style="font-size:19px;font-weight:bold;margin-top:4px">' || public.html_esc(upper(left(public.fr_date(new.scheduled_date), 1)) || substr(public.fr_date(new.scheduled_date), 2)) || '</div>'
    ||   '<div style="font-size:16px;margin-top:2px">à <b>' || public.html_esc(new.scheduled_time) || '</b></div></td>'
    || '<td align="right" style="padding:18px 20px;white-space:nowrap"><div style="font-size:12px;color:#4d6b1f;text-transform:uppercase;letter-spacing:1px">Prix</div>'
    ||   '<div style="font-size:26px;font-weight:bold;margin-top:4px">' || public.html_esc(public.dh(new.price)) || '</div></td>'
    || '</tr></table>'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:14px">'
    || public.email_row('Service', '<b>' || public.html_esc(new.service) || '</b><br><span style="color:#555555">' || public.html_esc(new.vehicle) || '</span>')
    || public.email_row('Client', '<b>' || public.html_esc(coalesce(new.customer_name, 'Sans nom')) || '</b><br><a href="tel:' || public.html_esc(new.phone) || '" style="color:#111111">' || public.html_esc(new.phone) || '</a>')
    || public.email_row('Adresse', public.html_esc(new.city) || '<br><span style="color:#555555">' || public.html_esc(new.address) || '</span>'
         || case when new.latitude is not null then '<br><span style="font-size:13px;color:#4d6b1f">Repère placé sur la carte</span>' else '' end)
    || case when coalesce(new.notes, '') <> '' then public.email_row('Notes', public.html_esc(new.notes)) else '' end
    || public.email_row('Référence', '<span style="font-family:monospace;font-size:14px">' || public.html_esc(new.ref) || '</span>')
    || '</table>'
    || '<div style="padding-top:18px">'
    ||   public.email_btn('Appeler le client', 'tel:' || new.phone, '#111111', '#B7F36B')
    ||   public.email_btn('WhatsApp', wa, '#25D366', '#ffffff')
    ||   public.email_btn('Itinéraire', maps, '#ffffff', '#111111')
    ||   case when site is not null then public.email_btn('Ouvrir le tableau de bord', site || '/admin.html', '#ffffff', '#111111') else '' end
    || '</div>';

  perform public.send_email(
    'Nouvelle réservation · ' || new.service || ' · ' || to_char(new.scheduled_date, 'DD/MM') || ' à ' || new.scheduled_time,
    public.email_shell('Nouvelle réservation', 'Réf. ' || new.ref, new.service || ' — ' || new.vehicle,
      new.city || ', ' || public.fr_date(new.scheduled_date) || ' à ' || new.scheduled_time || ' · ' || public.dh(new.price), body_html)
  );
  return new;
end;
$$;
drop trigger if exists bookings_notify on public.bookings;
create trigger bookings_notify after insert on public.bookings
  for each row execute function public.bookings_notify();

-- ---------- nouvelle candidature de professionnel ----------
create or replace function public.applications_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  wa text; site text; body_html text; villes text;
begin
  villes := coalesce(nullif(array_to_string(new.cities, ', '), ''), new.city);
  wa := 'https://wa.me/' || public.wa_digits(new.phone) || '?text='
        || public.url_q('Bonjour ' || new.name || ', ici SKINCAR. Merci pour votre candidature, pouvons-nous en parler ?');
  site := public.site_url();

  body_html :=
       '<table role="presentation" width="100%" cellpadding="0" cellspacing="0">'
    || public.email_row('Téléphone', '<a href="tel:' || public.html_esc(new.phone) || '" style="color:#111111"><b>' || public.html_esc(new.phone) || '</b></a>')
    || case when coalesce(new.email, '') <> '' then public.email_row('Email', public.html_esc(new.email)) else '' end
    || public.email_row('Villes', public.html_esc(villes))
    || public.email_row('Services', public.html_esc(coalesce(nullif(array_to_string(new.services, ', '), ''), '—')))
    || public.email_row('Expérience', case new.experience when 'oui' then 'Oui' when 'non' then 'Non' else public.html_esc(coalesce(new.experience, '—')) end)
    || public.email_row('Matériel', case when new.has_equipment then 'A son matériel' else 'N''a pas de matériel' end)
    || case when coalesce(new.availability, '') <> '' then public.email_row('Disponibilités', public.html_esc(new.availability)) else '' end
    || case when coalesce(new.message, '') <> '' then public.email_row('Message', public.html_esc(new.message)) else '' end
    || '</table>'
    || '<div style="padding-top:18px">'
    ||   public.email_btn('Appeler', 'tel:' || new.phone, '#111111', '#B7F36B')
    ||   public.email_btn('WhatsApp', wa, '#25D366', '#ffffff')
    ||   case when site is not null then public.email_btn('Voir les candidatures', site || '/admin.html', '#ffffff', '#111111') else '' end
    || '</div>';

  perform public.send_email(
    'Nouvelle candidature · ' || new.name || ' · ' || villes,
    public.email_shell('Candidature', 'Devenir partenaire', new.name, villes || ' · ' || new.phone, body_html)
  );
  return new;
end;
$$;
drop trigger if exists applications_notify on public.applications;
create trigger applications_notify after insert on public.applications
  for each row execute function public.applications_notify();

-- Votre compte admin (même email que l'utilisateur créé dans Authentication > Users).
-- Enlevez les "--" des deux lignes ci-dessous et mettez votre email (une seule fois suffit : il reste enregistré ensuite).
-- insert into public.admins (email) values ('TON_EMAIL@EXEMPLE.COM')
-- on conflict (email) do nothing;
