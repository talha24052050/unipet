// Nakama modülünün mantık testleri (Docker gerekmez): node server/nakama/test/module.test.js
var fs = require("fs");
var path = require("path");
var vm = require("vm");
var assert = require("assert");

var src = fs.readFileSync(path.join(__dirname, "..", "modules", "index.js"), "utf8");
var sandbox = { JSON: JSON, Date: Date, Math: Math, Object: Object, parseInt: parseInt, isNaN: isNaN, isFinite: isFinite, Error: Error, String: String };
vm.createContext(sandbox);
vm.runInContext(src, sandbox);
var M = sandbox;

var logs = [];
var logger = { info: function () {}, warn: function (m) { logs.push(m); }, error: function () {} };
function ctx(env, userId) { return { env: env || {}, userId: userId }; }

// --- köprü
var supaUser = { id: "u-1", email: "ali@std.yildiz.edu.tr" };
var storage = {};
var nk = {
  storageRead: function (reqs) { var k = reqs[0].userId + "/" + reqs[0].key; return storage[k] ? [{ value: JSON.parse(JSON.stringify(storage[k])) }] : []; },
  storageWrite: function (objs) { objs.forEach(function (o) { assert.strictEqual(o.permissionWrite, 0, "sadece sunucu yazar"); storage[o.userId + "/" + o.key] = JSON.parse(JSON.stringify(o.value)); }); },
  httpRequest: function (url, method, headers) {
    assert.ok(url.indexOf("/auth/v1/user") > 0);
    return headers.Authorization === "Bearer good" ? { code: 200, body: JSON.stringify(supaUser) } : { code: 401, body: "{}" };
  },
  binaryToString: function (s) { return s; },
  matchList: function () { return nk._matches; },
  matchCreate: function () { return "new-match"; },
  _matches: []
};
var env = { SUPABASE_URL: "https://x.supabase.co", SUPABASE_ANON_KEY: "anon" };

// --- efsanevi pet kilitleri (Kutbi, kapalı test hediyesi)
assert.deepEqual(JSON.parse(JSON.stringify(M.unlocksLoad(nk, "k-1"))), [], "başta kilit yok");
assert.deepEqual(JSON.parse(JSON.stringify(M.unlocksGrant(nk, "k-1", ["kutbi"]))), ["kutbi"], "ilk verişte yeni");
assert.deepEqual(JSON.parse(JSON.stringify(M.unlocksGrant(nk, "k-1", ["kutbi"]))), [], "ikinci verişte yeni yok");
assert.deepEqual(JSON.parse(JSON.stringify(M.unlocksLoad(nk, "k-1"))), ["kutbi"], "kalıcı");
assert.strictEqual(M.petAllowed("kutbi", []), false, "kilitliyken seçilemez");
assert.strictEqual(M.petAllowed("kutbi", ["kutbi"]), true);
assert.strictEqual(M.petAllowed("shark", []), true, "normal pet her zaman");
var req = M.beforeAuthenticateCustom(ctx(env), logger, nk, { account: { id: "u-1", vars: { supabase_token: "good" } } });
assert.strictEqual(req.account.vars.supabase_token, undefined, "token saklanmamalı");
assert.throws(function () { M.beforeAuthenticateCustom(ctx(env), logger, nk, { account: { id: "u-1", vars: { supabase_token: "bad" } } }); });
assert.throws(function () { M.beforeAuthenticateCustom(ctx(env), logger, nk, { account: { id: "baskasi", vars: { supabase_token: "good" } } }); }, "id eşleşmeli");
supaUser.email = "ali@gmail.com";
M.beforeAuthenticateCustom(ctx(env), logger, nk, { account: { id: "u-1", vars: { supabase_token: "good" } } }); // okul maili zorunlu değil
var envSchool = { SUPABASE_URL: env.SUPABASE_URL, SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY, UNIPET_REQUIRE_SCHOOL_EMAIL: "true" };
assert.throws(function () { M.beforeAuthenticateCustom(ctx(envSchool), logger, nk, { account: { id: "u-1", vars: { supabase_token: "good" } } }); }, "domain");
assert.throws(function () { M.beforeAuthenticateCustom(ctx({}), logger, nk, { account: { id: "mock-ali", vars: {} } }); }, "dev kapalıyken mock");
M.beforeAuthenticateCustom(ctx({ UNIPET_DEV_AUTH: "true" }), logger, nk, { account: { id: "mock-ali", vars: {} } });

// --- eşleştirme
assert.throws(function () { M.rpcFindRoom(ctx({}, "u-1"), logger, nk, '{"zone":"mars"}'); });
assert.throws(function () { M.rpcFindRoom(ctx({}, null), logger, nk, '{"zone":"kampus"}'); });
assert.strictEqual(JSON.parse(M.rpcFindRoom(ctx({}, "u-1"), logger, nk, '{"zone":"kampus"}')).match_id, "new-match");
nk._matches = [{ matchId: "a", size: 3 }, { matchId: "b", size: 10 }];
assert.strictEqual(JSON.parse(M.rpcFindRoom(ctx({}, "u-1"), logger, nk, '{"zone":"kampus"}')).match_id, "b", "en kalabalık dolu olmayan");

// --- oda
var sent = [];
var dispatcher = { broadcastMessage: function (op, data, to) { sent.push({ op: op, data: JSON.parse(data), to: (to || []).map(function (p) { return p.userId; }) }); } };
var st = M.matchInit(ctx({ UNIPET_ROOM_CAPACITY: "2", UNIPET_FREE_CHAT: "false" }), logger, nk, { zone: "kampus" }).state;
var A = { userId: "A" }, B = { userId: "B" }, C = { userId: "C" };
st = M.matchJoin(ctx(), logger, nk, dispatcher, 0, st, [A]).state;
st = M.matchJoin(ctx(), logger, nk, dispatcher, 0, st, [B]).state;
var snaps = sent.filter(function (x) { return x.op === 3; });
assert.strictEqual(snaps.length, 2); assert.deepEqual(snaps[1].to, ["B"]); assert.strictEqual(snaps[1].data.players.length, 1);
assert.strictEqual(M.matchJoinAttempt(ctx(), logger, nk, dispatcher, 0, st, C, {}).accept, false, "kapasite");
sent = [];
function msg(user, op, obj) { return { sender: user, opCode: op, data: JSON.stringify(obj) }; }
st = M.matchLoop(ctx(), logger, nk, dispatcher, 1, st, [
  msg(A, 1, { p: [1, 0, 2], y: 0.5, a: "walk" }),
  msg(A, 1, { p: [1e9, 0, 0], y: 0, a: "walk" }),          // dünya dışı → yok say
  msg(A, 1, { p: [1, 0, 2], y: 0, a: "<script>" }),        // geçersiz anim → yok say
  msg(A, 2, { k: 0, p: "selam" }),
  msg(A, 2, { k: 0, p: "selam" }),                          // 1 sn dolmadı → yok say
  msg(B, 2, { k: 2, p: "küfür" }),                          // serbest chat kapalı
  msg(B, 4, { pet: "yeti", acc: { head: "hat_cap", tail: "x" }, name: "  Ali   Veli  " })
]).state;
var ops = sent.map(function (s) { return s.op; });
assert.deepEqual(ops, [1, 2, 5, 4], "sadece geçerli mesajlar yayınlanır (+sosyal bakım): " + ops);
assert.deepEqual(sent[0].to, ["B"], "durum gönderene geri gitmez");
assert.deepEqual(sent[1].to.sort(), ["A", "B"], "chat herkese");
assert.deepEqual(sent[3].data.acc, { head: "hat_cap" }, "bilinmeyen slot atılır");
assert.strictEqual(sent[3].data.name, "Ali Veli", "isim temizlenir");
assert.strictEqual(M.cleanName("<script>"), "", "zararlı isim reddedilir");
assert.strictEqual(M.cleanName("Şükrü_42"), "Şükrü_42");
st = M.matchLeave(ctx(), logger, nk, dispatcher, 2, st, [A, B]).state;
var r = { state: st };
for (var t = 0; t < 400 && r; t++) r = M.matchLoop(ctx(), logger, nk, dispatcher, t, r.state, []);
assert.strictEqual(r, null, "boş oda kapanmalı");

// --- bakım: test_care.gd ile aynı örnekler
var d2 = M.careDecay({ food: 80, joy: 80, energy: 80, t: 1000 }, 1000 + 7200);
assert.deepEqual([d2.food, d2.joy, d2.energy, d2.t], [68, 72, 70, 8200], "2 saatlik azalma");
var dc = M.careDecay({ food: 50, joy: 30, energy: 100, t: 0 }, 100 * 3600);
assert.deepEqual([dc.food, dc.joy, dc.energy], [0, 0, 40], "sınır/kırpma");
assert.strictEqual(M.careDecay({ food: 50, joy: 50, energy: 50, t: 5000 }, 4000).t, 5000, "geri saat");
var ea = M.careApply({ food: 40, joy: 60, energy: 50, t: 0 }, "eat", 0, {});
assert.ok(ea.ok); assert.deepEqual([ea.state.food, ea.state.energy], [75, 55]);
assert.ok(!M.careApply(ea.state, "eat", 300, { eat: 0 }).ok, "bekleme");
assert.ok(M.careApply(ea.state, "eat", 601, { eat: 0 }).ok);
var pl2 = M.careApply({ food: 3, joy: 95, energy: 5, t: 0 }, "play", 0, {});
assert.deepEqual([pl2.state.joy, pl2.state.energy, pl2.state.food], [100, 0, 0], "oyun kırpma");
// care_spots.json ile aynı mı
var spots = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "..", "..", "game", "data", "care_spots.json"), "utf8"));
["eat", "rest", "play"].forEach(function (k) {
  assert.deepEqual(JSON.parse(JSON.stringify(M.CARE_SPOTS[k])), spots[k], "CARE_SPOTS." + k + " ≠ care_spots.json");
});
var pb = M.careApply({ food: 50, joy: 50, energy: 50, t: 0 }, "play", 0, {}, 2);
assert.deepEqual([pb.state.joy, pb.state.energy, pb.state.food, pb.bonus], [80, 40, 45, true], "bonus sadece artışlara");
assert.strictEqual(M.careBonus("play", [-285, 0, 49]), 2, "stadyumda oyun bonusu");
assert.strictEqual(M.careBonus("play", [500, 0, 500]), 1);
assert.strictEqual(M.careBonus("eat", [-285, 0, 49]), 1, "yemekte bonus yok");
// odada: uzakta yemek reddedilir, yakında kabul, sosyal chat ile gelir
sent = [];
var st2 = M.matchInit(ctx({}), logger, nk, { zone: "kampus" }).state;
var X = { userId: "X" }, Y = { userId: "Y" };
st2 = M.matchJoin(ctx(), logger, nk, dispatcher, 0, st2, [X, Y]).state;
var careMsgs = function () { return sent.filter(function (s) { return s.op === 5; }); };
assert.strictEqual(careMsgs().length, 2, "katılınca bakım durumu gönderilir");
sent = [];
st2 = M.matchLoop(ctx(), logger, nk, dispatcher, 1, st2, [msg(X, 5, { act: "eat" })]).state;
assert.ok(!careMsgs()[0].data.ok, "uzakta yemek yok");
sent = [];
st2 = M.matchLoop(ctx(), logger, nk, dispatcher, 2, st2, [msg(X, 1, { p: [-100, 0, -95], y: 0, a: "idle" }), msg(X, 5, { act: "eat" })]).state;
assert.ok(careMsgs()[0].data.ok, "Yemekhane'de yemek var");
assert.deepEqual(careMsgs()[0].to, ["X"], "bakım sadece sahibine");
sent = [];
st2 = M.matchLoop(ctx(), logger, nk, dispatcher, 3, st2, [msg(X, 5, { act: "social" })]).state;
assert.ok(!careMsgs()[0].data.ok, "istemci sosyal puanı kendisi isteyemez");
sent = [];
st2 = M.matchLoop(ctx(), logger, nk, dispatcher, 4, st2, [msg(Y, 2, { k: 1, p: "wave" })]).state;
assert.ok(careMsgs().length === 1 && careMsgs()[0].data.ok && careMsgs()[0].to[0] === "Y", "emote → sosyal puan");

// bölgeler zones.json ile aynı mı
var zonesJson = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "..", "..", "game", "data", "zones", "zones.json"), "utf8"));
assert.deepEqual(JSON.parse(JSON.stringify(M.ZONES)), zonesJson.zones.map(function (z) { return z.id; }), "ZONES ≠ zones.json");

// --- takma ad filtresi
["amk", "Ali amk", "0r0spu", "SIKTIR git", "yarrrak", "Şerefsiz"].forEach(function (n) {
  assert.strictEqual(M.cleanName(n), "", "küfür geçti: " + n);
});
["Ali Veli", "Siklon", "Memet", "Gotham", "Aqua", "Pusula"].forEach(function (n) {
  assert.strictEqual(M.cleanName(n), n, "masum isim engellendi: " + n);
});

// --- hız koruması
sent = [];
var st3 = M.matchInit(ctx({}), logger, nk, { zone: "kampus" }).state;
var P = { userId: "P" }, Q = { userId: "Q" };
st3 = M.matchJoin(ctx(), logger, nk, dispatcher, 0, st3, [P, Q]).state;
sent = [];
st3 = M.matchLoop(ctx(), logger, nk, dispatcher, 1, st3, [msg(P, 1, { p: [0, 0, 0], y: 0, a: "idle" })]).state;
st3 = M.matchLoop(ctx(), logger, nk, dispatcher, 2, st3, [msg(P, 1, { p: [500, 0, 0], y: 0, a: "walk" })]).state;
st3 = M.matchLoop(ctx(), logger, nk, dispatcher, 3, st3, [msg(P, 1, { p: [1.5, 0, 0], y: 0, a: "walk" })]).state;
var states = sent.filter(function (s) { return s.op === 1; }).map(function (s) { return s.data.p[0]; });
assert.deepEqual(states, [0, 1.5], "ışınlanma reddedilmeli, normal adım geçmeli: " + states);

// --- yıldız tozu + dükkan
var day = M.dayNumber(Date.now());
var di = JSON.parse(JSON.stringify(M.dailyIndices(day, M.STARDUST_POINTS.length, M.STARDUST_DAILY)));
assert.strictEqual(di.length, 40, "günde 40 nokta");
assert.deepEqual(di, JSON.parse(JSON.stringify(M.dailyIndices(day, M.STARDUST_POINTS.length, 40))), "aynı gün aynı noktalar");
assert.notDeepEqual(di, JSON.parse(JSON.stringify(M.dailyIndices(day + 1, M.STARDUST_POINTS.length, 40))), "ertesi gün farklı");
var w = M.walletLoad(nk, "W", Date.now());
var pt = M.STARDUST_POINTS[di[0]];
assert.ok(!M.stardustCollect(w, di[0], [pt[0] + 30, 0, pt[1]]), "uzaktan toplanamaz");
assert.ok(M.stardustCollect(w, di[0], [pt[0] + 1, 0, pt[1]]), "yakından toplanır");
assert.ok(!M.stardustCollect(w, di[0], [pt[0], 0, pt[1]]), "iki kez toplanamaz");
var notToday = 0; while (di.indexOf(notToday) >= 0) notToday++;
var p2 = M.STARDUST_POINTS[notToday];
assert.ok(!M.stardustCollect(w, notToday, [p2[0], 0, p2[1]]), "bugünün noktası değilse toplanamaz");
assert.strictEqual(w.dust, 1);
assert.strictEqual(M.shopBuy(w, "cape"), "yıldız tozu yetmiyor");
w.dust = 50;
assert.strictEqual(M.shopBuy(w, "cape"), "");
assert.strictEqual(w.dust, 10);
assert.strictEqual(M.shopBuy(w, "cape"), "zaten sende");
assert.strictEqual(M.shopBuy(w, "yok"), "böyle bir ürün yok");
// maçta: giriş cüzdanı, toplama mesajı, satın alınmamış aksesuar profilden düşer
sent = [];
var st4 = M.matchInit(ctx({}), logger, nk, { zone: "kampus" }).state;
var G = { userId: "G" }, H = { userId: "H" };
st4 = M.matchJoin(ctx(), logger, nk, dispatcher, 0, st4, [G, H]).state;
assert.ok(sent.some(function (m) { return m.op === 7 && m.to[0] === "G" && m.data.points.length === 40; }), "girişte cüzdan");
var tp = M.STARDUST_POINTS[di[1]];
st4 = M.matchLoop(ctx(), logger, nk, dispatcher, 1, st4, [msg(G, 1, { p: [tp[0], 0, tp[1]], y: 0, a: "idle" })]).state;
st4.players.G.p = [tp[0], 0, tp[1]];
sent = [];
st4 = M.matchLoop(ctx(), logger, nk, dispatcher, 2, st4, [msg(G, 8, { i: di[1] })]).state;
var wm = sent.filter(function (m) { return m.op === 7; })[0];
assert.ok(wm && wm.data.got && wm.data.dust === 1 && wm.data.points.indexOf(di[1]) < 0, "toplama → cüzdan");
var rb = JSON.parse(M.rpcBuyItem(ctx({}, "G"), logger, nk, JSON.stringify({ item: "flower_crown" })));
assert.ok(!rb.ok, "parası yetmez");
sent = [];
st4 = M.matchLoop(ctx(), logger, nk, dispatcher, 3, st4, [msg(G, 4, { pet: "shark", acc: { head: "crown_star", face: "glasses" }, name: "G" })]).state;
var pm = sent.filter(function (m) { return m.op === 4; })[0];
assert.deepEqual(JSON.parse(JSON.stringify(pm.data.acc)), { face: "glasses" }, "alınmamış dükkan ürünü takılamaz");

// --- mini oyun ödülü
assert.strictEqual(M.minigameReward("frisbee", 9, 0), 3);
assert.strictEqual(M.minigameReward("frisbee", 30, 0), 5, "oyun başına en çok 5");
assert.strictEqual(M.minigameReward("frisbee", 99, 0), 0, "imkânsız skor");
assert.strictEqual(M.minigameReward("frisbee", 30, 13), 2, "günlük tavan");
assert.strictEqual(M.minigameReward("yok", 30, 0), 0);
sent = [];
var mgDust0 = M.walletLoad(nk, "G", Date.now()).dust;
st4 = M.matchLoop(ctx(), logger, nk, dispatcher, 10, st4, [msg(G, 9, { game: "frisbee", score: 12 })]).state;
st4 = M.matchLoop(ctx(), logger, nk, dispatcher, 11, st4, [msg(G, 9, { game: "frisbee", score: 12 })]).state;
var mgMsgs = sent.filter(function (m) { return m.op === 7; });
assert.strictEqual(mgMsgs[0].data.reward, 4);
assert.strictEqual(mgMsgs[1].data.reward, 0, "art arda sonuç ödül almaz");
assert.strictEqual(M.walletLoad(nk, "G", Date.now()).dust, mgDust0 + 4);

// --- koşu yarışı
var CP = M.RACE_CPS;
assert.ok(CP.length === 7, "7 kontrol noktası");
var r = M.raceNew();
var t0 = 1000000;
assert.strictEqual(M.raceJoin(r, "R1", [CP[0][0] + 40, 0, CP[0][1]], t0), "başlangıç çizgisine gel");
assert.strictEqual(M.raceJoin(r, "R1", [CP[0][0], 0, CP[0][1]], t0), "");
assert.strictEqual(r.phase, "lobby");
assert.strictEqual(M.raceJoin(r, "R2", [CP[0][0] + 2, 0, CP[0][1]], t0 + 1000), "");
assert.ok(!M.raceTick(r, t0 + 5000), "lobi sürüyor");
assert.ok(M.raceTick(r, t0 + 10000) && r.phase === "running", "lobi bitti → koşu");
var go = r.startAt;
assert.strictEqual(M.raceJoin(r, "R3", [CP[0][0], 0, CP[0][1]], go), "yarış sürüyor");
function at(i) { return [CP[i][0], 0, CP[i][1]]; }
assert.strictEqual(M.raceCp(r, "R1", 1, at(1), go - 500), 0, "başlamadan geçilmez");
assert.strictEqual(M.raceCp(r, "R1", 2, at(2), go + 20000), 0, "sıra atlanamaz");
assert.strictEqual(M.raceCp(r, "R1", 1, at(1), go + 1000), 0, "imkânsız hız");
var tt = go;
for (var ci = 1; ci < CP.length; ci++) {
  tt += 7000;
  assert.strictEqual(M.raceCp(r, "R1", ci, at(ci), tt), ci === CP.length - 1 ? 2 : 1, "R1 cp " + ci);
}
assert.strictEqual(r.racers.R1.place, 1);
assert.strictEqual(M.raceReward(1, 2), 3);
assert.strictEqual(M.raceReward(2, 2), 1);
assert.ok(M.raceTick(r, go + 90001) && r.phase === "done", "süre dolunca biter");
assert.ok(M.raceTick(r, go + 90001 + 8000) && r.phase === "idle", "sonuçtan sonra boşta");
// maçta: katıl → görünüm herkese, çıkınca yarıştan düşer
sent = [];
var st5 = M.matchInit(ctx({}), logger, nk, { zone: "kampus" }).state;
var K = { userId: "K" }, L = { userId: "L" };
st5 = M.matchJoin(ctx(), logger, nk, dispatcher, 0, st5, [K, L]).state;
st5.players.K.p = at(0);
sent = [];
st5 = M.matchLoop(ctx(), logger, nk, dispatcher, 1, st5, [msg(K, 10, { act: "join" })]).state;
var rv = sent.filter(function (m) { return m.op === 10; })[0];
assert.ok(rv && rv.data.phase === "lobby" && rv.data.racers.length === 1 && rv.to.length === 0, "lobi herkese yayınlanır");
st5 = M.matchLeave(ctx(), logger, nk, dispatcher, 2, st5, [K]).state;
assert.strictEqual(st5.race.phase, "idle", "tek koşucu çıkınca lobi kapanır");

// --- sosyal sistem: serbest chat filtresi, kafe salonu, kalabalık grubu, arkadaşlık isteği & özel DM
sent = [];
var stSoc = M.matchInit(ctx({}), logger, nk, { zone: "kampus" }).state;
assert.strictEqual(stSoc.freeChat, true, "serbest chat varsayılan açık");
var S1 = { userId: "S1" }, S2 = { userId: "S2" }, S3 = { userId: "S3" };
stSoc = M.matchJoin(ctx(), logger, nk, dispatcher, 0, stSoc, [S1, S2, S3]).state;
stSoc.players.S1.name = "Talha";
stSoc.players.S2.name = "Zeynep";
stSoc.players.S3.name = "Mert";
sent = [];
// Küfürlü serbest mesaj engellenmeli, temiz mesaj + konum pini geçmeli
stSoc = M.matchLoop(ctx(), logger, nk, dispatcher, 1, stSoc, [
  msg(S1, 2, { k: 2, p: "selam amk", ch: "campus" }),
  msg(S1, 2, { k: 2, p: "Hokka'da buluşalım!", ch: "campus", px: -69.0, pz: -114.5, pl: "Hokka" })
]).state;
var socChats = sent.filter(function (m) { return m.op === 2; });
assert.strictEqual(socChats.length, 1, "küfürlü mesaj atılmalı, temiz mesaj geçmeli");
assert.strictEqual(socChats[0].data.sn, "Talha");
assert.strictEqual(socChats[0].data.pl, "Hokka");

// Kafe salonu: sadece o kafede olanlara gitmeli
stSoc.players.S1.lastChat = 0;
stSoc = M.matchLoop(ctx(), logger, nk, dispatcher, 2, stSoc, [
  msg(S1, 11, { act: "enter_cafe", cafe: "hokka" }),
  msg(S2, 11, { act: "enter_cafe", cafe: "hokka" })
]).state;
sent = [];
stSoc = M.matchLoop(ctx(), logger, nk, dispatcher, 3, stSoc, [
  msg(S1, 2, { k: 2, p: "Kahveler benden!", ch: "cafe:hokka" })
]).state;
var cafeChats = sent.filter(function (m) { return m.op === 2; });
assert.deepEqual(cafeChats[0].to.sort(), ["S1", "S2"], "kafe mesajı dışarıdaki S3'e gitmemeli");

// Arkadaş olmadan DM atılamaz; arkadaşlık isteği -> kabul -> sadece ikisi arasında DM
stSoc.players.S1.lastChat = 0;
sent = [];
stSoc = M.matchLoop(ctx(), logger, nk, dispatcher, 4, stSoc, [
  msg(S1, 2, { k: 2, p: "Gizli mesaj", ch: "dm:S2" })
]).state;
assert.strictEqual(sent.filter(function (m) { return m.op === 2; }).length, 0, "arkadaş olmadan DM reddedilmeli");
stSoc = M.matchLoop(ctx(), logger, nk, dispatcher, 5, stSoc, [
  msg(S1, 11, { act: "friend_req", to: "S2" })
]).state;
assert.strictEqual(M.socialLoad(nk, "S2").incoming.length, 1, "S2 istek kutusuna düşmeli");
stSoc = M.matchLoop(ctx(), logger, nk, dispatcher, 6, stSoc, [
  msg(S2, 11, { act: "friend_accept", from: "S1" })
]).state;
assert.ok(M.areFriends(nk, "S1", "S2") && M.areFriends(nk, "S2", "S1"), "iki taraf da arkadaş olmalı");
sent = [];
stSoc.players.S1.lastChat = 0;
stSoc = M.matchLoop(ctx(), logger, nk, dispatcher, 7, stSoc, [
  msg(S1, 2, { k: 2, p: "Selam Zeynep!", ch: "dm:S2" })
]).state;
var dmChats = sent.filter(function (m) { return m.op === 2; });
assert.strictEqual(dmChats.length, 1);
assert.deepEqual(dmChats[0].to.sort(), ["S1", "S2"], "özel DM üçüncü kişiye (S3) sızmamalı");

// Kalabalık grup odası: oluştur -> katıl -> grup içi sohbet
sent = [];
stSoc = M.matchLoop(ctx(), logger, nk, dispatcher, 8, stSoc, [
  msg(S3, 11, { act: "create_group", title: "Ortabahçe Tayfa" })
]).state;
var gJoinMsg = sent.filter(function (m) { return m.op === 11 && m.data.type === "group_joined"; })[0];
assert.ok(gJoinMsg && gJoinMsg.data.joined_group, "grup kurulmalı");
var gidTest = gJoinMsg.data.joined_group;
stSoc = M.matchLoop(ctx(), logger, nk, dispatcher, 9, stSoc, [
  msg(S1, 11, { act: "join_group", id: gidTest })
]).state;
sent = [];
stSoc.players.S3.lastChat = 0;
stSoc = M.matchLoop(ctx(), logger, nk, dispatcher, 10, stSoc, [
  msg(S3, 2, { k: 2, p: "Grup içi merhaba", ch: "group:" + gidTest })
]).state;
var grpChats = sent.filter(function (m) { return m.op === 2; });
assert.deepEqual(grpChats[0].to.sort(), ["S1", "S3"], "grup mesajı sadece grup üyelerine gitmeli");

// Doğrulanmış YTÜ Öğrencisi vs Misafir (OP_PROFILE otoriter doğrulama)
// Gerçek Nakama'da custom id (Supabase kimliği) ≠ Nakama user_id: doğrulama storage'a değil oturum değişkenine yazılır.
supaUser = { id: "sb-ytu", email: "talha@std.yildiz.edu.tr" };
var reqYtu = M.beforeAuthenticateCustom(ctx(env), logger, nk, { account: { id: "sb-ytu", vars: { supabase_token: "good", ytu: "false" } } });
assert.deepEqual(JSON.parse(JSON.stringify(reqYtu.account.vars)), { ytu: "true" }, "oturuma sadece sunucunun ytu kararı girer");
supaUser = { id: "sb-yks", email: "ece@gmail.com" };
var reqYks = M.beforeAuthenticateCustom(ctx(env), logger, nk, { account: { id: "sb-yks", vars: { supabase_token: "good", ytu: "true" } } });
assert.deepEqual(JSON.parse(JSON.stringify(reqYks.account.vars)), { ytu: "false" }, "istemcinin sahte ytu değişkeni atılır");
var devReq = M.beforeAuthenticateCustom(ctx({ UNIPET_DEV_AUTH: "true" }), logger, nk, { account: { id: "mock-ali", vars: { ytu: "true" } } });
assert.strictEqual(devReq.account.vars.ytu, "false", "dev girişte de istemci ytu taşıyamaz");
var stProf = M.matchInit(ctx(), logger, nk, { zone: "kampus" }).state;
var PYtu = { userId: "nk-ytu", sessionId: "s1" }, PYks = { userId: "nk-yks", sessionId: "s2" }, POld = { userId: "nk-old", sessionId: "s3" };
assert.ok(M.matchJoinAttempt({ vars: reqYtu.account.vars }, logger, nk, dispatcher, 0, stProf, PYtu, {}).accept);
assert.ok(M.matchJoinAttempt({ vars: reqYks.account.vars }, logger, nk, dispatcher, 0, stProf, PYks, {}).accept);
assert.ok(M.matchJoinAttempt({ vars: {} }, logger, nk, dispatcher, 0, stProf, POld, {}).accept);
stProf = M.matchJoin(ctx(), logger, nk, dispatcher, 0, stProf, [PYtu, PYks, POld]).state;
assert.strictEqual(stProf.players["nk-old"].ytu, false, "değişkeni olmayan eski oturum doğrulanmamış");
sent = [];
stProf = M.matchLoop(ctx(), logger, nk, dispatcher, 1, stProf, [
  msg(PYtu, 4, { pet: "shark", acc: {}, name: "Talha", ytu: false, role: "Bilgisayar Müh.", bio: "ARTLAB Zirvesi", disc: 24 }),
  msg(PYks, 4, { pet: "birb", acc: {}, name: "Ece", ytu: true, role: "YKS Adayı", bio: "Hedef YTÜ!", disc: 5 })
]).state;
var profMsgs = sent.filter(function (m) { return m.op === 4; });
assert.strictEqual(profMsgs.length, 2);
assert.strictEqual(profMsgs[0].data.ytu, true, "YTÜ maili olan her zaman doğrulanmış olmalı");
assert.strictEqual(profMsgs[1].data.ytu, false, "gmail hesabı sahte ytu:true gönderse bile sunucu false tutmalı");
assert.strictEqual(profMsgs[0].data.role, "Bilgisayar Müh.");
assert.strictEqual(M.cleanRole("Bilgisayar Müh.", false), "🎯 YKS Adayı (Hedef YTÜ)", "misafir fakülte etiketi takamaz");
assert.strictEqual(M.cleanRole("<b>x</b>", true), "Bilgisayar Müh.", "listede olmayan statü varsayılana düşer");
assert.strictEqual(profMsgs[1].data.bio, "Hedef YTÜ!");

// Hızlı yeniden bağlanma: yeni oturum katıldıktan sonra gelen eski oturum çıkışı oyuncuyu silmemeli
var PYtuNew = { userId: "nk-ytu", sessionId: "s1b" };
M.matchJoinAttempt({ vars: reqYtu.account.vars }, logger, nk, dispatcher, 0, stProf, PYtuNew, {});
stProf = M.matchJoin(ctx(), logger, nk, dispatcher, 0, stProf, [PYtuNew]).state;
stProf = M.matchLeave(ctx(), logger, nk, dispatcher, 2, stProf, [PYtu]).state;
assert.ok(stProf.players["nk-ytu"], "eski oturumun çıkışı yeni oturumu silmemeli");
assert.strictEqual(stProf.players["nk-ytu"].ytu, true);
stProf = M.matchLeave(ctx(), logger, nk, dispatcher, 3, stProf, [PYtuNew]).state;
assert.ok(!stProf.players["nk-ytu"], "güncel oturum çıkınca oyuncu silinir");

console.log("nakama modül testleri: OK");
