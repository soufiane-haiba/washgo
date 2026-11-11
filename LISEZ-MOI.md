# WASHGO Mobile: site + dashboard admin

Had l-dossier fih:
- `index.html` = l-site dyal l-clients (formulaire dyal l-réservation)
- `compte.html` = l-page fin l-client kaydir compte w kaychouf l-réservations dyalo
- `admin.html` = l-dashboard dyalek (khass login)
- `theme.js` = l-alwan dyal l-site (k7el w gris)
- `config.js` = fin tkteb l-clés dyal Supabase
- `i18n.js` = l-traductions dyal l-site (Français, العربية, English)
- `legal.js` = l-réglages dyal les pages légales
- `data.js` = l-code li kaykellem Supabase (ma tms-ouch)
- `setup.sql` = kay-sayb l-base de données w l-sécurité

Kifach kaykhdem: l-client kay3emmer l-formulaire f `index.html`, l-réservation katkhzen f Supabase (base de données), w nta kat-chouf-ha f `admin.html`. Ma kayn walo f WhatsApp.

Ma tkhdemch hta tdir l-khatwat men 1 l 5. Tqdr tjarreb l-design 9bel: 7ell `index.html` w `admin.html` f navigateur bla ma tbeddel walo, ghaydkhlo f **mode démo** (exemples, rien ma kaytsift).

## 1) Compte Supabase (majjani)

1. Dkhel l **supabase.com**, sjjel compte, w dir **New project**.
2. Khtar region qrib (mital **Frankfurt**), w hett mot de passe l-base de données f blast amn.
3. Tsnna chwiya 7ta ykoun l-project wajed.

## 2) Sayb l-base de données

1. F l-menu: **SQL Editor** > **New query**.
2. 7ell `setup.sql` f Bloc-notes w **bddel `TON_EMAIL@EXEMPLE.COM`** (f lakher dyal l-fichier) b l-email li ghadi tdkhel bih l-dashboard.
3. Copi kolchi, hettou f SQL Editor, w dghet **Run**. Khass ytl3 "Success".

## 3) Sayb l-compte admin

1. F l-menu: **Authentication** > **Users** > **Add user** > **Create new user**.
2. Hett **nafs l-email** li ktebti f `setup.sql` w mot de passe qwi.
3. **Authentication** > **Sign In / Providers**: **khlli "Allow new users to sign up" mfto7**, 7it l-clients kaydiro comptes f `compte.html`. Hadchi ma kay3tihomch l-admin: ghir l-email li f table `admins` (f `setup.sql`) li kaydkhol l-dashboard.
4. Khlli **"Confirm email"** mfto7 (kayn par défaut): l-client kaywslo email fih lien bach y-activi l-compte.
5. **Authentication** > **URL Configuration**: f **Site URL** 7ett l-lien dyal l-site (mital `https://ton-lien.netlify.app`), w f **Redirect URLs** zid `https://ton-lien.netlify.app/compte.html`. Bla hadchi, l-lien li f l-email ma ghaydikch l l-page dyal compte.

## 4) Hett l-clés f `config.js`

1. F Supabase: **Project Settings** > **API**.
2. Copi **Project URL** w **anon public key**.
3. 7ell `config.js` w hettohom:

```js
window.WASHGO_CONFIG = {
  SUPABASE_URL: "https://xxxx.supabase.co",
  SUPABASE_ANON_KEY: "eyJ..."
};
```

Mhimm: **ma tst3mlch l-clé `service_role`** hna, jamais. L-clé `anon` 3adi tban f l-site: l-sécurité kayna f `setup.sql` (l-public ghir kay-sayb réservation, ma kaychoufhach).

## 5) Nshr l-site

1. Dkhel l **app.netlify.com/drop** (compte majjani).
2. Jjer l-dossier kaml (kol l-fichiers: index.html, compte.html, admin.html, config.js, legal.js, i18n.js, data.js, theme.js) l dak s-safha.
3. Netlify kay3tik lien. `ton-lien.netlify.app` = l-site dyal l-clients. `ton-lien.netlify.app/admin.html` = l-dashboard dyalek (7fdh had l-lien l-nafsek).

## 6) Jarreb

1. 7ell l-site, dir réservation tajribiya.
2. 7ell `.../admin.html`, dkhel b l-email w mot de passe, w khass tchouf l-réservation. Hna tqdr tbeddel l-statut, t3ayyen professionnel w t7ott l-prix.
3. Zid professionnels men tab **Professionnels**. 9bel ma t3ayyen chi wa7ed khass ykoun mojoud.

Ila chi 7aja ma khdmatch, goul liya chno ban lik (mital: "Email ou mot de passe incorrect", wla "L'envoi a échoué") w nsa7e7ha.

## Chno kayn f dashboard

- **Réservations**: lista, filtre b statut, recherche, w fiche dyal kol réservation (statut, professionnel, prix final, notes, bouton WhatsApp l l-client).
- **Professionnels**: ajouter / modifier (ville, quartiers, services, horaires, commission %, disponibilité).
- **Commissions**: kol pro, chhal 3emmel, chhal commission dyal WASHGO, w "Marquer réglé" mnin yjib lik l-commission.
- **Clients**: lista dyal l-clients men l-réservations.

Mazal ma kaynch: Reviews (avis), Settings (prix / villes / commission global), paiement f internet, w notification automatique. Nzidhom mnin tkoun wajed.

## Comptes clients (`compte.html`)

- L-client kaydir compte b **email + mot de passe**, w kay3emmer merra wa7da: smiya, téléphone, ville, tomobil, adresse.
- Mlli ykoun connecté, l-formulaire dyal réservation f `index.html` kayt3emmer bo7do. Kaykhtar ghir **service, nhar w sa3a** w kaysift.
- F `compte.html` kaybeddel l-ma3loumat dyalo w kaychouf l-réservations dyalo b l-statut (Reçue, Confirmée, Terminée...).
- Kol réservation jdida katbeddel l-ma3loumat l-mkhzouna b lekhrin li ktb (mital ila bddel l-adresse).
- "Mot de passe oublié" kaysift email fih lien bach ydir mot de passe jdid.
- Réservation bla compte mazal khdama 3adi.

Ila kenti deja drti Run l `setup.sql` 9bel, **3awd dir Run** 3la l-version jdida: kayzid table `customers` w colonne `user_id` f `bookings`, w ma kaymsa7 walo.

Mhimm: l-page dyal confidentialité (f `i18n.js`) mazal katgoul ghir 3la l-réservations. Khassek tzid fiha bli kayn comptes w bli l-ma3loumat katb9a mkhzouna 7ta ymsa7 l-client l-compte dyalo (yt-sal b WASHGO). W golha l CNDP f déclaration.

## Langue

Daba l-site b l-**français ghir**. `i18n.js` fih deja l-traductions l l-3arabiya w l-injliziya, ila bghiti trj3ohom mn b3d (khass nzid bouton dyal l-lugha f l-header).

## Alwan

L-hero w l-footer b **gris clair** (machi noir). Bach tbeddel l-gris, bdel `--hero-bg` f `index.html`.

## Tswira dyal l-homepage

F l-hero kayn illustration dyal pro kaylaves tomobil (b l-alwan dyal WASHGO). Ila bghiti tswira 7a9i9iya dyalek: 7ett fichier smito **`hero.jpg`** f nafs l-dossier m3a `index.html`, w kat7ell blast l-illustration otomatikiyan. Nsa7ek tswira ofoqiya (3ard > tol), 7ajmha ≤ 300 KB, w ma tkounch fiha wjouh wla plaques dyal nass bla idnhom.

## Pages légales (confidentialité + mentions légales)

F l-footer dyal l-site kayn **Politique de confidentialité** w **Mentions légales** (mktoubin 3la l-loi marocaine 09-08). Ka-ytfta7o f fenêtre, w l-client kay-cochi case dyal consentement 9bel ma ysift l-réservation (kay-tsjjel l-date dyalo f l-base).

**Khass tdir 9bel ma tnshr**:
1. `legal.js`: bddel (ila khass) l-durée de conservation, l-région d'hébergement w l-hébergeur dyal l-site. Ma b9ach fih smiyt l-société, l-ICE wla l-email, 7it mssa7nahom men l-pages.
2. **Déclaration l CNDP** (cndp.ma, Avenue Al Arz, Secteur 4, M1, Hay Riad, Rabat, tel 05 37 57 11 24, contact@cndp.ma): l-loi 09-08 kat-tleb déclaration 9bel ma tjma3 donnés dyal nass. Khass tkon 3ndk l-texte dyal confidentialité (hada) w l-formulaire. 9ol l CNDP bli l-base kayna f serveurs f l-Europe (Supabase) w tsawlhom 3la l-procédure dyal transfert l l-kharij.
3. Chouf m3a avocat wla spécialiste mghribi: hadchi modèle w machi consultation juridique, w l-plan dyalek rah kay9ol bli l-contrats m3a l-professionnels khass yb9aw m3a mokhtass.

Mlahadat: durée de conservation f `legal.js` hiya **24 mois** par défaut (bddlha ila bghiti), w l-région d'hébergement hiya "l'Union européenne (Allemagne)" (khtar **Frankfurt** f Supabase, wla bddel l-ktaba).

## Carte (repère)

Kayn f formulaire dyal l-client carte (Leaflet + OpenStreetMap, majjani): l-client kayt9el 3la l-blasa wla kaydir "Utiliser ma position" (khasso ykon l-site 3la HTTPS, w Netlify kay3tik had chi). L-repère facultatif. F dashboard, f fiche dyal l-réservation, kayn "Voir sur la carte" w "Itinéraire" (Google Maps).

OpenStreetMap majjani walakin ma yst7a9ch trafic kbir. Ila kberti bzaf, khass provider dyal les tuiles (MapTiler, Stadia...). Ila 7ellti deja `setup.sql` f Supabase 9bel had l-carte, 3awd dir Run 3la l-version jdida (ma kaymsa7 walo, kayzid ghir 2 colonnes).

## Ma3loumat mohima

- Supabase majjani: ila ma kaynch activité chi ayyam, l-project 9d ykoun f "pause", w tkhssk t3awd t-activih men l-dashboard dyal Supabase.
- Bhal f l-plan dyalek: l-client kay-khlless l-pro mobacharatan, w WASHGO kat7seb l-commission f tab **Commissions**.
- Jarrebt l-formulaire w l-dashboard f mode démo, walakin ma jarrebthomch m3a compte Supabase 7a9i9i (ma 3ndich l-clés dyalek). Ila ban chi moshkil mnin tdir l-khatwat, goul liya.
