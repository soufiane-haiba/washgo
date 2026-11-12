# SKINCAR Mobile

At-home car wash booking website for Rabat, Salé and Salé Al Jadida (Morocco).
Static HTML/CSS/JavaScript, with [Supabase](https://supabase.com) as the database and login.

## Pages

| File | Purpose |
|---|---|
| `index.html` | Public homepage: prices by vehicle, how it works, FAQ, booking form |
| `compte.html` | Customer account: sign up, saved details, booking history, settings |
| `rejoindre.html` | "Become a partner" form for car-wash professionals |
| `admin.html` | Admin dashboard: bookings, professionals, commissions (20 %), clients, applications |

## Other files

| File | Purpose |
|---|---|
| `config.js` | Supabase project URL and **anon public** key |
| `data.js` | Data layer (Supabase, or demo mode in the browser when `config.js` is empty) |
| `theme.js` | Colours (black + light grey + lime) |
| `i18n.js` | Site texts and legal pages |
| `legal.js` | Settings used in the privacy policy (retention, hosting region) |
| `setup.sql` | Database tables, prices and security rules (Row Level Security) |

## Setup

1. Create a Supabase project.
2. In **SQL Editor**, paste the whole `setup.sql` and click **Run**.
   At the end of the file, uncomment the `insert into public.admins` lines once and put your admin email.
3. In **Authentication > Users**, create the admin user with that same email.
4. In **Authentication > URL Configuration**, set the Site URL and add `…/compte.html` and `…/admin.html` to Redirect URLs.
5. Put the Project URL and the **anon public** key in `config.js` (never the `service_role` key).

Without step 5 the site runs in **demo mode**: everything stays in the browser and nothing is sent.

## Deploy

Pushing to `main` deploys the site to GitHub Pages (`.github/workflows/static.yml`).
Any static host works too (Netlify, Cloudflare Pages…).

## Prices

Prices live in two places that must stay identical:
`PRICES` in `index.html` (shown to customers) and `default_price` in `setup.sql` (saved on each booking).
After changing them, run `setup.sql` again.

## Security notes

- The anon key in `config.js` is meant to be public; access is controlled by the RLS rules in `setup.sql`.
- The public can only create bookings and applications, never read them. Customers only see their own data.
- Only emails listed in the `admins` table can use the dashboard.

## Email notifications

`setup.sql` emails you each new booking and partner application, through [Resend](https://resend.com) and `pg_net`.
1. Create a free Resend account with the email that should receive the notifications, then create an API key.
2. Run `setup.sql` in Supabase SQL Editor.
3. In SQL Editor (not in a file), run once:
   `insert into public.notify_settings (id, resend_api_key, notify_email) values (1, 're_…', 'you@email.com') on conflict (id) do update set resend_api_key = excluded.resend_api_key, notify_email = excluded.notify_email;`

Without your own domain verified in Resend, emails can only go to the address of your Resend account.
