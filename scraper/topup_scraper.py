# -*- coding: utf-8 -*-
"""Top-up scraper - fills remaining places to reach 100 per category"""
import sys, time, random, re, requests, pyodbc
from deep_translator import GoogleTranslator

sys.stdout.reconfigure(encoding='utf-8')

DB_CONN_STR = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost,1433;DATABASE=DiscoverEgypt;"
    "UID=sa;PWD=YourPassword123!;TrustServerCertificate=yes;"
)
WIKI_API    = "https://en.wikipedia.org/w/api.php"
COMMONS_API = "https://commons.wikimedia.org/w/api.php"
HEADERS = {'User-Agent': 'DiscoverEgyptApp/1.0'}

TARGET = 100

EXTRA_PLACES = [
# ── DESERT (need 13 more) ─────────────────────────────────────────────────
('desert','New Valley',   'Ain Dalla'),
('desert','New Valley',   'Ain Tirghi'),
('desert','New Valley',   'Qasr el-Labkha'),
('desert','Matrouh',      'Siwa Traditional House'),
('desert','South Sinai',  'Wadi Taba desert'),
('desert','Red Sea',      'Eastern Desert Road Egypt'),
('desert','New Valley',   'Bir Wahed hot spring'),
('desert','Matrouh',      'Dakrur Mountain Siwa'),
('desert','New Valley',   'Ain Birbiya oasis'),
('desert','South Sinai',  'Blue Desert Sinai'),
('desert','Giza',         'Saqqara desert plain'),
('desert','Red Sea',      'Wadi Qena desert'),
('desert','New Valley',   'Ain Amur oasis'),
('desert','New Valley',   'Umm el-Dabadib'),
('desert','Matrouh',      'Aghurmi village Siwa'),

# ── NATURE (need 5 more) ──────────────────────────────────────────────────
('nature','Red Sea',      'Marsa Abu Dabbab'),
('nature','Fayoum',       'Qasr el-Sagha'),
('nature','South Sinai',  'Wadi Watir'),
('nature','Matrouh',      'Siwa date palms'),
('nature','New Valley',   'Ain Della spring'),
('nature','Red Sea',      'Dolphin House Hurghada'),
('nature','Aswan',        'Aswan Agha Khan area'),

# ── MARKET (need 4 more) ──────────────────────────────────────────────────
('market','Cairo',        'Wikala el-Balah Cairo'),
('market','Cairo',        'Souq el-Fustat'),
('market','Aswan',        'Aswan Old Souk'),
('market','Luxor',        'Luxor Night Bazaar'),
('market','Alexandria',   'Anfushi Bazaar Alexandria'),
('market','Cairo',        'El-Ataba Market Cairo'),

# ── RELIGIOUS (need 14 more) ──────────────────────────────────────────────
('religious','Cairo',     'Mosque of Qijmas al-Ishaqi'),
('religious','Cairo',     'Mosque of Azbak al-Yusufi'),
('religious','Cairo',     'Mosque of Emir Taz'),
('religious','Cairo',     'Church of Saint Mark Coptic Cairo'),
('religious','Cairo',     'Church of Saint George Old Cairo'),
('religious','Cairo',     'Monastery of Saint Samuel'),
('religious','Red Sea',   'Monastery of Saint Hadra'),
('religious','Aswan',     'Church of Saint Bishoy Aswan'),
('religious','Alexandria','Mosque of Sidi Gaber Alexandria'),
('religious','Cairo',     'Mosque of Sayyida Nafisa Cairo'),
('religious','Cairo',     'Mosque of Khayrbak Cairo'),
('religious','Cairo',     'Mosque of Sulayman Agha al-Silahdar'),
('religious','Cairo',     'Mosque of Emir Shaykhu'),
('religious','Cairo',     'Takiyyat Ibrahim al-Kulshani'),
('religious','Luxor',     'Temple of Medamud'),
('religious','Aswan',     'Temple of Maharraqa'),
]

def get_db(): return pyodbc.connect(DB_CONN_STR)
def count_cat(cur, cat):
    cur.execute("SELECT COUNT(*) FROM Places WHERE category=?", cat); return cur.fetchone()[0]
def exists(cur, name):
    cur.execute("SELECT COUNT(*) FROM Places WHERE name_en=?", name); return cur.fetchone()[0]>0

def translate_ar(text):
    if not text: return text
    try: return GoogleTranslator(source='en',target='ar').translate(text[:4500])
    except: return text

def wiki_get(title):
    try:
        r = requests.get(WIKI_API, params={
            'action':'query','titles':title,
            'prop':'extracts|pageimages|coordinates',
            'exintro':True,'exsentences':4,
            'piprop':'thumbnail|original','pithumbsize':1200,
            'format':'json','redirects':True,
        }, headers=HEADERS, timeout=12)
        if r.status_code!=200: return None
        pages = r.json().get('query',{}).get('pages',{})
        p = list(pages.values())[0]
        return None if p.get('pageid',-1)<0 else p
    except: return None

def commons_url(filename):
    try:
        r = requests.get(COMMONS_API, params={
            'action':'query','titles':'File:'+filename,
            'prop':'imageinfo','iiprop':'url','iiurlwidth':1200,'format':'json',
        }, headers=HEADERS, timeout=8)
        if r.status_code!=200: return None
        pages = r.json().get('query',{}).get('pages',{})
        p = list(pages.values())[0]
        info = p.get('imageinfo',[])
        if info:
            url = info[0].get('thumburl') or info[0].get('url','')
            if url and any(url.lower().endswith(e) for e in ['.jpg','.jpeg','.png','.webp']):
                return url
    except: pass
    return None

def wiki_images(title, want=3):
    imgs=[]
    try:
        r=requests.get(WIKI_API,params={'action':'query','titles':title,'prop':'images',
            'imlimit':20,'format':'json','redirects':True},headers=HEADERS,timeout=10)
        if r.status_code!=200: return imgs
        pages=r.json().get('query',{}).get('pages',{})
        p=list(pages.values())[0]
        skip=['svg','logo','flag','icon','map','stub','portal','commons','red_x','edit']
        img_list=[i['title'] for i in p.get('images',[])
                  if not any(x in i['title'].lower() for x in skip)]
        for fname in img_list[:want*3]:
            url=commons_url(fname.replace('File:',''))
            if url: imgs.append(url)
            if len(imgs)>=want: break
    except: pass
    return imgs

def clean_html(text):
    import html
    text=re.sub(r'<[^>]+>','',text); text=html.unescape(text)
    return re.sub(r'\s+',' ',text).strip()

TAGS = {
    'desert': 'desert,safari,adventure,Egypt,dunes,oasis',
    'nature': 'nature,wildlife,parks,Egypt,outdoors,scenery',
    'market': 'shopping,bazaar,market,Egypt,souvenirs,crafts',
    'religious': 'mosque,church,temple,religion,Egypt,spiritual',
}
OPENS = {
    'desert':('06:00','20:00'),'nature':('07:00','19:00'),
    'market':('09:00','21:00'),'religious':('08:00','18:00'),
}

def insert_place(cur, cat, gov, d):
    o,c = OPENS.get(cat,('09:00','18:00'))
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
    cat,gov,d['lat'],d['lng'],gov+', Egypt',0.0,0.0,o,c,'Daily',
    TAGS.get(cat,'Egypt,tourism'),False,4.2,0,0,0,0,0,0)
    return cur.fetchone()[0]

def insert_imgs(cur,pid,imgs):
    for i,u in enumerate(imgs[:3]):
        if u and u.startswith('http'):
            cur.execute("INSERT INTO PlaceImages(place_id,image_url,sort_order)VALUES(?,?,?)",pid,u,i)

def main():
    print("="*60); print("Top-up Scraper - filling to 100 per category"); print("="*60)
    conn=get_db(); cursor=conn.cursor(); added=0

    for cat,gov,wiki_title in EXTRA_PLACES:
        current=count_cat(cursor,cat)
        if current>=TARGET:
            continue

        print(f"\n[{current}/100] {cat.upper()} | {wiki_title}")
        page=wiki_get(wiki_title)
        if page:
            name=page.get('title',wiki_title)
            desc=clean_html(page.get('extract',''))
            desc=' '.join(re.split(r'(?<=[.!?])\s+',desc)[:5])[:1500]
            coords=page.get('coordinates',[])
            lat=float(coords[0]['lat']) if coords else 0.0
            lng=float(coords[0]['lon']) if coords else 0.0
            imgs=[]
            t=page.get('thumbnail',{})
            o=page.get('original',{})
            best=o.get('source') or t.get('source','')
            if best and any(best.lower().endswith(e) for e in ['.jpg','.jpeg','.png']):
                imgs.append(best)
            if len(imgs)<3:
                imgs.extend(wiki_images(wiki_title,3-len(imgs)))
        else:
            name=wiki_title
            desc=f"A remarkable {cat} destination in {gov}, Egypt."
            lat,lng=0.0,0.0; imgs=[]

        if not desc or len(desc)<20:
            desc=f"Explore this amazing {cat} spot in {gov}, Egypt."

        name=name[:299]
        if exists(cursor,name):
            print(f"  Exists: {name[:45]}"); continue

        print(f"  Name: {name[:55]} | Imgs: {len(imgs)}")
        name_ar=translate_ar(name)
        desc_ar=translate_ar(desc[:500])

        try:
            pid=insert_place(cursor,cat,gov,dict(
                name_en=name,name_ar=name_ar[:299],
                desc_en=desc[:3000],desc_ar=desc_ar[:3000],
                lat=lat,lng=lng))
            insert_imgs(cursor,pid,imgs)
            conn.commit(); added+=1
            print(f"  [OK] ID:{pid}")
        except Exception as e:
            conn.rollback(); print(f"  [ERR] {e}")

        time.sleep(random.uniform(0.3,0.7))

    print(f"\n{'='*60}\n[DONE] Added: {added}")
    for cat in ['desert','nature','market','religious']:
        print(f"  {cat:12}: {count_cat(cursor,cat)}/100")
    cursor.close(); conn.close()

if __name__=='__main__': main()
