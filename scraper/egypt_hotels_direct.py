# -*- coding: utf-8 -*-
"""
Egypt Hotels - Direct URL Scraper
Uses hardcoded TripAdvisor hotel review URLs for known Egypt hotels
Bypasses listing page blocking with cloudscraper
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

TARGET = 50

# Known Egypt hotel TripAdvisor URLs - curated list
EGYPT_HOTEL_URLS = [
    # Cairo
    ("Cairo",       "https://www.tripadvisor.com/Hotel_Review-g294201-d301746-Reviews-Le_Passage_Cairo_Hotel_Casino-Cairo_Cairo_Governorate.html"),
    ("Cairo",       "https://www.tripadvisor.com/Hotel_Review-g294201-d19065385-Reviews-Crowne_Plaza_West_Cairo_Arkan_By_IHG-6th_of_October_Giza_Governorate.html"),
    ("Cairo",       "https://www.tripadvisor.com/Hotel_Review-g294201-d288994-Reviews-Cairo_Marriott_Hotel_Omar_Khayyam_Casino-Cairo_Cairo_Governorate.html"),
    ("Cairo",       "https://www.tripadvisor.com/Hotel_Review-g294201-d288995-Reviews-Sofitel_Cairo_El_Gezirah-Cairo_Cairo_Governorate.html"),
    ("Cairo",       "https://www.tripadvisor.com/Hotel_Review-g294201-d288992-Reviews-Kempinski_Nile_Hotel_Cairo-Cairo_Cairo_Governorate.html"),
    ("Cairo",       "https://www.tripadvisor.com/Hotel_Review-g294201-d1534903-Reviews-Four_Seasons_Hotel_Cairo_at_Nile_Plaza-Cairo_Cairo_Governorate.html"),
    ("Cairo",       "https://www.tripadvisor.com/Hotel_Review-g294201-d288997-Reviews-InterContinental_Cairo_Semiramis-Cairo_Cairo_Governorate.html"),
    ("Cairo",       "https://www.tripadvisor.com/Hotel_Review-g294201-d288993-Reviews-Hilton_Cairo_Zamalek_Residences-Cairo_Cairo_Governorate.html"),
    ("Cairo",       "https://www.tripadvisor.com/Hotel_Review-g294201-d301739-Reviews-Conrad_Cairo-Cairo_Cairo_Governorate.html"),
    ("Cairo",       "https://www.tripadvisor.com/Hotel_Review-g294201-d301745-Reviews-The_Nile_Ritz_Carlton_Cairo-Cairo_Cairo_Governorate.html"),
    # Giza / Pyramids
    ("Giza",        "https://www.tripadvisor.com/Hotel_Review-g294202-d8754354-Reviews-Great_Pyramid_INN-Giza_Giza_Governorate.html"),
    ("Giza",        "https://www.tripadvisor.com/Hotel_Review-g294202-d288961-Reviews-Marriott_Mena_House_Cairo-Giza_Giza_Governorate.html"),
    ("Giza",        "https://www.tripadvisor.com/Hotel_Review-g294202-d288962-Reviews-Le_Meridien_Pyramids_Hotel_Spa-Giza_Giza_Governorate.html"),
    ("Giza",        "https://www.tripadvisor.com/Hotel_Review-g294202-d301727-Reviews-Venus_Pyramids_Inn-Giza_Giza_Governorate.html"),
    # Hurghada
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297549-d1535318-Reviews-Pickalbatros_Jungle_Aqua_Park_Neverland-Hurghada_Red_Sea_Governorate.html"),
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297549-d308117-Reviews-Hilton_Hurghada_Plaza-Hurghada_Red_Sea_Governorate.html"),
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297549-d302079-Reviews-Steigenberger_Aqua_Magic-Hurghada_Red_Sea_Governorate.html"),
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297549-d302086-Reviews-SUNRISE_Grand_Select_Arabian_Beach_Resort-Hurghada_Red_Sea_Governorate.html"),
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297549-d4488462-Reviews-Coral_Beach_Resort_Hurghada-Hurghada_Red_Sea_Governorate.html"),
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297549-d302077-Reviews-Marriott_Hurghada_Beach_Resort-Hurghada_Red_Sea_Governorate.html"),
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297549-d302084-Reviews-Serenity_Fun_City_Resort-Hurghada_Red_Sea_Governorate.html"),
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297549-d302085-Reviews-Sultan_Bey_Hotel-Hurghada_Red_Sea_Governorate.html"),
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297549-d302083-Reviews-Sheraton_Soma_Bay_Resort-Hurghada_Red_Sea_Governorate.html"),
    # Sharm El Sheikh
    ("South Sinai", "https://www.tripadvisor.com/Hotel_Review-g297555-d302134-Reviews-JAZ_Fanara_Resort-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"),
    ("South Sinai", "https://www.tripadvisor.com/Hotel_Review-g297555-d3573109-Reviews-SUNRISE_Arabian_Beach_Resort-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"),
    ("South Sinai", "https://www.tripadvisor.com/Hotel_Review-g297555-d302130-Reviews-Hilton_Sharm_Dreams_Resort-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"),
    ("South Sinai", "https://www.tripadvisor.com/Hotel_Review-g297555-d302128-Reviews-Marriott_Sharm_El_Sheikh_Mountain_Resort_Spa-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"),
    ("South Sinai", "https://www.tripadvisor.com/Hotel_Review-g297555-d302131-Reviews-Grand_Rotana_Resort_Spa-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"),
    ("South Sinai", "https://www.tripadvisor.com/Hotel_Review-g297555-d302132-Reviews-Reef_Oasis_Blue_Bay_Resort-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"),
    ("South Sinai", "https://www.tripadvisor.com/Hotel_Review-g297555-d302127-Reviews-Hyatt_Regency_Sharm_El_Sheikh_Resort-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"),
    ("South Sinai", "https://www.tripadvisor.com/Hotel_Review-g297555-d24084498-Reviews-Meraki_Resort_Sharm_El_Sheikh-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"),
    # Dahab
    ("South Sinai", "https://www.tripadvisor.com/Hotel_Review-g297551-d302166-Reviews-Nesima_Resort-Dahab_South_Sinai_Red_Sea_Governorate.html"),
    ("South Sinai", "https://www.tripadvisor.com/Hotel_Review-g297551-d302171-Reviews-Hilton_Dahab_Resort-Dahab_South_Sinai_Red_Sea_Governorate.html"),
    ("South Sinai", "https://www.tripadvisor.com/Hotel_Review-g297551-d302165-Reviews-Novotel_Dahab_Holiday_Resort-Dahab_South_Sinai_Red_Sea_Governorate.html"),
    # El Gouna
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297548-d611054-Reviews-Cook_s_Club_El_Gouna-El_Gouna_Red_Sea_Governorate.html"),
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297548-d302058-Reviews-Steigenberger_Golf_Resort_El_Gouna-El_Gouna_Red_Sea_Governorate.html"),
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297548-d302059-Reviews-Three_Corners_Ocean_View_Hotel-El_Gouna_Red_Sea_Governorate.html"),
    # Marsa Alam
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297552-d302201-Reviews-Orca_Dive_Club_Marsa_Alam-Marsa_Alam_Red_Sea_Governorate.html"),
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297552-d302200-Reviews-Shams_Alam_Beach_Resort-Marsa_Alam_Red_Sea_Governorate.html"),
    # Makadi Bay
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297550-d940461-Reviews-Serenity_Alpha_Beach-Makadi_Bay_Red_Sea_Governorate.html"),
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g297550-d302093-Reviews-Makadi_Palace-Makadi_Bay_Red_Sea_Governorate.html"),
    # Sahl Hasheesh
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g15516847-d25180348-Reviews-AJIRA_Resort_Sahl_Hasheesh-Sahl_Hasheesh_Red_Sea_Governorate.html"),
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g15516847-d302109-Reviews-Baron_Palace_Sahl_Hasheesh-Sahl_Hasheesh_Red_Sea_Governorate.html"),
    # Safaga
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g303855-d623280-Reviews-Regency_Plaza_Aqua_Park_SPA-Safaga_Red_Sea_Governorate.html"),
    # Luxor
    ("Luxor",       "https://www.tripadvisor.com/Hotel_Review-g190392-d289013-Reviews-Sofitel_Winter_Palace_Luxor-Luxor_Luxor_Governorate.html"),
    ("Luxor",       "https://www.tripadvisor.com/Hotel_Review-g190392-d289014-Reviews-Steigenberger_Nile_Palace_Luxor-Luxor_Luxor_Governorate.html"),
    ("Luxor",       "https://www.tripadvisor.com/Hotel_Review-g190392-d289015-Reviews-Iberotel_Luxor-Luxor_Luxor_Governorate.html"),
    # Aswan
    ("Aswan",       "https://www.tripadvisor.com/Hotel_Review-g190393-d289006-Reviews-Sofitel_Legend_Old_Cataract_Aswan-Aswan_Aswan_Governorate.html"),
    ("Aswan",       "https://www.tripadvisor.com/Hotel_Review-g190393-d289007-Reviews-Movenpick_Resort_Aswan-Aswan_Aswan_Governorate.html"),
    # Alexandria
    ("Alexandria",  "https://www.tripadvisor.com/Hotel_Review-g190394-d300888-Reviews-Marriott_Alexandria_Hotel-Alexandria_Alexandria_Governorate.html"),
    ("Alexandria",  "https://www.tripadvisor.com/Hotel_Review-g190394-d300889-Reviews-Helnan_Palestine_Hotel-Alexandria_Alexandria_Governorate.html"),
    ("Alexandria",  "https://www.tripadvisor.com/Hotel_Review-g190394-d300887-Reviews-Four_Seasons_Hotel_Alexandria_at_San_Stefano-Alexandria_Alexandria_Governorate.html"),
    # Sidi Heneish
    ("Red Sea",     "https://www.tripadvisor.com/Hotel_Review-g424910-d26363785-Reviews-Cleopatra_Sidi_Heneish-Sidi_Heneish_Matrouh_Governorate.html"),
]

scraper = cloudscraper.create_scraper(
    browser={'browser': 'chrome', 'platform': 'windows', 'mobile': False}
)


def get_db(): return pyodbc.connect(DB_CONN_STR)
def count_hotels(cur):
    cur.execute("SELECT COUNT(*) FROM Places WHERE category='hotel'")
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
            r = scraper.get(url, timeout=20)
            if r.status_code == 200:
                return r.text
            print(f"  HTTP {r.status_code}")
        except Exception as e:
            print(f"  Error: {e}")
    return None

def scrape_hotel(url, default_gov):
    html = get_page(url)
    if not html: return None

    # Verify Egypt content
    if not any(s in html[:15000] for s in ['Egypt','Cairo','Giza','Hurghada','Sharm','Sinai','Red Sea','Nile','Luxor','Aswan','Alexandria']):
        print("  Not Egypt - skip")
        return None

    soup = BeautifulSoup(html, 'html.parser')

    # Name
    name = ''
    h1 = soup.find('h1')
    if h1: name = h1.get_text(strip=True)
    if not name:
        og = soup.find('meta', property='og:title')
        if og: name = og.get('content', '').strip()
    if not name or len(name) < 3: return None
    print(f"  Name: {name[:55]}")

    # Description
    desc = ''
    meta = soup.find('meta', attrs={'name': 'description'})
    if meta: desc = meta.get('content', '').strip()
    if not desc or len(desc) < 30:
        for script in soup.find_all('script', type='application/ld+json'):
            try:
                d = json.loads(script.string or '{}')
                if isinstance(d, list): d = d[0] if d else {}
                if d.get('description'):
                    desc = d['description']
                    break
            except: pass
    if not desc: desc = f"A wonderful hotel in {default_gov}, Egypt."

    # Rating
    rating = 4.0
    m = re.search(r'"ratingValue"[:\s]+"?([\d.]+)"?', html)
    if m: rating = float(m.group(1))

    # Reviews
    reviews = 0
    m = re.search(r'"reviewCount"[:\s]+(\d+)', html)
    if m: reviews = int(m.group(1))
    else:
        m2 = re.search(r'([\d,]+)\s+reviews?', html, re.I)
        if m2: reviews = int(m2.group(1).replace(',', ''))

    # Images
    images, seen = [], set()
    for og in soup.find_all('meta', property='og:image'):
        src = og.get('content', '')
        if src.startswith('http') and src not in seen:
            seen.add(src); images.append(src)
    for script in soup.find_all('script', type='application/ld+json'):
        try:
            d = json.loads(script.string or '{}')
            if isinstance(d, list): d = d[0] if d else {}
            img = d.get('image', [])
            if isinstance(img, str): img = [img]
            for i in img:
                u = i if isinstance(i, str) else i.get('url', '')
                if u.startswith('http') and u not in seen:
                    seen.add(u); images.append(u)
        except: pass
    if len(images) < 3:
        for img in soup.find_all('img', src=True):
            src = img['src']
            if (src.startswith('http') and src not in seen and
                any(x in src for x in ['media','photo','dynamic','upload','bstatic']) and
                not any(x in src.lower() for x in ['avatar','logo','icon','flag'])):
                seen.add(src); images.append(src)
            if len(images) >= 3: break

    # Price
    price = 0.0
    m = re.search(r'\$\s*(\d+)', html)
    if m: price = float(m.group(1))

    # Address
    addr = default_gov + ', Egypt'
    m = re.search(r'"streetAddress"[:\s]+"([^"]+)"', html)
    if m: addr = m.group(1)

    # Gov from URL
    gov = default_gov
    gov_map = {
        'cairo':'Cairo','giza':'Giza','sharm':'South Sinai','hurghada':'Red Sea',
        'dahab':'South Sinai','el_gouna':'Red Sea','marsa_alam':'Red Sea',
        'makadi':'Red Sea','sahl':'Red Sea','luxor':'Luxor','aswan':'Aswan',
        'alexandria':'Alexandria','sinai':'South Sinai',
    }
    url_lower = url.lower()
    for k, v in gov_map.items():
        if k in url_lower: gov = v; break

    print(f"  Translating...")
    name_ar = translate_ar(name)
    desc_ar = translate_ar(desc[:500])

    return dict(
        name_en=name[:299], name_ar=name_ar[:299],
        desc_en=desc[:3000], desc_ar=desc_ar[:3000],
        gov=gov, addr=addr[:299], rating=rating, reviews=reviews,
        price=price, imgs=images,
    )

def insert_place(cur, d):
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
    'hotel',d['gov'],0.0,0.0,d['addr'],
    0.0,d['price'],'00:00','23:59','Daily',
    'accommodation,stay,hotel,Egypt,luxury',
    d['rating']>=4.5,d['rating'],d['reviews'],
    0,0,0,max(0,d['reviews']//5),max(0,d['reviews']-d['reviews']//5))
    return cur.fetchone()[0]

def insert_imgs(cur, pid, imgs):
    for i,u in enumerate(imgs[:3]):
        if u and u.startswith('http'):
            cur.execute("INSERT INTO PlaceImages(place_id,image_url,sort_order)VALUES(?,?,?)",pid,u,i)


def main():
    print("="*60)
    print("Egypt Hotels Direct Scraper - Target: 50")
    print("="*60)

    conn = get_db(); cursor = conn.cursor(); total = 0

    for gov, url in EGYPT_HOTEL_URLS:
        current = count_hotels(cursor)
        if current >= TARGET:
            print(f"\n[DONE] {current}/{TARGET} hotels!"); break

        print(f"\n[{current+1}/{TARGET}] {gov}")
        print(f"  {url[35:75]}")

        if exists(cursor, ''):
            pass  # will check after scrape

        data = scrape_hotel(url, gov)
        if not data:
            print("  Skipped"); continue

        if exists(cursor, data['name_en']):
            print(f"  Exists: {data['name_en'][:40]}"); continue

        try:
            pid = insert_place(cursor, data)
            insert_imgs(cursor, pid, data['imgs'])
            conn.commit(); total += 1
            print(f"  [OK] {data['name_en'][:45]} | Imgs:{len(data['imgs'])}")
        except Exception as e:
            conn.rollback(); print(f"  [ERR] {e}")

        time.sleep(random.uniform(1.5, 3.5))

    final = count_hotels(cursor)
    print(f"\n{'='*60}")
    print(f"[DONE] Added: {total} | Total: {final}/{TARGET}")
    print("="*60)
    cursor.close(); conn.close()


if __name__ == '__main__':
    main()
