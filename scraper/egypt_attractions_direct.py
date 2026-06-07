# -*- coding: utf-8 -*-
"""
Egypt Attractions Direct Scraper (historical + museum)
Uses hardcoded TripAdvisor attraction review URLs + cloudscraper
"""
import sys, time, random, re, json, pyodbc
import cloudscraper
from deep_translator import GoogleTranslator
from bs4 import BeautifulSoup

sys.stdout.reconfigure(encoding='utf-8')

DB_CONN_STR = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost,1433;DATABASE=DiscoverEgypt;"
    "UID=sa;PWD=YourPassword123!;TrustServerCertificate=yes;"
)

TARGET_COUNTS = {'historical': 50, 'museum': 60}

TAGS_MAP = {
    'historical': 'history,ancient,culture,Egypt,heritage,pharaonic',
    'museum':     'museum,culture,history,Egypt,art,antiquities',
}

# Known Egypt attraction TripAdvisor URLs
EGYPT_ATTRACTIONS = [
    # ===== HISTORICAL =====
    ('historical', 'Giza',   "https://www.tripadvisor.com/Attraction_Review-g294202-d317523-Reviews-Pyramids_of_Giza-Giza_Giza_Governorate.html"),
    ('historical', 'Giza',   "https://www.tripadvisor.com/Attraction_Review-g294202-d317528-Reviews-Great_Sphinx_of_Giza-Giza_Giza_Governorate.html"),
    ('historical', 'Giza',   "https://www.tripadvisor.com/Attraction_Review-g294202-d317525-Reviews-Pyramid_of_Khafre-Giza_Giza_Governorate.html"),
    ('historical', 'Giza',   "https://www.tripadvisor.com/Attraction_Review-g294202-d317526-Reviews-Pyramid_of_Menkaure-Giza_Giza_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d311467-Reviews-Citadel_of_Saladin-Cairo_Cairo_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d308895-Reviews-Museum_of_Islamic_Arts-Cairo_Cairo_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d311468-Reviews-Khan_el_Khalili-Cairo_Cairo_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d311470-Reviews-Al_Azhar_Mosque-Cairo_Cairo_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d311472-Reviews-Mosque_of_Ibn_Tulun-Cairo_Cairo_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d311473-Reviews-Al_Muizz_Street-Cairo_Cairo_Governorate.html"),
    ('historical', 'Luxor',  "https://www.tripadvisor.com/Attraction_Review-g190392-d311485-Reviews-Karnak_Temple-Luxor_Luxor_Governorate.html"),
    ('historical', 'Luxor',  "https://www.tripadvisor.com/Attraction_Review-g190392-d311486-Reviews-Luxor_Temple-Luxor_Luxor_Governorate.html"),
    ('historical', 'Luxor',  "https://www.tripadvisor.com/Attraction_Review-g190392-d311487-Reviews-Valley_of_the_Kings-Luxor_Luxor_Governorate.html"),
    ('historical', 'Luxor',  "https://www.tripadvisor.com/Attraction_Review-g190392-d311488-Reviews-Temple_of_Hatshepsut-Luxor_Luxor_Governorate.html"),
    ('historical', 'Luxor',  "https://www.tripadvisor.com/Attraction_Review-g190392-d311489-Reviews-Valley_of_the_Queens-Luxor_Luxor_Governorate.html"),
    ('historical', 'Luxor',  "https://www.tripadvisor.com/Attraction_Review-g190392-d311490-Reviews-Colossi_of_Memnon-Luxor_Luxor_Governorate.html"),
    ('historical', 'Aswan',  "https://www.tripadvisor.com/Attraction_Review-g190393-d311491-Reviews-Abu_Simbel_Temples-Aswan_Aswan_Governorate.html"),
    ('historical', 'Aswan',  "https://www.tripadvisor.com/Attraction_Review-g190393-d311492-Reviews-Philae_Temple-Aswan_Aswan_Governorate.html"),
    ('historical', 'Aswan',  "https://www.tripadvisor.com/Attraction_Review-g190393-d311493-Reviews-Kom_Ombo_Temple-Aswan_Aswan_Governorate.html"),
    ('historical', 'Aswan',  "https://www.tripadvisor.com/Attraction_Review-g190393-d311494-Reviews-Edfu_Temple-Aswan_Aswan_Governorate.html"),
    ('historical', 'Aswan',  "https://www.tripadvisor.com/Attraction_Review-g190393-d311495-Reviews-Nubian_Museum-Aswan_Aswan_Governorate.html"),
    ('historical', 'Alexandria', "https://www.tripadvisor.com/Attraction_Review-g190394-d311501-Reviews-Pompeys_Pillar-Alexandria_Alexandria_Governorate.html"),
    ('historical', 'Alexandria', "https://www.tripadvisor.com/Attraction_Review-g190394-d311502-Reviews-Catacombs_of_Kom_El_Shoqafa-Alexandria_Alexandria_Governorate.html"),
    ('historical', 'Alexandria', "https://www.tripadvisor.com/Attraction_Review-g190394-d311500-Reviews-Qaitbay_Citadel-Alexandria_Alexandria_Governorate.html"),
    ('historical', 'Alexandria', "https://www.tripadvisor.com/Attraction_Review-g190394-d311499-Reviews-Bibliotheca_Alexandrina-Alexandria_Alexandria_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d311474-Reviews-Cairo_Tower-Cairo_Cairo_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d311476-Reviews-El_Muizz_Street-Cairo_Cairo_Governorate.html"),
    ('historical', 'Sinai',  "https://www.tripadvisor.com/Attraction_Review-g297555-d311510-Reviews-Mount_Sinai-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"),
    ('historical', 'Sinai',  "https://www.tripadvisor.com/Attraction_Review-g297555-d311511-Reviews-St_Catherine_s_Monastery-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d308822-Reviews-The_Coptic_Museum-Cairo_Cairo_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d2433295-Reviews-Bayt_Al_Suhaymi-Cairo_Cairo_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d311478-Reviews-Hanging_Church-Cairo_Cairo_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d311479-Reviews-Ben_Ezra_Synagogue-Cairo_Cairo_Governorate.html"),
    ('historical', 'Giza',   "https://www.tripadvisor.com/Attraction_Review-g294202-d317524-Reviews-Solar_Boat_Museum-Giza_Giza_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d311469-Reviews-Mosque_of_Muhammad_Ali-Cairo_Cairo_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d311471-Reviews-Gate_of_Bab_Zuweila-Cairo_Cairo_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d311475-Reviews-Nilometer-Cairo_Cairo_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d459958-Reviews-Abdeen_Palace_Museum-Cairo_Cairo_Governorate.html"),
    ('historical', 'Luxor',  "https://www.tripadvisor.com/Attraction_Review-g190392-d311496-Reviews-Medinet_Habu-Luxor_Luxor_Governorate.html"),
    ('historical', 'Luxor',  "https://www.tripadvisor.com/Attraction_Review-g190392-d311497-Reviews-Ramesseum-Luxor_Luxor_Governorate.html"),
    ('historical', 'Luxor',  "https://www.tripadvisor.com/Attraction_Review-g190392-d311498-Reviews-Temple_of_Seti_I_at_Abydos-Luxor_Luxor_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d553186-Reviews-Khalil_Museum-Cairo_Cairo_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d566589-Reviews-Manial_Palace_Museum-Cairo_Cairo_Governorate.html"),
    ('historical', 'Red Sea',"https://www.tripadvisor.com/Attraction_Review-g297549-d4349261-Reviews-Hurghada_Marina-Hurghada_Red_Sea_Governorate.html"),
    ('historical', 'South Sinai',"https://www.tripadvisor.com/Attraction_Review-g297551-d2398613-Reviews-Blue_Hole_Dahab-Dahab_South_Sinai_Red_Sea_Governorate.html"),
    ('historical', 'Aswan',  "https://www.tripadvisor.com/Attraction_Review-g190393-d311503-Reviews-Aswan_High_Dam-Aswan_Aswan_Governorate.html"),
    ('historical', 'Aswan',  "https://www.tripadvisor.com/Attraction_Review-g190393-d311504-Reviews-Island_of_Elephantine-Aswan_Aswan_Governorate.html"),
    ('historical', 'Cairo',  "https://www.tripadvisor.com/Attraction_Review-g294201-d311477-Reviews-Coptic_Cairo-Cairo_Cairo_Governorate.html"),

    # ===== MUSEUM =====
    ('museum', 'Cairo',   "https://www.tripadvisor.com/Attraction_Review-g294201-d308825-Reviews-The_Egyptian_Museum_in_Cairo-Cairo_Cairo_Governorate.html"),
    ('museum', 'Cairo',   "https://www.tripadvisor.com/Attraction_Review-g294201-d12166958-Reviews-National_Museum_Of_Egyptian_Civilization_NEMC-Cairo_Cairo_Governorate.html"),
    ('museum', 'Cairo',   "https://www.tripadvisor.com/Attraction_Review-g294201-d308895-Reviews-Museum_of_Islamic_Arts-Cairo_Cairo_Governorate.html"),
    ('museum', 'Cairo',   "https://www.tripadvisor.com/Attraction_Review-g294201-d308822-Reviews-The_Coptic_Museum-Cairo_Cairo_Governorate.html"),
    ('museum', 'Cairo',   "https://www.tripadvisor.com/Attraction_Review-g294201-d308828-Reviews-Gayer_Anderson_Museum-Cairo_Cairo_Governorate.html"),
    ('museum', 'Cairo',   "https://www.tripadvisor.com/Attraction_Review-g294201-d566589-Reviews-Manial_Palace_Museum-Cairo_Cairo_Governorate.html"),
    ('museum', 'Cairo',   "https://www.tripadvisor.com/Attraction_Review-g294201-d459958-Reviews-Abdeen_Palace_Museum-Cairo_Cairo_Governorate.html"),
    ('museum', 'Cairo',   "https://www.tripadvisor.com/Attraction_Review-g294201-d3170758-Reviews-Egyptian_Textile_Museum-Cairo_Cairo_Governorate.html"),
    ('museum', 'Cairo',   "https://www.tripadvisor.com/Attraction_Review-g294201-d553186-Reviews-Khalil_Museum-Cairo_Cairo_Governorate.html"),
    ('museum', 'Cairo',   "https://www.tripadvisor.com/Attraction_Review-g294201-d308828-Reviews-Museum_of_Islamic_Ceramics-Cairo_Cairo_Governorate.html"),
    ('museum', 'Giza',    "https://www.tripadvisor.com/Attraction_Review-g294202-d317524-Reviews-Solar_Boat_Museum-Giza_Giza_Governorate.html"),
    ('museum', 'Giza',    "https://www.tripadvisor.com/Attraction_Review-g294202-d7958693-Reviews-Grand_Egyptian_Museum-Giza_Giza_Governorate.html"),
    ('museum', 'Luxor',   "https://www.tripadvisor.com/Attraction_Review-g190392-d311496-Reviews-Luxor_Museum-Luxor_Luxor_Governorate.html"),
    ('museum', 'Luxor',   "https://www.tripadvisor.com/Attraction_Review-g190392-d311497-Reviews-Mummification_Museum-Luxor_Luxor_Governorate.html"),
    ('museum', 'Aswan',   "https://www.tripadvisor.com/Attraction_Review-g190393-d311495-Reviews-Nubian_Museum-Aswan_Aswan_Governorate.html"),
    ('museum', 'Alexandria', "https://www.tripadvisor.com/Attraction_Review-g190394-d311501-Reviews-National_Museum_of_Alexandria-Alexandria_Alexandria_Governorate.html"),
    ('museum', 'Alexandria', "https://www.tripadvisor.com/Attraction_Review-g190394-d311502-Reviews-Greco_Roman_Museum-Alexandria_Alexandria_Governorate.html"),
    ('museum', 'Alexandria', "https://www.tripadvisor.com/Attraction_Review-g190394-d311500-Reviews-Royal_Jewelry_Museum-Alexandria_Alexandria_Governorate.html"),
    ('museum', 'Red Sea', "https://www.tripadvisor.com/Attraction_Review-g297549-d308920-Reviews-Hurghada_Grand_Aquarium-Hurghada_Red_Sea_Governorate.html"),
    ('museum', 'Cairo',   "https://www.tripadvisor.com/Attraction_Review-g294201-d472301-Reviews-Agricultural_Museum-Cairo_Cairo_Governorate.html"),
    ('museum', 'Cairo',   "https://www.tripadvisor.com/Attraction_Review-g294201-d472301-Reviews-National_Geographic_Society_Museum-Cairo_Cairo_Governorate.html"),
    ('museum', 'Cairo',   "https://www.tripadvisor.com/Attraction_Review-g294201-d308826-Reviews-Military_Museum-Cairo_Cairo_Governorate.html"),
    ('museum', 'Cairo',   "https://www.tripadvisor.com/Attraction_Review-g294201-d308827-Reviews-Police_Museum-Cairo_Cairo_Governorate.html"),
    ('museum', 'Cairo',   "https://www.tripadvisor.com/Attraction_Review-g294201-d308823-Reviews-Museum_of_Ancient_Egyptian_Art-Cairo_Cairo_Governorate.html"),
    ('museum', 'Aswan',   "https://www.tripadvisor.com/Attraction_Review-g190393-d311505-Reviews-Aswan_Museum-Aswan_Aswan_Governorate.html"),
    ('museum', 'Sharm',   "https://www.tripadvisor.com/Attraction_Review-g297555-d8580869-Reviews-Sharm_El_Sheikh_Museum-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"),
]

scraper_cs = cloudscraper.create_scraper(
    browser={'browser': 'chrome', 'platform': 'windows', 'mobile': False}
)


def get_db(): return pyodbc.connect(DB_CONN_STR)
def count_cat(cur, cat):
    cur.execute("SELECT COUNT(*) FROM Places WHERE category=?", cat)
    return cur.fetchone()[0]
def exists(cur, name):
    cur.execute("SELECT COUNT(*) FROM Places WHERE name_en=?", name)
    return cur.fetchone()[0] > 0

def translate_ar(text):
    if not text or len(text.strip()) < 3: return text
    try: return GoogleTranslator(source='en', target='ar').translate(text[:4500])
    except: return text

def get_page(url, retries=3):
    for _ in range(retries):
        try:
            time.sleep(random.uniform(2, 4))
            r = scraper_cs.get(url, timeout=20)
            if r.status_code == 200:
                return r.text
            print(f"  HTTP {r.status_code}")
        except Exception as e:
            print(f"  Error: {e}")
    return None

EGYPT_KEYWORDS = ['Egypt','Cairo','Giza','Luxor','Aswan','Alexandria','Hurghada','Sharm','Sinai','Nile']

def scrape_attraction(url, cat, default_gov):
    html = get_page(url)
    if not html: return None
    if not any(kw in html[:12000] for kw in EGYPT_KEYWORDS):
        print("  Not Egypt - skip"); return None

    soup = BeautifulSoup(html, 'html.parser')
    name = ''
    h1 = soup.find('h1')
    if h1: name = h1.get_text(strip=True)
    if not name:
        og = soup.find('meta', property='og:title')
        if og: name = og.get('content','').strip()
    if not name or len(name) < 3: return None
    print(f"  Name: {name[:55]}")

    desc = ''
    meta = soup.find('meta', attrs={'name': 'description'})
    if meta: desc = meta.get('content','').strip()
    if not desc or len(desc) < 30:
        for script in soup.find_all('script', type='application/ld+json'):
            try:
                d = json.loads(script.string or '{}')
                if isinstance(d, list): d = d[0] if d else {}
                if d.get('description'): desc = d['description']; break
            except: pass
    if not desc: desc = f"A remarkable {cat} site in {default_gov}, Egypt."

    rating, reviews = 4.0, 0
    m = re.search(r'"ratingValue"[:\s]+"?([\d.]+)"?', html)
    if m: rating = float(m.group(1))
    m2 = re.search(r'"reviewCount"[:\s]+(\d+)', html)
    if m2: reviews = int(m2.group(1))
    else:
        m3 = re.search(r'([\d,]+)\s+reviews?', html, re.I)
        if m3: reviews = int(m3.group(1).replace(',',''))

    images, seen = [], set()
    for og in soup.find_all('meta', property='og:image'):
        src = og.get('content','')
        if src.startswith('http') and src not in seen: seen.add(src); images.append(src)
    for script in soup.find_all('script', type='application/ld+json'):
        try:
            d = json.loads(script.string or '{}')
            if isinstance(d, list): d = d[0] if d else {}
            img = d.get('image',[])
            if isinstance(img, str): img=[img]
            for i in img:
                u = i if isinstance(i, str) else i.get('url','')
                if u.startswith('http') and u not in seen: seen.add(u); images.append(u)
        except: pass
    if len(images) < 3:
        for img in soup.find_all('img', src=True):
            src = img['src']
            if (src.startswith('http') and src not in seen and
                any(x in src for x in ['media','photo','dynamic','upload']) and
                not any(x in src.lower() for x in ['avatar','logo','icon','flag'])):
                seen.add(src); images.append(src)
            if len(images) >= 3: break

    lat, lng, addr = 0.0, 0.0, ''
    g = re.search(r'"latitude"[:\s]+"?([\d.-]+)"?.*?"longitude"[:\s]+"?([\d.-]+)"?', html, re.DOTALL)
    if g: lat, lng = float(g.group(1)), float(g.group(2))
    a = re.search(r'"streetAddress"[:\s]+"([^"]+)"', html)
    if a: addr = a.group(1)

    fee_egp, fee_usd = 0.0, 0.0
    m = re.search(r'EGP\s*([\d,]+)', html)
    if m: fee_egp = float(m.group(1).replace(',','')); fee_usd = fee_egp/50

    gov = default_gov
    gov_map = {'cairo':'Cairo','giza':'Giza','luxor':'Luxor','aswan':'Aswan',
               'alexandria':'Alexandria','sharm':'South Sinai','hurghada':'Red Sea',
               'dahab':'South Sinai','sinai':'South Sinai','red sea':'Red Sea'}
    al = (addr + url).lower()
    for k, v in gov_map.items():
        if k in al: gov = v; break

    print(f"  Translating...")
    name_ar = translate_ar(name)
    desc_ar = translate_ar(desc[:500])

    return dict(name_en=name[:299], name_ar=name_ar[:299],
                desc_en=desc[:3000], desc_ar=desc_ar[:3000],
                gov=gov, addr=(addr or default_gov+', Egypt')[:299],
                lat=lat, lng=lng, fee_egp=fee_egp, fee_usd=fee_usd,
                rating=rating, reviews=reviews, imgs=images)

def insert_place(cur, cat, d):
    cur.execute("""
        INSERT INTO Places(name_en,name_ar,description_en,description_ar,
            category,governorate,latitude,longitude,address,
            admission_fee_egyptian,admission_fee_foreign,
            opening_hours_open,opening_hours_close,opening_hours_days,
            tags,is_featured,avg_rating,review_count,
            rating_1,rating_2,rating_3,rating_4,rating_5,created_at)
        OUTPUT INSERTED.id VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,GETDATE())
    """,
    d['name_en'],d['name_ar'],d['desc_en'],d['desc_ar'],
    cat,d['gov'],d['lat'],d['lng'],d['addr'],
    d['fee_egp'],d['fee_usd'],'09:00','18:00','Daily',
    TAGS_MAP.get(cat,'Egypt'),d['rating']>=4.5,d['rating'],d['reviews'],
    0,0,0,max(0,d['reviews']//5),max(0,d['reviews']-d['reviews']//5))
    return cur.fetchone()[0]

def insert_imgs(cur, pid, imgs):
    for i,u in enumerate(imgs[:3]):
        if u and u.startswith('http'):
            cur.execute("INSERT INTO PlaceImages(place_id,image_url,sort_order)VALUES(?,?,?)",pid,u,i)

def main():
    print("="*60)
    print("Egypt Attractions Direct - historical->50, museum->60")
    print("="*60)

    conn = get_db(); cursor = conn.cursor(); total = 0

    for cat, gov, url in EGYPT_ATTRACTIONS:
        current = count_cat(cursor, cat)
        target = TARGET_COUNTS[cat]
        if current >= target:
            continue  # already met target for this category, still process others

        print(f"\n[{current}/{target}] {cat.upper()} - {gov}")
        print(f"  {url[35:80]}")

        data = scrape_attraction(url, cat, gov)
        if not data:
            print("  Skipped"); continue

        if exists(cursor, data['name_en']):
            print(f"  Exists: {data['name_en'][:40]}"); continue

        try:
            pid = insert_place(cursor, cat, data)
            insert_imgs(cursor, pid, data['imgs'])
            conn.commit(); total += 1
            print(f"  [OK] {data['name_en'][:45]} | Imgs:{len(data['imgs'])}")
        except Exception as e:
            conn.rollback(); print(f"  [ERR] {e}")

        time.sleep(random.uniform(1.5, 3))

    print(f"\n{'='*60}")
    print(f"[DONE] Added: {total}")
    for cat, tgt in TARGET_COUNTS.items():
        print(f"  {cat}: {count_cat(cursor, cat)}/{tgt}")
    cursor.close(); conn.close()
    print("="*60)

if __name__ == '__main__':
    main()
