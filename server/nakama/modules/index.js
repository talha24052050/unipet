// UniPet Nakama sunucu modülü (JavaScript runtime, ES5 uyumlu yazıldı).
// 4.2  Supabase oturumu → Nakama hesabı köprüsü (beforeAuthenticateCustom)
// 4.3  Bölge/oda eşleştirme (RPC find_room) + yetkili oda (match "zone_room")
// 5.5  Pet bakımı: sunucu yetkili; kurallar game/src/care/pet_care_rules.gd ile AYNI
//
// Ortam değişkenleri (docker-compose → --runtime.env):
//   SUPABASE_URL, SUPABASE_ANON_KEY   Supabase oturum doğrulaması
//   UNIPET_DEV_AUTH=true              "mock-..." kimliklerine izin ver (sadece yerel geliştirme!)
//   UNIPET_REQUIRE_SCHOOL_EMAIL=false sadece @std.yildiz.edu.tr (şimdilik kapalı; oyundaki Config ile aynı tutulmalı)
//   UNIPET_ROOM_CAPACITY=40           oda kapasitesi (oyundaki Config.ROOM_CAPACITY ile aynı)
//   UNIPET_FREE_CHAT=false            serbest yazı (kapalı; açılırsa filtre şart)
//
// Not: Nakama JS runtime'ında kayıtlı fonksiyonlar global tanımlı olmalı (closure değil).

var ALLOWED_EMAIL = /^[^@\s]+@std\.yildiz\.edu\.tr$/;
var ZONES = ["ortabahce"];
var TICK_RATE = 10;
var EMPTY_TICKS_BEFORE_CLOSE = TICK_RATE * 30;

var OP_STATE = 1;    // c→s {p:[x,y,z], y:yaw, a:anim}            s→c {id, p, y, a}
var OP_CHAT = 2;     // c→s {k:0|1|2, p:payload}                 s→c {s:senderId, k, p}
var OP_SNAPSHOT = 3; // s→c {players:[{id, p, y, a, pet, acc}]}  (sadece yeni katılana)
var OP_PROFILE = 4;  // c→s {pet, acc:{slot:id}}                 s→c {id, pet, acc}
var OP_CARE = 5;     // c→s {act}                                s→c {ok, reason, state:{food,joy,energy,t}} (sadece o oyuncuya)

// ---- bakım kuralları (pet_care_rules.gd ile aynı; test_care.gd / module.test.js aynı örnekler)
var CARE_MAX = 100;
var CARE_DECAY_PER_HOUR = { food: 6, joy: 4, energy: 5 };
var CARE_MAX_DECAY_HOURS = 12;
var CARE_ACTIONS = {
  eat: { food: 35, energy: 5, cooldown: 600 },
  rest: { energy: 30, cooldown: 300 },
  social: { joy: 8, cooldown: 30 },
  play: { joy: 15, energy: -10, food: -5, cooldown: 120 }
};
var CARE_STATS = ["food", "joy", "energy"];
// game/data/care_spots.json ile AYNI (module.test.js kontrol eder)
var CARE_SPOTS = {
  eat: [
    { name: "Yemekhane", x: -103.5, z: -95.2, r: 45.0 },
    { name: "Hokka", x: -75.2, z: -106.6, r: 22.0 },
    { name: "Kayıntı Kafe", x: -99.9, z: -124.7, r: 22.0 }
  ]
};
var CARE_COLLECTION = "pet";
var CARE_KEY = "care";

function snap2(v) { return Math.round(v * 100) / 100; }
function clampCare(v) { return Math.max(0, Math.min(CARE_MAX, v)); }

function careNew(now) { return { food: 80, joy: 80, energy: 80, t: now }; }

function careDecay(state, now) {
  var t = typeof state.t === "number" ? state.t : now;
  var hours = Math.max(0, Math.min(CARE_MAX_DECAY_HOURS, (now - t) / 3600));
  var out = { t: Math.max(now, t) };
  for (var i = 0; i < CARE_STATS.length; i++) {
    var s = CARE_STATS[i];
    var v = typeof state[s] === "number" ? state[s] : CARE_MAX;
    out[s] = snap2(clampCare(v - CARE_DECAY_PER_HOUR[s] * hours));
  }
  return out;
}

function careApply(state, action, now, lastAction) {
  var rule = CARE_ACTIONS[action];
  if (!rule) return { ok: false, state: state, reason: "bilinmeyen eylem" };
  var last = lastAction && typeof lastAction[action] === "number" ? lastAction[action] : -1000000;
  if (now - last < rule.cooldown) return { ok: false, state: careDecay(state, now), reason: "biraz bekle" };
  var s = careDecay(state, now);
  for (var i = 0; i < CARE_STATS.length; i++) {
    var k = CARE_STATS[i];
    if (typeof rule[k] === "number") s[k] = snap2(clampCare(s[k] + rule[k]));
  }
  return { ok: true, state: s, reason: "" };
}

function nearSpot(kind, p) {
  var spots = CARE_SPOTS[kind] || [];
  for (var i = 0; i < spots.length; i++) {
    var dx = p[0] - spots[i].x, dz = p[2] - spots[i].z;
    if (dx * dx + dz * dz <= spots[i].r * spots[i].r) return true;
  }
  return false;
}

function careLoad(nk, userId) {
  var objs = nk.storageRead([{ collection: CARE_COLLECTION, key: CARE_KEY, userId: userId }]);
  if (objs && objs.length > 0 && objs[0].value) return objs[0].value;
  return null;
}

function careSave(nk, userId, record) {
  nk.storageWrite([{ collection: CARE_COLLECTION, key: CARE_KEY, userId: userId, value: record,
    permissionRead: 1, permissionWrite: 0 }]);
}

// Bir eylemi oyuncu adına uygular ve kaydeder. Dönen: {ok, reason, state}
function careAct(nk, userId, action, now) {
  var rec = careLoad(nk, userId) || { state: careNew(now), last: {} };
  var r = careApply(rec.state, action, now, rec.last);
  rec.state = r.state;
  if (r.ok) rec.last[action] = now;
  careSave(nk, userId, rec);
  return { ok: r.ok, reason: r.reason, state: r.state };
}

var CHAT_PRESET = 0, CHAT_EMOTE = 1, CHAT_FREE = 2;
var CHAT_MIN_INTERVAL_MS = 1000;
var ID_PATTERN = /^[a-z0-9_]{1,32}$/;
var WORLD_LIMIT = 2000;

function env(ctx, key, fallback) {
  var v = ctx.env && ctx.env[key];
  return v === undefined || v === "" ? fallback : v;
}

function capacity(ctx) {
  var n = parseInt(env(ctx, "UNIPET_ROOM_CAPACITY", "40"), 10);
  return isNaN(n) || n < 2 ? 40 : n;
}

// ---------------------------------------------------------------- 4.2 köprü

function beforeAuthenticateCustom(ctx, logger, nk, req) {
  var id = req.account && req.account.id;
  var vars = (req.account && req.account.vars) || {};
  if (!id) {
    throw Error("kimlik yok");
  }
  if (env(ctx, "UNIPET_DEV_AUTH", "false") === "true" && id.indexOf("mock-") === 0) {
    logger.warn("DEV_AUTH ile giriş: %s", id);
    return req;
  }
  var token = vars.supabase_token;
  var base = env(ctx, "SUPABASE_URL", "");
  var anon = env(ctx, "SUPABASE_ANON_KEY", "");
  if (!token || !base || !anon) {
    throw Error("oturum doğrulanamadı");
  }
  var res;
  try {
    res = nk.httpRequest(base.replace(/\/$/, "") + "/auth/v1/user", "get",
      { "apikey": anon, "Authorization": "Bearer " + token }, "", 5000);
  } catch (e) {
    logger.error("Supabase erişilemedi: %s", e.message);
    throw Error("oturum doğrulanamadı");
  }
  if (res.code !== 200) {
    throw Error("oturum geçersiz");
  }
  var user = JSON.parse(res.body);
  var email = (user.email || "").toLowerCase();
  var schoolOnly = env(ctx, "UNIPET_REQUIRE_SCHOOL_EMAIL", "false") === "true";
  if (user.id !== id || (schoolOnly && !ALLOWED_EMAIL.test(email))) {
    logger.warn("Reddedildi: id eşleşmedi ya da domain dışı (%s)", email);
    throw Error("bu hesap kullanılamaz");
  }
  // Token Nakama'da saklanmasın.
  delete req.account.vars.supabase_token;
  return req;
}

// ---------------------------------------------------------------- 4.3 eşleştirme

function rpcFindRoom(ctx, logger, nk, payload) {
  if (!ctx.userId) {
    throw Error("giriş gerekli");
  }
  var zone = "";
  try {
    zone = JSON.parse(payload || "{}").zone;
  } catch (e) {
    throw Error("geçersiz istek");
  }
  if (ZONES.indexOf(zone) < 0) {
    throw Error("bilinmeyen bölge");
  }
  var cap = capacity(ctx);
  // Dolu olmayan en kalabalık odayı seç (insanlar dağılmasın).
  var matches = nk.matchList(100, true, null, 0, cap - 1, "+label.zone:" + zone);
  var best = null;
  for (var i = 0; i < matches.length; i++) {
    if (best === null || matches[i].size > best.size) {
      best = matches[i];
    }
  }
  var matchId = best ? best.matchId : nk.matchCreate("zone_room", { zone: zone });
  return JSON.stringify({ match_id: matchId });
}

// ---------------------------------------------------------------- oda

function matchInit(ctx, logger, nk, params) {
  var zone = params.zone;
  var label = JSON.stringify({ zone: zone });
  return {
    state: { zone: zone, players: {}, emptyTicks: 0, cap: capacity(ctx), freeChat: env(ctx, "UNIPET_FREE_CHAT", "false") === "true" },
    tickRate: TICK_RATE,
    label: label
  };
}

function matchJoinAttempt(ctx, logger, nk, dispatcher, tick, state, presence, metadata) {
  var count = Object.keys(state.players).length;
  if (state.players[presence.userId]) {
    return { state: state, accept: true };
  }
  if (count >= state.cap) {
    return { state: state, accept: false, rejectMessage: "oda dolu" };
  }
  return { state: state, accept: true };
}

function matchJoin(ctx, logger, nk, dispatcher, tick, state, presences) {
  for (var i = 0; i < presences.length; i++) {
    var p = presences[i];
    state.players[p.userId] = state.players[p.userId] || { presence: p, p: [0, 0, 0], y: 0, a: "idle", pet: "", acc: {}, lastChat: 0 };
    state.players[p.userId].presence = p;
    // Yeni gelene odadaki herkesin son durumu.
    var list = [];
    for (var id in state.players) {
      if (id === p.userId) continue;
      var o = state.players[id];
      list.push({ id: id, p: o.p, y: o.y, a: o.a, pet: o.pet, acc: o.acc });
    }
    dispatcher.broadcastMessage(OP_SNAPSHOT, JSON.stringify({ players: list }), [p], null, true);
    var nowS = Math.floor(Date.now() / 1000);
    var rec = careLoad(nk, p.userId);
    var careState = rec ? careDecay(rec.state, nowS) : careNew(nowS);
    if (!rec) careSave(nk, p.userId, { state: careState, last: {} });
    dispatcher.broadcastMessage(OP_CARE, JSON.stringify({ ok: true, reason: "", state: careState }), [p], null, true);
  }
  state.emptyTicks = 0;
  return { state: state };
}

function matchLeave(ctx, logger, nk, dispatcher, tick, state, presences) {
  for (var i = 0; i < presences.length; i++) {
    delete state.players[presences[i].userId];
  }
  return { state: state };
}

function othersOf(state, userId) {
  var out = [];
  for (var id in state.players) {
    if (id !== userId) out.push(state.players[id].presence);
  }
  return out;
}

function everyone(state) {
  return othersOf(state, "");
}

function finiteIn(n, limit) {
  return typeof n === "number" && isFinite(n) && Math.abs(n) <= limit;
}

function matchLoop(ctx, logger, nk, dispatcher, tick, state, messages) {
  for (var i = 0; i < messages.length; i++) {
    var m = messages[i];
    var uid = m.sender.userId;
    var pl = state.players[uid];
    if (!pl) continue;
    var data;
    try {
      data = JSON.parse(nk.binaryToString(m.data));
    } catch (e) {
      continue;
    }
    if (m.opCode === OP_STATE) {
      if (!data.p || data.p.length !== 3 || !finiteIn(data.p[0], WORLD_LIMIT) || !finiteIn(data.p[1], WORLD_LIMIT) ||
          !finiteIn(data.p[2], WORLD_LIMIT) || !finiteIn(data.y, 1000) || !ID_PATTERN.test(String(data.a))) {
        continue;
      }
      pl.p = data.p; pl.y = data.y; pl.a = data.a;
      var others = othersOf(state, uid);
      if (others.length > 0) {
        dispatcher.broadcastMessage(OP_STATE, JSON.stringify({ id: uid, p: pl.p, y: pl.y, a: pl.a }), others, null, false);
      }
    } else if (m.opCode === OP_CHAT) {
      var now = Date.now();
      if (now - pl.lastChat < CHAT_MIN_INTERVAL_MS) continue;
      var k = data.k, payload = String(data.p || "");
      var ok = (k === CHAT_PRESET || k === CHAT_EMOTE) && ID_PATTERN.test(payload);
      if (k === CHAT_FREE && state.freeChat) {
        payload = payload.substring(0, 80);
        ok = payload.length > 0;
      }
      if (!ok) continue;
      pl.lastChat = now;
      dispatcher.broadcastMessage(OP_CHAT, JSON.stringify({ s: uid, k: k, p: payload }), everyone(state), null, true);
      if (othersOf(state, uid).length > 0) {
        var soc = careAct(nk, uid, "social", Math.floor(now / 1000));
        if (soc.ok) dispatcher.broadcastMessage(OP_CARE, JSON.stringify(soc), [pl.presence], null, true);
      }
    } else if (m.opCode === OP_CARE) {
      var act = String(data.act || "");
      var res;
      if (act === "social" || !CARE_ACTIONS[act]) {
        res = { ok: false, reason: "geçersiz eylem", state: null };
      } else if (act === "eat" && !nearSpot("eat", pl.p)) {
        res = { ok: false, reason: "Yemek için Yemekhane, Hokka ya da Kayıntı'ya git", state: null };
      } else {
        res = careAct(nk, uid, act, Math.floor(Date.now() / 1000));
      }
      if (res.state === null) {
        var cur = careLoad(nk, uid);
        res.state = cur ? careDecay(cur.state, Math.floor(Date.now() / 1000)) : careNew(Math.floor(Date.now() / 1000));
      }
      dispatcher.broadcastMessage(OP_CARE, JSON.stringify(res), [pl.presence], null, true);
    } else if (m.opCode === OP_PROFILE) {
      if (!ID_PATTERN.test(String(data.pet))) continue;
      var acc = {};
      var slots = ["head", "face", "neck", "back"];
      for (var s = 0; s < slots.length; s++) {
        var a = data.acc && data.acc[slots[s]];
        if (a && ID_PATTERN.test(String(a))) acc[slots[s]] = String(a);
      }
      pl.pet = String(data.pet); pl.acc = acc;
      var rest = othersOf(state, uid);
      if (rest.length > 0) {
        dispatcher.broadcastMessage(OP_PROFILE, JSON.stringify({ id: uid, pet: pl.pet, acc: acc }), rest, null, true);
      }
    }
  }
  if (Object.keys(state.players).length === 0) {
    state.emptyTicks++;
    if (state.emptyTicks > EMPTY_TICKS_BEFORE_CLOSE) {
      return null; // boş oda kapanır
    }
  } else {
    state.emptyTicks = 0;
  }
  return { state: state };
}

function matchTerminate(ctx, logger, nk, dispatcher, tick, state, graceSeconds) {
  return { state: state };
}

function matchSignal(ctx, logger, nk, dispatcher, tick, state, data) {
  return { state: state, data: "" };
}

// ---------------------------------------------------------------- kayıt

function InitModule(ctx, logger, nk, initializer) {
  initializer.registerBeforeAuthenticateCustom(beforeAuthenticateCustom);
  initializer.registerRpc("find_room", rpcFindRoom);
  initializer.registerMatch("zone_room", {
    matchInit: matchInit,
    matchJoinAttempt: matchJoinAttempt,
    matchJoin: matchJoin,
    matchLeave: matchLeave,
    matchLoop: matchLoop,
    matchTerminate: matchTerminate,
    matchSignal: matchSignal
  });
  if (env(ctx, "UNIPET_DEV_AUTH", "false") === "true") {
    logger.warn("UNIPET_DEV_AUTH açık: mock- kimlikleri kabul ediliyor. Yayında KAPATILMALI.");
  }
  logger.info("UniPet modülü yüklendi (bölgeler: %s, kapasite: %d)", ZONES.join(","), capacity(ctx));
}

// Nakama modülü yüklerken InitModule'ü global olarak arar.
!InitModule && InitModule.bind(null);
