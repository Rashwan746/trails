# -*- coding: utf-8 -*-
"""
Wikipedia API Scraper for Egypt Places
Uses Wikipedia API for descriptions + Wikipedia Commons for images
No IP blocking, open API, real Egypt data
"""
import sys, time, random, re, json, pyodbc, requests
from deep_translator import GoogleTranslator
from urllib.parse import quote

sys.stdout.reconfigure(encoding='utf-8')

DB_CONN_STR = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost,1433;DATABASE=DiscoverEgypt;"
    "UID=sa;PWD=YourPassword123!;TrustServerCertificate=yes;"
)

TARGET_COUNTS = {'historical': 50, 'museum': 60, 'hotel': 50}

WIKI_API = "https://en.wikipedia.org/w/api.php"
COMMONS_API = "https://commons.wikimedia.org/w/api.php"

HEADERS = {
    'User-Agent': 'DiscoverEgyptApp/1.0 (educational project; contact@discover-egypt.com)',
    'Accept': 'application/json',
}

TAGS_MAP = {
    'historical': 'history,ancient,culture,Egypt,heritage,pharaonic',
    'museum':     'museum,culture,history,Egypt,art,antiquities',
    'hotel':      'accommodation,stay,hotel,Egypt,luxury',
}

# Egypt places to look up on Wikipedia
EGYPT_PLACES = [
    # ===== HISTORICAL (target 50) =====
    ('historical', 'Giza',       'Pyramids of Giza'),
    ('historical', 'Giza',       'Great Sphinx of Giza'),
    ('historical', 'Giza',       'Pyramid of Khufu'),
    ('historical', 'Giza',       'Pyramid of Khafre'),
    ('historical', 'Giza',       'Pyramid of Menkaure'),
    ('historical', 'Cairo',      'Cairo Citadel'),
    ('historical', 'Cairo',      'Khan el-Khalili'),
    ('historical', 'Cairo',      'Al-Azhar Mosque'),
    ('historical', 'Cairo',      'Mosque of Ibn Tulun'),
    ('historical', 'Cairo',      'Al-Muizz Street'),
    ('historical', 'Cairo',      'Hanging Church Cairo'),
    ('historical', 'Cairo',      'Ben Ezra Synagogue'),
    ('historical', 'Cairo',      'Coptic Cairo'),
    ('historical', 'Cairo',      'Mosque of Muhammad Ali Pasha'),
    ('historical', 'Cairo',      'Bab Zuweila'),
    ('historical', 'Cairo',      'Nilometer'),
    ('historical', 'Cairo',      'Abdeen Palace'),
    ('historical', 'Cairo',      'Manial Palace'),
    ('historical', 'Luxor',      'Karnak'),
    ('historical', 'Luxor',      'Luxor Temple'),
    ('historical', 'Luxor',      'Valley of the Kings'),
    ('historical', 'Luxor',      'Mortuary Temple of Hatshepsut'),
    ('historical', 'Luxor',      'Valley of the Queens'),
    ('historical', 'Luxor',      'Colossi of Memnon'),
    ('historical', 'Luxor',      'Medinet Habu'),
    ('historical', 'Luxor',      'Ramesseum'),
    ('historical', 'Luxor',      'Temple of Seti I at Abydos'),
    ('historical', 'Aswan',      'Abu Simbel temples'),
    ('historical', 'Aswan',      'Philae temple'),
    ('historical', 'Aswan',      'Kom Ombo'),
    ('historical', 'Aswan',      'Edfu'),
    ('historical', 'Aswan',      'Aswan Dam'),
    ('historical', 'Aswan',      'Elephantine'),
    ('historical', 'Alexandria', "Pompey's Pillar"),
    ('historical', 'Alexandria', 'Catacombs of Kom el Shoqafa'),
    ('historical', 'Alexandria', 'Citadel of Qaitbay'),
    ('historical', 'Alexandria', 'Bibliotheca Alexandrina'),
    ('historical', 'Sinai',      'Mount Sinai'),
    ("historical", 'Sinai',      "Saint Catherine's Monastery"),
    ('historical', 'Cairo',      'Egyptian Museum Cairo'),
    ('historical', 'Cairo',      'Mosque of Amr ibn al-As'),
    ('historical', 'Cairo',      'Roda Island Cairo'),
    ('historical', 'Luxor',      'Luxor Museum'),
    ('historical', 'Luxor',      'Temple of Dendera'),
    ('historical', 'Aswan',      'Temple of Kalabsha'),
    ('historical', 'Aswan',      'Nubian Village'),
    ('historical', 'Red Sea',    'Hurghada'),
    ('historical', 'South Sinai','Dahab'),
    ('historical', 'Alexandria', 'Montazah Palace'),
    ('historical', 'Cairo',      'Al-Hakim Mosque'),

    # ===== MUSEUM (target 60) =====
    ('museum', 'Cairo',      'Egyptian Museum Cairo'),
    ('museum', 'Cairo',      'National Museum of Egyptian Civilization'),
    ('museum', 'Cairo',      'Museum of Islamic Art Cairo'),
    ('museum', 'Cairo',      'Coptic Museum Cairo'),
    ('museum', 'Cairo',      'Gayer-Anderson Museum'),
    ('museum', 'Cairo',      'Manial Palace Museum'),
    ('museum', 'Cairo',      'Abdeen Palace Museum'),
    ('museum', 'Cairo',      'Egyptian Textile Museum'),
    ('museum', 'Cairo',      'Mahmoud Khalil Museum'),
    ('museum', 'Cairo',      'Agricultural Museum Cairo'),
    ('museum', 'Cairo',      'Military Museum Cairo Citadel'),
    ('museum', 'Cairo',      'Gezirah Arts Center'),
    ('museum', 'Giza',       'Solar Boat Museum'),
    ('museum', 'Giza',       'Grand Egyptian Museum'),
    ('museum', 'Luxor',      'Luxor Museum'),
    ('museum', 'Luxor',      'Mummification Museum'),
    ('museum', 'Aswan',      'Nubian Museum'),
    ('museum', 'Aswan',      'Aswan Museum'),
    ('museum', 'Alexandria', 'National Museum of Alexandria'),
    ('museum', 'Alexandria', 'Greco-Roman Museum Alexandria'),
    ('museum', 'Alexandria', 'Royal Jewelry Museum Alexandria'),
    ('museum', 'Alexandria', 'Bibliotheca Alexandrina'),
    ('museum', 'Hurghada',   'Hurghada Grand Aquarium'),
    ('museum', 'Cairo',      'Cairo Opera House'),
    ('museum', 'Cairo',      'Postal Museum Cairo'),
    ('museum', 'Cairo',      'Egyptian Geological Museum'),
    ('museum', 'Cairo',      'Pharaonic Village'),
    ('museum', 'Sharm El Sheikh', 'Sharm El-Sheikh Museum'),
    ('museum', 'Cairo',      'Qasr el-Aini Museum'),
    ('museum', 'Cairo',      'Islamic Ceramics Museum Cairo'),

    # ===== HOTEL (target 50) =====
    ('hotel', 'Cairo',       'Cairo Marriott Hotel'),
    ('hotel', 'Cairo',       'Four Seasons Hotel Cairo at Nile Plaza'),
    ('hotel', 'Cairo',       'Sofitel Cairo El Gezirah'),
    ('hotel', 'Cairo',       'Kempinski Nile Hotel Cairo'),
    ('hotel', 'Cairo',       'InterContinental Cairo Semiramis'),
    ('hotel', 'Cairo',       'Conrad Cairo'),
    ('hotel', 'Cairo',       'The Nile Ritz-Carlton Cairo'),
    ('hotel', 'Cairo',       'Hilton Cairo Zamalek Residences'),
    ('hotel', 'Giza',        'Marriott Mena House Cairo'),
    ('hotel', 'Giza',        'Le Méridien Pyramids Hotel & Spa'),
    ('hotel', 'Hurghada',    'Steigenberger Aqua Magic Hurghada'),
    ('hotel', 'Hurghada',    'Coral Beach Resort Hurghada'),
    ('hotel', 'Hurghada',    'Marriott Hurghada Beach Resort'),
    ('hotel', 'Hurghada',    'Hilton Hurghada Plaza'),
    ('hotel', 'Hurghada',    'SUNRISE Grand Select Arabian Beach Resort'),
    ('hotel', 'Hurghada',    'Pickalbatros Aqua Park Resort'),
    ('hotel', 'Sharm El Sheikh', 'Hilton Sharm Dreams Resort'),
    ('hotel', 'Sharm El Sheikh', 'Grand Rotana Resort & Spa Sharm El Sheikh'),
    ('hotel', 'Sharm El Sheikh', 'Reef Oasis Blue Bay Resort'),
    ('hotel', 'Sharm El Sheikh', 'Hyatt Regency Sharm El Sheikh Resort'),
    ('hotel', 'Sharm El Sheikh', 'Marriott Sharm El Sheikh Mountain Resort'),
    ('hotel', 'Dahab',       'Nesima Resort Dahab'),
    ('hotel', 'Dahab',       'Hilton Dahab Resort'),
    ('hotel', 'El Gouna',    "Steigenberger Golf Resort El Gouna"),
    ('hotel', 'El Gouna',    "Three Corners Ocean View El Gouna"),
    ('hotel', 'Luxor',       'Sofitel Winter Palace Luxor'),
    ('hotel', 'Luxor',       'Steigenberger Nile Palace Luxor'),
    ('hotel', 'Luxor',       'Hilton Luxor Resort & Spa'),
    ('hotel', 'Aswan',       'Sofitel Legend Old Cataract Hotel Aswan'),
    ('hotel', 'Aswan',       'Movenpick Resort Aswan'),
    ('hotel', 'Alexandria',  'Four Seasons Hotel Alexandria'),
    ('hotel', 'Alexandria',  'Marriott Alexandria Hotel'),
    ('hotel', 'Alexandria',  'Helnan Palestine Hotel'),
    ('hotel', 'Marsa Alam',  'Shams Alam Beach Resort'),
    ('hotel', 'Red Sea',     'Regency Plaza Aqua Park Safaga'),
]

GOV_MAP = {
    'cairo': 'Cairo', 'giza': 'Giza', 'luxor': 'Luxor', 'aswan': 'Aswan',
    'alexandria': 'Alexandria', 'sharm': 'South Sinai', 'hurghada': 'Red Sea',
    'dahab': 'South Sinai', 'el gouna': 'Red Sea', 'marsa': 'Red Sea',
    'sinai': 'South Sinai', 'red sea': 'Red Sea',
}


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

def wiki_search(query):
    """Search Wikipedia and get page info"""
    try:
        params = {
            'action': 'query',
            'titles': query,
            'prop': 'extracts|pageimages|coordinates',
            'exintro': True,
            'exsentences': 5,
            'piprop': 'thumbnail|original',
            'pithumbsize': 800,
            'format': 'json',
            'redirects': True,
        }
        r = requests.get(WIKI_API, params=params, headers=HEADERS, timeout=15)
        if r.status_code != 200: return None
        data = r.json()
        pages = data.get('query', {}).get('pages', {})
        if not pages: return None
        page = list(pages.values())[0]
        if page.get('pageid', -1) == -1: return None  # page not found
        return page
    except Exception as e:
        print(f"  Wiki error: {e}")
        return None

def get_wiki_images(title, count=3):
    """Get images from a Wikipedia article via Commons"""
    images = []
    try:
        params = {
            'action': 'query',
            'titles': title,
            'prop': 'images',
            'imlimit': 10,
            'format': 'json',
            'redirects': True,
        }
        r = requests.get(WIKI_API, params=params, headers=HEADERS, timeout=15)
        if r.status_code != 200: return images
        data = r.json()
        pages = data.get('query', {}).get('pages', {})
        if not pages: return images
        page = list(pages.values())[0]
        img_list = page.get('images', [])

        for img_info in img_list:
            img_name = img_info.get('title', '').replace('File:', 'File:')
            if not img_name or any(x in img_name.lower() for x in
                                   ['icon', 'logo', 'flag', 'map', 'symbol', '.svg', 'stub', 'portal']):
                continue
            # Get image URL from Commons
            url = get_commons_image_url(img_name)
            if url:
                images.append(url)
            if len(images) >= count:
                break
    except Exception as e:
        print(f"  Image error: {e}")
    return images

def get_commons_image_url(filename):
    """Get direct URL for a Commons file"""
    try:
        clean = filename.replace('File:', '').replace('Image:', '').strip()
        params = {
            'action': 'query',
            'titles': 'File:' + clean,
            'prop': 'imageinfo',
            'iiprop': 'url',
            'format': 'json',
        }
        r = requests.get(COMMONS_API, params=params, headers=HEADERS, timeout=10)
        if r.status_code != 200: return None
        data = r.json()
        pages = data.get('query', {}).get('pages', {})
        if not pages: return None
        page = list(pages.values())[0]
        imginfo = page.get('imageinfo', [])
        if imginfo:
            url = imginfo[0].get('url', '')
            if url and any(ext in url.lower() for ext in ['.jpg', '.jpeg', '.png', '.webp']):
                return url
    except: pass
    return None

def extract_desc(page):
    """Extract clean description from Wikipedia extract"""
    extract = page.get('extract', '') or ''
    # Remove HTML tags
    import re
    clean = re.sub(r'<[^>]+>', '', extract)
    clean = clean.replace('\n', ' ').strip()
    # Take first 3 sentences
    sentences = re.split(r'(?<=[.!?])\s+', clean)[:4]
    desc = ' '.join(sentences)[:1000]
    return desc if len(desc) > 30 else ''

def extract_coords(page):
    """Extract lat/lng from Wikipedia page"""
    coords = page.get('coordinates', [])
    if coords:
        return float(coords[0].get('lat', 0)), float(coords[0].get('lon', 0))
    return 0.0, 0.0

def insert_place(cur, cat, gov, d):
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
    cat,gov,d['lat'],d['lng'],d.get('addr', gov+', Egypt')[:299],
    d['fee_egp'],d['fee_usd'],
    '09:00' if cat != 'hotel' else '00:00',
    '18:00' if cat != 'hotel' else '23:59',
    'Daily',
    TAGS_MAP.get(cat,'Egypt'),
    d.get('rating',4.0)>=4.5,
    d.get('rating',4.0),
    d.get('reviews',0),
    0,0,0,0,0)
    return cur.fetchone()[0]

def insert_imgs(cur, pid, imgs):
    for i,u in enumerate(imgs[:3]):
        if u and u.startswith('http'):
            cur.execute("INSERT INTO PlaceImages(place_id,image_url,sort_order)VALUES(?,?,?)",pid,u,i)


def main():
    print("="*60)
    print("Wikipedia Egypt Scraper - historical:50, museum:60, hotel:50")
    print("="*60)

    conn = get_db(); cursor = conn.cursor(); total = 0

    for cat, default_gov, wiki_title in EGYPT_PLACES:
        current = count_cat(cursor, cat)
        target = TARGET_COUNTS.get(cat, 999)
        if current >= target:
            continue  # skip this category, still process others

        print(f"\n[{current}/{target}] {cat.upper()} - {default_gov} | {wiki_title}")

        # Search Wikipedia
        page = wiki_search(wiki_title)
        if not page:
            print(f"  Not found on Wikipedia: {wiki_title}")
            # Use fallback data
            name = wiki_title
            desc = f"A remarkable {cat} in {default_gov}, Egypt."
            lat, lng = 0.0, 0.0
            imgs = []
        else:
            name = page.get('title', wiki_title)
            desc = extract_desc(page)
            lat, lng = extract_coords(page)
            # Get thumbnail first
            imgs = []
            thumb = page.get('thumbnail', {}).get('original', '')
            if thumb and thumb.startswith('http') and any(ext in thumb.lower() for ext in ['.jpg','.jpeg','.png']):
                imgs.append(thumb)
            # Get more images if needed
            if len(imgs) < 3:
                more_imgs = get_wiki_images(wiki_title, 3)
                for img in more_imgs:
                    if img not in imgs:
                        imgs.append(img)
                    if len(imgs) >= 3: break

        if not desc:
            desc = f"A remarkable {cat} in {default_gov}, Egypt."

        print(f"  Name: {name[:55]}")
        print(f"  Desc: {desc[:60]}...")
        print(f"  Imgs: {len(imgs)}")

        if exists(cursor, name[:299]):
            print(f"  Exists: {name[:40]}"); continue

        print(f"  Translating...")
        name_ar = translate_ar(name)
        desc_ar = translate_ar(desc[:500])

        # Gov
        gov = default_gov
        al = (name + ' ' + wiki_title).lower()
        for k, v in GOV_MAP.items():
            if k in al: gov = v; break

        data = dict(
            name_en=name[:299], name_ar=name_ar[:299],
            desc_en=desc[:3000], desc_ar=desc_ar[:3000],
            lat=lat, lng=lng, addr=default_gov+', Egypt',
            fee_egp=0.0, fee_usd=0.0, rating=4.2, reviews=0,
        )

        try:
            pid = insert_place(cursor, cat, gov, data)
            insert_imgs(cursor, pid, imgs)
            conn.commit(); total += 1
            print(f"  [OK] ID:{pid} | Imgs:{len(imgs)}")
        except Exception as e:
            conn.rollback(); print(f"  [ERR] {e}")

        time.sleep(random.uniform(0.5, 1.5))  # be nice to Wikipedia

    print(f"\n{'='*60}")
    print(f"[DONE] Added: {total}")
    for cat, tgt in TARGET_COUNTS.items():
        print(f"  {cat}: {count_cat(cursor, cat)}/{tgt}")
    cursor.close(); conn.close()
    print("="*60)


if __name__ == '__main__':
    main()
