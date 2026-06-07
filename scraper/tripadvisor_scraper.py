# -*- coding: utf-8 -*-
"""
TripAdvisor Egypt Scraper - City Level (Egypt Only)
Uses specific Egyptian city URLs to avoid non-Egypt sponsored results
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

# Egypt city geo IDs - ONLY these are valid
EGYPT_GEO_IDS = {
    '294200', '294201', '294202',    # Egypt, Cairo, Giza
    '297549', '297550', '297548',    # Hurghada, Makadi, El Gouna
    '297555', '297551', '297552',    # Sharm, Dahab, Marsa Alam
    '303855', '15516847', '424910',  # Safaga, Sahl Hasheesh, Sidi Heneish
    '19065385', '297553', '297554',  # 6Oct, Taba, Nuweiba
    '190392', '190393', '190394',    # Luxor, Aswan, Alexandria
    '297556', '311424', '7959104',   # Ras Sudr, Ain Sokhna, etc
    '3714625', '8581660', '190395',  # Siwa, Fayoum
    '14261', '190396', '190397',     # more Egypt cities
}

# City-specific Egypt URLs (much less likely to have non-Egypt ads)
TARGETS = [
    # Historical / Attractions
    {"category": "historical", "governorate": "Cairo",
     "url": "https://www.tripadvisor.com/Attractions-g294201-Activities-c47-Cairo_Governorate.html"},
    {"category": "historical", "governorate": "Giza",
     "url": "https://www.tripadvisor.com/Attractions-g294202-Activities-c47-Giza_Governorate.html"},
    {"category": "historical", "governorate": "Luxor",
     "url": "https://www.tripadvisor.com/Attractions-g190392-Activities-c47-Luxor_Luxor_Governorate.html"},
    {"category": "historical", "governorate": "Aswan",
     "url": "https://www.tripadvisor.com/Attractions-g190393-Activities-c47-Aswan_Aswan_Governorate.html"},
    {"category": "historical", "governorate": "Alexandria",
     "url": "https://www.tripadvisor.com/Attractions-g190394-Activities-c47-Alexandria_Alexandria_Governorate.html"},

    # Restaurants
    {"category": "restaurant", "governorate": "Cairo",
     "url": "https://www.tripadvisor.com/Restaurants-g294201-Cairo_Governorate.html"},
    {"category": "restaurant", "governorate": "Alexandria",
     "url": "https://www.tripadvisor.com/Restaurants-g190394-Alexandria_Alexandria_Governorate.html"},
    {"category": "restaurant", "governorate": "Sharm El Sheikh",
     "url": "https://www.tripadvisor.com/Restaurants-g297555-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate.html"},
    {"category": "restaurant", "governorate": "Hurghada",
     "url": "https://www.tripadvisor.com/Restaurants-g297549-Hurghada_Red_Sea_Governorate.html"},
    {"category": "restaurant", "governorate": "Luxor",
     "url": "https://www.tripadvisor.com/Restaurants-g190392-Luxor_Luxor_Governorate.html"},

    # Hotels
    {"category": "hotel", "governorate": "Cairo",
     "url": "https://www.tripadvisor.com/Hotels-g294201-Cairo_Governorate-Hotels.html"},
    {"category": "hotel", "governorate": "Sharm El Sheikh",
     "url": "https://www.tripadvisor.com/Hotels-g297555-Sharm_El_Sheikh_South_Sinai_Red_Sea_Governorate-Hotels.html"},
    {"category": "hotel", "governorate": "Hurghada",
     "url": "https://www.tripadvisor.com/Hotels-g297549-Hurghada_Red_Sea_Governorate-Hotels.html"},
    {"category": "hotel", "governorate": "Luxor",
     "url": "https://www.tripadvisor.com/Hotels-g190392-Luxor_Luxor_Governorate-Hotels.html"},
    {"category": "hotel", "governorate": "Aswan",
     "url": "https://www.tripadvisor.com/Hotels-g190393-Aswan_Aswan_Governorate-Hotels.html"},
]

PAGES_PER_TARGET = 3  # 3 pages per city = more data


def is_egypt_url(url: str) -> bool:
    m = re.search(r'-g(\d+)-', url)
    if m:
        return m.group(1) in EGYPT_GEO_IDS
    return False


def is_egypt_page(content: str) -> bool:
    signals = ['Egypt', 'Cairo', 'Giza', 'Luxor', 'Aswan', 'Alexandria',
               'Hurghada', 'Sharm', 'Sinai', 'Nile', 'Egyptian']
    sample = content[:8000]
    return any(s in sample for s in signals)


def translate_to_arabic(text: str) -> str:
    if not text or len(text.strip()) < 3:
        return text
    try:
        return GoogleTranslator(source='en', target='ar').translate(text[:4500])
    except Exception:
        return text


def get_db_connection():
    return pyodbc.connect(DB_CONN_STR)


def place_exists(cursor, name_en: str) -> bool:
    cursor.execute("SELECT COUNT(*) FROM Places WHERE name_en = ?", name_en)
    return cursor.fetchone()[0] > 0


def insert_place(cursor, p: dict) -> int:
    cursor.execute("""
        INSERT INTO Places (
            name_en, name_ar, description_en, description_ar,
            category, governorate, latitude, longitude, address,
            admission_fee_egyptian, admission_fee_foreign,
            opening_hours_open, opening_hours_close, opening_hours_days,
            tags, is_featured, avg_rating, review_count,
            rating_1, rating_2, rating_3, rating_4, rating_5,
            created_at
        )
        OUTPUT INSERTED.id
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,GETDATE())
    """,
        p['name_en'], p['name_ar'], p['description_en'], p['description_ar'],
        p['category'], p['governorate'], p['latitude'], p['longitude'], p['address'],
        p['admission_fee_egyptian'], p['admission_fee_foreign'],
        p['opening_hours_open'], p['opening_hours_close'], p['opening_hours_days'],
        p['tags'], p['is_featured'], p['avg_rating'], p['review_count'],
        p['rating_1'], p['rating_2'], p['rating_3'], p['rating_4'], p['rating_5'],
    )
    return cursor.fetchone()[0]


def insert_images(cursor, place_id: int, images: list):
    for i, url in enumerate(images[:3]):
        if url and url.startswith('http'):
            cursor.execute(
                "INSERT INTO PlaceImages (place_id, image_url, sort_order) VALUES (?,?,?)",
                place_id, url, i
            )


def insert_review(cursor, place_id: int, review: dict):
    text = review.get('text', '')[:3000]
    if not text:
        return
    cursor.execute("""
        INSERT INTO Reviews (place_id, user_id, stars, review_text, tags, images, helpful_count, created_at)
        VALUES (?,?,?,?,?,?,?,GETDATE())
    """, place_id, 1, review.get('stars', 5), text, '', '', 0)


async def rnd(mn=2, mx=5):
    await asyncio.sleep(random.uniform(mn, mx))


async def safe_goto(page, url: str) -> bool:
    for wait in ['domcontentloaded', 'commit']:
        try:
            await page.goto(url, wait_until=wait, timeout=35000)
            await rnd(1, 2)
            return True
        except Exception as e:
            print(f"    [{wait}] failed: {str(e)[:50]}")
    return False


async def collect_links(page, list_url: str, category: str) -> list:
    """Collect Egypt-only place links from listing page."""
    patterns = {
        'historical': '/Attraction_Review',
        'restaurant': '/Restaurant_Review',
        'hotel': '/Hotel_Review',
    }
    pat = patterns[category]
    links = []
    try:
        hrefs = await page.eval_on_selector_all('a[href]', 'els => els.map(e => e.href)')
        seen = set()
        for href in hrefs:
            if pat in href:
                clean = href.split('#')[0].split('?')[0]
                if clean not in seen and is_egypt_url(clean):
                    seen.add(clean)
                    links.append(clean)
    except Exception as e:
        print(f"    Link error: {e}")
    return links


async def scrape_place(page, url: str, category: str, default_gov: str) -> dict | None:
    """Scrape one place - only inserts if it's confirmed Egypt."""
    if not is_egypt_url(url):
        return None

    ok = await safe_goto(page, url)
    if not ok:
        return None

    try:
        content = await page.content()
        # Must contain Egypt references
        if not is_egypt_page(content):
            print(f"    Not Egypt - skipping")
            return None
    except Exception:
        return None

    # Name
    name_en = ''
    for sel in ['h1', '[data-automation="mainH1"]']:
        try:
            el = page.locator(sel).first
            if await el.count() > 0:
                txt = (await el.inner_text()).strip()
                if len(txt) > 2:
                    name_en = txt
                    break
        except Exception:
            pass
    if not name_en:
        return None

    print(f"    Name: {name_en[:55]}")

    # Description
    description_en = ''
    for sel in [
        '[data-automation="OVERVIEW_TAB_ELEMENT"] .biGQs span',
        '.fIrGe span', 'div[class*="bikleE"]',
    ]:
        try:
            el = page.locator(sel).first
            if await el.count() > 0:
                txt = (await el.inner_text()).strip()
                if len(txt) > 40:
                    description_en = txt
                    break
        except Exception:
            pass
    if not description_en:
        try:
            meta = await page.get_attribute('meta[name="description"]', 'content') or ''
            if len(meta) > 30:
                description_en = meta.strip()
        except Exception:
            pass
    if not description_en:
        description_en = f"A remarkable {category} in Egypt."

    # Rating from JSON-LD
    avg_rating = 4.0
    review_count = 0
    try:
        m = re.search(r'"ratingValue"[:\s]+"?([\d.]+)"?', content)
        if m:
            avg_rating = float(m.group(1))
        m2 = re.search(r'"reviewCount"[:\s]+(\d+)', content)
        if m2:
            review_count = int(m2.group(1))
        if review_count == 0:
            m3 = re.search(r'([\d,]+)\s+reviews?', content, re.IGNORECASE)
            if m3:
                review_count = int(m3.group(1).replace(',', ''))
    except Exception:
        pass

    # Images max 3
    images = []
    try:
        imgs = await page.query_selector_all('img')
        seen = set()
        for img in imgs:
            src = await img.get_attribute('src') or ''
            if (src.startswith('http') and src not in seen and
                any(x in src for x in ['media', 'photo', 'dynamic', 'upload']) and
                not any(x in src.lower() for x in ['avatar', 'logo', 'icon', 'flag'])):
                seen.add(src)
                images.append(src)
            if len(images) >= 3:
                break
    except Exception:
        pass

    # Address & coordinates
    address = ''
    lat, lng = 0.0, 0.0
    try:
        geo = re.search(r'"latitude"[:\s]+"?([\d.-]+)"?.*?"longitude"[:\s]+"?([\d.-]+)"?', content, re.DOTALL)
        if geo:
            lat = float(geo.group(1))
            lng = float(geo.group(2))
        addr = re.search(r'"streetAddress"[:\s]+"([^"]+)"', content)
        if addr:
            address = addr.group(1)
        if not address:
            region = re.search(r'"addressRegion"[:\s]+"([^"]+)"', content)
            if region:
                address = region.group(1) + ', Egypt'
    except Exception:
        pass

    # Price
    fee_egp, fee_usd = 0.0, 0.0
    try:
        m = re.search(r'EGP\s*([\d,]+)', content)
        if m:
            fee_egp = float(m.group(1).replace(',', ''))
            fee_usd = fee_egp / 50
        else:
            m = re.search(r'\$\s*(\d+)', content)
            if m:
                fee_usd = float(m.group(1))
                fee_egp = fee_usd * 50
    except Exception:
        pass

    # Reviews up to 3
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
                    if m:
                        stars = int(m.group(1)) // 10
            except Exception:
                pass
            text = ''
            try:
                for sel in ['[class*="yCeTE"]', 'q', 'p']:
                    t = await card.query_selector(sel)
                    if t:
                        text = (await t.inner_text()).strip()[:800]
                        if len(text) > 20:
                            break
            except Exception:
                pass
            if text:
                reviews.append({'stars': stars, 'text': text})
    except Exception:
        pass

    # Translate
    print(f"    Translating...")
    name_ar = translate_to_arabic(name_en)
    desc_ar = translate_to_arabic(description_en[:500])

    tags_map = {
        'historical': 'history,ancient,culture,Egypt,heritage',
        'restaurant': 'food,dining,cuisine,Egypt,restaurant',
        'hotel': 'accommodation,stay,hotel,Egypt,luxury',
    }

    governorate = default_gov
    # Try to refine from address
    addr_lower = (address + ' ' + name_en).lower()
    gov_map = {
        'cairo': 'Cairo', 'giza': 'Giza', 'luxor': 'Luxor',
        'aswan': 'Aswan', 'alexandria': 'Alexandria',
        'sharm': 'South Sinai', 'hurghada': 'Red Sea',
        'dahab': 'South Sinai', 'marsa': 'Red Sea',
        'el gouna': 'Red Sea', 'safaga': 'Red Sea',
    }
    for k, v in gov_map.items():
        if k in addr_lower:
            governorate = v
            break

    return {
        'name_en': name_en[:299],
        'name_ar': name_ar[:299],
        'description_en': description_en[:3000],
        'description_ar': desc_ar[:3000],
        'category': category,
        'governorate': governorate,
        'latitude': lat, 'longitude': lng,
        'address': (address or 'Egypt')[:299],
        'admission_fee_egyptian': fee_egp,
        'admission_fee_foreign': fee_usd,
        'opening_hours_open': '09:00',
        'opening_hours_close': '18:00',
        'opening_hours_days': 'Daily',
        'tags': tags_map.get(category, 'Egypt,travel'),
        'is_featured': avg_rating >= 4.5,
        'avg_rating': avg_rating,
        'review_count': review_count,
        'rating_1': 0, 'rating_2': 0, 'rating_3': 0,
        'rating_4': max(0, review_count // 5),
        'rating_5': max(0, review_count - review_count // 5),
        'images': images,
        'reviews': reviews,
    }


async def main():
    print("=" * 60)
    print("TripAdvisor Egypt Scraper - City Level")
    print("=" * 60)

    conn = get_db_connection()
    cursor = conn.cursor()
    total_inserted = 0

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=False,
            args=['--disable-blink-features=AutomationControlled'],
        )
        context = await browser.new_context(
            viewport={'width': 1280, 'height': 900},
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            locale='en-US',
        )
        await context.add_init_script(
            "Object.defineProperty(navigator, 'webdriver', { get: () => undefined });"
        )

        page = await context.new_page()

        # Accept cookies
        print("Opening TripAdvisor...")
        await safe_goto(page, "https://www.tripadvisor.com")
        await rnd(2, 4)
        try:
            btn = page.locator('#onetrust-accept-btn-handler').first
            if await btn.count() > 0:
                await btn.click()
                await rnd(1, 2)
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
                print(f"  [Page {pg+1}] collecting links...")
                ok = await safe_goto(page, current_url)
                if not ok:
                    break
                await rnd(2, 4)

                links = await collect_links(page, current_url, cat)
                new = [l for l in links if l not in all_urls]
                all_urls.extend(new)
                print(f"    +{len(new)} Egypt links (total: {len(all_urls)})")

                # Next page
                next_href = None
                for sel in ['a[aria-label="Next page"]', 'a.nav.next']:
                    try:
                        el = page.locator(sel).first
                        if await el.count() > 0:
                            next_href = await el.get_attribute('href')
                            if next_href:
                                break
                    except Exception:
                        pass

                if next_href:
                    current_url = f"https://www.tripadvisor.com{next_href}" if next_href.startswith('/') else next_href
                else:
                    break

            print(f"  Total to scrape: {len(all_urls)}")

            for i, url in enumerate(all_urls):
                print(f"\n  [{i+1}/{len(all_urls)}] {url[35:80]}")

                place_data = await scrape_place(page, url, cat, gov)
                if not place_data:
                    print("  Skipped")
                    continue

                if place_exists(cursor, place_data['name_en']):
                    print(f"  Exists: {place_data['name_en'][:40]}")
                    continue

                try:
                    place_id = insert_place(cursor, place_data)
                    insert_images(cursor, place_id, place_data['images'])
                    for rev in place_data.get('reviews', []):
                        insert_review(cursor, place_id, rev)
                    conn.commit()
                    total_inserted += 1
                    print(f"  [OK] {place_data['name_en'][:45]} -> ID:{place_id} ({place_data['governorate']})")
                except Exception as e:
                    conn.rollback()
                    print(f"  [DB ERR] {e}")

                await rnd(2, 4)

        await browser.close()

    cursor.close()
    conn.close()
    print(f"\n{'='*60}")
    print(f"[DONE] Total inserted: {total_inserted} Egypt places")
    print(f"{'='*60}")


if __name__ == '__main__':
    asyncio.run(main())
