# -*- coding: utf-8 -*-
"""Hotel scraper using requests (no browser needed) - Egypt Only"""
import sys, time, random, re, pyodbc, requests
from deep_translator import GoogleTranslator
from bs4 import BeautifulSoup

sys.stdout.reconfigure(encoding='utf-8')

DB_CONN_STR = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost,1433;DATABASE=DiscoverEgypt;"
    "UID=sa;PWD=YourPassword123!;TrustServerCertificate=yes;"
)

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Referer': 'https://www.tripadvisor.com/',
}

# Egypt hotel listing pages - city level
HOTEL_URLS = [
    ("Cairo",         "https://www.tripadvisor.com/Hotels-g294201-Cairo_Governorate-Hotels.html"),
    ("Sharm El Sheikh","https://www.tripadvisor.com/Hotels-g297555-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate-Hotels.html"),
    ("Hurghada",      "https://www.tripadvisor.com/Hotels-g297549-Hurghada_Red_Sea_Governorate-Hotels.html"),
    ("Giza",          "https://www.tripadvisor.com/Hotels-g294202-Giza_Governorate-Hotels.html"),
    ("Dahab",         "https://www.tripadvisor.com/Hotels-g297551-Dahab_South_Sinai_Red_Sea_Governorate-Hotels.html"),
    ("El Gouna",      "https://www.tripadvisor.com/Hotels-g297548-El_Gouna_Red_Sea_Governorate-Hotels.html"),
    ("Marsa Alam",    "https://www.tripadvisor.com/Hotels-g297552-Marsa_Alam_Red_Sea_Governorate-Hotels.html"),
    ("Makadi Bay",    "https://www.tripadvisor.com/Hotels-g297550-Makadi_Bay_Red_Sea_Governorate-Hotels.html"),
    ("Sahl Hasheesh", "https://www.tripadvisor.com/Hotels-g15516847-Sahl_Hasheesh_Red_Sea_Governorate-Hotels.html"),
]

EGYPT_GEO_IDS = {
    '294200','294201','294202','297549','297550','297548',
    '297555','297551','297552','303855','15516847','424910',
    '19065385',
}

TARGET = 50

def get_db(): return pyodbc.connect(DB_CONN_STR)

def count_hotels(cursor):
    cursor.execute("SELECT COUNT(*) FROM Places WHERE category='hotel'")
    return cursor.fetchone()[0]

def exists(cursor, name):
    cursor.execute("SELECT COUNT(*) FROM Places WHERE name_en=?", name)
    return cursor.fetchone()[0] > 0

def insert_place(cursor, p):
    cursor.execute("""
        INSERT INTO Places(name_en,name_ar,description_en,description_ar,
            category,governorate,latitude,longitude,address,
            admission_fee_egyptian,admission_fee_foreign,
            opening_hours_open,opening_hours_close,opening_hours_days,
            tags,is_featured,avg_rating,review_count,
            rating_1,rating_2,rating_3,rating_4,rating_5,created_at)
        OUTPUT INSERTED.id VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,GETDATE())
    """, p['name_en'],p['name_ar'],p['desc_en'],p['desc_ar'],
        'hotel',p['gov'],0.0,0.0,p['addr'],
        0.0,p['price'],'00:00','23:59','Daily',
        'accommodation,stay,hotel,Egypt,luxury',
        p['rating']>=4.5,p['rating'],p['reviews'],
        0,0,0,max(0,p['reviews']//5),max(0,p['reviews']-p['reviews']//5))
    return cursor.fetchone()[0]

def insert_imgs(cursor, pid, imgs):
    for i,u in enumerate(imgs[:3]):
        if u and u.startswith('http'):
            cursor.execute("INSERT INTO PlaceImages(place_id,image_url,sort_order)VALUES(?,?,?)",pid,u,i)

def translate_ar(text):
    if not text or len(text.strip()) < 3: return text
    try: return GoogleTranslator(source='en', target='ar').translate(text[:4500])
    except: return text

def is_egypt_url(url):
    m = re.search(r'-g(\d+)-', url)
    return bool(m and m.group(1) in EGYPT_GEO_IDS)

def get_page(url, retries=3):
    for i in range(retries):
        try:
            time.sleep(random.uniform(2, 4))
            r = requests.get(url, headers=HEADERS, timeout=20)
            if r.status_code == 200:
                return r.text
            print(f"  Status {r.status_code}")
        except Exception as e:
            print(f"  Error: {e}")
    return None

def extract_hotel_links(html):
    soup = BeautifulSoup(html, 'html.parser')
    links = []
    seen = set()
    for a in soup.find_all('a', href=True):
        href = a['href']
        if '/Hotel_Review' in href:
            if href.startswith('/'):
                href = 'https://www.tripadvisor.com' + href
            clean = href.split('#')[0].split('?')[0]
            if clean not in seen and is_egypt_url(clean):
                seen.add(clean)
                links.append(clean)
    return links

def scrape_hotel_page(url, gov):
    html = get_page(url)
    if not html:
        return None

    # Verify Egypt
    if not any(s in html[:10000] for s in
               ['Egypt','Cairo','Giza','Hurghada','Sharm','Sinai','Red Sea','Nile']):
        print(f"  Not Egypt page")
        return None

    soup = BeautifulSoup(html, 'html.parser')

    # Name from h1
    name = ''
    h1 = soup.find('h1')
    if h1:
        name = h1.get_text(strip=True)
    if not name or len(name) < 3:
        return None
    print(f"  Name: {name[:55]}")

    # Description from meta or JSON-LD
    desc = ''
    meta_desc = soup.find('meta', attrs={'name': 'description'})
    if meta_desc:
        desc = meta_desc.get('content', '').strip()
    if not desc or len(desc) < 30:
        # Try JSON-LD description
        for script in soup.find_all('script', type='application/ld+json'):
            try:
                import json
                d = json.loads(script.string or '{}')
                if isinstance(d, list): d = d[0] if d else {}
                if d.get('description'):
                    desc = d['description']
                    break
            except Exception:
                pass
    if not desc:
        desc = f"A wonderful hotel in {gov}, Egypt."

    # Rating
    rating = 4.0
    rating_match = re.search(r'"ratingValue"[:\s]+"?([\d.]+)"?', html)
    if rating_match:
        rating = float(rating_match.group(1))

    # Review count
    reviews = 0
    rev_match = re.search(r'"reviewCount"[:\s]+(\d+)', html)
    if rev_match:
        reviews = int(rev_match.group(1))
    else:
        rev_match2 = re.search(r'([\d,]+)\s+reviews?', html, re.I)
        if rev_match2:
            reviews = int(rev_match2.group(1).replace(',', ''))

    # Images - from og:image and JSON-LD
    images = []
    seen_imgs = set()

    # og:image
    for og in soup.find_all('meta', property='og:image'):
        src = og.get('content', '')
        if src.startswith('http') and src not in seen_imgs:
            seen_imgs.add(src)
            images.append(src)

    # JSON-LD images
    for script in soup.find_all('script', type='application/ld+json'):
        try:
            import json
            d = json.loads(script.string or '{}')
            if isinstance(d, list): d = d[0] if d else {}
            img = d.get('image', [])
            if isinstance(img, str): img = [img]
            for i in img:
                url_i = i if isinstance(i, str) else i.get('url', '')
                if url_i.startswith('http') and url_i not in seen_imgs:
                    seen_imgs.add(url_i)
                    images.append(url_i)
        except Exception:
            pass

    if len(images) < 3:
        # Try srcset images
        for img_tag in soup.find_all('img', src=True):
            src = img_tag['src']
            if (src.startswith('http') and src not in seen_imgs and
                any(x in src for x in ['media','photo','dynamic','upload']) and
                not any(x in src.lower() for x in ['avatar','logo','icon'])):
                seen_imgs.add(src)
                images.append(src)
            if len(images) >= 3:
                break

    # Price
    price = 0.0
    price_m = re.search(r'\$\s*(\d+)', html)
    if price_m:
        price = float(price_m.group(1))

    # Address
    addr = gov + ', Egypt'
    addr_m = re.search(r'"streetAddress"[:\s]+"([^"]+)"', html)
    if addr_m:
        addr = addr_m.group(1)

    # Translate
    print(f"  Translating...")
    name_ar = translate_ar(name)
    desc_ar = translate_ar(desc[:500])

    # Refine governorate
    al = (addr + ' ' + name).lower()
    gov_map = {'cairo':'Cairo','giza':'Giza','sharm':'South Sinai',
               'hurghada':'Red Sea','dahab':'South Sinai','el gouna':'Red Sea',
               'marsa':'Red Sea','makadi':'Red Sea','sahl':'Red Sea',
               'sinai':'South Sinai'}
    for k, v in gov_map.items():
        if k in al:
            gov = v
            break

    return dict(
        name_en=name[:299], name_ar=name_ar[:299],
        desc_en=desc[:3000], desc_ar=desc_ar[:3000],
        gov=gov, addr=addr[:299],
        rating=rating, reviews=reviews,
        price=price, imgs=images,
    )


def main():
    print("="*60)
    print("Hotel Scraper (requests) - Egypt Only - Target: 50")
    print("="*60)

    conn = get_db()
    cursor = conn.cursor()
    total = 0

    for gov, list_url in HOTEL_URLS:
        current = count_hotels(cursor)
        if current >= TARGET:
            print(f"\n[DONE] Reached {current}/{TARGET} hotels!")
            break

        print(f"\n{'='*50}")
        print(f"HOTEL - {gov} | {current}/{TARGET}")
        print(f"{'='*50}")

        # Get listing page and extract links
        html = get_page(list_url)
        if not html:
            print("  Failed to load listing page")
            continue

        links = extract_hotel_links(html)
        print(f"  Found {len(links)} Egypt hotel links")

        for i, url in enumerate(links):
            current = count_hotels(cursor)
            if current >= TARGET:
                print(f"  [TARGET REACHED] {current}/{TARGET}")
                break

            print(f"\n  [{i+1}/{len(links)}] ({current}/{TARGET})")
            print(f"  {url[35:80]}")

            data = scrape_hotel_page(url, gov)
            if not data:
                print("  Skipped")
                continue

            if exists(cursor, data['name_en']):
                print(f"  Exists: {data['name_en'][:40]}")
                continue

            try:
                pid = insert_place(cursor, data)
                insert_imgs(cursor, pid, data['imgs'])
                conn.commit()
                total += 1
                print(f"  [OK] {data['name_en'][:45]} ({data['gov']}) | Rating:{data['rating']} | Imgs:{len(data['imgs'])}")
            except Exception as e:
                conn.rollback()
                print(f"  [ERR] {e}")

            time.sleep(random.uniform(2, 4))

    final = count_hotels(cursor)
    print(f"\n{'='*60}")
    print(f"[DONE] Added: {total} hotels | Total: {final}/{TARGET}")
    print("="*60)
    cursor.close()
    conn.close()


if __name__ == '__main__':
    main()
