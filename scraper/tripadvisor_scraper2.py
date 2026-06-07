# -*- coding: utf-8 -*-
"""
TripAdvisor Egypt Scraper - Extra Categories
Religious, Nature, Market, Cruise, Beach, Desert, Museum
"""
import sys
import asyncio
import random
import re
import pyodbc
from playwright.async_api import async_playwright
from deep_translator import GoogleTranslator

sys.stdout.reconfigure(encoding='utf-8')

DB_CONN_STR = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost,1433;"
    "DATABASE=DiscoverEgypt;"
    "UID=sa;"
    "PWD=YourPassword123!;"
    "TrustServerCertificate=yes;"
)

EGYPT_GEO_IDS = {
    '294200','294201','294202','297549','297550','297548',
    '297555','297551','297552','303855','15516847','424910',
    '19065385',
    # Luxor, Aswan, Alexandria - verified Egypt
    '190392','190393','190394',
}

# c49=Museums, c55=Religious, c57=Nature, c26=Shopping/Markets
# c61=Beaches, c36=Boat Tours(Cruise), c47=Outdoors(Desert)
TARGETS = [
    # Museums
    {"category": "museum", "governorate": "Cairo",
     "url": "https://www.tripadvisor.com/Attractions-g294201-Activities-c49-Cairo_Governorate.html"},
    {"category": "museum", "governorate": "Giza",
     "url": "https://www.tripadvisor.com/Attractions-g294202-Activities-c49-Giza_Governorate.html"},
    {"category": "museum", "governorate": "Alexandria",
     "url": "https://www.tripadvisor.com/Attractions-g190394-Activities-c49-Alexandria_Alexandria_Governorate.html"},
    {"category": "museum", "governorate": "Luxor",
     "url": "https://www.tripadvisor.com/Attractions-g190392-Activities-c49-Luxor_Luxor_Governorate.html"},

    # Religious
    {"category": "religious", "governorate": "Cairo",
     "url": "https://www.tripadvisor.com/Attractions-g294201-Activities-c55-Cairo_Governorate.html"},
    {"category": "religious", "governorate": "Giza",
     "url": "https://www.tripadvisor.com/Attractions-g294202-Activities-c55-Giza_Governorate.html"},
    {"category": "religious", "governorate": "Luxor",
     "url": "https://www.tripadvisor.com/Attractions-g190392-Activities-c55-Luxor_Luxor_Governorate.html"},
    {"category": "religious", "governorate": "Aswan",
     "url": "https://www.tripadvisor.com/Attractions-g190393-Activities-c55-Aswan_Aswan_Governorate.html"},

    # Nature
    {"category": "nature", "governorate": "Sinai",
     "url": "https://www.tripadvisor.com/Attractions-g297555-Activities-c57-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"},
    {"category": "nature", "governorate": "Red Sea",
     "url": "https://www.tripadvisor.com/Attractions-g297549-Activities-c57-Hurghada_Red_Sea_Governorate.html"},
    {"category": "nature", "governorate": "Aswan",
     "url": "https://www.tripadvisor.com/Attractions-g190393-Activities-c57-Aswan_Aswan_Governorate.html"},
    {"category": "nature", "governorate": "Sinai",
     "url": "https://www.tripadvisor.com/Attractions-g297551-Activities-c57-Dahab_South_Sinai_Red_Sea_Governorate.html"},

    # Market / Shopping
    {"category": "market", "governorate": "Cairo",
     "url": "https://www.tripadvisor.com/Attractions-g294201-Activities-c26-Cairo_Governorate.html"},
    {"category": "market", "governorate": "Luxor",
     "url": "https://www.tripadvisor.com/Attractions-g190392-Activities-c26-Luxor_Luxor_Governorate.html"},
    {"category": "market", "governorate": "Aswan",
     "url": "https://www.tripadvisor.com/Attractions-g190393-Activities-c26-Aswan_Aswan_Governorate.html"},
    {"category": "market", "governorate": "Sharm El Sheikh",
     "url": "https://www.tripadvisor.com/Attractions-g297555-Activities-c26-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"},

    # Beach
    {"category": "beach", "governorate": "South Sinai",
     "url": "https://www.tripadvisor.com/Attractions-g297555-Activities-c61-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"},
    {"category": "beach", "governorate": "Red Sea",
     "url": "https://www.tripadvisor.com/Attractions-g297549-Activities-c61-Hurghada_Red_Sea_Governorate.html"},
    {"category": "beach", "governorate": "South Sinai",
     "url": "https://www.tripadvisor.com/Attractions-g297551-Activities-c61-Dahab_South_Sinai_Red_Sea_Governorate.html"},
    {"category": "beach", "governorate": "Alexandria",
     "url": "https://www.tripadvisor.com/Attractions-g190394-Activities-c61-Alexandria_Alexandria_Governorate.html"},

    # Cruise / Boat (Nile)
    {"category": "cruise", "governorate": "Luxor",
     "url": "https://www.tripadvisor.com/Attractions-g190392-Activities-c36-Luxor_Luxor_Governorate.html"},
    {"category": "cruise", "governorate": "Aswan",
     "url": "https://www.tripadvisor.com/Attractions-g190393-Activities-c36-Aswan_Aswan_Governorate.html"},
    {"category": "cruise", "governorate": "Cairo",
     "url": "https://www.tripadvisor.com/Attractions-g294201-Activities-c36-Cairo_Governorate.html"},

    # Desert / Outdoor
    {"category": "desert", "governorate": "Giza",
     "url": "https://www.tripadvisor.com/Attractions-g294202-Activities-c61_t212-Giza_Governorate.html"},
    {"category": "desert", "governorate": "Sinai",
     "url": "https://www.tripadvisor.com/Attractions-g297555-Activities-c36-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"},
    {"category": "desert", "governorate": "Red Sea",
     "url": "https://www.tripadvisor.com/Attractions-g297549-Activities-c36-Hurghada_Red_Sea_Governorate.html"},
    {"category": "desert", "governorate": "Sinai",
     "url": "https://www.tripadvisor.com/Attractions-g297551-Activities-c36-Dahab_South_Sinai_Red_Sea_Governorate.html"},
]

PAGES_PER_TARGET = 2

TAGS_MAP = {
    'museum':   'museum,culture,history,Egypt,art',
    'religious':'mosque,church,temple,religion,Egypt',
    'nature':   'nature,wildlife,parks,Egypt,outdoors',
    'market':   'shopping,bazaar,market,Egypt,souvenirs',
    'beach':    'beach,sea,swimming,Egypt,coast',
    'cruise':   'nile,cruise,boat,Egypt,river',
    'desert':   'desert,safari,adventure,Egypt,dunes',
}


def is_egypt_url(url: str) -> bool:
    m = re.search(r'-g(\d+)-', url)
    return m and m.group(1) in EGYPT_GEO_IDS if m else False


def is_egypt_page(content: str) -> bool:
    signals = ['Egypt','Cairo','Giza','Luxor','Aswan','Alexandria',
               'Hurghada','Sharm','Sinai','Nile','Egyptian']
    return any(s in content[:8000] for s in signals)


def translate_to_arabic(text: str) -> str:
    if not text or len(text.strip()) < 3:
        return text
    try:
        return GoogleTranslator(source='en', target='ar').translate(text[:4500])
    except Exception:
        return text


def get_db():
    return pyodbc.connect(DB_CONN_STR)


def place_exists(cursor, name_en: str) -> bool:
    cursor.execute("SELECT COUNT(*) FROM Places WHERE name_en=?", name_en)
    return cursor.fetchone()[0] > 0


def insert_place(cursor, p: dict) -> int:
    cursor.execute("""
        INSERT INTO Places (name_en,name_ar,description_en,description_ar,
            category,governorate,latitude,longitude,address,
            admission_fee_egyptian,admission_fee_foreign,
            opening_hours_open,opening_hours_close,opening_hours_days,
            tags,is_featured,avg_rating,review_count,
            rating_1,rating_2,rating_3,rating_4,rating_5,created_at)
        OUTPUT INSERTED.id
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,GETDATE())
    """,
        p['name_en'],p['name_ar'],p['description_en'],p['description_ar'],
        p['category'],p['governorate'],p['latitude'],p['longitude'],p['address'],
        p['fee_egp'],p['fee_usd'],
        '09:00','18:00','Daily',
        p['tags'],p['is_featured'],p['avg_rating'],p['review_count'],
        0,0,0,max(0,p['review_count']//5),max(0,p['review_count']-p['review_count']//5),
    )
    return cursor.fetchone()[0]


def insert_images(cursor, pid: int, images: list):
    for i, url in enumerate(images[:3]):
        if url and url.startswith('http'):
            cursor.execute("INSERT INTO PlaceImages(place_id,image_url,sort_order) VALUES(?,?,?)", pid, url, i)


def insert_review(cursor, pid: int, rev: dict):
    # Skip review insertion - Reviews table requires a valid user_id FK
    # Place review stats are stored in Places.avg_rating and review_count already
    pass


async def rnd(a=2,b=5):
    await asyncio.sleep(random.uniform(a,b))


async def goto(page, url):
    for w in ['domcontentloaded','commit']:
        try:
            await page.goto(url, wait_until=w, timeout=35000)
            await rnd(1,2)
            return True
        except Exception:
            pass
    return False


async def get_links(page, category: str) -> list:
    pat_map = {
        'museum':'Attraction_Review','religious':'Attraction_Review',
        'nature':'Attraction_Review','market':'Attraction_Review',
        'beach':'Attraction_Review','cruise':'Attraction_Review',
        'desert':'Attraction_Review',
    }
    pat = pat_map.get(category, 'Attraction_Review')
    try:
        hrefs = await page.eval_on_selector_all('a[href]','els=>els.map(e=>e.href)')
        seen = set()
        links = []
        for h in hrefs:
            if pat in h:
                c = h.split('#')[0].split('?')[0]
                if c not in seen and is_egypt_url(c):
                    seen.add(c)
                    links.append(c)
        return links
    except Exception:
        return []


async def scrape_place(page, url, category, default_gov) -> dict | None:
    if not is_egypt_url(url):
        return None
    if not await goto(page, url):
        return None

    try:
        content = await page.content()
        if not is_egypt_page(content):
            return None
    except Exception:
        return None

    # Name
    name_en = ''
    for sel in ['h1','[data-automation="mainH1"]']:
        try:
            el = page.locator(sel).first
            if await el.count() > 0:
                t = (await el.inner_text()).strip()
                if len(t) > 2:
                    name_en = t
                    break
        except Exception:
            pass
    if not name_en:
        return None
    print(f"    {name_en[:55]}")

    # Description
    desc = ''
    for sel in ['[data-automation="OVERVIEW_TAB_ELEMENT"] .biGQs span','.fIrGe span','div[class*="bikleE"]']:
        try:
            el = page.locator(sel).first
            if await el.count() > 0:
                t = (await el.inner_text()).strip()
                if len(t) > 40:
                    desc = t
                    break
        except Exception:
            pass
    if not desc:
        try:
            desc = (await page.get_attribute('meta[name="description"]','content') or '').strip()
        except Exception:
            pass
    if not desc:
        desc = f"Discover this amazing {category} in Egypt."

    # Rating & reviews
    avg_rating, review_count = 4.0, 0
    try:
        c = await page.content()
        m = re.search(r'"ratingValue"[:\s]+"?([\d.]+)"?', c)
        if m: avg_rating = float(m.group(1))
        m2 = re.search(r'"reviewCount"[:\s]+(\d+)', c)
        if m2: review_count = int(m2.group(1))
        elif not m2:
            m3 = re.search(r'([\d,]+)\s+reviews?', c, re.I)
            if m3: review_count = int(m3.group(1).replace(',',''))
    except Exception:
        pass

    # Images
    images = []
    try:
        imgs = await page.query_selector_all('img')
        seen = set()
        for img in imgs:
            src = await img.get_attribute('src') or ''
            if (src.startswith('http') and src not in seen and
                any(x in src for x in ['media','photo','dynamic','upload']) and
                not any(x in src.lower() for x in ['avatar','logo','icon','flag'])):
                seen.add(src)
                images.append(src)
            if len(images) >= 3:
                break
    except Exception:
        pass

    # Geo & address
    lat, lng, address = 0.0, 0.0, ''
    try:
        c = await page.content()
        geo = re.search(r'"latitude"[:\s]+"?([\d.-]+)"?.*?"longitude"[:\s]+"?([\d.-]+)"?', c, re.DOTALL)
        if geo:
            lat, lng = float(geo.group(1)), float(geo.group(2))
        a = re.search(r'"streetAddress"[:\s]+"([^"]+)"', c)
        if a: address = a.group(1)
        elif not a:
            r = re.search(r'"addressRegion"[:\s]+"([^"]+)"', c)
            if r: address = r.group(1) + ', Egypt'
    except Exception:
        pass

    # Fees
    fee_egp, fee_usd = 0.0, 0.0
    try:
        c = await page.content()
        m = re.search(r'EGP\s*([\d,]+)', c)
        if m:
            fee_egp = float(m.group(1).replace(',',''))
            fee_usd = fee_egp / 50
        else:
            m = re.search(r'\$\s*(\d+)', c)
            if m:
                fee_usd = float(m.group(1))
                fee_egp = fee_usd * 50
    except Exception:
        pass

    # Reviews
    reviews = []
    try:
        cards = await page.query_selector_all('[data-automation="reviewCard"]')
        for card in cards[:3]:
            stars = 5
            try:
                sc = await card.query_selector('[class*="ui_bubble_rating"]')
                if sc:
                    cls = await sc.get_attribute('class') or ''
                    m = re.search(r'bubble_(\d+)', cls)
                    if m: stars = int(m.group(1)) // 10
            except Exception:
                pass
            text = ''
            try:
                for sel in ['[class*="yCeTE"]','q','p']:
                    t = await card.query_selector(sel)
                    if t:
                        text = (await t.inner_text()).strip()[:800]
                        if len(text) > 20: break
            except Exception:
                pass
            if text:
                reviews.append({'stars': stars, 'text': text})
    except Exception:
        pass

    # Translate
    print(f"    Translating...")
    name_ar = translate_to_arabic(name_en)
    desc_ar = translate_to_arabic(desc[:500])

    # Governorate refinement
    gov = default_gov
    al = (address + ' ' + name_en).lower()
    for k,v in {'cairo':'Cairo','giza':'Giza','luxor':'Luxor','aswan':'Aswan',
                'alexandria':'Alexandria','sharm':'South Sinai','hurghada':'Red Sea',
                'dahab':'South Sinai','sinai':'South Sinai','el gouna':'Red Sea'}.items():
        if k in al:
            gov = v
            break

    return {
        'name_en': name_en[:299], 'name_ar': name_ar[:299],
        'description_en': desc[:3000], 'description_ar': desc_ar[:3000],
        'category': category, 'governorate': gov,
        'latitude': lat, 'longitude': lng,
        'address': (address or 'Egypt')[:299],
        'fee_egp': fee_egp, 'fee_usd': fee_usd,
        'tags': TAGS_MAP.get(category, 'Egypt,travel'),
        'is_featured': avg_rating >= 4.5,
        'avg_rating': avg_rating, 'review_count': review_count,
        'images': images, 'reviews': reviews,
    }


async def main():
    print("="*60)
    print("TripAdvisor Egypt - Extra Categories")
    print("Museum | Religious | Nature | Market | Beach | Cruise | Desert")
    print("="*60)

    conn = get_db()
    cursor = conn.cursor()
    total = 0

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=False,
            args=['--disable-blink-features=AutomationControlled'],
        )
        ctx = await browser.new_context(
            viewport={'width':1280,'height':900},
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            locale='en-US',
        )
        await ctx.add_init_script("Object.defineProperty(navigator,'webdriver',{get:()=>undefined});")
        page = await ctx.new_page()

        print("Opening TripAdvisor...")
        await goto(page, "https://www.tripadvisor.com")
        await rnd(2,4)
        try:
            btn = page.locator('#onetrust-accept-btn-handler').first
            if await btn.count() > 0:
                await btn.click()
                await rnd(1,2)
        except Exception:
            pass

        for target in TARGETS:
            cat = target['category']
            gov = target['governorate']
            print(f"\n{'='*50}")
            print(f"{cat.upper()} - {gov}")
            print(f"{'='*50}")

            all_urls = []
            current_url = target['url']

            for pg in range(PAGES_PER_TARGET):
                print(f"  [Page {pg+1}]")
                if not await goto(page, current_url):
                    break
                await rnd(2,3)

                links = await get_links(page, cat)
                new = [l for l in links if l not in all_urls]
                all_urls.extend(new)
                print(f"    +{len(new)} links (total {len(all_urls)})")

                next_href = None
                for sel in ['a[aria-label="Next page"]','a.nav.next']:
                    try:
                        el = page.locator(sel).first
                        if await el.count() > 0:
                            next_href = await el.get_attribute('href')
                            if next_href: break
                    except Exception:
                        pass
                if next_href:
                    current_url = f"https://www.tripadvisor.com{next_href}" if next_href.startswith('/') else next_href
                else:
                    break

            print(f"  Scraping {len(all_urls)} places...")
            for i, url in enumerate(all_urls):
                print(f"\n  [{i+1}/{len(all_urls)}] {url[35:80]}")
                data = await scrape_place(page, url, cat, gov)
                if not data:
                    print("  Skipped")
                    continue
                if place_exists(cursor, data['name_en']):
                    print(f"  Exists: {data['name_en'][:40]}")
                    continue
                try:
                    pid = insert_place(cursor, data)
                    insert_images(cursor, pid, data['images'])
                    for rev in data.get('reviews',[]):
                        insert_review(cursor, pid, rev)
                    conn.commit()
                    total += 1
                    print(f"  [OK] {data['name_en'][:45]} -> ID:{pid} ({data['governorate']})")
                except Exception as e:
                    conn.rollback()
                    print(f"  [ERR] {e}")
                await rnd(2,4)

        await browser.close()

    cursor.close()
    conn.close()
    print(f"\n{'='*60}")
    print(f"[DONE] Inserted: {total} extra category places")
    print(f"{'='*60}")


if __name__ == '__main__':
    asyncio.run(main())
