# -*- coding: utf-8 -*-
"""Boost Historical to 50, Hotel to 50, Museum to 60 - Egypt Only"""
import sys, asyncio, random, re, pyodbc
from playwright.async_api import async_playwright
from deep_translator import GoogleTranslator

sys.stdout.reconfigure(encoding='utf-8')

DB_CONN_STR = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost,1433;DATABASE=DiscoverEgypt;"
    "UID=sa;PWD=YourPassword123!;TrustServerCertificate=yes;"
)

# Only geo IDs confirmed to be in Egypt
EGYPT_GEO_IDS = {
    '294200','294201','294202',   # Egypt, Cairo, Giza
    '297549','297550','297548',   # Hurghada, Makadi, El Gouna
    '297555','297551','297552',   # Sharm, Dahab, Marsa Alam
    '303855','15516847','424910', # Safaga, Sahl Hasheesh, Sidi Heneish
    '19065385',                   # 6th October
}

# Only use URLs we confirmed return Egypt content
TARGETS = [
    # HISTORICAL - confirmed Egypt geo IDs only
    {"category": "historical", "gov": "Cairo",
     "url": "https://www.tripadvisor.com/Attractions-g294201-Activities-c47-Cairo_Governorate.html"},
    {"category": "historical", "gov": "Giza",
     "url": "https://www.tripadvisor.com/Attractions-g294202-Activities-c47-Giza_Governorate.html"},
    {"category": "historical", "gov": "Egypt",
     "url": "https://www.tripadvisor.com/Attractions-g294200-Activities-c47-Egypt.html"},
    {"category": "historical", "gov": "Sharm El Sheikh",
     "url": "https://www.tripadvisor.com/Attractions-g297555-Activities-c47-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"},
    {"category": "historical", "gov": "Red Sea",
     "url": "https://www.tripadvisor.com/Attractions-g297549-Activities-c47-Hurghada_Red_Sea_Governorate.html"},

    # HOTEL - confirmed Egypt geo IDs only
    {"category": "hotel", "gov": "Hurghada",
     "url": "https://www.tripadvisor.com/Hotels-g297549-Hurghada_Red_Sea_Governorate-Hotels.html"},
    {"category": "hotel", "gov": "Sharm El Sheikh",
     "url": "https://www.tripadvisor.com/Hotels-g297555-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate-Hotels.html"},
    {"category": "hotel", "gov": "Cairo",
     "url": "https://www.tripadvisor.com/Hotels-g294201-Cairo_Governorate-Hotels.html"},
    {"category": "hotel", "gov": "Dahab",
     "url": "https://www.tripadvisor.com/Hotels-g297551-Dahab_South_Sinai_Red_Sea_Governorate-Hotels.html"},
    {"category": "hotel", "gov": "El Gouna",
     "url": "https://www.tripadvisor.com/Hotels-g297548-El_Gouna_Red_Sea_Governorate-Hotels.html"},
    {"category": "hotel", "gov": "Marsa Alam",
     "url": "https://www.tripadvisor.com/Hotels-g297552-Marsa_Alam_Red_Sea_Governorate-Hotels.html"},

    # MUSEUM - confirmed Egypt geo IDs only
    {"category": "museum", "gov": "Cairo",
     "url": "https://www.tripadvisor.com/Attractions-g294201-Activities-c49-Cairo_Governorate.html"},
    {"category": "museum", "gov": "Giza",
     "url": "https://www.tripadvisor.com/Attractions-g294202-Activities-c49-Giza_Governorate.html"},
    {"category": "museum", "gov": "Egypt",
     "url": "https://www.tripadvisor.com/Attractions-g294200-Activities-c49-Egypt.html"},
    {"category": "museum", "gov": "Hurghada",
     "url": "https://www.tripadvisor.com/Attractions-g297549-Activities-c49-Hurghada_Red_Sea_Governorate.html"},
    {"category": "museum", "gov": "Sharm El Sheikh",
     "url": "https://www.tripadvisor.com/Attractions-g297555-Activities-c49-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"},
]

TARGET_COUNTS = {'historical': 50, 'hotel': 50, 'museum': 60}
PAGES_PER = 4

TAGS_MAP = {
    'historical': 'history,ancient,culture,Egypt,heritage',
    'hotel':      'accommodation,stay,hotel,Egypt,luxury',
    'museum':     'museum,culture,history,Egypt,art',
}

GOV_MAP = {
    'cairo':'Cairo','giza':'Giza','luxor':'Luxor','aswan':'Aswan',
    'alexandria':'Alexandria','sharm':'South Sinai','hurghada':'Red Sea',
    'dahab':'South Sinai','el gouna':'Red Sea','marsa':'Red Sea',
    'sinai':'South Sinai','red sea':'Red Sea','nile':'Cairo',
}

def is_egypt_url(url):
    m = re.search(r'-g(\d+)-', url)
    return bool(m and m.group(1) in EGYPT_GEO_IDS)

def is_egypt_page(content):
    return any(s in content[:8000] for s in
        ['Egypt','Cairo','Giza','Luxor','Aswan','Alexandria',
         'Hurghada','Sharm','Sinai','Nile','Egyptian','Pharaoh','Pharaonic'])

def translate_ar(text):
    if not text or len(text.strip()) < 3: return text
    try: return GoogleTranslator(source='en', target='ar').translate(text[:4500])
    except: return text

def get_db(): return pyodbc.connect(DB_CONN_STR)
def count_cat(cursor, cat):
    cursor.execute("SELECT COUNT(*) FROM Places WHERE category=?", cat)
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
        p['cat'],p['gov'],p['lat'],p['lng'],p['addr'],
        p['fee_egp'],p['fee_usd'],'09:00','18:00','Daily',
        TAGS_MAP.get(p['cat'],'Egypt'),p['avg']>=4.5,p['avg'],p['revs'],
        0,0,0,max(0,p['revs']//5),max(0,p['revs']-p['revs']//5))
    return cursor.fetchone()[0]

def insert_imgs(cursor, pid, imgs):
    for i,u in enumerate(imgs[:3]):
        if u and u.startswith('http'):
            cursor.execute("INSERT INTO PlaceImages(place_id,image_url,sort_order)VALUES(?,?,?)",pid,u,i)

async def rnd(a=2,b=5): await asyncio.sleep(random.uniform(a,b))

async def goto(page, url):
    for w in ['domcontentloaded','commit']:
        try:
            await page.goto(url,wait_until=w,timeout=35000)
            await rnd(1,2); return True
        except: pass
    return False

async def get_links(page, category):
    pat = 'Hotel_Review' if category == 'hotel' else 'Attraction_Review'
    try:
        hrefs = await page.eval_on_selector_all('a[href]','els=>els.map(e=>e.href)')
        seen, links = set(), []
        for h in hrefs:
            if pat in h:
                c = h.split('#')[0].split('?')[0]
                if c not in seen and is_egypt_url(c):
                    seen.add(c); links.append(c)
        return links
    except: return []

async def scrape(page, url, cat, default_gov):
    if not is_egypt_url(url): return None
    if not await goto(page, url): return None
    try:
        content = await page.content()
        if not is_egypt_page(content):
            print(f"    Not Egypt - skip")
            return None
    except: return None

    name = ''
    for sel in ['h1','[data-automation="mainH1"]']:
        try:
            el = page.locator(sel).first
            if await el.count()>0:
                t=(await el.inner_text()).strip()
                if len(t)>2: name=t; break
        except: pass
    if not name: return None
    print(f"    {name[:55]}")

    desc = ''
    for sel in ['[data-automation="OVERVIEW_TAB_ELEMENT"] .biGQs span','.fIrGe span','div[class*="bikleE"]']:
        try:
            el=page.locator(sel).first
            if await el.count()>0:
                t=(await el.inner_text()).strip()
                if len(t)>40: desc=t; break
        except: pass
    if not desc:
        try: desc=(await page.get_attribute('meta[name="description"]','content') or '').strip()
        except: pass
    if not desc: desc=f"A remarkable {cat} in Egypt."

    avg, revs = 4.0, 0
    try:
        c=await page.content()
        m=re.search(r'"ratingValue"[:\s]+"?([\d.]+)"?',c)
        if m: avg=float(m.group(1))
        m2=re.search(r'"reviewCount"[:\s]+(\d+)',c)
        if m2: revs=int(m2.group(1))
        else:
            m3=re.search(r'([\d,]+)\s+reviews?',c,re.I)
            if m3: revs=int(m3.group(1).replace(',',''))
    except: pass

    imgs=[]
    try:
        els=await page.query_selector_all('img')
        seen=set()
        for el in els:
            src=await el.get_attribute('src') or ''
            if (src.startswith('http') and src not in seen and
                any(x in src for x in ['media','photo','dynamic','upload']) and
                not any(x in src.lower() for x in ['avatar','logo','icon','flag'])):
                seen.add(src); imgs.append(src)
            if len(imgs)>=3: break
    except: pass

    lat,lng,addr=0.0,0.0,''
    try:
        c=await page.content()
        g=re.search(r'"latitude"[:\s]+"?([\d.-]+)"?.*?"longitude"[:\s]+"?([\d.-]+)"?',c,re.DOTALL)
        if g: lat,lng=float(g.group(1)),float(g.group(2))
        a=re.search(r'"streetAddress"[:\s]+"([^"]+)"',c)
        if a: addr=a.group(1)
        elif not a:
            r=re.search(r'"addressRegion"[:\s]+"([^"]+)"',c)
            if r: addr=r.group(1)+', Egypt'
    except: pass

    fee_egp,fee_usd=0.0,0.0
    try:
        c=await page.content()
        m=re.search(r'EGP\s*([\d,]+)',c)
        if m: fee_egp=float(m.group(1).replace(',','')); fee_usd=fee_egp/50
        else:
            m=re.search(r'\$\s*(\d+)',c)
            if m: fee_usd=float(m.group(1)); fee_egp=fee_usd*50
    except: pass

    print(f"    Translating...")
    name_ar=translate_ar(name)
    desc_ar=translate_ar(desc[:500])

    gov=default_gov
    al=(addr+' '+name).lower()
    for k,v in GOV_MAP.items():
        if k in al: gov=v; break

    return dict(name_en=name[:299],name_ar=name_ar[:299],
                desc_en=desc[:3000],desc_ar=desc_ar[:3000],
                cat=cat,gov=gov,lat=lat,lng=lng,
                addr=(addr or 'Egypt')[:299],
                fee_egp=fee_egp,fee_usd=fee_usd,
                avg=avg,revs=revs,imgs=imgs)


async def main():
    print("="*60)
    print("BOOST Egypt Only: Historical->50 | Hotel->50 | Museum->60")
    print("="*60)
    conn=get_db(); cursor=conn.cursor(); total=0

    async with async_playwright() as p:
        browser=await p.chromium.launch(headless=True,
            args=['--disable-blink-features=AutomationControlled',
                  '--no-sandbox','--disable-dev-shm-usage'])
        ctx=await browser.new_context(
            viewport={'width':1280,'height':900},
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36',
            locale='en-US')
        await ctx.add_init_script("Object.defineProperty(navigator,'webdriver',{get:()=>undefined});")
        page=await ctx.new_page()

        print("Opening TripAdvisor...")
        await goto(page,"https://www.tripadvisor.com")
        await rnd(2,4)
        try:
            btn=page.locator('#onetrust-accept-btn-handler').first
            if await btn.count()>0: await btn.click(); await rnd(1,2)
        except: pass

        for target in TARGETS:
            cat=target['category']; gov=target['gov']
            cur=count_cat(cursor,cat); need=TARGET_COUNTS[cat]
            if cur>=need:
                print(f"\n[SKIP] {cat}: {cur}/{need} already reached")
                continue

            print(f"\n{'='*50}")
            print(f"{cat.upper()} - {gov} | {cur}/{need}")
            print(f"{'='*50}")

            all_urls=[]; cur_url=target['url']
            for pg in range(PAGES_PER):
                if not await goto(page,cur_url): break
                await rnd(2,3)
                links=await get_links(page,cat)
                new=[l for l in links if l not in all_urls]
                all_urls.extend(new)
                print(f"  [Page {pg+1}] +{len(new)} Egypt links")

                nh=None
                for sel in ['a[aria-label="Next page"]','a.nav.next']:
                    try:
                        el=page.locator(sel).first
                        if await el.count()>0:
                            nh=await el.get_attribute('href')
                            if nh: break
                    except: pass
                if nh:
                    cur_url=f"https://www.tripadvisor.com{nh}" if nh.startswith('/') else nh
                else: break

            for i,url in enumerate(all_urls):
                cur=count_cat(cursor,cat)
                if cur>=need:
                    print(f"  [TARGET REACHED] {cat}: {cur}/{need}"); break

                print(f"\n  [{i+1}/{len(all_urls)}] ({cur}/{need})")
                data=await scrape(page,url,cat,gov)
                if not data: print("  Skipped"); continue
                if exists(cursor,data['name_en']):
                    print(f"  Exists: {data['name_en'][:40]}"); continue

                try:
                    pid=insert_place(cursor,data)
                    insert_imgs(cursor,pid,data['imgs'])
                    conn.commit(); total+=1
                    print(f"  [OK] {data['name_en'][:45]} ({data['gov']})")
                except Exception as e:
                    conn.rollback(); print(f"  [ERR] {e}")
                await rnd(2,4)

        await browser.close()

    print(f"\n{'='*60}")
    print(f"[DONE] Added: {total}")
    for cat in ['historical','hotel','museum']:
        print(f"  {cat}: {count_cat(cursor,cat)}/{TARGET_COUNTS[cat]}")
    cursor.close(); conn.close()
    print("="*60)

if __name__=='__main__':
    asyncio.run(main())
