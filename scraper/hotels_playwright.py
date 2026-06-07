# -*- coding: utf-8 -*-
"""
Egypt Hotels Playwright Scraper (headless=False, off-screen window)
Uses a tiny off-screen browser window - user won't see it
"""
import sys, asyncio, random, re, pyodbc
from playwright.async_api import async_playwright
from deep_translator import GoogleTranslator

sys.stdout.reconfigure(encoding='utf-8')

DB_CONN_STR = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost,1433;DATABASE=DiscoverEgypt;"
    "UID=sa;PWD=YourPassword123!;TrustServerCertificate=yes;"
)

TARGET = 50

EGYPT_GEO_IDS = {
    '294200','294201','294202','297549','297550','297548',
    '297555','297551','297552','303855','15516847','424910','19065385',
    '190392','190393','190394',  # Luxor, Aswan, Alexandria
}

EGYPT_KEYWORDS = [
    'Egypt','Cairo','Giza','Hurghada','Sharm','Sinai',
    'Red Sea','Nile','Luxor','Aswan','Alexandria'
]

# Hotels listing URLs - city level only (confirmed Egypt geo IDs)
HOTEL_LISTING_URLS = [
    ("Cairo",        "https://www.tripadvisor.com/Hotels-g294201-Cairo_Governorate-Hotels.html"),
    ("Hurghada",     "https://www.tripadvisor.com/Hotels-g297549-Hurghada_Red_Sea_Governorate-Hotels.html"),
    ("Sharm",        "https://www.tripadvisor.com/Hotels-g297555-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate-Hotels.html"),
    ("Giza",         "https://www.tripadvisor.com/Hotels-g294202-Giza_Governorate-Hotels.html"),
    ("Dahab",        "https://www.tripadvisor.com/Hotels-g297551-Dahab_South_Sinai_Red_Sea_Governorate-Hotels.html"),
    ("El Gouna",     "https://www.tripadvisor.com/Hotels-g297548-El_Gouna_Red_Sea_Governorate-Hotels.html"),
    ("Marsa Alam",   "https://www.tripadvisor.com/Hotels-g297552-Marsa_Alam_Red_Sea_Governorate-Hotels.html"),
    ("Makadi",       "https://www.tripadvisor.com/Hotels-g297550-Makadi_Bay_Red_Sea_Governorate-Hotels.html"),
    ("Sahl Hasheesh","https://www.tripadvisor.com/Hotels-g15516847-Sahl_Hasheesh_Red_Sea_Governorate-Hotels.html"),
    ("Luxor",        "https://www.tripadvisor.com/Hotels-g190392-Luxor_Luxor_Governorate-Hotels.html"),
    ("Aswan",        "https://www.tripadvisor.com/Hotels-g190393-Aswan_Aswan_Governorate-Hotels.html"),
    ("Alexandria",   "https://www.tripadvisor.com/Hotels-g190394-Alexandria_Alexandria_Governorate-Hotels.html"),
]

GOV_MAP = {
    'cairo':'Cairo','giza':'Giza','sharm':'South Sinai','hurghada':'Red Sea',
    'dahab':'South Sinai','el gouna':'Red Sea','marsa':'Red Sea',
    'makadi':'Red Sea','sahl':'Red Sea','luxor':'Luxor','aswan':'Aswan',
    'alexandria':'Alexandria','sinai':'South Sinai',
}


def get_db(): return pyodbc.connect(DB_CONN_STR)
def count_hotels(cur):
    cur.execute("SELECT COUNT(*) FROM Places WHERE category='hotel'")
    return cur.fetchone()[0]
def exists(cur, name):
    cur.execute("SELECT COUNT(*) FROM Places WHERE name_en=?", name)
    return cur.fetchone()[0] > 0

def is_egypt_url(url):
    m = re.search(r'-g(\d+)-', url)
    return bool(m and m.group(1) in EGYPT_GEO_IDS)

def translate_ar(text):
    if not text or len(text.strip()) < 3: return text
    try: return GoogleTranslator(source='en', target='ar').translate(text[:4500])
    except: return text

async def rnd(a=2, b=5): await asyncio.sleep(random.uniform(a, b))

async def goto(page, url):
    for wait in ['domcontentloaded', 'commit']:
        try:
            await page.goto(url, wait_until=wait, timeout=40000)
            await rnd(1, 2); return True
        except: pass
    return False

async def get_hotel_links(page):
    try:
        hrefs = await page.eval_on_selector_all('a[href]', 'els=>els.map(e=>e.href)')
        seen, links = set(), []
        for h in hrefs:
            if 'Hotel_Review' in h:
                c = h.split('#')[0].split('?')[0]
                if c not in seen and is_egypt_url(c):
                    seen.add(c); links.append(c)
        return links
    except: return []

async def scrape_hotel(page, url, default_gov):
    if not is_egypt_url(url): return None
    if not await goto(page, url): return None

    try:
        content = await page.content()
        if not any(kw in content[:12000] for kw in EGYPT_KEYWORDS):
            print(f"    Not Egypt - skip"); return None
    except: return None

    # Name
    name = ''
    for sel in ['h1', '[data-automation="mainH1"]', 'h1[class*="header"]']:
        try:
            el = page.locator(sel).first
            if await el.count() > 0:
                t = (await el.inner_text()).strip()
                if len(t) > 2: name = t; break
        except: pass
    if not name: return None
    print(f"    {name[:55]}")

    # Description
    desc = ''
    for sel in ['[data-automation="OVERVIEW_TAB_ELEMENT"] .biGQs span', 'meta[name="description"]']:
        try:
            if 'meta' in sel:
                desc = (await page.get_attribute(sel, 'content') or '').strip()
            else:
                el = page.locator(sel).first
                if await el.count() > 0:
                    t = (await el.inner_text()).strip()
                    if len(t) > 40: desc = t; break
        except: pass
    if not desc:
        try: desc = (await page.get_attribute('meta[name="description"]', 'content') or '').strip()
        except: pass
    if not desc: desc = f"A wonderful hotel in {default_gov}, Egypt."

    # Rating + reviews
    avg, revs = 4.0, 0
    try:
        c = await page.content()
        m = re.search(r'"ratingValue"[:\s]+"?([\d.]+)"?', c)
        if m: avg = float(m.group(1))
        m2 = re.search(r'"reviewCount"[:\s]+(\d+)', c)
        if m2: revs = int(m2.group(1))
        else:
            m3 = re.search(r'([\d,]+)\s+reviews?', c, re.I)
            if m3: revs = int(m3.group(1).replace(',', ''))
    except: pass

    # Images
    imgs = []
    try:
        els = await page.query_selector_all('img')
        seen = set()
        for el in els:
            src = await el.get_attribute('src') or ''
            if (src.startswith('http') and src not in seen and
                any(x in src for x in ['media', 'photo', 'dynamic', 'upload']) and
                not any(x in src.lower() for x in ['avatar', 'logo', 'icon', 'flag'])):
                seen.add(src); imgs.append(src)
            if len(imgs) >= 3: break
    except: pass

    # Address + coords
    addr, lat, lng = default_gov + ', Egypt', 0.0, 0.0
    try:
        c = await page.content()
        a = re.search(r'"streetAddress"[:\s]+"([^"]+)"', c)
        if a: addr = a.group(1)
        g = re.search(r'"latitude"[:\s]+"?([\d.-]+)"?.*?"longitude"[:\s]+"?([\d.-]+)"?', c, re.DOTALL)
        if g: lat, lng = float(g.group(1)), float(g.group(2))
    except: pass

    # Price
    price = 0.0
    try:
        c = await page.content()
        m = re.search(r'\$\s*(\d+)', c)
        if m: price = float(m.group(1))
    except: pass

    # Gov
    gov = default_gov
    al = (addr + url + name).lower()
    for k, v in GOV_MAP.items():
        if k in al: gov = v; break

    print(f"    Translating...")
    name_ar = translate_ar(name)
    desc_ar = translate_ar(desc[:500])

    return dict(
        name_en=name[:299], name_ar=name_ar[:299],
        desc_en=desc[:3000], desc_ar=desc_ar[:3000],
        gov=gov, addr=addr[:299], lat=lat, lng=lng,
        avg=avg, revs=revs, price=price, imgs=imgs,
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
    'hotel',d['gov'],d['lat'],d['lng'],d['addr'],
    0.0,d['price'],'00:00','23:59','Daily',
    'accommodation,stay,hotel,Egypt,luxury',
    d['avg']>=4.5,d['avg'],d['revs'],
    0,0,0,max(0,d['revs']//5),max(0,d['revs']-d['revs']//5))
    return cur.fetchone()[0]

def insert_imgs(cur, pid, imgs):
    for i, u in enumerate(imgs[:3]):
        if u and u.startswith('http'):
            cur.execute("INSERT INTO PlaceImages(place_id,image_url,sort_order)VALUES(?,?,?)", pid, u, i)


async def main():
    print("="*60)
    print("Egypt Hotels Playwright - headless=False offscreen - Target:50")
    print("="*60)

    conn = get_db(); cursor = conn.cursor(); total = 0

    async with async_playwright() as p:
        # headless=False but window is positioned off-screen and very small
        browser = await p.chromium.launch(
            headless=False,
            args=[
                '--disable-blink-features=AutomationControlled',
                '--no-sandbox',
                '--disable-dev-shm-usage',
                '--window-position=-10000,-10000',  # Off-screen
                '--window-size=1,1',                 # Tiny
                '--start-minimized',                 # Minimized
            ]
        )
        ctx = await browser.new_context(
            viewport={'width': 1280, 'height': 900},
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36',
            locale='en-US'
        )
        await ctx.add_init_script("Object.defineProperty(navigator,'webdriver',{get:()=>undefined});")
        page = await ctx.new_page()

        print("Opening TripAdvisor...")
        await goto(page, "https://www.tripadvisor.com")
        await rnd(2, 4)
        try:
            btn = page.locator('#onetrust-accept-btn-handler').first
            if await btn.count() > 0: await btn.click(); await rnd(1, 2)
        except: pass

        for city, list_url in HOTEL_LISTING_URLS:
            current = count_hotels(cursor)
            if current >= TARGET:
                print(f"\n[DONE] {current}/{TARGET} hotels!"); break

            print(f"\n{'='*50}")
            print(f"HOTEL - {city} | {current}/{TARGET}")

            if not await goto(page, list_url): continue
            await rnd(2, 3)

            links = await get_hotel_links(page)
            print(f"  Found {len(links)} Egypt hotel links")

            for i, url in enumerate(links):
                current = count_hotels(cursor)
                if current >= TARGET:
                    print(f"  [TARGET] {current}/{TARGET}"); break

                print(f"\n  [{i+1}/{len(links)}] ({current}/{TARGET})")
                data = await scrape_hotel(page, url, city)
                if not data: print("  Skipped"); continue

                if exists(cursor, data['name_en']):
                    print(f"  Exists: {data['name_en'][:40]}"); continue

                try:
                    pid = insert_place(cursor, data)
                    insert_imgs(cursor, pid, data['imgs'])
                    conn.commit(); total += 1
                    print(f"  [OK] {data['name_en'][:45]} | Imgs:{len(data['imgs'])}")
                except Exception as e:
                    conn.rollback(); print(f"  [ERR] {e}")

                await rnd(2, 4)

        await browser.close()

    final = count_hotels(cursor)
    print(f"\n{'='*60}")
    print(f"[DONE] Added: {total} | Total: {final}/{TARGET}")
    print("="*60)
    cursor.close(); conn.close()


if __name__ == '__main__':
    asyncio.run(main())
