// Couche de données de SKINCAR: Supabase si config.js est rempli, sinon mode démo (navigateur).
(function () {
  var cfg = window.WASHGO_CONFIG || {};
  var live = !!(cfg.SUPABASE_URL && cfg.SUPABASE_ANON_KEY && window.supabase && window.supabase.createClient);
  var sb = live ? window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY) : null;
  var KEY = "washgo-demo-v1";
  var mem = null;

  function pad(n) { return String(n).padStart(2, "0"); }
  function isoDate(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
  function dayOffset(n) { var d = new Date(); d.setDate(d.getDate() + n); return isoDate(d); }
  function minutesAgo(n) { return new Date(Date.now() - n * 60000).toISOString(); }
  function uuid() {
    try { if (window.crypto && crypto.randomUUID) return crypto.randomUUID(); } catch (e) {}
    return "id-" + Date.now().toString(36) + Math.random().toString(36).slice(2, 10);
  }
  function refCode() {
    var d = new Date(), chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789", s = "";
    for (var i = 0; i < 4; i++) s += chars.charAt(Math.floor(Math.random() * chars.length));
    return "WG-" + String(d.getFullYear()).slice(2) + pad(d.getMonth() + 1) + pad(d.getDate()) + "-" + s;
  }
  function clone(x) { return JSON.parse(JSON.stringify(x)); }

  // ---------- mode démo ----------
  function seed() {
    var p1 = uuid(), p2 = uuid(), p3 = uuid();
    function bk(o) {
      return Object.assign({ id: uuid(), created_at: minutesAgo(30), customer_name: null, notes: null, status: "New",
        professional_id: null, price: null, admin_notes: null, completed_at: null, commission_settled: false }, o);
    }
    return {
      professionals: [
        { id: p1, name: "Pro 01 (exemple)", phone: "0600000001", city: "Rabat", zones: "Agdal, Hay Riad, Souissi",
          services: ["Lavage extérieur", "Lavage intérieur", "Lavage complet"], hours: "09:00–19:00",
          has_equipment: true, has_water: true, availability: "available", commission_pct: 15, notes: null },
        { id: p2, name: "Pro 02 (exemple)", phone: "0600000002", city: "Salé", zones: "Tabriquet, Hay Salam",
          services: ["Lavage extérieur", "Lavage complet", "Nettoyage premium"], hours: "08:00–18:00",
          has_equipment: true, has_water: true, availability: "busy", commission_pct: 15, notes: null },
        { id: p3, name: "Pro 03 (exemple)", phone: "0600000003", city: "Salé Al Jadida", zones: "Salé Al Jadida",
          services: ["Lavage extérieur", "Lavage intérieur"], hours: "10:00–19:00",
          has_equipment: true, has_water: false, availability: "available", commission_pct: 20, notes: null }
      ],
      bookings: [
        bk({ ref: "WG-DEMO-0001", created_at: minutesAgo(12), city: "Rabat", service: "Lavage complet", vehicle: "SUV / 4x4",
          address: "Agdal, rue Oued Fès, parking de l'immeuble", scheduled_date: dayOffset(0), scheduled_time: "10:00",
          phone: "0611111101", customer_name: "Client 01", notes: "Code de la résidence 1234" }),
        bk({ ref: "WG-DEMO-0002", created_at: minutesAgo(55), city: "Salé", service: "Lavage extérieur", vehicle: "Citadine",
          address: "Tabriquet, avenue principale", scheduled_date: dayOffset(1), scheduled_time: "14:00",
          phone: "0611111102", customer_name: "Client 02" }),
        bk({ ref: "WG-DEMO-0003", created_at: minutesAgo(180), city: "Rabat", service: "Lavage intérieur", vehicle: "Berline",
          address: "Hay Riad, près du centre commercial", scheduled_date: dayOffset(0), scheduled_time: "16:00",
          phone: "0611111103", customer_name: "Client 03", status: "Assigned", professional_id: p1 }),
        bk({ ref: "WG-DEMO-0004", created_at: minutesAgo(300), city: "Salé Al Jadida", service: "Lavage extérieur", vehicle: "Utilitaire",
          address: "Salé Al Jadida, avenue principale", scheduled_date: dayOffset(0), scheduled_time: "11:00",
          phone: "0611111104", customer_name: "Client 04", status: "In progress", professional_id: p3, price: 100 }),
        bk({ ref: "WG-DEMO-0005", created_at: minutesAgo(1500), city: "Rabat", service: "Lavage complet", vehicle: "Berline",
          address: "Souissi, avenue des Zaërs", scheduled_date: dayOffset(-1), scheduled_time: "09:00",
          phone: "0611111105", customer_name: "Client 05", status: "Completed", professional_id: p1, price: 120,
          completed_at: minutesAgo(1300) }),
        bk({ ref: "WG-DEMO-0006", created_at: minutesAgo(2900), city: "Salé", service: "Nettoyage premium", vehicle: "SUV / 4x4",
          address: "Tabriquet, résidence Al Amal", scheduled_date: dayOffset(-2), scheduled_time: "15:00",
          phone: "0611111106", customer_name: "Client 06", status: "Completed", professional_id: p2, price: 180,
          completed_at: minutesAgo(2700) })
      ]
    };
  }
  function load() {
    if (mem) return mem;
    try {
      var raw = window.localStorage.getItem(KEY);
      if (raw) { var s = JSON.parse(raw); if (s && s.bookings && s.professionals) { mem = s; return mem; } }
    } catch (e) {}
    mem = seed();
    return mem;
  }
  function save() { try { window.localStorage.setItem(KEY, JSON.stringify(mem)); } catch (e) {} }

  // ---------- Supabase ----------
  function ok(r) { if (r.error) throw r.error; return r.data; }
  function insertWithRetry(row, tries) {
    return sb.from("bookings").insert(row).then(function (r) {
      if (r.error) {
        if (r.error.code === "23505" && tries > 0) { row.ref = refCode(); return insertWithRetry(row, tries - 1); }
        throw r.error;
      }
      return row.ref;
    });
  }

  var api = { live: live, refCode: refCode };

  // mode démo : même tarif que la base (fonction default_price de setup.sql)
  function demoPrice(vehicle, service) {
    var big = vehicle === "SUV / 4x4" || vehicle === "Utilitaire";
    var t = big ? { "Lavage extérieur": 99, "Lavage intérieur": 120, "Lavage complet": 199, "Nettoyage premium": 349 }
                : { "Lavage extérieur": 80, "Lavage intérieur": 100, "Lavage complet": 120, "Nettoyage premium": 180 };
    return t[service] != null ? t[service] : null;
  }
  api.createBooking = function (fields) {
    var row = Object.assign({}, fields, { ref: refCode() });
    if (live) return insertWithRetry(row, 3);
    var s = load();
    s.bookings.unshift(Object.assign({ id: uuid(), created_at: new Date().toISOString(), status: "New", professional_id: null,
      admin_notes: null, completed_at: null, commission_settled: false }, row, { price: demoPrice(row.vehicle, row.service) }));
    save();
    return Promise.resolve(row.ref);
  };

  api.user = function () {
    if (!live) return Promise.resolve({ email: "démo" });
    return sb.auth.getSession().then(function (r) { return r.data && r.data.session ? r.data.session.user : null; });
  };
  api.signIn = function (email, password) {
    if (!live) return Promise.resolve({ email: "démo" });
    return sb.auth.signInWithPassword({ email: email, password: password }).then(function (r) { return ok(r).user; });
  };
  api.signOut = function () { return live ? sb.auth.signOut() : Promise.resolve(); };
  api.isAdmin = function () {
    if (!live) return Promise.resolve(true);
    return sb.rpc("is_admin").then(function (r) { return ok(r) === true; });
  };

  api.listBookings = function () {
    if (!live) return Promise.resolve(clone(load().bookings));
    return sb.from("bookings").select("*").order("created_at", { ascending: false }).limit(500).then(ok);
  };
  api.updateBooking = function (id, patch) {
    if (!live) {
      var b = load().bookings.filter(function (x) { return x.id === id; })[0];
      if (b) Object.assign(b, patch);
      save();
      return Promise.resolve();
    }
    // .select() : vérifie que la ligne a vraiment été modifiée (sinon les règles RLS l'ont bloquée sans erreur)
    function run(p) { return sb.from("bookings").update(p).eq("id", id).select("id"); }
    return run(patch).then(function (r) {
      // base pas encore mise à jour (colonne professional_name absente) : on enregistre sans ce champ
      if (r.error && /professional_name/.test(r.error.message || "")) {
        var p2 = Object.assign({}, patch); delete p2.professional_name;
        return run(p2);
      }
      return r;
    }).then(function (r) {
      var rows = ok(r);
      if (!rows || !rows.length) { var e = new Error("Aucune ligne modifiée : ce compte n'a pas les droits admin (table admins dans setup.sql)."); e.code = "rls"; throw e; }
    });
  };
  api.deleteBooking = function (id) {
    if (!live) {
      var s = load();
      s.bookings = s.bookings.filter(function (b) { return b.id !== id; });
      save();
      return Promise.resolve();
    }
    // .select() permet de vérifier que la ligne a vraiment été supprimée (sinon les règles RLS l'ont bloquée)
    return sb.from("bookings").delete().eq("id", id).select("id").then(function (r) {
      var rows = ok(r);
      if (!rows || !rows.length) throw new Error("not_deleted");
    });
  };
  api.settle = function (ids) {
    if (!live) {
      load().bookings.forEach(function (b) { if (ids.indexOf(b.id) !== -1) b.commission_settled = true; });
      save();
      return Promise.resolve();
    }
    return sb.from("bookings").update({ commission_settled: true }).in("id", ids).then(ok);
  };

  api.listPros = function () {
    if (!live) return Promise.resolve(clone(load().professionals));
    return sb.from("professionals").select("*").order("name", { ascending: true }).then(ok);
  };
  api.savePro = function (p) {
    if (!live) {
      var s = load();
      if (p.id) {
        var cur = s.professionals.filter(function (x) { return x.id === p.id; })[0];
        if (cur) Object.assign(cur, p);
      } else {
        s.professionals.push(Object.assign({ id: uuid() }, p));
      }
      save();
      return Promise.resolve();
    }
    // si la base n'a pas encore la colonne « cities » (setup.sql pas relancé), on enregistre sans elle
    function run(row) {
      if (row.id) { var id = row.id, body = Object.assign({}, row); delete body.id; return sb.from("professionals").update(body).eq("id", id); }
      return sb.from("professionals").insert(row);
    }
    var partial = false;
    return run(p).then(function (r) {
      if (r.error && /cities/i.test(r.error.message || "") && "cities" in p) {
        partial = (p.cities || []).length > 1;                   // une seule ville a pu être enregistrée
        var p2 = Object.assign({}, p); delete p2.cities; return run(p2);
      }
      return r;
    }).then(ok).then(function () { return { partial: partial }; });
  };
  api.deletePro = function (id) {
    if (!live) {
      var s = load();
      s.professionals = s.professionals.filter(function (x) { return x.id !== id; });
      s.bookings.forEach(function (b) { if (b.professional_id === id) b.professional_id = null; });
      save();
      return Promise.resolve();
    }
    return sb.from("professionals").delete().eq("id", id).then(ok);
  };
  api.resetDemo = function () { mem = seed(); save(); return Promise.resolve(); };

  // ---------- candidatures des professionnels (page rejoindre.html) ----------
  var APP_KEY = "washgo-demo-applications-v1";
  function demoApps() { try { return JSON.parse(localStorage.getItem(APP_KEY)) || []; } catch (e) { return []; } }
  function demoSaveApps(a) { try { localStorage.setItem(APP_KEY, JSON.stringify(a)); } catch (e) {} }

  api.createApplication = function (fields) {
    var row = Object.assign({}, fields, { status: "new" });
    if (!live) {
      var a = demoApps();
      a.unshift(Object.assign({ id: uuid(), created_at: new Date().toISOString(), admin_notes: null }, row));
      demoSaveApps(a);
      return Promise.resolve();
    }
    // insertion seule : le public ne peut jamais relire les candidatures.
    // Si la base n'a pas encore les derniers changements de setup.sql, on réessaie sans les champs récents.
    function attempt(r0, left) {
      return sb.from("applications").insert(r0).then(function (r) {
        if (!r.error) return;
        var m = (r.error.message || "") + " " + (r.error.details || "");
        if (/relation .*applications|applications.* does not exist|schema cache.*applications/i.test(m) && !/column/i.test(m)) {
          var e0 = new Error(m); e0.code = "no_table"; throw e0;
        }
        if (left > 0 && /cities/i.test(m) && "cities" in r0) { var a = Object.assign({}, r0); delete a.cities; return attempt(a, left - 1); }
        if (left > 0 && /experience/i.test(m) && r0.experience) { var b = Object.assign({}, r0, { experience: null }); return attempt(b, left - 1); }
        var e = new Error(m); e.code = r.error.code; throw e;
      });
    }
    return attempt(row, 3);
  };
  api.listApplications = function () {
    if (!live) return Promise.resolve(clone(demoApps()));
    return sb.from("applications").select("*").order("created_at", { ascending: false }).limit(500).then(ok);
  };
  api.updateApplication = function (id, patch) {
    if (!live) {
      var a = demoApps();
      a.forEach(function (x) { if (x.id === id) Object.assign(x, patch); });
      demoSaveApps(a);
      return Promise.resolve();
    }
    return sb.from("applications").update(patch).eq("id", id).select("id").then(function (r) {
      var rows = ok(r); if (!rows || !rows.length) throw new Error("not_updated");
    });
  };
  api.deleteApplication = function (id) {
    if (!live) { demoSaveApps(demoApps().filter(function (x) { return x.id !== id; })); return Promise.resolve(); }
    return sb.from("applications").delete().eq("id", id).select("id").then(function (r) {
      var rows = ok(r); if (!rows || !rows.length) throw new Error("not_deleted");
    });
  };

  // ---------- comptes clients ----------
  // Le profil (nom, téléphone, ville, véhicule, adresse) est enregistré une fois,
  // puis il remplit automatiquement le formulaire de réservation.
  var PROFILE_FIELDS = ["full_name", "phone", "city", "vehicle", "address", "latitude", "longitude", "consent_at"];
  var ACC_KEY = "washgo-demo-accounts-v1", CUR_KEY = "washgo-demo-current-v1";
  function pick(o) {
    var r = {};
    PROFILE_FIELDS.forEach(function (k) { if (o && o[k] !== undefined) r[k] = o[k] === "" ? null : o[k]; });
    return r;
  }
  function demoAccounts() { try { return JSON.parse(localStorage.getItem(ACC_KEY)) || {}; } catch (e) { return {}; } }
  function demoSaveAccounts(a) { try { localStorage.setItem(ACC_KEY, JSON.stringify(a)); } catch (e) {} }
  function demoCurrent() { try { return localStorage.getItem(CUR_KEY) || null; } catch (e) { return null; } }
  function demoSetCurrent(email) { try { if (email) localStorage.setItem(CUR_KEY, email); else localStorage.removeItem(CUR_KEY); } catch (e) {} }
  function fail(code) { var e = new Error(code); e.code = code; return Promise.reject(e); }
  function pageUrl(file) { return location.href.split("#")[0].split("?")[0].replace(/[^\/]*$/, file); }

  var cust = {};

  // Utilisateur connecté (ou null)
  cust.current = function () {
    if (!live) {
      var email = demoCurrent();
      return Promise.resolve(email && demoAccounts()[email] ? { id: "demo-" + email, email: email } : null);
    }
    return sb.auth.getSession().then(function (r) { return r.data && r.data.session ? r.data.session.user : null; });
  };

  // Inscription. Renvoie { user, confirm } : confirm = true si l'email doit d'abord être confirmé.
  cust.signUp = function (email, password, profile) {
    var p = pick(profile);
    if (!live) {
      var a = demoAccounts();
      if (a[email]) return fail("exists");
      a[email] = { password: password, profile: p };
      demoSaveAccounts(a); demoSetCurrent(email);
      return Promise.resolve({ user: { id: "demo-" + email, email: email }, confirm: false });
    }
    return sb.auth.signUp({ email: email, password: password, options: { data: p, emailRedirectTo: pageUrl("compte.html") } })
      .then(function (r) {
        if (r.error) throw r.error;
        var user = r.data.user, session = r.data.session;
        // Supabase renvoie un utilisateur sans identités quand l'email existe déjà
        if (user && user.identities && user.identities.length === 0) { var e = new Error("exists"); e.code = "exists"; throw e; }
        if (!session) return { user: user, confirm: true };
        return cust.saveProfile(p).then(function () { return { user: user, confirm: false }; });
      });
  };

  cust.signIn = function (email, password) {
    if (!live) {
      var acc = demoAccounts()[email];
      if (!acc || acc.password !== password) return fail("invalid");
      demoSetCurrent(email);
      return Promise.resolve({ id: "demo-" + email, email: email });
    }
    return sb.auth.signInWithPassword({ email: email, password: password }).then(function (r) {
      if (r.error) { var e = new Error(r.error.message); e.code = /confirm/i.test(r.error.message) ? "unconfirmed" : "invalid"; throw e; }
      return r.data.user;
    });
  };

  cust.signOut = function () {
    if (!live) { demoSetCurrent(null); return Promise.resolve(); }
    return sb.auth.signOut();
  };

  // Profil enregistré. À la première connexion, il est créé à partir des infos données à l'inscription.
  cust.getProfile = function () {
    return cust.current().then(function (user) {
      if (!user) return null;
      if (!live) { var acc = demoAccounts()[user.email]; return acc ? Object.assign({ email: user.email }, acc.profile) : null; }
      return sb.from("customers").select("*").eq("id", user.id).maybeSingle().then(function (r) {
        if (r.error) throw r.error;
        if (r.data) return r.data;
        var p = pick(user.user_metadata || {});
        return cust.saveProfile(p).then(function () { return Object.assign({ email: user.email }, p); });
      });
    });
  };

  cust.saveProfile = function (profile) {
    var p = pick(profile);
    return cust.current().then(function (user) {
      if (!user) return fail("signed_out");
      if (!live) {
        var a = demoAccounts();
        if (a[user.email]) { a[user.email].profile = Object.assign({}, a[user.email].profile, p); demoSaveAccounts(a); }
        return;
      }
      var row = Object.assign({ id: user.id, email: user.email, updated_at: new Date().toISOString() }, p);
      return sb.from("customers").upsert(row).then(ok);
    });
  };

  // Réservations du client connecté
  cust.bookings = function () {
    return cust.current().then(function (user) {
      if (!user) return [];
      if (!live) return clone(load().bookings.filter(function (b) { return b.user_id === user.id; }));
      return sb.from("bookings")
        .select("ref, created_at, city, service, vehicle, address, scheduled_date, scheduled_time, status, price")
        .eq("user_id", user.id).order("created_at", { ascending: false }).limit(50).then(ok);
    });
  };

  // Mot de passe oublié : envoie un lien par email, qui ramène sur compte.html
  cust.resetPassword = function (email, page) {
    if (!live) return Promise.resolve();
    return sb.auth.resetPasswordForEmail(email, { redirectTo: pageUrl(page || "compte.html") }).then(function (r) { if (r.error) throw r.error; });
  };
  cust.updatePassword = function (password) {
    if (!live) {
      var a = demoAccounts(), cur = demoCurrent();
      if (cur && a[cur]) { a[cur].password = password; demoSaveAccounts(a); }
      return Promise.resolve();
    }
    return sb.auth.updateUser({ password: password }).then(function (r) { if (r.error) throw r.error; });
  };
  // Le lien "nouveau mot de passe" est lu dès le chargement, avant que Supabase nettoie l'adresse
  var recovery = /type=recovery/.test(location.hash || ""), recoveryFns = [];
  if (live) sb.auth.onAuthStateChange(function (ev) {
    if (ev === "PASSWORD_RECOVERY") { recovery = true; recoveryFns.forEach(function (f) { f(); }); }
  });
  cust.onRecovery = function (fn) { if (recovery) fn(); else recoveryFns.push(fn); };

  api.customer = cust;

  window.WASHGO = api;
})();
