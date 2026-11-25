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
//   UNIPET_FREE_CHAT=true             serbest yazı (80 karakter + argo/spam filtresi; kapatmak için false)
//
// Not: Nakama JS runtime'ında kayıtlı fonksiyonlar global tanımlı olmalı (closure değil).

var ALLOWED_EMAIL = /^[^@\s]+@std\.yildiz\.edu\.tr$/;
// game/data/zones/zones.json ile AYNI (module.test.js kontrol eder)
var ZONES = ["kampus"];
var TICK_RATE = 10;
var EMPTY_TICKS_BEFORE_CLOSE = TICK_RATE * 30;

var OP_STATE = 1;    // c→s {p:[x,y,z], y:yaw, a:anim}            s→c {id, p, y, a}
var OP_CHAT = 2;     // c→s {k:0|1|2, p:payload}                 s→c {s:senderId, k, p}
var OP_SNAPSHOT = 3; // s→c {players:[{id, p, y, a, pet, acc}]}  (sadece yeni katılana)
var OP_PROFILE = 4;  // c→s {pet, acc:{slot:id}, name}           s→c {id, pet, acc, name}
var OP_CARE = 5;     // c→s {act}                                s→c {ok, reason, state:{food,joy,energy,t}} (sadece o oyuncuya)
var OP_UNLOCKS = 6;  // s→c {pets:[...], fresh:[...]}  (sadece o oyuncuya; fresh = bu girişte yeni açılanlar)
var OP_WALLET = 7;   // s→c {dust, owned:[...], points:[i...], got}  (sadece o oyuncuya; points = bugün kalan yıldız tozları)
var OP_COLLECT = 8;  // c→s {i}  yıldız tozu topla → OP_WALLET
var OP_MINIGAME = 9; // c→s {game, score}  mini oyun bitti → OP_WALLET (reward = verilen toz)
var OP_RACE = 10;    // c→s {act:"join"|"leave"|"cp", i}   s→c yarış görünümü (odadaki herkese; raceView)
var OP_SOCIAL = 11;  // c→s/s→c kafe salonları, kalabalık gruplar, arkadaşlık & istek kutusu

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
  "eat": [
    {
      "name": "Yemekhane",
      "x": -103.5,
      "z": -95.2,
      "r": 45.0
    },
    {
      "name": "Hokka",
      "x": -75.2,
      "z": -106.6,
      "r": 22.0
    },
    {
      "name": "Kayıntı Kafe",
      "x": -99.9,
      "z": -124.7,
      "r": 22.0
    }
  ],
  "rest": [
    {
      "name": "Ortabahçe",
      "x": 0.0,
      "z": 0.0,
      "r": 100.0
    },
    {
      "name": "Kulüpler Vadisi",
      "x": -280.0,
      "z": -20.0,
      "r": 50.0
    }
  ],
  "play": [
    {
      "name": "YTÜ Stadyumu",
      "x": -285.5,
      "z": 49.3,
      "r": 60.0
    },
    {
      "name": "Açık Oyun Sahaları",
      "x": -260.0,
      "z": -115.0,
      "r": 50.0
    },
    {
      "name": "Kulüpler Vadisi",
      "x": -280.0,
      "z": -20.0,
      "r": 50.0
    },
    {
      "name": "Spor Kompleksi",
      "x": -298.8,
      "z": -213.6,
      "r": 40.0
    }
  ]
};
// ---- efsanevi petler (Kutbi): sadece kilidi açılmış hesaplar seçebilir
// Kapalı test hediyesi (Talha 2026-11-22): UNIPET_CLOSED_TEST=true iken odaya giren her hesaba Kutbi kalıcı açılır.
var LEGENDARY_PETS = ["kutbi"];
var UNLOCK_COLLECTION = "unlocks";
var UNLOCK_KEY = "pets";

function unlocksLoad(nk, userId) {
  var objs = nk.storageRead([{ collection: UNLOCK_COLLECTION, key: UNLOCK_KEY, userId: userId }]);
  if (objs && objs.length > 0 && objs[0].value && objs[0].value.pets) return objs[0].value.pets.slice();
  return [];
}

// Verilenleri ekler, yeni açılanları döndürür.
function unlocksGrant(nk, userId, pets) {
  var have = unlocksLoad(nk, userId);
  var fresh = [];
  for (var i = 0; i < pets.length; i++) {
    if (have.indexOf(pets[i]) < 0) { have.push(pets[i]); fresh.push(pets[i]); }
  }
  if (fresh.length > 0) {
    nk.storageWrite([{ collection: UNLOCK_COLLECTION, key: UNLOCK_KEY, userId: userId, value: { pets: have },
      permissionRead: 1, permissionWrite: 0 }]);
  }
  return fresh;
}

// Profilde seçilebilir mi: efsanevi değilse evet, efsaneviyse kilidi açıksa.
function petAllowed(pet, unlocked) {
  return LEGENDARY_PETS.indexOf(pet) < 0 || unlocked.indexOf(pet) >= 0;
}

// ---- Yıldız tozu (kampüse dağılmış toplanabilir) + dükkan (aksesuar satın alma)
// Her gün (TR saatiyle) havuzdan STARDUST_DAILY nokta seçilir; herkes aynı noktaları görür ama her oyuncu kendi
// kopyasını bir kez toplar. Toplama, oyuncunun sunucudaki son konumuna göre doğrulanır.
// <stardust-points> (tools/collect/make_stardust_points.py üretir, elle düzenleme)
var STARDUST_POINTS = [[87.9,-347.1],[98.8,-363.9],[159.3,-270.7],[175.7,-282.2],[191.9,-293.9],[139.9,-322.1],[153.6,-336.8],[39.7,-360.7],[-18.8,-253.4],[148.5,-358.0],[169.1,-316.5],[114.4,-346.0],[57.6,-363.1],[18.1,-358.7],[-0.5,-351.5],[-14.9,-338.2],[-27.4,-322.5],[-57.3,-313.7],[-64.1,-295.3],[-59.8,-276.0],[-45.8,-262.1],[-1.2,-228.1],[15.5,-217.1],[32.3,-206.2],[50.7,-199.8],[67.4,-189.5],[83.1,-177.1],[98.8,-164.7],[114.5,-152.3],[50.5,-230.0],[26.3,-255.0],[197.4,-214.4],[231.2,-224.7],[145.5,-171.7],[133.0,-156.1],[254.9,-287.7],[169.7,-236.2],[206.0,-279.8],[149.5,-145.4],[165.1,-133.6],[179.4,-119.9],[240.0,-253.0],[197.1,-187.2],[173.9,-154.9],[92.4,-395.4],[111.3,-388.8],[130.7,-384.2],[150.1,-379.1],[168.6,-371.7],[186.1,-362.1],[203.5,-352.2],[220.9,-342.3],[238.3,-332.4],[254.8,-321.2],[271.0,-309.4],[286.4,-296.7],[301.8,-283.9],[317.2,-271.2],[332.6,-258.4],[348.0,-245.7],[362.9,-232.3],[375.8,-217.1],[386.2,-200.0],[392.6,-181.1],[397.5,-161.7],[402.4,-142.3],[406.6,-122.8],[411.8,-103.5],[418.6,-84.7],[422.6,-65.2],[422.6,-45.2],[421.0,-25.3],[419.4,-5.4],[417.7,14.6],[416.1,34.5],[416.1,54.5],[-136.7,-506.7],[-126.2,-489.7],[-115.7,-472.7],[-169.2,-487.0],[-178.1,-454.1],[-161.1,-464.7],[-111.4,-398.0],[-78.6,-336.3],[-154.7,-415.7],[-116.6,-362.1],[-137.9,-397.6],[-182.5,-393.3],[-197.3,-379.8],[-212.1,-366.4],[-195.3,-444.0],[-212.7,-434.3],[-211.9,-402.2],[-231.8,-407.5],[-243.3,-391.2],[-131.4,-428.4],[-259.1,-433.2],[-87.0,-372.1],[-65.7,-391.6],[-48.2,-400.9],[-141.1,-335.8],[-158.4,-345.8],[-143.2,-358.9],[-192.3,-346.0],[-130.4,-314.0],[-116.4,-539.6],[-106.4,-522.2],[-96.4,-504.9],[-86.4,-487.6],[-76.4,-470.3],[-66.4,-453.0],[-56.4,-435.6],[-121.0,-448.4],[-88.4,-432.9],[-102.7,-418.9],[-18.6,-403.5],[-39.5,-381.3],[-54.0,-367.5],[-68.5,-353.8],[-290.0,-425.0],[-238.8,-456.3],[-221.7,-466.7],[-204.6,-477.1],[-187.5,-487.5],[72.8,-397.4],[52.9,-395.2],[33.0,-394.7],[13.0,-395.1],[-48.3,-349.8],[-83.7,-301.7],[-93.2,-284.1],[-110.6,-292.8],[-161.7,-324.1],[-276.4,-404.3],[-309.2,-427.3],[-169.7,-182.8],[-154.5,-169.8],[-146.9,-192.8],[-133.1,-207.2],[-185.6,-162.9],[-202.2,-172.6],[-233.0,-131.4],[-219.9,-146.5],[-93.6,-256.1],[-114.4,-222.8],[-168.0,-138.9],[-175.1,-120.2],[-184.4,-102.6],[-202.8,-101.4],[-220.3,-111.1],[-255.3,-130.4],[-271.2,-142.4],[-285.7,-156.1],[-281.2,-174.3],[-269.3,-190.4],[-256.9,-206.1],[-242.6,-220.1],[-228.1,-233.8],[-213.6,-247.6],[-199.1,-261.4],[-184.6,-275.2],[-170.1,-288.9],[-153.7,-299.3],[-136.0,-291.1],[-128.3,-188.2],[-91.7,-235.7],[-60.4,-248.4],[-43.8,-237.3],[-27.1,-226.1],[16.6,-190.5],[5.1,-174.1],[-6.3,-157.6],[-17.7,-141.2],[-28.3,-124.3],[-38.1,-106.8],[-48.1,-89.5],[-58.7,-72.6],[-70.1,-56.1],[-83.3,-41.1],[-113.1,-43.5],[-128.9,-55.8],[-144.6,-68.2],[-155.9,-83.7],[-160.6,-103.1],[-85.5,-118.3],[64.2,58.4],[48.7,45.8],[32.8,33.7],[17.0,21.3],[2.1,8.0],[-14.1,-3.6],[-30.0,-15.7],[-45.8,-28.1],[-40.8,-156.7],[-131.0,-157.9],[-114.9,-146.1],[-62.6,-143.0],[-16.0,-206.6],[243.0,-57.3],[230.5,-41.7],[201.0,-90.4],[207.8,-73.0],[218.5,-56.1],[246.3,-27.8],[8.2,-19.6],[28.1,-17.9],[53.1,-15.3],[73.0,-13.9],[93.0,-13.2],[112.9,-11.2],[-31.6,3.5],[-25.0,22.4],[-18.4,41.3],[-20.2,62.6],[-33.3,77.7],[-44.7,94.0],[-57.2,109.6],[-69.7,125.3],[-82.2,140.9],[153.5,10.7],[35.1,-44.9],[29.8,-64.2],[-5.0,-53.9],[10.7,-41.5],[73.5,8.0],[89.3,20.3],[-54.1,38.1],[-66.6,53.8],[24.8,-90.6],[56.2,-65.9],[71.9,-53.5],[87.7,-41.2],[103.4,-28.8],[53.6,15.8],[109.0,-98.6],[96.5,-82.9],[84.0,-67.3],[59.1,-36.0],[37.7,155.7],[24.5,74.6],[12.0,90.2],[-0.4,105.8],[-94.2,51.8],[-62.8,76.6],[0.1,126.1],[-62.3,16.7],[0.6,66.2],[-35.4,133.0],[-82.6,104.2],[-83.7,84.5],[46.7,-86.0],[64.3,-94.9],[112.9,-68.6],[114.9,-49.0],[-13.5,85.4],[-154.5,130.8],[94.6,82.4],[-146.8,181.0],[-159.4,196.5],[-187.9,196.5],[-215.2,208.0],[-227.9,223.5],[-142.4,223.2],[-111.2,248.2],[-95.6,260.7],[-64.3,285.7],[-48.7,298.2],[-33.1,310.7],[-17.5,323.2],[-1.9,335.7],[-109.3,339.9],[-96.7,324.4],[-84.1,308.9],[-151.1,313.2],[-138.5,297.7],[-113.3,266.6],[-107.5,212.6],[-64.9,246.1],[-22.1,279.8],[-189.4,124.3],[-200.3,140.0],[-207.8,158.6],[-214.5,177.4],[-235.2,254.6],[-238.9,274.3],[-242.7,293.9],[-246.8,313.5],[-251.3,333.0],[-255.5,352.5],[-257.2,372.4],[-253.9,392.0],[-245.5,410.1],[-233.9,426.3],[-220.7,441.4],[-207.6,456.5],[-194.5,471.6],[-181.1,486.5],[-163.7,495.7],[-144.3,500.2],[-125.4,506.7],[-162.8,216.6],[-191.4,287.1],[-128.9,337.1],[-97.7,362.1],[-82.1,374.6],[-18.6,367.2],[159.2,138.5],[174.6,151.2],[190.1,163.8],[205.6,176.5],[221.1,189.2],[236.5,201.8],[252.0,214.5],[267.2,227.5],[281.2,241.8],[293.1,257.8],[303.4,274.9],[313.1,292.4],[322.8,309.9],[332.5,327.4],[347.7,338.3],[92.3,101.3],[117.2,70.0],[149.4,118.8],[135.5,104.4],[120.9,90.8],[-10.8,-369.1],[6.6,-377.9],[26.6,-376.7],[233.1,-315.1],[281.0,-279.0],[296.4,-266.3],[311.8,-253.5],[327.2,-240.8],[342.6,-228.0],[356.7,-213.9],[368.1,-197.5],[399.8,-82.1],[403.6,-62.5],[404.3,-42.5],[403.2,-22.6],[395.2,33.8],[376.6,26.3],[358.1,18.7],[339.6,11.2],[321.0,3.7],[302.5,-3.9],[284.0,-11.4],[265.3,-18.4],[123.8,-127.3],[139.6,-115.0],[155.3,-102.6],[171.0,-90.2],[186.7,-77.9],[192.4,-33.0],[179.9,-17.3],[167.4,-1.7],[142.5,29.5],[130.0,45.2],[67.6,123.3],[55.1,139.0],[17.7,185.9],[5.2,201.5],[-7.3,217.1],[-19.7,232.7],[-50.4,225.5],[-66.1,213.1],[-81.8,200.7],[-97.5,188.4],[-113.2,176.0],[-128.9,163.6],[-144.7,151.3],[-173.8,95.1],[-161.2,79.6],[-148.6,64.1],[-136.0,48.6],[-123.4,33.0],[-110.8,17.5],[-98.2,2.0],[-85.6,-13.6],[202.4,448.9],[205.6,429.2],[-20.3,253.9],[-4.6,266.3],[8.6,280.0],[24.3,292.4],[40.1,304.8],[55.8,317.1],[71.5,329.5],[87.2,341.9],[102.9,354.3],[118.6,366.6],[134.3,379.0],[150.0,391.4],[165.7,403.8],[183.7,410.7],[222.8,408.8],[239.8,398.3],[256.9,387.9],[273.9,377.4],[291.0,367.0],[308.0,356.5],[323.7,344.1],[230.2,435.4],[243.0,450.7],[257.3,464.5],[274.4,474.8],[292.6,483.0],[323.8,467.6],[338.5,454.1],[353.3,440.5],[368.0,427.0],[382.7,413.5],[400.0,403.5],[388.7,386.6],[370.9,377.5],[355.2,365.3],[321.8,370.9],[304.5,380.9],[287.2,390.9],[269.9,401.0],[23.3,322.8],[-26.7,385.1],[-38.6,401.2],[-50.6,417.2],[-62.5,433.3],[-74.4,449.3],[-86.4,465.4],[-98.3,481.4],[-104.1,524.9],[-87.8,536.4],[-71.3,547.7],[-54.2,558.1],[-36.5,567.3],[-17.3,572.8],[2.6,574.1],[22.6,574.6],[42.6,575.2],[62.6,575.7],[82.6,576.3],[102.6,576.8],[122.6,576.3],[142.6,575.8],[162.5,574.9],[182.1,570.7],[201.0,564.4],[219.4,556.5],[237.1,547.2],[254.2,536.9],[270.8,525.7],[281.4,509.6],[-260.6,-362.6],[-244.2,-355.1],[-227.8,-343.6],[-211.4,-332.1],[-195.0,-320.7],[-178.7,-309.2],[-241.1,-316.2],[-255.8,-340.6],[-232.6,-285.2],[-209.7,-292.9],[-283.8,-313.6],[-272.4,-298.2],[-264.6,-279.8],[-256.9,-261.3],[-249.2,-242.9],[-290.4,-293.7],[-218.5,-266.2],[-236.9,-258.5],[-273.6,-247.0],[806.6,573.3],[788.0,570.5],[768.1,570.0],[806.4,602.4],[776.7,610.0],[758.5,618.1],[751.0,636.3],[11.8,241.0],[24.1,225.2],[36.3,209.4],[208.7,347.1],[192.8,335.0],[176.8,322.9],[160.9,310.7],[145.0,298.6],[129.1,286.5],[113.2,274.4],[97.3,262.3],[81.4,250.2],[65.5,238.0],[49.5,225.9],[139.4,256.6],[106.2,231.3],[118.4,215.5],[130.6,199.7],[57.2,195.6],[77.2,196.3],[97.2,197.0],[157.1,199.0],[177.1,199.7],[201.1,207.9],[214.1,223.1],[227.1,238.3],[240.0,253.6],[253.0,268.8],[266.0,284.0],[279.0,299.2],[292.0,314.4],[305.0,329.6],[236.7,288.7],[230.7,307.8],[224.8,326.9],[212.9,365.1],[207.0,384.2],[201.0,403.3],[40.5,187.9],[330.6,265.0],[327.7,245.3],[320.3,226.8],[309.3,210.1],[293.1,198.6],[274.8,190.6],[255.8,184.3],[237.2,177.0],[205.3,153.3],[193.4,137.3],[184.0,119.7],[178.5,100.5],[177.4,80.6],[183.1,61.6],[196.1,46.7],[214.8,40.6],[234.3,44.3],[250.6,55.6],[261.8,72.1],[274.3,87.7],[291.4,97.6],[311.1,100.8],[330.7,104.8],[346.4,116.6],[350.0,135.6],[339.4,152.1],[324.6,165.4],[315.9,183.1],[267.0,330.2],[247.0,330.7],[191.3,310.3],[175.6,298.1],[162.0,283.5],[136.2,229.8],[138.3,171.1],[147.6,153.4],[350.9,81.1],[300.4,69.5],[259.8,111.8],[240.5,116.5],[221.0,113.3],[204.3,102.6],[47.0,-113.3],[181.9,21.8],[169.7,37.6],[245.8,26.5],[275.0,31.3],[245.4,3.8],[-340.4,-282.3],[-357.6,-292.5],[-94.6,-151.2],[149.6,-211.1]];
// </stardust-points>
var STARDUST_DAILY = 40;
var STARDUST_RADIUS = 6.0;
// Fiyatlar game/data/accessories/*.tres "price" ile aynı olmalı (test kontrol eder).
var SHOP = { flower_crown: 15, crown_star: 30, cape: 40 };
var WALLET_COLLECTION = "wallet";
var WALLET_KEY = "wallet";

function dayNumber(nowMs) {
  return Math.floor((nowMs / 1000 + 3 * 3600) / 86400);  // Türkiye saati (UTC+3)
}

// Günün noktaları: gün numarasıyla tohumlanan karıştırma (mulberry32), sıralı indeksler.
function dailyIndices(day, n, count) {
  var s = (day * 2654435761) >>> 0;
  function rnd() {
    s = (s + 0x6D2B79F5) >>> 0;
    var t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  var idx = [];
  for (var i = 0; i < n; i++) idx.push(i);
  count = Math.min(count, n);
  for (var k = 0; k < count; k++) {
    var j = k + Math.floor(rnd() * (n - k));
    var tmp = idx[k]; idx[k] = idx[j]; idx[j] = tmp;
  }
  return idx.slice(0, count).sort(function (a, b) { return a - b; });
}

function walletLoad(nk, userId, nowMs) {
  var objs = nk.storageRead([{ collection: WALLET_COLLECTION, key: WALLET_KEY, userId: userId }]);
  var w = (objs && objs.length > 0 && objs[0].value) ? objs[0].value : {};
  var today = dayNumber(nowMs);
  return { dust: w.dust | 0, owned: (w.owned || []).slice(), day: today, taken: w.day === today ? (w.taken || []).slice() : [],
    mg: w.day === today ? (w.mg | 0) : 0 };
}

// ---- mini oyunlar: skor → yıldız tozu (oyun başına en çok MINIGAME_MAX_REWARD, günde en çok MINIGAME_DAILY_CAP).
// Skoru istemci bildirir; süre ve oyun başına üst sınır + günlük tavan hileyi anlamsız kılar.
// game/src/minigame/minigame_rules.gd ile AYNI.
var MINIGAMES = { frisbee: { maxScore: 40, perDust: 3 } };
var MINIGAME_MAX_REWARD = 5;
var MINIGAME_DAILY_CAP = 15;
var MINIGAME_MIN_GAP_S = 30;  // iki oyun sonucu arası en az (oyun ~45 sn)

function minigameReward(game, score, already) {
  var g = MINIGAMES[game];
  if (!g || typeof score !== "number" || score !== Math.floor(score) || score < 0 || score > g.maxScore) return 0;
  var r = Math.min(Math.floor(score / g.perDust), MINIGAME_MAX_REWARD);
  return Math.max(0, Math.min(r, MINIGAME_DAILY_CAP - already));
}

function walletSave(nk, userId, w) {
  nk.storageWrite([{ collection: WALLET_COLLECTION, key: WALLET_KEY, userId: userId, value: w,
    permissionRead: 1, permissionWrite: 0 }]);
}

function walletView(w, got) {
  var pts = dailyIndices(w.day, STARDUST_POINTS.length, STARDUST_DAILY).filter(function (i) { return w.taken.indexOf(i) < 0; });
  return { dust: w.dust, owned: w.owned, points: pts, got: !!got };
}

// Toplama: bugünün noktası mı, alınmamış mı, oyuncu yakın mı? Başarılıysa cüzdan güncellenir.
function stardustCollect(w, i, pos) {
  if (typeof i !== "number" || i !== Math.floor(i) || i < 0 || i >= STARDUST_POINTS.length) return false;
  if (w.taken.indexOf(i) >= 0) return false;
  if (dailyIndices(w.day, STARDUST_POINTS.length, STARDUST_DAILY).indexOf(i) < 0) return false;
  var pt = STARDUST_POINTS[i];
  if (!pos || Math.sqrt(Math.pow(pos[0] - pt[0], 2) + Math.pow(pos[2] - pt[1], 2)) > STARDUST_RADIUS) return false;
  w.taken.push(i);
  w.dust += 1;
  return true;
}

function shopBuy(w, item) {
  if (!SHOP.hasOwnProperty(item)) return "böyle bir ürün yok";
  if (w.owned.indexOf(item) >= 0) return "zaten sende";
  if (w.dust < SHOP[item]) return "yıldız tozu yetmiyor";
  w.dust -= SHOP[item];
  w.owned.push(item);
  return "";
}

function rpcWallet(ctx, logger, nk, payload) {
  if (!ctx.userId) throw Error("giriş gerekli");
  return JSON.stringify(walletView(walletLoad(nk, ctx.userId, Date.now())));
}

function rpcBuyItem(ctx, logger, nk, payload) {
  if (!ctx.userId) throw Error("giriş gerekli");
  var item = "";
  try { item = String(JSON.parse(payload || "{}").item || ""); } catch (e) { throw Error("geçersiz istek"); }
  var w = walletLoad(nk, ctx.userId, Date.now());
  var reason = shopBuy(w, item);
  if (!reason) walletSave(nk, ctx.userId, w);
  return JSON.stringify({ ok: !reason, reason: reason, wallet: walletView(w) });
}

// ---- koşu yarışı (YTÜ Stadyumu pisti, yarım tur). Sunucu otoriter: lobi → geri sayım → koşu → sonuç.
// Kontrol noktası geçişi konum + en düşük süre ile doğrulanır. game/src/minigame/race_rules.gd ile AYNI.
// <race-cps> (tools/collect/make_race_track.py üretir, elle düzenleme)
var RACE_CPS = [[-322.51,39.14,0.0],[-313.11,4.73,35.7],[-296.8,-26.1,71.4],[-263.06,-32.93,107.0],[-237.47,-9.91,142.7],[-239.09,24.94,178.4],[-248.49,59.35,214.1]];
// </race-cps>
var RACE_CP_RADIUS = 9;
var RACE_JOIN_RADIUS = 25;
var RACE_LOBBY_MS = 10000;
var RACE_COUNTDOWN_MS = 3000;
var RACE_TIMEOUT_MS = 90000;
var RACE_RESULTS_MS = 8000;
var RACE_MAX = 8;
var RACE_MAX_SPEED = 9;  // m/s (pet 4.6 m/s yürür; gecikme payı)

function raceNew() {
  return { phase: "idle", lobbyEnds: 0, startAt: 0, endsAt: 0, doneUntil: 0, racers: {}, order: [], n: 0 };
}

function raceDist(pos, cp) {
  return Math.sqrt(Math.pow(pos[0] - cp[0], 2) + Math.pow(pos[2] - cp[1], 2));
}

// "" = katıldı; aksi halde neden.
function raceJoin(r, uid, pos, now) {
  if (r.phase !== "idle" && r.phase !== "lobby") return "yarış sürüyor";
  if (r.racers[uid]) return "";
  if (Object.keys(r.racers).length >= RACE_MAX) return "yarış dolu";
  if (!pos || raceDist(pos, RACE_CPS[0]) > RACE_JOIN_RADIUS) return "başlangıç çizgisine gel";
  if (r.phase === "idle") { r.phase = "lobby"; r.lobbyEnds = now + RACE_LOBBY_MS; r.racers = {}; r.order = []; }
  r.racers[uid] = { cp: 0, time: 0, place: 0 };
  return "";
}

function raceLeave(r, uid) {
  if (!r.racers[uid]) return false;
  delete r.racers[uid];
  if (r.phase === "lobby" && Object.keys(r.racers).length === 0) r.phase = "idle";
  return true;
}

// Kontrol noktası: sıradaki mi, yakın mı, o mesafeye bu sürede gerçekten koşulabilir mi?
// Dönen: 0 geçersiz, 1 geçti, 2 bitirdi.
function raceCp(r, uid, i, pos, now) {
  var rc = r.racers[uid];
  if (r.phase !== "running" || !rc || rc.place > 0 || now < r.startAt) return 0;
  if (i !== rc.cp + 1 || i >= RACE_CPS.length || !pos) return 0;
  var cp = RACE_CPS[i];
  if (raceDist(pos, cp) > RACE_CP_RADIUS) return 0;
  if (cp[2] - 2 * RACE_CP_RADIUS > RACE_MAX_SPEED * (now - r.startAt) / 1000) return 0;
  rc.cp = i;
  if (i < RACE_CPS.length - 1) return 1;
  rc.time = now - r.startAt;
  r.order.push(uid);
  rc.place = r.order.length;
  return 2;
}

// Zaman ilerlet; aşama değiştiyse true.
function raceTick(r, now) {
  if (r.phase === "lobby" && now >= r.lobbyEnds) {
    r.n = Object.keys(r.racers).length;
    if (r.n === 0) { r.phase = "idle"; return true; }
    r.phase = "running"; r.startAt = now + RACE_COUNTDOWN_MS; r.endsAt = r.startAt + RACE_TIMEOUT_MS;
    return true;
  }
  if (r.phase === "running") {
    var all = true;
    for (var id in r.racers) if (r.racers[id].place === 0) all = false;
    if (all || now >= r.endsAt) { r.phase = "done"; r.doneUntil = now + RACE_RESULTS_MS; return true; }
  }
  if (r.phase === "done" && now >= r.doneUntil) { r.phase = "idle"; r.racers = {}; r.order = []; return true; }
  return false;
}

function raceReward(place, n) {
  if (place <= 0) return 0;
  if (place === 1 && n >= 2) return 3;
  if (place === 2 && n >= 3) return 2;
  return 1;
}

function raceView(r, now, names) {
  var list = [];
  for (var id in r.racers) {
    var rc = r.racers[id];
    list.push({ id: id, name: (names && names[id]) || "", cp: rc.cp, time: rc.time, place: rc.place });
  }
  return { phase: r.phase, lobby_in: Math.max(0, r.lobbyEnds - now), start_in: r.startAt - now,
    racers: list, cps: RACE_CPS.length - 1 };
}

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

var CARE_BONUS_MULTIPLIER = 2;

// bonus: olumlu artışların çarpanı; eksiler değişmez (pet_care_rules.gd ile aynı).
function careApply(state, action, now, lastAction, bonus) {
  bonus = typeof bonus === "number" ? bonus : 1;
  var rule = CARE_ACTIONS[action];
  if (!rule) return { ok: false, state: state, reason: "bilinmeyen eylem" };
  var last = lastAction && typeof lastAction[action] === "number" ? lastAction[action] : -1000000;
  if (now - last < rule.cooldown) return { ok: false, state: careDecay(state, now), reason: "biraz bekle" };
  var s = careDecay(state, now);
  for (var i = 0; i < CARE_STATS.length; i++) {
    var k = CARE_STATS[i];
    if (typeof rule[k] === "number") s[k] = snap2(clampCare(s[k] + (rule[k] > 0 ? rule[k] * bonus : rule[k])));
  }
  return { ok: true, state: s, reason: "", bonus: bonus > 1 };
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
function careBonus(action, p) {
  if ((action === "rest" || action === "play") && p && nearSpot(action, p)) return CARE_BONUS_MULTIPLIER;
  return 1;
}

function careAct(nk, userId, action, now, pos) {
  var rec = careLoad(nk, userId) || { state: careNew(now), last: {} };
  var r = careApply(rec.state, action, now, rec.last, careBonus(action, pos));
  rec.state = r.state;
  if (r.ok) rec.last[action] = now;
  careSave(nk, userId, rec);
  return { ok: r.ok, reason: r.reason, state: r.state, bonus: !!r.bonus };
}

var CHAT_PRESET = 0, CHAT_EMOTE = 1, CHAT_FREE = 2;
var CHAT_MIN_INTERVAL_MS = 1000;
var ID_PATTERN = /^[a-z0-9_]{1,32}$/;
var WORLD_LIMIT = 2000;
// Hareket hile koruması: iki durum arasında bu hızdan (m/s) hızlı yer değiştirme reddedilir (yürüme 4.6, Ring/41AT 14.2).
var MAX_SPEED = 18;
var SPEED_TOLERANCE_M = 2;
var BUS_SNAP_TOLERANCE_M = 22;

function isBusCafeId(cid) {
  return cid === "iett_41at" || String(cid || "").indexOf("ring_") === 0;
}
var NAME_PATTERN = /^[0-9A-Za-zÇĞİÖŞÜçğıöşü _-]{1,16}$/;

// Herkesin gördüğü takma adlar için kaba küfür filtresi. Yakalanan ad "" olur (istemci kimliğin başını gösterir).
// Kısa kökler sadece tam kelime olarak, uzunlar kelime içinde de aranır (yanlış pozitifi azaltmak için).
var BAD_WORDS_EXACT = ["amk", "aq", "amq", "oc", "pic", "got", "sg", "siktir", "sik", "yarak", "meme", "pust"];
var BAD_WORDS_SUB = ["orospu", "yarrak", "amcik", "sikerim", "sikeyim", "sikik", "siktig", "pezevenk", "kahpe", "ibne",
  "gavat", "yavsak", "serefsiz", "surtuk", "dalyarak", "kaltak", "amina", "anani", "bacini"];

function normalizeForFilter(s) {
  var map = { "ç": "c", "ğ": "g", "ı": "i", "i̇": "i", "ö": "o", "ş": "s", "ü": "u", "0": "o", "1": "i", "3": "e",
    "4": "a", "5": "s", "7": "t", "@": "a", "$": "s" };
  var out = "";
  var low = String(s).toLowerCase();
  for (var i = 0; i < low.length; i++) {
    var ch = low.charAt(i);
    out += map[ch] !== undefined ? map[ch] : ch;
  }
  return out;
}

function isOffensive(name) {
  var n = normalizeForFilter(name);
  var words = n.split(/[^a-z]+/);
  for (var i = 0; i < words.length; i++) {
    if (BAD_WORDS_EXACT.indexOf(words[i]) >= 0) return true;
  }
  var squashed = n.replace(/[^a-z]/g, "").replace(/(.)\1+/g, "$1");
  for (var j = 0; j < BAD_WORDS_SUB.length; j++) {
    if (squashed.indexOf(BAD_WORDS_SUB[j].replace(/(.)\1+/g, "$1")) >= 0) return true;
  }
  return false;
}

function cleanName(raw) {
  var n = String(raw || "").replace(/\s+/g, " ").trim().substring(0, 16);
  return NAME_PATTERN.test(n) && !isOffensive(n) ? n : "";
}

// Profil statüsü sabit listeden seçilir (game/src/core/local_profile.gd ile aynı). Doğrulanmamış oyuncu
// fakülte etiketi takamaz; listede olmayan değer listenin ilkine düşer.
var YTU_ROLES = ["Bilgisayar Müh.", "Elektrik-Elektronik Fak.", "Makine Fak.", "İnşaat Fak.", "İİBF", "Fen-Edebiyat Fak.",
  "Eğitim Fak.", "Kimya-Metalurji Fak.", "Sanat ve Tasarım Fak.", "YDYO Hazırlık"];
var VISITOR_ROLES = ["🎯 YKS Adayı (Hedef YTÜ)", "👀 Kampüs Misafiri", "🎓 Misafir Öğrenci", "🏛 YTÜ Mezunu"];

function cleanRole(raw, ytu) {
  var list = ytu ? YTU_ROLES : VISITOR_ROLES;
  var r = String(raw || "");
  return list.indexOf(r) >= 0 ? r : list[0];
}

function cleanFreeChat(raw, maxLen) {
  var lim = maxLen || 80;
  var s = String(raw || "").replace(/[\x00-\x1F\x7F]/g, "").replace(/\s+/g, " ").trim().substring(0, lim);
  if (!s || isOffensive(s)) return "";
  if (/(.)\1{7,}/.test(s.replace(/\s/g, ""))) return "";
  return s;
}

var VALID_CAFES = ["hokka", "kayinti_kafe", "buyuk_ev", "yemekhane", "yildiz_cafe", "eskafe", "academic_lounge",
  "ring_1", "ring_2", "ring_3", "ring_4", "iett_41at"];
var SOCIAL_COLLECTION = "social";
var SOCIAL_KEY = "social_friends";

function socialLoad(nk, userId) {
  var objs = nk.storageRead([{ collection: SOCIAL_COLLECTION, key: SOCIAL_KEY, userId: userId }]);
  var v = (objs && objs.length > 0 && objs[0].value) ? objs[0].value : {};
  return {
    name: String(v.name || ""),
    friends: (v.friends || []).slice(),
    incoming: (v.incoming || []).slice(),
    outgoing: (v.outgoing || []).slice()
  };
}

function socialSave(nk, userId, doc) {
  nk.storageWrite([{
    collection: SOCIAL_COLLECTION,
    key: SOCIAL_KEY,
    userId: userId,
    value: doc,
    permissionRead: 1,
    permissionWrite: 0
  }]);
}

function hasUserEntry(arr, uid) {
  for (var i = 0; i < arr.length; i++) {
    if (arr[i] && arr[i].id === uid) return true;
  }
  return false;
}

function removeUserEntry(arr, uid) {
  var out = [];
  for (var i = 0; i < arr.length; i++) {
    if (arr[i] && arr[i].id !== uid) out.push(arr[i]);
  }
  return out;
}

// Hedef kimlik gerçek bir Nakama kullanıcısı mı (uydurma kimliğe storage yazılmaya çalışılmasın).
function userExists(nk, uid) {
  if (!uid || typeof uid !== "string" || uid.length > 64) return false;
  try {
    var u = nk.usersGetId([uid]);
    return !!(u && u.length > 0);
  } catch (e) {
    return false;
  }
}

var SOCIAL_MIN_INTERVAL_MS = 400;  // storage'a dokunan sosyal eylemler arası en az süre (spam/DB yükü)
var SOCIAL_LIST_MAX = 100;         // arkadaş / istek kutusu üst sınırı
// Şikayetler (Google Play kullanıcı içeriği şartı): sistem kullanıcısının "reports" koleksiyonuna yazılır,
// Nakama konsolundan (Storage → reports) okunur. Kanıt: şikayet edilenin sunucunun gördüğü son mesajları.
var REPORT_COLLECTION = "reports";
var REPORT_REASONS = ["abuse", "harass", "spam"];
var REPORT_MIN_INTERVAL_MS = 20000;
var RECENT_CHAT_KEEP = 6;

function areFriends(nk, uidA, uidB) {
  if (!uidA || !uidB || uidA === uidB) return false;
  var doc = socialLoad(nk, uidA);
  return hasUserEntry(doc.friends, uidB);
}

function cafeMap(state) {
  var out = {};
  for (var id in state.players) {
    var p = state.players[id];
    if (p.cafe) {
      out[p.cafe] = out[p.cafe] || [];
      out[p.cafe].push({ id: id, name: p.name || id.substring(0, 6), pet: p.pet || "mushnub" });
    }
  }
  return out;
}

function groupList(state) {
  var list = [];
  var gs = state.groups || {};
  for (var gid in gs) {
    var g = gs[gid];
    var mems = [];
    for (var i = 0; i < g.members.length; i++) {
      var mid = g.members[i];
      var mp = state.players[mid];
      if (mp) mems.push({ id: mid, name: mp.name || mid.substring(0, 6) });
    }
    if (mems.length > 0) {
      list.push({ id: g.id, title: g.title, owner: g.owner, owner_name: g.ownerName, x: g.x, z: g.z, members: mems });
    }
  }
  return list;
}

function groupLeaveAll(state, uid) {
  var gs = state.groups || {};
  var changed = false;
  for (var gid in gs) {
    var g = gs[gid];
    var idx = g.members.indexOf(uid);
    if (idx >= 0) {
      g.members.splice(idx, 1);
      changed = true;
      if (g.members.length === 0) delete gs[gid];
      else if (g.owner === uid) g.owner = g.members[0];
    }
  }
  return changed;
}

function sendSocialStateTo(nk, dispatcher, state, uid, extra) {
  var pl = state.players[uid];
  if (!pl || !pl.presence) return;
  var doc = socialLoad(nk, uid);
  var pkt = {
    type: "social_state",
    friends: doc.friends,
    incoming: doc.incoming,
    outgoing: doc.outgoing,
    cafes: cafeMap(state),
    groups: groupList(state)
  };
  if (extra) {
    for (var k in extra) pkt[k] = extra[k];
  }
  dispatcher.broadcastMessage(OP_SOCIAL, JSON.stringify(pkt), [pl.presence], null, true);
}

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
    // İstemcinin gönderdiği vars asla oturuma taşınmaz; dev'de "mock-ytu-" önekli kimlik doğrulanmış sayılır.
    req.account.vars = { ytu: id.indexOf("mock-ytu-") === 0 ? "true" : "false" };
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
  var isYtuMail = ALLOWED_EMAIL.test(email);
  if (user.id !== id || (schoolOnly && !isYtuMail)) {
    logger.warn("Reddedildi: id eşleşmedi ya da domain dışı (%s)", email);
    throw Error("bu hesap kullanılamaz");
  }
  // Sunucu otoriter YTÜ öğrenci doğrulaması: sonuç sunucunun imzaladığı oturum değişkenine yazılır.
  // (Burada storage kullanılamaz: custom id Supabase kimliğidir, Nakama user_id'si değil; yeni hesapta kullanıcı
  // henüz yok.) vars tamamen değiştirilir: istemcinin gönderdiği her şey (supabase_token, sahte ytu) atılır.
  req.account.vars = { ytu: isYtuMail ? "true" : "false" };
  return req;
}

// ---------------------------------------------------------------- hesap silme (Play Store şartı)
// Oyuncunun Nakama hesabını ve sunucudaki tüm kayıtlarını (cüzdan, bakım, kilitler, arkadaşlar) kalıcı siler.
// Arkadaşlarının listesindeki kaydı da temizlenir. Supabase hesabını istemci ayrıca siler (delete_my_account).
function rpcDeleteAccount(ctx, logger, nk, payload) {
  if (!ctx.userId) throw Error("giriş gerekli");
  var doc = socialLoad(nk, ctx.userId);
  var others = doc.friends.concat(doc.incoming, doc.outgoing);
  for (var i = 0; i < others.length; i++) {
    var oid = others[i] && others[i].id;
    if (!oid || oid === ctx.userId || !userExists(nk, oid)) continue;
    try {
      var od = socialLoad(nk, oid);
      od.friends = removeUserEntry(od.friends, ctx.userId);
      od.incoming = removeUserEntry(od.incoming, ctx.userId);
      od.outgoing = removeUserEntry(od.outgoing, ctx.userId);
      socialSave(nk, oid, od);
    } catch (e) {
      logger.warn("arkadaş kaydı temizlenemedi: %s", e && e.message);
    }
  }
  nk.accountDeleteId(ctx.userId, false);
  logger.info("hesap silindi: %s", ctx.userId);
  return JSON.stringify({ ok: true });
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
  if (best) return JSON.stringify({ match_id: best.matchId });
  // Arama dizini (label) birkaç yüz ms gecikebilir: yeni açılmış oda listede görünmeyebilir.
  // Bölgenin "son açılan oda" kaydına bak; hâlâ yaşıyor ve yer varsa onu kullan (aynı anda gelenler ayrı odaya düşmesin).
  var ptr = roomPointerRead(nk, zone);
  if (ptr) {
    var m = nk.matchGet(ptr.id);
    if (m && m.size < cap) return JSON.stringify({ match_id: ptr.id });
  }
  var matchId = nk.matchCreate("zone_room", { zone: zone });
  if (!roomPointerWrite(nk, zone, matchId, ptr ? ptr.version : "*")) {
    // Başkası aynı anda oda açtı: onunkini kullan (bizimki boş kalır, 30 sn sonra kapanır).
    var other = roomPointerRead(nk, zone);
    if (other) matchId = other.id;
  }
  return JSON.stringify({ match_id: matchId });
}

var ROOM_PTR_COLLECTION = "rooms";
var SYSTEM_USER = "00000000-0000-0000-0000-000000000000";

function roomPointerRead(nk, zone) {
  var r = nk.storageRead([{ collection: ROOM_PTR_COLLECTION, key: zone, userId: SYSTEM_USER }]);
  if (!r || r.length === 0) return null;
  return { id: r[0].value.id, version: r[0].version };
}

// version: "*" = sadece yoksa yaz; aksi halde okunan sürüm değişmediyse yaz. Çakışmada false.
function roomPointerWrite(nk, zone, matchId, version) {
  try {
    nk.storageWrite([{ collection: ROOM_PTR_COLLECTION, key: zone, userId: SYSTEM_USER, value: { id: matchId },
      version: version, permissionRead: 0, permissionWrite: 0 }]);
    return true;
  } catch (e) {
    return false;
  }
}

// ---------------------------------------------------------------- oda

function matchInit(ctx, logger, nk, params) {
  var zone = params.zone;
  var label = JSON.stringify({ zone: zone });
  return {
    state: {
      zone: zone,
      players: {},
      emptyTicks: 0,
      cap: capacity(ctx),
      freeChat: env(ctx, "UNIPET_FREE_CHAT", "true") !== "false",
      race: raceNew(),
      groups: {},
      nextGroupId: 1
    },
    tickRate: TICK_RATE,
    label: label
  };
}

// Katılanın oturum değişkenindeki (sunucu imzalı) YTÜ doğrulaması. Değişkeni olmayan eski oturum = doğrulanmamış.
function sessionYtu(ctx) {
  return !!(ctx && ctx.vars && ctx.vars.ytu === "true");
}

function matchJoinAttempt(ctx, logger, nk, dispatcher, tick, state, presence, metadata) {
  state.ytuPending = state.ytuPending || {};
  state.ytuPending[presence.userId] = sessionYtu(ctx);
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
    var ytuAuth = !!(state.ytuPending && state.ytuPending[p.userId]);
    if (state.ytuPending) delete state.ytuPending[p.userId];
    state.players[p.userId] = state.players[p.userId] || { presence: p, p: [0, 0, 0], y: 0, a: "idle", pet: "", acc: {}, name: "", ytu: false, role: "", bio: "", disc: 0, cafe: "", lastChat: 0 };
    state.players[p.userId].presence = p;
    state.players[p.userId].ytu = ytuAuth;
    // Efsanevi pet kilitleri: kapalı testte Kutbi hediye; oyuncuya güncel liste
    var fresh = env(ctx, "UNIPET_CLOSED_TEST", "false") === "true" ? unlocksGrant(nk, p.userId, ["kutbi"]) : [];
    state.players[p.userId].unlocked = unlocksLoad(nk, p.userId);
    dispatcher.broadcastMessage(OP_UNLOCKS, JSON.stringify({ pets: state.players[p.userId].unlocked, fresh: fresh }), [p], null, true);
    dispatcher.broadcastMessage(OP_WALLET, JSON.stringify(walletView(walletLoad(nk, p.userId, Date.now()))), [p], null, true);
    if (state.race && state.race.phase !== "idle") raceBroadcast(dispatcher, state, Date.now(), [p]);
    // Yeni gelene odadaki herkesin son durumu.
    var list = [];
    for (var id in state.players) {
      if (id === p.userId) continue;
      var o = state.players[id];
      list.push({ id: id, p: o.p, y: o.y, a: o.a, pet: o.pet, acc: o.acc, name: o.name, ytu: !!o.ytu, role: o.role || "", bio: o.bio || "", disc: o.disc | 0 });
    }
    dispatcher.broadcastMessage(OP_SNAPSHOT, JSON.stringify({ players: list }), [p], null, true);
    var nowS = Math.floor(Date.now() / 1000);
    var rec = careLoad(nk, p.userId);
    var careState = rec ? careDecay(rec.state, nowS) : careNew(nowS);
    if (!rec) careSave(nk, p.userId, { state: careState, last: {} });
    dispatcher.broadcastMessage(OP_CARE, JSON.stringify({ ok: true, reason: "", state: careState }), [p], null, true);
    sendSocialStateTo(nk, dispatcher, state, p.userId);
  }
  state.emptyTicks = 0;
  return { state: state };
}

function matchLeave(ctx, logger, nk, dispatcher, tick, state, presences) {
  var cafeChanged = false;
  var grpChanged = false;
  for (var i = 0; i < presences.length; i++) {
    var uid = presences[i].userId;
    // Hızlı yeniden bağlanmada eski oturumun çıkışı yeni oturumdan SONRA gelebilir: yeni kaydı silme.
    var cur = state.players[uid];
    if (cur && cur.presence && cur.presence.sessionId && presences[i].sessionId && cur.presence.sessionId !== presences[i].sessionId) continue;
    if (state.players[uid] && state.players[uid].cafe) cafeChanged = true;
    if (groupLeaveAll(state, uid)) grpChanged = true;
    delete state.players[uid];
    if (state.race) raceLeave(state.race, uid);
  }
  var rem = everyone(state);
  if (rem.length > 0 && (cafeChanged || grpChanged)) {
    dispatcher.broadcastMessage(OP_SOCIAL, JSON.stringify({ type: "rooms", cafes: cafeMap(state), groups: groupList(state) }), rem, null, true);
  }
  return { state: state };
}

function raceNames(state) {
  var names = {};
  for (var id in state.players) names[id] = state.players[id].name || "";
  return names;
}

function raceBroadcast(dispatcher, state, now, to) {
  dispatcher.broadcastMessage(OP_RACE, JSON.stringify(raceView(state.race, now, raceNames(state))), to || null, null, true);
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

// Tek bir istemci mesajını işler. matchLoop bunu try/catch içinde çağırır: bozuk/kötü niyetli bir paket
// (ya da storage hatası) odadaki herkesi düşürmesin.
function handleMessage(ctx, logger, nk, dispatcher, state, m) {
  var uid = m.sender.userId;
  var pl = state.players[uid];
  if (!pl) return;
  var data;
  try {
    data = JSON.parse(nk.binaryToString(m.data));
  } catch (e) {
    return;
  }
  if (!data || typeof data !== "object" || Array.isArray(data)) return;  // "null", sayı, dizi: yok say
  if (m.opCode === OP_STATE) {
    if (!data.p || data.p.length !== 3 || !finiteIn(data.p[0], WORLD_LIMIT) || !finiteIn(data.p[1], WORLD_LIMIT) ||
        !finiteIn(data.p[2], WORLD_LIMIT) || !finiteIn(data.y, 1000) || !ID_PATTERN.test(String(data.a))) {
      return;
    }
    var nowMs = Date.now();
    var snapTol = pl.busSnapAllowance || 0;
    pl.busSnapAllowance = 0;
    if (typeof pl.lastStateAt === "number") {
      var dt = Math.max(0.1, (nowMs - pl.lastStateAt) / 1000);
      var moved = Math.sqrt(Math.pow(data.p[0] - pl.p[0], 2) + Math.pow(data.p[2] - pl.p[2], 2));
      if (moved > MAX_SPEED * dt + SPEED_TOLERANCE_M + snapTol) {
        pl.speedRejects = (pl.speedRejects || 0) + 1;
        return;
      }
    }
    pl.lastStateAt = nowMs;
    pl.p = data.p; pl.y = data.y; pl.a = data.a;
    var others = othersOf(state, uid);
    if (others.length > 0) {
      dispatcher.broadcastMessage(OP_STATE, JSON.stringify({ id: uid, p: pl.p, y: pl.y, a: pl.a }), others, null, false);
    }
  } else if (m.opCode === OP_CHAT) {
    var now = Date.now();
    if (now - pl.lastChat < CHAT_MIN_INTERVAL_MS) return;
    var k = data.k, payload = String(data.p || "");
    var ok = (k === CHAT_PRESET || k === CHAT_EMOTE) && ID_PATTERN.test(payload);
    if (k === CHAT_FREE && state.freeChat) {
      payload = cleanFreeChat(payload, 80);
      ok = payload.length > 0;
    }
    if (!ok) return;

    var ch = String(data.ch || "campus");
    var recipients = null;
    if (ch === "campus") {
      recipients = everyone(state);
    } else if (ch.indexOf("cafe:") === 0) {
      var cid = ch.substring(5);
      if (VALID_CAFES.indexOf(cid) < 0) return;
      recipients = [];
      for (var pidC in state.players) {
        if (pidC === uid || state.players[pidC].cafe === cid) recipients.push(state.players[pidC].presence);
      }
    } else if (ch.indexOf("group:") === 0) {
      var gid = ch.substring(6);
      var grp = state.groups && state.groups[gid];
      if (!grp || grp.members.indexOf(uid) < 0) return;
      recipients = [];
      for (var gm = 0; gm < grp.members.length; gm++) {
        var gpl = state.players[grp.members[gm]];
        if (gpl) recipients.push(gpl.presence);
      }
    } else if (ch.indexOf("dm:") === 0) {
      var targetUid = ch.substring(3);
      if (!areFriends(nk, uid, targetUid)) {
        dispatcher.broadcastMessage(OP_SOCIAL, JSON.stringify({ type: "toast", ok: false, text: "Özel mesaj için önce arkadaş olmalısınız." }), [pl.presence], null, true);
        return;
      }
      recipients = [pl.presence];
      if (state.players[targetUid] && state.players[targetUid].presence) {
        recipients.push(state.players[targetUid].presence);
      }
    } else {
      return;
    }

    pl.lastChat = now;
    pl.recentChat = (pl.recentChat || []).concat([{ t: Math.floor(now / 1000), ch: ch, k: k, p: payload }]).slice(-RECENT_CHAT_KEEP);
    var outChat = { s: uid, sn: pl.name || uid.substring(0, 6), k: k, p: payload, ch: ch };
    if (finiteIn(data.px, WORLD_LIMIT) && finiteIn(data.pz, WORLD_LIMIT)) {
      outChat.px = Math.round(data.px * 10) / 10;
      outChat.pz = Math.round(data.pz * 10) / 10;
      outChat.pl = cleanFreeChat(data.pl || "Kampüs", 36) || "Kampüs";
    }
    if (recipients && recipients.length > 0) {
      dispatcher.broadcastMessage(OP_CHAT, JSON.stringify(outChat), recipients, null, true);
    }
    if (othersOf(state, uid).length > 0) {
      var soc = careAct(nk, uid, "social", Math.floor(now / 1000));
      if (soc.ok) dispatcher.broadcastMessage(OP_CARE, JSON.stringify(soc), [pl.presence], null, true);
    }
  } else if (m.opCode === OP_SOCIAL) {
    var sAct = String(data.act || "");
    var myNick = pl.name || uid.substring(0, 6);
    state.groups = state.groups || {};
    if (sAct === "sync") {
      sendSocialStateTo(nk, dispatcher, state, uid);
    } else if (sAct === "enter_cafe") {
      var newCafe = String(data.cafe || "");
      if (VALID_CAFES.indexOf(newCafe) >= 0 && pl.cafe !== newCafe) {
        if (isBusCafeId(newCafe) && (!pl.lastBusSnapAt || Date.now() - pl.lastBusSnapAt > 2500)) {
          pl.busSnapAllowance = BUS_SNAP_TOLERANCE_M;
          pl.lastBusSnapAt = Date.now();
        }
        pl.cafe = newCafe;
        dispatcher.broadcastMessage(OP_SOCIAL, JSON.stringify({ type: "cafes", cafes: cafeMap(state) }), everyone(state), null, true);
      }
    } else if (sAct === "leave_cafe") {
      if (pl.cafe) {
        if (isBusCafeId(pl.cafe) && (!pl.lastBusSnapAt || Date.now() - pl.lastBusSnapAt > 2500)) {
          pl.busSnapAllowance = BUS_SNAP_TOLERANCE_M;
          pl.lastBusSnapAt = Date.now();
        }
        pl.cafe = "";
        dispatcher.broadcastMessage(OP_SOCIAL, JSON.stringify({ type: "cafes", cafes: cafeMap(state) }), everyone(state), null, true);
      }
    } else if (sAct === "create_group") {
      var gTitle = cleanFreeChat(data.title || "", 24);
      if (!gTitle) {
        dispatcher.broadcastMessage(OP_SOCIAL, JSON.stringify({ type: "toast", ok: false, text: "Geçerli bir grup adı girin." }), [pl.presence], null, true);
        return;
      }
      if (Object.keys(state.groups).length >= 12) return;
      groupLeaveAll(state, uid);
      state.nextGroupId = (state.nextGroupId || 1) + 1;
      var newGid = "g" + state.nextGroupId;
      state.groups[newGid] = { id: newGid, title: gTitle, owner: uid, ownerName: myNick, x: Math.round(pl.p[0]), z: Math.round(pl.p[2]), members: [uid] };
      dispatcher.broadcastMessage(OP_SOCIAL, JSON.stringify({ type: "groups", groups: groupList(state) }), everyone(state), null, true);
      dispatcher.broadcastMessage(OP_SOCIAL, JSON.stringify({ type: "group_joined", joined_group: newGid, groups: groupList(state) }), [pl.presence], null, true);
    } else if (sAct === "join_group") {
      var jGid = String(data.id || "");
      var targetG = state.groups[jGid];
      if (!targetG) return;
      groupLeaveAll(state, uid);
      if (targetG.members.indexOf(uid) < 0) targetG.members.push(uid);
      dispatcher.broadcastMessage(OP_SOCIAL, JSON.stringify({ type: "groups", groups: groupList(state) }), everyone(state), null, true);
      dispatcher.broadcastMessage(OP_SOCIAL, JSON.stringify({ type: "group_joined", joined_group: jGid, groups: groupList(state) }), [pl.presence], null, true);
    } else if (sAct === "leave_group") {
      if (groupLeaveAll(state, uid)) {
        dispatcher.broadcastMessage(OP_SOCIAL, JSON.stringify({ type: "groups", groups: groupList(state) }), everyone(state), null, true);
      }
      dispatcher.broadcastMessage(OP_SOCIAL, JSON.stringify({ type: "group_left", left_group: true, groups: groupList(state) }), [pl.presence], null, true);
    } else if (sAct === "report") {
      var repId = String(data.id || "");
      var reason = REPORT_REASONS.indexOf(String(data.reason)) >= 0 ? String(data.reason) : "spam";
      if (!repId || repId === uid || !userExists(nk, repId)) return;
      if (pl.lastReportAt && Date.now() - pl.lastReportAt < REPORT_MIN_INTERVAL_MS) {
        dispatcher.broadcastMessage(OP_SOCIAL, JSON.stringify({ type: "toast", ok: false, text: "Biraz bekleyip tekrar şikayet edebilirsin." }), [pl.presence], null, true);
        return;
      }
      pl.lastReportAt = Date.now();
      var tp = state.players[repId];
      nk.storageWrite([{ collection: REPORT_COLLECTION, key: Date.now() + "-" + uid.substring(0, 8), userId: SYSTEM_USER,
        value: { t: Math.floor(Date.now() / 1000), reporter: uid, reporter_name: myNick, target: repId,
          target_name: (tp && tp.name) || cleanName(data.name) || "", reason: reason, zone: state.zone,
          recent: (tp && tp.recentChat) || [] },
        permissionRead: 0, permissionWrite: 0 }]);
      logger.warn("şikayet: %s → %s (%s)", uid, repId, reason);
      dispatcher.broadcastMessage(OP_SOCIAL, JSON.stringify({ type: "toast", ok: true, text: "Şikayetin alındı. Teşekkürler!" }), [pl.presence], null, true);
    } else if (sAct.indexOf("friend_") === 0 && pl.lastSocialAt && Date.now() - pl.lastSocialAt < SOCIAL_MIN_INTERVAL_MS) {
      return;
    } else if (sAct === "friend_req") {
      pl.lastSocialAt = Date.now();
      var toId = String(data.to || "");
      if (!toId || toId === uid || !userExists(nk, toId)) return;
      var myDoc = socialLoad(nk, uid);
      var theirDoc = socialLoad(nk, toId);
      var theirNick = (state.players[toId] && state.players[toId].name) || theirDoc.name || cleanName(data.name) || toId.substring(0, 6);
      if (hasUserEntry(myDoc.friends, toId)) return;
      if (myDoc.friends.length >= SOCIAL_LIST_MAX || theirDoc.incoming.length >= SOCIAL_LIST_MAX) {
        dispatcher.broadcastMessage(OP_SOCIAL, JSON.stringify({ type: "toast", ok: false, text: "Arkadaş/istek listesi dolu." }), [pl.presence], null, true);
        return;
      }
      // Karşı taraf zaten bize istek göndermişse doğrudan arkadaş yap!
      if (hasUserEntry(myDoc.incoming, toId)) {
        myDoc.incoming = removeUserEntry(myDoc.incoming, toId);
        theirDoc.outgoing = removeUserEntry(theirDoc.outgoing, uid);
        myDoc.friends.push({ id: toId, name: theirNick });
        theirDoc.friends.push({ id: uid, name: myNick });
        socialSave(nk, uid, myDoc);
        socialSave(nk, toId, theirDoc);
        sendSocialStateTo(nk, dispatcher, state, uid, { ok: true, text: theirNick + " ile artık arkadaşsınız!" });
        sendSocialStateTo(nk, dispatcher, state, toId, { ok: true, text: myNick + " arkadaşlık isteğini kabul etti!" });
        return;
      }
      if (!hasUserEntry(myDoc.outgoing, toId)) myDoc.outgoing.push({ id: toId, name: theirNick });
      if (!hasUserEntry(theirDoc.incoming, uid)) theirDoc.incoming.push({ id: uid, name: myNick, t: Math.floor(Date.now() / 1000) });
      socialSave(nk, uid, myDoc);
      socialSave(nk, toId, theirDoc);
      sendSocialStateTo(nk, dispatcher, state, uid, { ok: true, text: "Arkadaşlık isteği gönderildi!" });
      sendSocialStateTo(nk, dispatcher, state, toId, { ok: true, text: myNick + " arkadaşlık isteği gönderdi!" });
    } else if (sAct === "friend_accept") {
      pl.lastSocialAt = Date.now();
      var fromId = String(data.from || "");
      if (!fromId || fromId === uid || !userExists(nk, fromId)) return;
      var aDoc = socialLoad(nk, uid);
      if (!hasUserEntry(aDoc.incoming, fromId)) return;
      var bDoc = socialLoad(nk, fromId);
      var bNick = (state.players[fromId] && state.players[fromId].name) || bDoc.name || fromId.substring(0, 6);
      aDoc.incoming = removeUserEntry(aDoc.incoming, fromId);
      aDoc.outgoing = removeUserEntry(aDoc.outgoing, fromId);
      bDoc.outgoing = removeUserEntry(bDoc.outgoing, uid);
      bDoc.incoming = removeUserEntry(bDoc.incoming, uid);
      if (!hasUserEntry(aDoc.friends, fromId)) aDoc.friends.push({ id: fromId, name: bNick });
      if (!hasUserEntry(bDoc.friends, uid)) bDoc.friends.push({ id: uid, name: myNick });
      socialSave(nk, uid, aDoc);
      socialSave(nk, fromId, bDoc);
      sendSocialStateTo(nk, dispatcher, state, uid, { ok: true, text: bNick + " ile artık arkadaşsınız!" });
      sendSocialStateTo(nk, dispatcher, state, fromId, { ok: true, text: myNick + " arkadaşlık isteğini kabul etti!" });
    } else if (sAct === "friend_decline") {
      pl.lastSocialAt = Date.now();
      var decId = String(data.from || "");
      if (!decId || decId === uid || !userExists(nk, decId)) return;
      var dMy = socialLoad(nk, uid);
      var dTh = socialLoad(nk, decId);
      dMy.incoming = removeUserEntry(dMy.incoming, decId);
      dTh.outgoing = removeUserEntry(dTh.outgoing, uid);
      socialSave(nk, uid, dMy);
      socialSave(nk, decId, dTh);
      sendSocialStateTo(nk, dispatcher, state, uid);
      sendSocialStateTo(nk, dispatcher, state, decId);
    } else if (sAct === "friend_remove") {
      pl.lastSocialAt = Date.now();
      var remId = String(data.id || "");
      if (!remId || remId === uid || !userExists(nk, remId)) return;
      var rMy = socialLoad(nk, uid);
      var rTh = socialLoad(nk, remId);
      rMy.friends = removeUserEntry(rMy.friends, remId);
      rTh.friends = removeUserEntry(rTh.friends, uid);
      socialSave(nk, uid, rMy);
      socialSave(nk, remId, rTh);
      sendSocialStateTo(nk, dispatcher, state, uid);
      sendSocialStateTo(nk, dispatcher, state, remId);
    }
  } else if (m.opCode === OP_CARE) {
    var act = String(data.act || "");
    var res;
    if (act === "social" || !CARE_ACTIONS[act]) {
      res = { ok: false, reason: "geçersiz eylem", state: null };
    } else if (act === "eat" && !nearSpot("eat", pl.p)) {
      res = { ok: false, reason: "Yemek için Yemekhane, Hokka ya da Kayıntı'ya git", state: null };
    } else {
      res = careAct(nk, uid, act, Math.floor(Date.now() / 1000), pl.p);
    }
    if (res.state === null) {
      var cur = careLoad(nk, uid);
      res.state = cur ? careDecay(cur.state, Math.floor(Date.now() / 1000)) : careNew(Math.floor(Date.now() / 1000));
    }
    dispatcher.broadcastMessage(OP_CARE, JSON.stringify(res), [pl.presence], null, true);
  } else if (m.opCode === OP_RACE) {
    var nowR = Date.now();
    state.race = state.race || raceNew();
    var act = String(data.act);
    if (act === "join") {
      var why = raceJoin(state.race, uid, pl.p, nowR);
      if (why) dispatcher.broadcastMessage(OP_RACE, JSON.stringify({ error: why }), [pl.presence], null, true);
      else raceBroadcast(dispatcher, state, nowR);
    } else if (act === "leave") {
      if (raceLeave(state.race, uid)) raceBroadcast(dispatcher, state, nowR);
    } else if (act === "cp") {
      var res = raceCp(state.race, uid, data.i, pl.p, nowR);
      if (res > 0) raceBroadcast(dispatcher, state, nowR);
      if (res === 2) {
        var rc = state.race.racers[uid];
        var wr = walletLoad(nk, uid, nowR);
        var rw = Math.max(0, Math.min(raceReward(rc.place, state.race.n), MINIGAME_DAILY_CAP - wr.mg));
        if (rw > 0) { wr.dust += rw; wr.mg += rw; walletSave(nk, uid, wr); }
        var vr = walletView(wr);
        vr.reward = rw;
        dispatcher.broadcastMessage(OP_WALLET, JSON.stringify(vr), [pl.presence], null, true);
      }
    }
  } else if (m.opCode === OP_MINIGAME) {
    var nowMg = Date.now();
    var wg = walletLoad(nk, uid, nowMg);
    var reward = 0;
    if (!pl.lastMinigame || nowMg - pl.lastMinigame >= MINIGAME_MIN_GAP_S * 1000) {
      reward = minigameReward(String(data.game), data.score, wg.mg);
      pl.lastMinigame = nowMg;
    }
    if (reward > 0) { wg.dust += reward; wg.mg += reward; walletSave(nk, uid, wg); }
    var vg = walletView(wg);
    vg.reward = reward;
    dispatcher.broadcastMessage(OP_WALLET, JSON.stringify(vg), [pl.presence], null, true);
  } else if (m.opCode === OP_COLLECT) {
    var wl = walletLoad(nk, uid, Date.now());
    var got = stardustCollect(wl, data.i, pl.p);
    if (got) walletSave(nk, uid, wl);
    dispatcher.broadcastMessage(OP_WALLET, JSON.stringify(walletView(wl, got)), [pl.presence], null, true);
  } else if (m.opCode === OP_PROFILE) {
    if (!ID_PATTERN.test(String(data.pet))) return;
    if (!petAllowed(String(data.pet), pl.unlocked || [])) return;  // kilitli efsanevi pet: profil kabul edilmez
    var acc = {};
    var ownedNow = null;  // satın alınmamış dükkan ürünü takılamaz
    var slots = ["head", "face", "neck", "back"];
    for (var s = 0; s < slots.length; s++) {
      var a = data.acc && data.acc[slots[s]];
      if (!a || !ID_PATTERN.test(String(a))) continue;
      if (SHOP.hasOwnProperty(String(a))) {
        if (ownedNow === null) ownedNow = walletLoad(nk, uid, Date.now()).owned;
        if (ownedNow.indexOf(String(a)) < 0) continue;
      }
      acc[slots[s]] = String(a);
    }
    pl.pet = String(data.pet); pl.acc = acc; pl.name = cleanName(data.name);
    // pl.ytu yalnızca oturumdan gelir (matchJoin); istemcinin gönderdiği data.ytu yok sayılır.
    pl.role = cleanRole(data.role, pl.ytu);
    pl.bio = cleanFreeChat(data.bio || "", 40);
    pl.disc = typeof data.disc === "number" && isFinite(data.disc) ? Math.max(0, Math.min(60, Math.floor(data.disc))) : 0;
    if (pl.name) {
      var sDoc = socialLoad(nk, uid);
      if (sDoc.name !== pl.name) { sDoc.name = pl.name; socialSave(nk, uid, sDoc); }
    }
    var rest = othersOf(state, uid);
    if (rest.length > 0) {
      dispatcher.broadcastMessage(OP_PROFILE, JSON.stringify({ id: uid, pet: pl.pet, acc: acc, name: pl.name, ytu: pl.ytu, role: pl.role, bio: pl.bio, disc: pl.disc }), rest, null, true);
    }
  }
}

function matchLoop(ctx, logger, nk, dispatcher, tick, state, messages) {
  for (var i = 0; i < messages.length; i++) {
    try {
      handleMessage(ctx, logger, nk, dispatcher, state, messages[i]);
    } catch (e) {
      logger.warn("mesaj işlenemedi (op %d): %s", messages[i].opCode, e && e.message);
    }
  }
  if (state.race && raceTick(state.race, Date.now())) raceBroadcast(dispatcher, state, Date.now());
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

// Oyun yalnızca authenticate/custom (Supabase köprüsü) ve gerçek zamanlı soketi kullanır. Nakama'nın diğer giriş
// yolları server key'i (APK'da açık) bilen herkese Supabase'siz hesap açtırıyordu; istemcinin doğrudan storage
// yazması da yeni hesapta cüzdan/kilit/arkadaş kaydını kendisinin oluşturmasına izin veriyordu. Hepsi kapalı.
function rejectClientCall(ctx, logger, nk, req) {
  throw Error("izin yok");
}


function InitModule(ctx, logger, nk, initializer) {
  initializer.registerBeforeAuthenticateCustom(beforeAuthenticateCustom);
  // Nakama kayıtları InitModule kaynağından okur: her çağrı açıkça yazılmalı (döngü/dinamik ad çalışmaz).
  initializer.registerBeforeAuthenticateDevice(rejectClientCall);
  initializer.registerBeforeAuthenticateEmail(rejectClientCall);
  initializer.registerBeforeAuthenticateApple(rejectClientCall);
  initializer.registerBeforeAuthenticateFacebook(rejectClientCall);
  initializer.registerBeforeAuthenticateFacebookInstantGame(rejectClientCall);
  initializer.registerBeforeAuthenticateGameCenter(rejectClientCall);
  initializer.registerBeforeAuthenticateGoogle(rejectClientCall);
  initializer.registerBeforeAuthenticateSteam(rejectClientCall);
  initializer.registerBeforeLinkDevice(rejectClientCall);
  initializer.registerBeforeLinkEmail(rejectClientCall);
  initializer.registerBeforeLinkApple(rejectClientCall);
  initializer.registerBeforeLinkFacebook(rejectClientCall);
  initializer.registerBeforeLinkFacebookInstantGame(rejectClientCall);
  initializer.registerBeforeLinkGameCenter(rejectClientCall);
  initializer.registerBeforeLinkGoogle(rejectClientCall);
  initializer.registerBeforeLinkSteam(rejectClientCall);
  initializer.registerBeforeLinkCustom(rejectClientCall);
  initializer.registerBeforeWriteStorageObjects(rejectClientCall);
  initializer.registerBeforeDeleteStorageObjects(rejectClientCall);
  initializer.registerRpc("find_room", rpcFindRoom);
  initializer.registerRpc("wallet", rpcWallet);
  initializer.registerRpc("buy_item", rpcBuyItem);
  initializer.registerRpc("delete_account", rpcDeleteAccount);
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
