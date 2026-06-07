# -*- coding: utf-8 -*-
"""Hotel scraper from Booking.com - Egypt Only"""
import sys, time, random, re, json, pyodbc, requests
from deep_translator import GoogleTranslator
from bs4 import BeautifulSoup

sys.stdout.reconfigure(encoding='utf-8')

DB_CONN_STR = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost,1433;DATABASE=DiscoverEgypt;"
    "UID=sa;PWD=YourPassword123!;TrustServerCertificate=yes;"
)

TARGET = 50

SESSION = requests.Session()
SESSION.headers.update({
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'Referer': 'https://www.booking.com/',
    'Cache-Control': 'max-age=0',
})

# Booking.com search URLs for Egyptian cities
CITY_SEARCHES = [
    ('Cairo',       'https://www.booking.com/searchresults.html?dest_id=-549517&dest_type=city&ss=Cairo%2C+Egypt&lang=en-us'),
    ('Sharm',       'https://www.booking.com/searchresults.html?dest_id=-549543&dest_type=city&ss=Sharm+El+Sheikh&lang=en-us'),
    ('Hurghada',    'https://www.booking.com/searchresults.html?dest_id=-549538&dest_type=city&ss=Hurghada&lang=en-us'),
    ('Giza',        'https://www.booking.com/searchresults.html?dest_id=-549522&dest_type=city&ss=Giza%2C+Egypt&lang=en-us'),
    ('Dahab',       'https://www.booking.com/searchresults.html?dest_id=-549518&dest_type=city&ss=Dahab%2C+Egypt&lang=en-us'),
    ('El Gouna',    'https://www.booking.com/searchresults.html?dest_id=-549519&dest_type=city&ss=El+Gouna%2C+Egypt&lang=en-us'),
    ('Marsa Alam',  'https://www.booking.com/searchresults.html?dest_id=-549532&dest_type=city&ss=Marsa+Alam%2C+Egypt&lang=en-us'),
    ('Luxor',       'https://www.booking.com/searchresults.html?dest_id=-549530&dest_type=city&ss=Luxor%2C+Egypt&lang=en-us'),
    ('Aswan',       'https://www.booking.com/searchresults.html?dest_id=-549516&dest_type=city&ss=Aswan%2C+Egypt&lang=en-us'),
    ('Alexandria',  'https://www.booking.com/searchresults.html?dest_id=-549514&dest_type=city&ss=Alexandria%2C+Egypt&lang=en-us'),
]

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
            r = SESSION.get(url, timeout=20)
            if r.status_code == 200:
                return r.text
            print(f"  HTTP {r.status_code}")
        except Exception as e:
            print(f"  Error: {e}")
    return None

def extract_hotel_links(html, city):
    soup = BeautifulSoup(html, 'html.parser')
    links, seen = [], set()
    for a in soup.find_all('a', href=True):
        href = a['href']
        if '/hotel/' in href and '.html' in href:
            if href.startswith('/'):
                href = 'https://www.booking.com' + href
            clean = href.split('?')[0].split('#')[0]
            if 'booking.com/hotel/' in clean and clean not in seen:
                seen.add(clean)
                links.append(clean)
    return links

def scrape_hotel_page(url, default_gov):
    html = get_page(url)
    if not html: return None

    # Validate it's Egypt
    egypt_check = html[:15000]
    if not any(s in egypt_check for s in ['Egypt','Cairo','Giza','Hurghada','Sharm','Sinai','Red Sea','Nile','Luxor','Aswan','Alexandria']):
        print("  Not Egypt - skip")
        return None

    soup = BeautifulSoup(html, 'html.parser')

    # Name
    name = ''
    h1 = soup.find('h1', id='hp_hotel_name') or soup.find('h1', class_=re.compile(r'hotel.*name|pp-header', re.I))
    if not h1:
        h1 = soup.find('h1')
    if h1: name = h1.get_text(strip=True)
    if not name:
        # Try meta og:title
        og = soup.find('meta', property='og:title')
        if og: name = og.get('content', '').strip()
    if not name or len(name) < 3: return None
    print(f"  Name: {name[:55]}")

    # Description from meta
    desc = ''
    meta = soup.find('meta', attrs={'name': 'description'})
    if meta: desc = meta.get('content', '').strip()
    if not desc or len(desc) < 30:
        og_d = soup.find('meta', property='og:description')
        if og_d: desc = og_d.get('content', '').strip()
    if not desc:
        # Try hotel description div
        for cls in ['hotel_description', 'hotel-description', 'property-description']:
            div = soup.find('div', class_=cls)
            if div:
                desc = div.get_text(strip=True)[:500]
                break
    if not desc:
        desc = f"A wonderful hotel in {default_gov}, Egypt offering comfort and hospitality."

    # Rating (Booking.com uses 0-10 scale)
    rating = 4.0
    m = re.search(r'"ratingValue"[:\s]+"?([\d.]+)"?', html)
    if m:
        v = float(m.group(1))
        rating = v / 2.0 if v > 5 else v  # convert 8.5/10 → 4.25/5
    else:
        m2 = re.search(r'class="[^"]*score[^"]*"[^>]*>(\d+\.?\d*)', html)
        if m2:
            v = float(m2.group(1))
            rating = min(5.0, v / 2.0 if v > 5 else v)

    # Review count
    reviews = 0
    m = re.search(r'"reviewCount"[:\s]+(\d+)', html)
    if m: reviews = int(m.group(1))
    else:
        m2 = re.search(r'([\d,]+)\s+(?:reviews?|ratings?)', html, re.I)
        if m2: reviews = int(m2.group(1).replace(',',''))

    # Images
    images, seen_imgs = [], set()
    for og in soup.find_all('meta', property='og:image'):
        src = og.get('content', '')
        if src.startswith('http') and src not in seen_imgs:
            seen_imgs.add(src); images.append(src)
    if len(images) < 3:
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
                if len(images) >= 3: break
            except: pass
    if len(images) < 3:
        for img in soup.find_all('img', src=True):
            src = img['src']
            if (src.startswith('http') and src not in seen_imgs and
                any(x in src for x in ['bstatic','hotel','photo','image']) and
                not any(x in src.lower() for x in ['avatar','logo','icon','flag','thumb'])):
                seen_imgs.add(src); images.append(src)
            if len(images) >= 3: break

    # Price
    price = 0.0
    m = re.search(r'[\$£€]\s*(\d+)', html)
    if m: price = float(m.group(1))

    # Address
    addr = default_gov + ', Egypt'
    m = re.search(r'"streetAddress"[:\s]+"([^"]+)"', html)
    if m: addr = m.group(1)
    else:
        m2 = re.search(r'data-address="([^"]+)"', html)
        if m2: addr = m2.group(1)

    # Governorate
    gov_map = {
        'cairo':'Cairo','giza':'Giza','sharm':'South Sinai','hurghada':'Red Sea',
        'dahab':'South Sinai','el gouna':'Red Sea','marsa':'Red Sea',
        'luxor':'Luxor','aswan':'Aswan','alexandria':'Alexandria',
        'sinai':'South Sinai','red sea':'Red Sea',
    }
    al = (addr + ' ' + name).lower()
    gov = default_gov
    for k, v in gov_map.items():
        if k in al: gov = v; break

    print(f"  Translating...")
    name_ar = translate_ar(name)
    desc_ar = translate_ar(desc[:500])

    return dict(
        name_en=name[:299], name_ar=name_ar[:299],
        desc_en=desc[:3000], desc_ar=desc_ar[:3000],
        gov=gov, addr=addr[:299],
        rating=max(0.0, min(5.0, rating)),
        reviews=reviews, price=price, imgs=images,
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
    print("Booking.com Hotel Scraper - Egypt Only - Target: 50")
    print("="*60)

    conn = get_db(); cursor = conn.cursor(); total = 0

    # Initialize session (get cookies)
    print("Initializing session...")
    r = SESSION.get("https://www.booking.com/country/eg.html", timeout=20)
    print(f"  Session init: HTTP {r.status_code}")
    time.sleep(2)

    for city, search_url in CITY_SEARCHES:
        current = count_hotels(cursor)
        if current >= TARGET:
            print(f"\n[DONE] {current}/{TARGET} hotels!"); break

        print(f"\n{'='*50}")
        print(f"HOTEL - {city} | {current}/{TARGET}")
        print(f"{'='*50}")

        html = get_page(search_url)
        if not html:
            print(f"  Failed listing for {city}"); continue

        links = extract_hotel_links(html, city)
        print(f"  Found {len(links)} hotel links")

        for i, url in enumerate(links):
            current = count_hotels(cursor)
            if current >= TARGET:
                print(f"  [TARGET] {current}/{TARGET}"); break

            print(f"\n  [{i+1}/{len(links)}] ({current}/{TARGET})")
            print(f"  {url[30:80]}")

            data = scrape_hotel_page(url, city)
            if not data:
                print("  Skipped"); continue

            if exists(cursor, data['name_en']):
                print(f"  Exists: {data['name_en'][:40]}"); continue

            try:
                pid = insert_place(cursor, data)
                insert_imgs(cursor, pid, data['imgs'])
                conn.commit(); total += 1
                print(f"  [OK] {data['name_en'][:45]} ({data['gov']}) | Imgs:{len(data['imgs'])}")
            except Exception as e:
                conn.rollback(); print(f"  [ERR] {e}")

            time.sleep(random.uniform(2, 4))

    final = count_hotels(cursor)
    print(f"\n{'='*60}")
    print(f"[DONE] Added: {total} | Total hotels: {final}/{TARGET}")
    print("="*60)
    cursor.close(); conn.close()


if __name__ == '__main__':
    main()
