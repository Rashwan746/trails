# -*- coding: utf-8 -*-
"""
Image Scraper - Gets Wikipedia/Wikimedia images for places with no images
Also ensures Grand Egyptian Museum has good images
"""
import sys, time, random, re, requests, pyodbc

sys.stdout.reconfigure(encoding='utf-8')

DB_CONN_STR = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost,1433;DATABASE=DiscoverEgypt;"
    "UID=sa;PWD=YourPassword123!;TrustServerCertificate=yes;"
)

WIKI_API    = "https://en.wikipedia.org/w/api.php"
COMMONS_API = "https://commons.wikimedia.org/w/api.php"
HEADERS = {'User-Agent': 'DiscoverEgyptApp/1.0 (contact@discover-egypt.com)'}

# ─────────────────────────────────────────────────────────────────────────────
def get_db():
    return pyodbc.connect(DB_CONN_STR)

def get_places_no_images(cur):
    cur.execute("""
        SELECT p.id, p.name_en, p.category, p.governorate
        FROM Places p
        LEFT JOIN PlaceImages pi ON pi.place_id = p.id
        WHERE pi.id IS NULL
        ORDER BY p.category, p.id
    """)
    return cur.fetchall()

def has_images(cur, pid):
    cur.execute("SELECT COUNT(*) FROM PlaceImages WHERE place_id=?", pid)
    return cur.fetchone()[0] > 0

def insert_imgs(cur, pid, imgs):
    count = 0
    for i, u in enumerate(imgs[:3]):
        if u and u.startswith('http') and len(u) < 500:
            try:
                cur.execute(
                    "INSERT INTO PlaceImages(place_id,image_url,sort_order) VALUES(?,?,?)",
                    pid, u, i)
                count += 1
            except: pass
    return count

# ─────────────────────────────────────────────────────────────────────────────
def commons_url(filename):
    """Get direct URL from Wikimedia Commons filename"""
    try:
        r = requests.get(COMMONS_API, params={
            'action': 'query',
            'titles': 'File:' + filename,
            'prop': 'imageinfo',
            'iiprop': 'url',
            'iiurlwidth': 1200,
            'format': 'json',
        }, headers=HEADERS, timeout=8)
        if r.status_code != 200:
            return None
        pages = r.json().get('query', {}).get('pages', {})
        p = list(pages.values())[0]
        info = p.get('imageinfo', [])
        if info:
            url = info[0].get('thumburl') or info[0].get('url', '')
            if url and any(url.lower().endswith(e) for e in ['.jpg','.jpeg','.png','.webp']):
                return url
    except:
        pass
    return None

def wiki_images(title, want=3):
    """Get image URLs from a Wikipedia article"""
    imgs = []
    try:
        # First try to get thumbnail from page props
        r = requests.get(WIKI_API, params={
            'action': 'query',
            'titles': title,
            'prop': 'pageimages|images',
            'piprop': 'thumbnail|original',
            'pithumbsize': 1200,
            'imlimit': 15,
            'format': 'json',
            'redirects': True,
        }, headers=HEADERS, timeout=12)
        if r.status_code != 200:
            return imgs

        pages = r.json().get('query', {}).get('pages', {})
        p = list(pages.values())[0]
        if p.get('pageid', -1) < 0:
            return imgs

        # Thumbnail (best quality)
        thumb = p.get('thumbnail', {})
        orig  = p.get('original', {})
        best_url = orig.get('source') or thumb.get('source', '')
        if best_url and any(best_url.lower().endswith(e) for e in ['.jpg','.jpeg','.png']):
            imgs.append(best_url)

        # Article images
        skip_words = ['svg','logo','flag','icon','map','stub','portal',
                      'commons','red_x','edit','wikip','placeholder']
        img_list = [i['title'].replace('File:', '')
                    for i in p.get('images', [])
                    if not any(x in i['title'].lower() for x in skip_words)]

        for fname in img_list[:want*4]:
            if len(imgs) >= want:
                break
            url = commons_url(fname)
            if url and url not in imgs:
                imgs.append(url)

    except Exception as e:
        pass
    return imgs[:want]

def search_wiki(name):
    """Search Wikipedia for best matching article"""
    try:
        r = requests.get(WIKI_API, params={
            'action': 'query',
            'list': 'search',
            'srsearch': name + ' Egypt',
            'srlimit': 3,
            'format': 'json',
        }, headers=HEADERS, timeout=10)
        if r.status_code != 200:
            return None
        results = r.json().get('query', {}).get('search', [])
        if results:
            return results[0]['title']
    except:
        pass
    return None

def get_images_for_place(name, category):
    """Try multiple strategies to get images for a place"""
    imgs = []

    # Strategy 1: Direct Wikipedia lookup
    imgs = wiki_images(name, 3)
    if imgs:
        return imgs

    # Strategy 2: Search Wikipedia
    found_title = search_wiki(name)
    if found_title and found_title.lower() != name.lower():
        imgs = wiki_images(found_title, 3)
        if imgs:
            return imgs

    # Strategy 3: Try simplified name (remove "Tour", "from", etc.)
    simple = re.sub(r'\b(tour|from|day|trip|by|in|at|the|and|or|to|of|on)\b', '',
                    name, flags=re.I).strip()
    simple = re.sub(r'\s+', ' ', simple).strip()
    if simple and simple != name:
        imgs = wiki_images(simple, 3)
        if imgs:
            return imgs

    # Strategy 4: Category fallback images (guaranteed to work)
    FALLBACK = {
        'historical': [
            'https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/All_Gizah_Pyramids.jpg/1280px-All_Gizah_Pyramids.jpg',
            'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/Karnak_amun.jpg/1280px-Karnak_amun.jpg',
        ],
        'museum': [
            'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/EgyptianMuseumCairo.jpg/1280px-EgyptianMuseumCairo.jpg',
            'https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/GEM_building.jpg/1280px-GEM_building.jpg',
        ],
        'hotel': [
            'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bb/Sofitel_Winter_Palace_Luxor.jpg/1280px-Sofitel_Winter_Palace_Luxor.jpg',
        ],
        'beach': [
            'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6e/Sharm_El_Sheikh.jpg/1280px-Sharm_El_Sheikh.jpg',
            'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1e/Hurghada_beach.jpg/1280px-Hurghada_beach.jpg',
        ],
        'desert': [
            'https://upload.wikimedia.org/wikipedia/commons/thumb/2/27/White_Desert_Egypt.jpg/1280px-White_Desert_Egypt.jpg',
            'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7f/Sahara_desert.jpg/1280px-Sahara_desert.jpg',
        ],
        'nature': [
            'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d1/Sinai_peninsula_NASA.jpg/1280px-Sinai_peninsula_NASA.jpg',
        ],
        'market': [
            'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8d/Khan_el-Khalili_market.jpg/1280px-Khan_el-Khalili_market.jpg',
        ],
        'religious': [
            'https://upload.wikimedia.org/wikipedia/commons/thumb/1/16/Muhammad_Ali_Mosque.jpg/1280px-Muhammad_Ali_Mosque.jpg',
        ],
        'cruise': [
            'https://upload.wikimedia.org/wikipedia/commons/thumb/3/31/Nile_river_at_Luxor.jpg/1280px-Nile_river_at_Luxor.jpg',
        ],
        'restaurant': [
            'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6d/Cairo_food.jpg/1280px-Cairo_food.jpg',
        ],
    }
    return FALLBACK.get(category, [
        'https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/All_Gizah_Pyramids.jpg/1280px-All_Gizah_Pyramids.jpg'
    ])


def fix_grand_egyptian_museum(cur, conn):
    """Ensure Grand Egyptian Museum has great images"""
    cur.execute("SELECT id FROM Places WHERE name_en LIKE '%Grand Egyptian Museum%' OR name_en LIKE '%Grand Egyptian%'")
    rows = cur.fetchall()
    if not rows:
        print("[GEM] Not found in DB!")
        return

    for row in rows:
        pid = row[0]
        cur.execute("DELETE FROM PlaceImages WHERE place_id=?", pid)
        gem_imgs = [
            'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Grand_Egyptian_Museum_%28GEM%29.jpg/1280px-Grand_Egyptian_Museum_%28GEM%29.jpg',
            'https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Grand_Egyptian_Museum_interior.jpg/1280px-Grand_Egyptian_Museum_interior.jpg',
            'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/EgyptianMuseumCairo.jpg/1280px-EgyptianMuseumCairo.jpg',
        ]
        # Try to get fresh images from Wikipedia
        fresh = wiki_images('Grand Egyptian Museum', 3)
        if fresh:
            gem_imgs = fresh

        for i, u in enumerate(gem_imgs[:3]):
            try:
                cur.execute("INSERT INTO PlaceImages(place_id,image_url,sort_order) VALUES(?,?,?)",
                           pid, u, i)
            except: pass
        conn.commit()
        print(f"[GEM] ID:{pid} - Updated with {len(gem_imgs)} images")


def main():
    print("="*65)
    print("Image Scraper - Fill missing images for 550 places")
    print("="*65)

    conn = get_db()
    cur  = conn.cursor()

    # Fix Grand Egyptian Museum first
    print("\n[1] Fixing Grand Egyptian Museum images...")
    fix_grand_egyptian_museum(cur, conn)

    # Get all places with no images
    print("\n[2] Loading places with no images...")
    places = get_places_no_images(cur)
    total  = len(places)
    print(f"    Found: {total} places without images")

    done = 0
    failed = 0

    for i, (pid, name, cat, gov) in enumerate(places):
        print(f"\n[{i+1}/{total}] {cat} | {name[:55]}")

        imgs = get_images_for_place(name, cat)
        if not imgs:
            print(f"  No images found - skip")
            failed += 1
            continue

        print(f"  Found {len(imgs)} image(s)")

        try:
            added = insert_imgs(cur, pid, imgs)
            conn.commit()
            done += 1
            print(f"  [OK] Added {added} imgs")
        except Exception as e:
            conn.rollback()
            print(f"  [ERR] {e}")
            failed += 1

        # Respect Wikipedia API rate limit
        time.sleep(random.uniform(0.2, 0.5))

        # Progress report every 50
        if (i+1) % 50 == 0:
            cur2 = conn.cursor()
            cur2.execute("SELECT COUNT(*) FROM Places p LEFT JOIN PlaceImages pi ON pi.place_id=p.id WHERE pi.id IS NULL")
            remaining = cur2.fetchone()[0]
            print(f"\n  === Progress: {i+1}/{total} | Still no image: {remaining} ===\n")
            cur2.close()

    # Final stats
    cur.execute("SELECT COUNT(*) FROM Places p LEFT JOIN PlaceImages pi ON pi.place_id=p.id WHERE pi.id IS NULL")
    still_empty = cur.fetchone()[0]

    print(f"\n{'='*65}")
    print(f"[DONE] Added images: {done} | Failed: {failed}")
    print(f"Places still without images: {still_empty}")

    # Per category
    cur.execute("""
        SELECT p.category, COUNT(*) as no_img
        FROM Places p
        LEFT JOIN PlaceImages pi ON pi.place_id = p.id
        WHERE pi.id IS NULL
        GROUP BY p.category ORDER BY p.category
    """)
    rows = cur.fetchall()
    if rows:
        print("\nStill missing images by category:")
        for row in rows:
            print(f"  {row[0]:12}: {row[1]}")
    else:
        print("\nAll places have images!")

    print("="*65)
    cur.close()
    conn.close()

if __name__ == '__main__':
    main()
