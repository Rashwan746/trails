# -*- coding: utf-8 -*-
"""Attractions scraper (historical + museum) using requests - Egypt Only"""
import sys, time, random, re, json, pyodbc, requests
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

EGYPT_GEO_IDS = {
    '294200','294201','294202','297549','297550','297548',
    '297555','297551','297552','303855','15516847','424910','19065385',
}

EGYPT_KEYWORDS = [
    'Egypt','Cairo','Giza','Luxor','Aswan','Alexandria','Hurghada',
    'Sharm','Sinai','Nile','Egyptian','Pharaoh','Pharaonic','pyramid',
]

TARGET_COUNTS = {'historical': 50, 'museum': 60}

TARGETS = [
    # HISTORICAL (c47)
    ('historical', 'Cairo',    'https://www.tripadvisor.com/Attractions-g294201-Activities-c47-Cairo_Governorate.html'),
    ('historical', 'Giza',     'https://www.tripadvisor.com/Attractions-g294202-Activities-c47-Giza_Governorate.html'),
    ('historical', 'Egypt',    'https://www.tripadvisor.com/Attractions-g294200-Activities-c47-Egypt.html'),
    ('historical', 'Luxor',    'https://www.tripadvisor.com/Attractions-g297548-Activities-c47-Hurghada_Red_Sea_Governorate.html'),
    ('historical', 'Sharm',    'https://www.tripadvisor.com/Attractions-g297555-Activities-c47-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html'),
    # MUSEUM (c49)
    ('museum', 'Cairo',    'https://www.tripadvisor.com/Attractions-g294201-Activities-c49-Cairo_Governorate.html'),
    ('museum', 'Giza',     'https://www.tripadvisor.com/Attractions-g294202-Activities-c49-Giza_Governorate.html'),
    ('museum', 'Egypt',    'https://www.tripadvisor.com/Attractions-g294200-Activities-c49-Egypt.html'),
    ('museum', 'Hurghada', 'https://www.tripadvisor.com/Attractions-g297549-Activities-c49-Hurghada_Red_Sea_Governorate.html'),
    ('museum', 'Sharm',    'https://www.tripadvisor.com/Attractions-g297555-Activities-c49-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html'),
]

TAGS_MAP = {
    'historical': 'history,ancient,culture,Egypt,heritage',
    'museum':     'museum,culture,history,Egypt,art',
}

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

def is_egypt_url(url):
    m = re.search(r'-g(\d+)-', url)
    return bool(m and m.group(1) in EGYPT_GEO_IDS)

def get_page(url, retries=3):
    for _ in range(retries):
        try:
            time.sleep(random.uniform(2, 5))
            r = requests.get(url, headers=HEADERS, timeout=20)
            if r.status_code == 200:
                return r.text
            print(f"  HTTP {r.status_code}")
        except Exception as e:
            print(f"  Error: {e}")
    return None

def extract_attraction_links(html):
    soup = BeautifulSoup(html, 'html.parser')
    links, seen = [], set()
    for a in soup.find_all('a', href=True):
        href = a['href']
        if '/Attraction_Review' in href:
            if href.startswith('/'):
                href = 'https://www.tripadvisor.com' + href
            clean = href.split('#')[0].split('?')[0]
            if clean not in seen and is_egypt_url(clean):
                seen.add(clean)
                links.append(clean)
    return links

def get_next_page(html, base_url):
    """Try to find next page URL"""
    soup = BeautifulSoup(html, 'html.parser')
    # Look for pagination 'next' link
    for a in soup.find_all('a', href=True):
        txt = (a.get_text(strip=True) or '').lower()
        cls = ' '.join(a.get('class', []))
        aria = a.get('aria-label', '').lower()
        if 'next' in aria or 'next' in txt or 'nav next' in cls:
            href = a['href']
            if href.startswith('/'):
                return 'https://www.tripadvisor.com' + href
    # Pattern-based: replace -oa0- with -oa30-, -oa30- with -oa60-, etc.
    m = re.search(r'-oa(\d+)-', base_url)
    if m:
        offset = int(m.group(1)) + 30
        return base_url.replace(f'-oa{m.group(1)}-', f'-oa{offset}-')
    else:
        # Insert offset before last .html
        return base_url.replace('.html', '-oa30.html')

def translate_ar(text):
    if not text or len(text.strip()) < 3: return text
    try: return GoogleTranslator(source='en', target='ar').translate(text[:4500])
    except: return text

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
    cat,gov,d['lat'],d['lng'],d['addr'],
    d['fee_egp'],d['fee_usd'],'09:00','18:00','Daily',
    TAGS_MAP.get(cat,'Egypt,culture'),d['rating']>=4.5,d['rating'],d['reviews'],
    0,0,0,max(0,d['reviews']//5),max(0,d['reviews']-d['reviews']//5))
    return cur.fetchone()[0]

def insert_imgs(cur, pid, imgs):
    for i, u in enumerate(imgs[:3]):
        if u and u.startswith('http'):
            cur.execute("INSERT INTO PlaceImages(place_id,image_url,sort_order)VALUES(?,?,?)", pid, u, i)

def scrape_attraction(url, default_gov):
    html = get_page(url)
    if not html: return None
    if not any(kw in html[:12000] for kw in EGYPT_KEYWORDS):
        print("  Not Egypt - skip")
        return None

    soup = BeautifulSoup(html, 'html.parser')

    # Name
    name = ''
    h1 = soup.find('h1')
    if h1: name = h1.get_text(strip=True)
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
    if not desc: desc = f"A remarkable historical site in {default_gov}, Egypt."

    # Rating + reviews
    rating, reviews = 4.0, 0
    m = re.search(r'"ratingValue"[:\s]+"?([\d.]+)"?', html)
    if m: rating = float(m.group(1))
    m2 = re.search(r'"reviewCount"[:\s]+(\d+)', html)
    if m2: reviews = int(m2.group(1))
    else:
        m3 = re.search(r'([\d,]+)\s+reviews?', html, re.I)
        if m3: reviews = int(m3.group(1).replace(',', ''))

    # Images
    images, seen_imgs = [], set()
    for og in soup.find_all('meta', property='og:image'):
        src = og.get('content', '')
        if src.startswith('http') and src not in seen_imgs:
            seen_imgs.add(src); images.append(src)
    for script in soup.find_all('script', type='application/ld+json'):
        try:
            d = json.loads(script.string or '{}')
            if isinstance(d, list): d = d[0] if d else {}
            img = d.get('image', [])
            if isinstance(img, str): img = [img]
            for i in img:
                u = i if isinstance(i, str) else i.get('url','')
                if u.startswith('http') and u not in seen_imgs:
                    seen_imgs.add(u); images.append(u)
        except: pass
    if len(images) < 3:
        for img_tag in soup.find_all('img', src=True):
            src = img_tag['src']
            if (src.startswith('http') and src not in seen_imgs and
                any(x in src for x in ['media','photo','dynamic','upload']) and
                not any(x in src.lower() for x in ['avatar','logo','icon','flag'])):
                seen_imgs.add(src); images.append(src)
            if len(images) >= 3: break

    # Coords + address
    lat, lng, addr = 0.0, 0.0, ''
    g = re.search(r'"latitude"[:\s]+"?([\d.-]+)"?.*?"longitude"[:\s]+"?([\d.-]+)"?', html, re.DOTALL)
    if g: lat, lng = float(g.group(1)), float(g.group(2))
    a = re.search(r'"streetAddress"[:\s]+"([^"]+)"', html)
    if a: addr = a.group(1)
    if not addr:
        a2 = re.search(r'"addressRegion"[:\s]+"([^"]+)"', html)
        if a2: addr = a2.group(1) + ', Egypt'

    # Fees
    fee_egp, fee_usd = 0.0, 0.0
    m = re.search(r'EGP\s*([\d,]+)', html)
    if m: fee_egp = float(m.group(1).replace(',','')); fee_usd = fee_egp/50
    else:
        m2 = re.search(r'\$\s*(\d+)', html)
        if m2: fee_usd = float(m2.group(1)); fee_egp = fee_usd * 50

    print(f"  Translating...")
    name_ar = translate_ar(name)
    desc_ar = translate_ar(desc[:500])

    # Gov from address
    gov = default_gov
    al = (addr + ' ' + name + ' ' + html[:3000]).lower()
    for k, v in GOV_MAP.items():
        if k in al: gov = v; break

    return dict(
        name_en=name[:299], name_ar=name_ar[:299],
        desc_en=desc[:3000], desc_ar=desc_ar[:3000],
        addr=(addr or default_gov + ', Egypt')[:299],
        lat=lat, lng=lng, fee_egp=fee_egp, fee_usd=fee_usd,
        rating=rating, reviews=reviews, imgs=images,
    )


def main():
    print("="*60)
    print("Attractions Scraper (requests) - historical->50, museum->60")
    print("="*60)

    conn = get_db(); cursor = conn.cursor(); total = 0

    for cat, default_gov, list_url in TARGETS:
        current = count_cat(cursor, cat)
        target = TARGET_COUNTS[cat]
        if current >= target:
            print(f"\n[SKIP] {cat}: {current}/{target} reached")
            continue

        print(f"\n{'='*50}")
        print(f"{cat.upper()} - {default_gov} | {current}/{target}")
        print(f"{'='*50}")

        all_links = []
        cur_url = list_url
        for page_num in range(4):
            html = get_page(cur_url)
            if not html:
                print(f"  Failed to load page {page_num+1}")
                break
            links = extract_attraction_links(html)
            new = [l for l in links if l not in all_links]
            all_links.extend(new)
            print(f"  [Page {page_num+1}] +{len(new)} Egypt links (total: {len(all_links)})")
            if len(new) == 0:
                break
            cur_url = get_next_page(html, cur_url)
            if not cur_url: break

        for i, url in enumerate(all_links):
            current = count_cat(cursor, cat)
            if current >= target:
                print(f"  [TARGET REACHED] {cat}: {current}/{target}"); break

            print(f"\n  [{i+1}/{len(all_links)}] ({current}/{target})")
            print(f"  {url[35:80]}")

            data = scrape_attraction(url, default_gov)
            if not data:
                print("  Skipped"); continue

            if exists(cursor, data['name_en']):
                print(f"  Exists: {data['name_en'][:40]}"); continue

            try:
                pid = insert_place(cursor, cat, data['addr'] and GOV_MAP.get(
                    next((k for k in GOV_MAP if k in data['addr'].lower()), ''), default_gov
                ) or default_gov, data)
                insert_imgs(cursor, pid, data['imgs'])
                conn.commit(); total += 1
                print(f"  [OK] {data['name_en'][:45]} | Rating:{data['rating']} | Imgs:{len(data['imgs'])}")
            except Exception as e:
                conn.rollback(); print(f"  [ERR] {e}")

            time.sleep(random.uniform(1.5, 3.5))

    print(f"\n{'='*60}")
    print(f"[DONE] Added: {total}")
    for cat, tgt in TARGET_COUNTS.items():
        print(f"  {cat}: {count_cat(cursor, cat)}/{tgt}")
    cursor.close(); conn.close()
    print("="*60)


if __name__ == '__main__':
    main()
