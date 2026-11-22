"""YTÜ Davutpaşa Kampüsü yer listesi (landmark) verisi üretici (ROADMAP 5.4 / Task 010).

YTÜ resmi kampüs haritası (1-38 numaralı yerler, kapılar ve metro) ile eski krokideki
ünlü kampüs kafelerini OSM verisiyle (game/data/zones/davutpasa_campus.json) ve bölge
tanımlarıyla (game/data/zones/zones.json) eşleştirerek game/data/places.json üretir.

Kullanım:
    python -I tools/osm/make_places.py

Çıktı:
    game/data/places.json:
    {"places": [{"id": "...", "name": "...", "kind": "...", "pos": [x, z],
                 "zone": "...", "source": "osm|manual", "osm_name": "..."}]}

Sadece standart kütüphane kullanılır. Çıktı tamamen deterministiktir.
"""

from __future__ import annotations

import json
import math
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
CAMPUS_JSON = ROOT / "game" / "data" / "zones" / "davutpasa_campus.json"
ZONES_JSON = ROOT / "game" / "data" / "zones" / "zones.json"
OUTPUT_JSON = ROOT / "game" / "data" / "places.json"

ALLOWED_KINDS = {
    "food",
    "faculty",
    "dorm",
    "sport",
    "landmark",
    "service",
    "gate",
    "transport",
}


def normalize_text(text: str) -> str:
    """Türkçe karakterleri ve büyük/küçük harf farklarını eşitleyen metin normalizasyonu."""
    text = text.replace("İ", "i").replace("I", "ı").lower()
    mapping = str.maketrans("çğıöşü", "cgiosu")
    text = text.translate(mapping)
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    return " ".join(text.split())


def calculate_centroid(pts: list[list[float]]) -> list[float]:
    """2B poligon noktalarının ağırlık merkezini hesaplar (1 ondalık basamak)."""
    n = len(pts)
    if n == 0:
        return [0.0, 0.0]
    cx = sum(p[0] for p in pts) / n
    cz = sum(p[1] for p in pts) / n
    return [round(cx, 1), round(cz, 1)]


def assign_zone(pos: list[float], zones: list[dict]) -> str:
    """Verilen koordinatın düştüğü en yakın bölgenin id'sini bulur; bölge dışındaysa boş döner."""
    x, z = pos[0], pos[1]
    candidates = []
    for zone in zones:
        cx, cz = zone["center"][0], zone["center"][1]
        dist = math.hypot(x - cx, z - cz)
        if dist <= float(zone["radius"]):
            candidates.append((dist, zone["id"]))
    if not candidates:
        return ""
    candidates.sort(key=lambda item: item[0])
    return candidates[0][1]


# ---------------------------------------------------------------------------
# Elle belirlenen koordinatlar (MANUAL_PLACES)
# OSM'de adı bulunmayan, bağımsız bina kaydı olmayan veya açık alan niteliğindeki
# yerlerin koordinatları resmi kampüs haritası ve eski kroki referans alınarak
# aşağıda açıkça tanımlanmıştır.
# ---------------------------------------------------------------------------
MANUAL_PLACES: dict[str, dict] = {
    # 6: Kimya-Metalurji Fakültesi — OSM'de fakülte adı geçmez; FEF doğusundaki B, D, E blokları kompleksi
    "kimya_metalurji_fakultesi": {
        "pos": [240.0, -230.0],
        "reason": "OSM'de bağımsız Kimya-Metalurji Fakültesi adı yoktur. Haritada B, D, E blokları civarındaki komplekstir.",
    },
    # 7: İktisat ve İdari Bilimler Fakültesi — OSM'de adı yok; FEF kuzeydoğusundaki isimsiz bina çifti (Bldg 129, 130)
    "iktisat_ve_idari_bilimler_fakultesi": {
        "pos": [353.8, -183.8],
        "reason": "OSM'de İİBF bina kaydı yoktur. Haritada FEF'in kuzeydoğusundaki isimsiz bina çiftidir (Bldg 129, 130).",
    },
    # 8: Ring ve Otobüs Peronu — Bina değil; FEF güneyi ve Yıldız Cafe kuzeyindeki otobüs bekleme/hareket cebi
    "ring_ve_otobus_peronu": {
        "pos": [210.0, -95.0],
        "reason": "Resmi haritada 8 numaralı ring ve otobüs peronudur; açık alan ve yol cebidir.",
    },
    # 10: Kongre Merkezi — OSM'de 38 noktalı dairesel isimsiz modern yapıdır (Bldg 82)
    "kongre_merkezi": {
        "pos": [549.2, 305.7],
        "reason": "Resmi haritada 10 numaralı Kongre Merkezi; OSM'de 38 noktalı dairesel isimsiz yapıdır (Bldg 82).",
    },
    # 13: Teknopark — Kampüs güneyindeki A1-D2 blokları kümesinin merkezidir
    "teknopark": {
        "pos": [53.5, 660.5],
        "reason": "Resmi haritada 13 numaralı Teknopark; güneydeki A1-D2 blokları kümesinin merkezidir.",
    },
    # 17: Bilgelik Yolu — Taşbina güney kapısından YDYO'ya inen ağaçlı tören/yürüyüş yolu (OSM way 1437077332)
    "bilgelik_yolu": {
        "pos": [130.4, 300.3],
        "reason": "Taşbina güney kapısından YDYO'ya inen ağaçlı tören/yürüyüş yolu (OSM way 1437077332).",
    },
    # 18: YTÜ Stadyumu — OSM'de futbol sahası (way 521339557) isimsiz pitch geometrisi olarak kayıtlıdır (Area 0)
    "ytu_stadyumu": {
        "pos": [-285.5, 49.3],
        "reason": "OSM'de futbol stadyumu (way 521339557) isimsiz pitch alanı olarak kayıtlıdır (Area 0).",
    },
    # 19: Kulüpler Vadisi — Stadyumun hemen kuzeyindeki kulüp konteynerleri vadisi
    "kulupler_vadisi": {
        "pos": [-280.0, -20.0],
        "reason": "Resmi haritada 19 numaralı Kulüpler Vadisi; stadyumun hemen kuzeyindeki öğrenci kulüpleri konteyner alanıdır.",
    },
    # 20: Spor Kompleksi / Beden Eğitimi Bölümü — OSM'de 'Kapalı Yüzme Havuzu' adıyla geçen spor salonu (Bldg 95)
    "spor_kompleksi": {
        "pos": [-298.8, -213.6],
        "reason": "Resmi haritada 20 numaralı Spor Kompleksi; OSM'deki Kapalı Yüzme Havuzu spor kompleksidir (Bldg 95).",
    },
    # 21: Açık Oyun Sahaları — Açık tenis, basketbol ve halı saha spor alanları
    "acik_oyun_sahalari": {
        "pos": [-260.0, -115.0],
        "reason": "Resmi haritada 21 numaralı açık spor sahaları; tenis, basketbol ve halı sahaların bulunduğu alandır.",
    },
    # 22: Yıldız Store / Süpermarket — Yemekhane batı cephesine bitişik kampüs marketi yapısı (Bldg 40)
    "yildiz_store_supermarket": {
        "pos": [-127.8, -68.0],
        "reason": "Resmi haritada 22 numara; yemekhanenin batı bitişiğinde yer alan market yapısıdır (OSM Bldg 40).",
    },
    # 23: Şehide Türkan Türkmen Tekin Kız Öğrenci Yurdu — Yüksek katlı kız yurdu kulesi (OSM Bldg 37 Çağdaş Yaşam Yurdu)
    "sehide_turkan_turkmen_tekin_kiz_ogrenci_yurdu": {
        "pos": [-179.8, -197.8],
        "reason": "Resmi haritada 23 numaralı yüksek katlı kız yurdu kulesidir (OSM Bldg 37 Çağdaş Yaşam Yurdu).",
    },
    # 25: Mediko — Sağlık Merkezi; Eğitim Fakültesi batısındaki sağlık binasıdır (OSM Bldg 96)
    "mediko": {
        "pos": [-373.1, -315.7],
        "reason": "Resmi haritada 25 numaralı Sağlık Merkezi (Mediko); Eğitim Fakültesi batısındaki sağlık binasıdır (Bldg 96).",
    },
    # 26: Bilgi İşlem Merkezi — Mediko'nun hemen kuzeyindeki hizmet binasıdır (OSM Bldg 97)
    "bilgi_islem_merkezi": {
        "pos": [-374.7, -370.5],
        "reason": "Resmi haritada 26 numaralı Bilgi İşlem Daire Başkanlığı binasıdır (Bldg 97).",
    },
    # 27: YTÜ-KYK Erkek ve Kız Yurdu — Kampüsün kuzeybatısındaki çok bloklu KYK yurtları yerleşkesi
    "ytu_kyk_yurdu": {
        "pos": [-354.9, -474.6],
        "reason": "Resmi haritada 27 numaralı kampüsün kuzeybatısındaki çok bloklu KYK yurtları yerleşkesidir.",
    },
    # 28: Lojmanlar — Kuzeybatıdaki öğretim üyesi lojman bloklarının (J, K, L, C, F blokları) merkezidir
    "lojmanlar": {
        "pos": [-170.0, -450.0],
        "reason": "Resmi haritada 28 numaralı lojman yerleşkesi; OSM'deki J, K, L, C, F bloklarının merkezidir.",
    },
    # 29: Sanat ve Tasarım Fakültesi — Tarihi Taşbina'nın batı kanadı içerisindedir (bağımsız bina poligonu yoktur)
    "sanat_ve_tasarim_fakultesi": {
        "pos": [-100.0, 50.0],
        "reason": "Resmi haritada 29 numara; bağımsız bina olmayıp tarihi Taşbina'nın batı kanadında faaliyet göstermektedir.",
    },
    # 30: Sancak Köşkü — YDYO ile Kütüphane arasındaki koruluk içinde yer alan tarihi köşk
    "sancak_kosku": {
        "pos": [300.0, 350.0],
        "reason": "Resmi haritada 30 numaralı tarihi Sancak Köşkü; YDYO ile Kütüphane arasındaki koruluk içinde yer alır.",
    },
    # 32: Güvenlik Müdürlüğü — YDYO batısındaki güvenlik hizmet binası (OSM Bldg 137)
    "guvenlik_mudurlugu": {
        "pos": [95.4, 426.2],
        "reason": "Resmi haritada 32 numaralı Güvenlik Müdürlüğü hizmet binasıdır (OSM Bldg 137).",
    },
    # 33: Temiz Enerji Teknolojileri Enstitüsü — Çatısında güneş panelleri bulunan enstitü binası
    "temiz_enerji_enstitusu": {
        "pos": [10.0, 470.0],
        "reason": "Resmi haritada 33 numaralı çatısında fotovoltaik paneller bulunan Temiz Enerji Enstitüsü yapısıdır.",
    },
    # 34: Yıldız Teknopark Yönetim Binası — Hidrodinamik Lab güneyindeki idari bina (OSM Bldg 93)
    "yildiz_teknopark_yonetim_binasi": {
        "pos": [-140.9, 551.0],
        "reason": "Resmi haritada 34 numaralı Teknopark Yönetim Binası; Hidrodinamik Lab güneyindeki yapıdır (OSM Bldg 93).",
    },
    # 35: Innovation Hub — Teknopark güneybatısındaki kuluçka ve inovasyon merkezi
    "innovation_hub": {
        "pos": [-200.0, 530.0],
        "reason": "Resmi haritada 35 numaralı Teknopark Innovation Hub / kuluçka merkezidir.",
    },
    # 38: Cami — Davutpaşa Kampüs Camii; lojmanlar ve kuzey nizamiye kavşağındadır
    "cami": {
        "pos": [-70.0, -345.0],
        "reason": "Resmi haritada 38 numaralı Davutpaşa Kampüs Camii; lojmanlar ve kuzey kapısı kavşağındadır.",
    },
    # A Girişi — Kampüs ana doğu giriş kapısı (A Kapısı / 41AT otobüs durakları)
    "a_girisi": {
        "pos": [800.0, 575.0],
        "reason": "Kampüs ana doğu giriş kapısı (A Kapısı), 41AT peronu ve Esenler/Davutpaşa Caddesi bağlantısı.",
    },
    # B Girişi — Kampüs kuzey giriş kapısı (B Kapısı / metro bağlantı yolu)
    "b_girisi": {
        "pos": [-70.0, -470.0],
        "reason": "Kampüs kuzey giriş kapısı (B Kapısı), M1A metro istasyonuna açılan ana yaya ve araç kapısı.",
    },
    # Teknopark Girişi — Kampüs güneyindeki Teknopark nizamiye giriş kapısı
    "teknopark_girisi": {
        "pos": [15.0, 830.0],
        "reason": "Yıldız Teknopark güney nizamiye giriş kapısı.",
    },
    # M1A Davutpaşa-YTÜ metro durağı — Kampüs dışı viyadük istasyonu
    "m1a_davutpasa_ytu_metro": {
        "pos": [-40.0, -560.0],
        "reason": "Kampüs dışında, B girişine yakın viyadük üzerindeki M1A Yenikapı-Atatürk Havalimanı metro durağı.",
    },
}

# ---------------------------------------------------------------------------
# Tüm hedef yerler listesi (Resmi harita 1-38, kapılar/metro, eski kroki kafeleri)
# osm_query: OSM'de isim benzerliği araması yapılacak anahtar kelimeler/ifadeler
# ---------------------------------------------------------------------------
PLACE_SPECS: list[dict] = [
    # 1-38 Resmi Harita
    {
        "id": "tasbina",
        "name": "Taşbina / Rektörlük / İdari Bilimler / Enstitüler",
        "kind": "landmark",
        "osm_query": "Yıldız Teknik Üniversitesi Davutpaşa Kışlası",
    },
    {
        "id": "ortabahce",
        "name": "Ortabahçe",
        "kind": "landmark",
        "osm_query": "Ortabahçe",
    },
    {
        "id": "yemekhane",
        "name": "Yemekhane",
        "kind": "food",
        "osm_query": "Yemekhane",
    },
    {
        "id": "elektrik_elektronik_fakultesi",
        "name": "Elektrik-Elektronik Fakültesi",
        "kind": "faculty",
        "osm_query": "Elektrik Elektronik Fakültesi",
    },
    {
        "id": "fen_edebiyat_fakultesi",
        "name": "Fen-Edebiyat Fakültesi",
        "kind": "faculty",
        "osm_query": "Fen Edebiyat Fakültesi",
    },
    {
        "id": "kimya_metalurji_fakultesi",
        "name": "Kimya-Metalurji Fakültesi",
        "kind": "faculty",
        "osm_query": "Kimya Metalurji",
    },
    {
        "id": "iktisat_ve_idari_bilimler_fakultesi",
        "name": "İktisat ve İdari Bilimler Fakültesi",
        "kind": "faculty",
        "osm_query": "İktisat",
    },
    {
        "id": "ring_ve_otobus_peronu",
        "name": "Ring ve Otobüs Peronu",
        "kind": "transport",
        "osm_query": "Ring Otobüs Peron",
    },
    {
        "id": "otag_i_humayun",
        "name": "Otağ-ı Hümayun",
        "kind": "landmark",
        "osm_query": "Otağ-ı Hümayun",
    },
    {
        "id": "kongre_merkezi",
        "name": "Kongre Merkezi",
        "kind": "service",
        "osm_query": "Kongre Merkezi",
    },
    {
        "id": "kutuphane",
        "name": "Kütüphane",
        "kind": "service",
        "osm_query": "İlhan Varank Kütüphanesi",
    },
    {
        "id": "yabanci_diller_yuksekokulu",
        "name": "Yabancı Diller Yüksekokulu",
        "kind": "faculty",
        "osm_query": "Yabancı Diller Yüksekokulu",
    },
    {
        "id": "teknopark",
        "name": "Teknopark",
        "kind": "service",
        "osm_query": "Yıldız Teknopark",
    },
    {
        "id": "merkez_laboratuvari",
        "name": "Merkez Laboratuvarı",
        "kind": "service",
        "osm_query": "Merkez Laboratuvarı",
    },
    {
        "id": "hidrodinamik_laboratuvari",
        "name": "Hidrodinamik Laboratuvarı",
        "kind": "service",
        "osm_query": "Hidrolik Laboratuarı",
    },
    {
        "id": "insaat_fakultesi",
        "name": "İnşaat Fakültesi",
        "kind": "faculty",
        "osm_query": "İnşaat Mühendisliği",
    },
    {
        "id": "bilgelik_yolu",
        "name": "Bilgelik Yolu",
        "kind": "landmark",
        "osm_query": "Bilgelik Yolu",
    },
    {
        "id": "ytu_stadyumu",
        "name": "YTÜ Stadyumu",
        "kind": "sport",
        "osm_query": "Stadyum",
    },
    {
        "id": "kulupler_vadisi",
        "name": "Kulüpler Vadisi",
        "kind": "sport",
        "osm_query": "Kulüpler Vadisi",
    },
    {
        "id": "spor_kompleksi",
        "name": "Spor Kompleksi / Beden Eğitimi Bölümü",
        "kind": "sport",
        "osm_query": "Spor Kompleksi",
    },
    {
        "id": "acik_oyun_sahalari",
        "name": "Açık Oyun Sahaları",
        "kind": "sport",
        "osm_query": "Açık Oyun Sahaları",
    },
    {
        "id": "yildiz_store_supermarket",
        "name": "Yıldız Store / Süpermarket",
        "kind": "service",
        "osm_query": "Süpermarket",
    },
    {
        "id": "sehide_turkan_turkmen_tekin_kiz_ogrenci_yurdu",
        "name": "Şehide Türkan Türkmen Tekin Kız Öğrenci Yurdu",
        "kind": "dorm",
        "osm_query": "Türkan Türkmen Tekin",
    },
    {
        "id": "egitim_fakultesi",
        "name": "Eğitim Fakültesi",
        "kind": "faculty",
        "osm_query": "Eğitim Fakültesi",
    },
    {
        "id": "mediko",
        "name": "Mediko",
        "kind": "service",
        "osm_query": "Mediko",
    },
    {
        "id": "bilgi_islem_merkezi",
        "name": "Bilgi İşlem Merkezi",
        "kind": "service",
        "osm_query": "Bilgi İşlem",
    },
    {
        "id": "ytu_kyk_yurdu",
        "name": "YTÜ-KYK Erkek ve Kız Yurdu",
        "kind": "dorm",
        "osm_query": "KYK Yurdu",
    },
    {
        "id": "lojmanlar",
        "name": "Lojmanlar",
        "kind": "dorm",
        "osm_query": "Lojmanlar",
    },
    {
        "id": "sanat_ve_tasarim_fakultesi",
        "name": "Sanat ve Tasarım Fakültesi",
        "kind": "faculty",
        "osm_query": "Sanat ve Tasarım",
    },
    {
        "id": "sancak_kosku",
        "name": "Sancak Köşkü",
        "kind": "landmark",
        "osm_query": "Sancak Köşkü",
    },
    {
        "id": "yeni_kutuphane",
        "name": "Yeni Kütüphane",
        "kind": "service",
        "osm_query": "Merkez Kütüphanesi",
    },
    {
        "id": "guvenlik_mudurlugu",
        "name": "Güvenlik Müdürlüğü",
        "kind": "service",
        "osm_query": "Güvenlik Müdürlüğü",
    },
    {
        "id": "temiz_enerji_enstitusu",
        "name": "Temiz Enerji Teknolojileri Enstitüsü",
        "kind": "service",
        "osm_query": "Temiz Enerji",
    },
    {
        "id": "yildiz_teknopark_yonetim_binasi",
        "name": "Yıldız Teknopark Yönetim Binası",
        "kind": "service",
        "osm_query": "Teknopark Yönetim",
    },
    {
        "id": "innovation_hub",
        "name": "Innovation Hub",
        "kind": "service",
        "osm_query": "Innovation Hub",
    },
    {
        "id": "academic_lounge",
        "name": "Academic Lounge",
        "kind": "food",
        "osm_query": "Academic Lounge",
    },
    {
        "id": "misafirhane",
        "name": "Misafirhane",
        "kind": "service",
        "osm_query": "Misafirhane",
    },
    {
        "id": "cami",
        "name": "Cami",
        "kind": "landmark",
        "osm_query": "Cami",
    },
    # Kapılar ve Metro
    {
        "id": "a_girisi",
        "name": "A Girişi",
        "kind": "gate",
        "osm_query": "A Girişi",
    },
    {
        "id": "b_girisi",
        "name": "B Girişi",
        "kind": "gate",
        "osm_query": "B Girişi",
    },
    {
        "id": "teknopark_girisi",
        "name": "Teknopark Girişi",
        "kind": "gate",
        "osm_query": "Teknopark Girişi",
    },
    {
        "id": "m1a_davutpasa_ytu_metro",
        "name": "M1A Davutpaşa-YTÜ metro durağı",
        "kind": "transport",
        "osm_query": "Davutpaşa Metro",
    },
    # Eski Krokideki Kafeler
    {
        "id": "hokka",
        "name": "Hokka",
        "kind": "food",
        "osm_query": "Hokka",
    },
    {
        "id": "kayinti_kafe",
        "name": "Kayıntı Kafe",
        "kind": "food",
        "osm_query": "KAYINTI KAFE",
    },
    {
        "id": "buyuk_ev",
        "name": "Büyük Ev",
        "kind": "food",
        "osm_query": "BÜYÜK EV",
    },
    {
        "id": "eskafe",
        "name": "Eskafe",
        "kind": "food",
        "osm_query": "Eskafe",
    },
    {
        "id": "yildiz_cafe",
        "name": "YILDIZ CAFE",
        "kind": "food",
        "osm_query": "YILDIZ CAFE",
    },
]


def match_osm(query: str, osm_entities: list[dict]) -> tuple[dict | None, float]:
    """OSM varlıkları arasında en iyi isim benzerliğini bulur.
    
    Normalleştirilmiş tam eşleşme, alt küme belirleme ve token örtüşmesi kullanır.
    """
    q_norm = normalize_text(query)
    q_tokens = set(q_norm.split())

    best_entity = None
    best_score = 0.0

    for entity in osm_entities:
        e_norm = entity["norm_name"]
        e_tokens = set(e_norm.split())

        if q_norm == e_norm:
            score = 1.0
        elif q_tokens.issubset(e_tokens):
            # Sorgudaki tüm tokenlar OSM adında mevcut (ör. "merkez laboratuvari" in "ytu merkez laboratuvari")
            score = 0.90 + 0.09 * (len(q_tokens) / max(len(e_tokens), 1))
        elif e_tokens.issubset(q_tokens):
            # OSM adı sorgunun bir alt kümesi
            score = 0.70 + 0.10 * (len(e_tokens) / max(len(q_tokens), 1))
        else:
            common = q_tokens.intersection(e_tokens)
            if common:
                score = 0.50 * (2.0 * len(common) / (len(q_tokens) + len(e_tokens)))
            else:
                score = 0.0

        if score > best_score:
            best_score = score
            best_entity = entity

    return (best_entity, best_score)


def build_places() -> dict:
    campus = json.loads(CAMPUS_JSON.read_text(encoding="utf-8"))
    zones_data = json.loads(ZONES_JSON.read_text(encoding="utf-8"))["zones"]

    # Adlandırılmış OSM varlıklarını (binalar ve alanlar) topla
    osm_entities = []
    for b in campus.get("buildings", []):
        name = b.get("name")
        if name:
            osm_entities.append({
                "osm_name": name,
                "norm_name": normalize_text(name),
                "pos": calculate_centroid(b.get("points", [])),
            })
    for a in campus.get("areas", []):
        name = a.get("name")
        if name:
            osm_entities.append({
                "osm_name": name,
                "norm_name": normalize_text(name),
                "pos": calculate_centroid(a.get("points", [])),
            })

    places_list = []

    for spec in PLACE_SPECS:
        pid = spec["id"]
        pname = spec["name"]
        pkind = spec["kind"]

        if pkind not in ALLOWED_KINDS:
            raise ValueError(f"Geçersiz kind '{pkind}' for place '{pid}'")

        # 1. Öncelikle elle tanımlanmış koordinat kontrolü
        if pid in MANUAL_PLACES:
            manual_entry = MANUAL_PLACES[pid]
            pos = manual_entry["pos"]
            zone = assign_zone(pos, zones_data)
            places_list.append({
                "id": pid,
                "name": pname,
                "kind": pkind,
                "pos": pos,
                "zone": zone,
                "source": "manual",
            })
            continue

        # 2. OSM isim benzerliği eşleştirmesi
        query = spec.get("osm_query", pname)
        matched_entity, score = match_osm(query, osm_entities)

        if matched_entity is not None and score >= 0.6:
            pos = matched_entity["pos"]
            zone = assign_zone(pos, zones_data)
            places_list.append({
                "id": pid,
                "name": pname,
                "kind": pkind,
                "pos": pos,
                "zone": zone,
                "source": "osm",
                "osm_name": matched_entity["osm_name"],
            })
        else:
            raise RuntimeError(f"Yer eşleştirilemedi ve manuel koordinatı yok: {pid} ({pname})")

    return {"places": places_list}


def main() -> None:
    data = build_places()
    # Deterministik formatlama: 2 boşluk girinti, ensure_ascii=False
    formatted_json = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    OUTPUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_JSON.write_text(formatted_json, encoding="utf-8")
    print(f"Başarıyla üretildi: {OUTPUT_JSON} ({len(data['places'])} yer)")


if __name__ == "__main__":
    main()
