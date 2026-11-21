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
assert.throws(function () { M.rpcFindRoom(ctx({}, null), logger, nk, '{"zone":"ortabahce"}'); });
assert.strictEqual(JSON.parse(M.rpcFindRoom(ctx({}, "u-1"), logger, nk, '{"zone":"ortabahce"}')).match_id, "new-match");
nk._matches = [{ matchId: "a", size: 3 }, { matchId: "b", size: 10 }];
assert.strictEqual(JSON.parse(M.rpcFindRoom(ctx({}, "u-1"), logger, nk, '{"zone":"ortabahce"}')).match_id, "b", "en kalabalık dolu olmayan");

// --- oda
var sent = [];
var dispatcher = { broadcastMessage: function (op, data, to) { sent.push({ op: op, data: JSON.parse(data), to: (to || []).map(function (p) { return p.userId; }) }); } };
var st = M.matchInit(ctx({ UNIPET_ROOM_CAPACITY: "2" }), logger, nk, { zone: "ortabahce" }).state;
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
  msg(B, 4, { pet: "yeti", acc: { head: "hat_cap", tail: "x" } })
]).state;
var ops = sent.map(function (s) { return s.op; });
assert.deepEqual(ops, [1, 2, 5, 4], "sadece geçerli mesajlar yayınlanır (+sosyal bakım): " + ops);
assert.deepEqual(sent[0].to, ["B"], "durum gönderene geri gitmez");
assert.deepEqual(sent[1].to.sort(), ["A", "B"], "chat herkese");
assert.deepEqual(sent[3].data.acc, { head: "hat_cap" }, "bilinmeyen slot atılır");
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
assert.deepEqual(JSON.parse(JSON.stringify(M.CARE_SPOTS.eat)), spots.eat, "CARE_SPOTS ≠ care_spots.json");
// odada: uzakta yemek reddedilir, yakında kabul, sosyal chat ile gelir
sent = [];
var st2 = M.matchInit(ctx({}), logger, nk, { zone: "ortabahce" }).state;
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

console.log("nakama modül testleri: OK");
