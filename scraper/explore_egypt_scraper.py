# -*- coding: utf-8 -*-
"""
ExploreEgyptTours.com Scraper
Scrapes 186 tours and adds to DiscoverEgypt DB in correct categories
"""
import sys, time, random, re, requests, pyodbc
from bs4 import BeautifulSoup
from deep_translator import GoogleTranslator

sys.stdout.reconfigure(encoding='utf-8')

DB_CONN_STR = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost,1433;DATABASE=DiscoverEgypt;"
    "UID=sa;PWD=YourPassword123!;TrustServerCertificate=yes;"
)

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
}

TARGET = 100

# ── Category mapping by keywords in URL / title ──────────────────────────────
def map_category(url, title):
    t = (url + ' ' + title).lower()
    if any(x in t for x in ['nile cruise','dahabiya','felucca','river cruise',
                              'lake nasser cruise','ms-','m-s-','m-y-',
                              'cruise-tour','nile-cruise']):
        return 'cruise'
    if any(x in t for x in ['white desert','black desert','bahariya','oasis',
                              'desert','safari','jeep','siwa','farafra']):
        return 'desert'
    if any(x in t for x in ['snorkeling','diving','dive','reef','giftun',
                              'blue hole','ras-mohammed','ras mohammed',
                              'sataya','hamata','red-sea','beach','sea']):
        return 'beach'
    if any(x in t for x in ['monastery','st-catherine','saint catherine',
                              'religious','holy','bible','coptic','mosque',
                              'church','pilgrimage','faith','sinai-mount',
                              'mount-sinai','mount sinai']):
        return 'religious'
    if any(x in t for x in ['museum','egyptian museum','grand egyptian',
                              'mummification']):
        return 'museum'
    if any(x in t for x in ['khan el-khalili','khan-el-khalili','bazaar',
                              'market','shopping','souk']):
        return 'market'
    if any(x in t for x in ['botanical','garden','park','nature','wildlife',
                              'lake qarun','fayoum','wadi','island-tour']):
        return 'nature'
    # Default: historical (temples, pyramids, citadels, etc.)
    return 'historical'

# ── Governorate mapping ───────────────────────────────────────────────────────
GOV_MAP = {
    'cairo':'Cairo','giza':'Giza','luxor':'Luxor','aswan':'Aswan',
    'alexandria':'Alexandria','hurghada':'Red Sea','sharm':'South Sinai',
    'dahab':'South Sinai','sinai':'South Sinai','marsa alam':'Red Sea',
    'safaga':'Red Sea','taba':'South Sinai','port said':'Port Said',
    'sokhna':'Suez','ismailia':'Ismailia','fayoum':'Fayoum',
    'bahariya':'Giza','white desert':'New Valley','siwa':'Matrouh',
    'red sea':'Red Sea','el gouna':'Red Sea','nubian':'Aswan',
    'lake nasser':'Aswan','nile':'Cairo',
}

def infer_gov(url, title):
    t = (url + ' ' + title).lower()
    for k, v in GOV_MAP.items():
        if k in t: return v
    return 'Cairo'

OPEN_MAP = {
    'cruise':   ('07:00','22:00'),
    'beach':    ('06:00','20:00'),
    'market':   ('09:00','21:00'),
    'historical':('08:00','17:00'),
    'museum':   ('09:00','17:00'),
    'desert':   ('06:00','20:00'),
    'nature':   ('07:00','19:00'),
    'religious':('08:00','18:00'),
}

TAGS_MAP = {
    'historical':'history,ancient,culture,Egypt,heritage,pharaonic',
    'museum':    'museum,culture,history,Egypt,art,antiquities',
    'cruise':    'nile,cruise,boat,Egypt,river,sailing,felucca',
    'beach':     'beach,sea,swimming,Egypt,coast,snorkeling',
    'market':    'shopping,bazaar,market,Egypt,souvenirs,crafts',
    'desert':    'desert,safari,adventure,Egypt,dunes,oasis',
    'nature':    'nature,wildlife,parks,Egypt,outdoors,scenery',
    'religious': 'mosque,church,temple,religion,Egypt,spiritual',
    'hotel':     'accommodation,stay,hotel,Egypt,luxury',
}

# ── All 186 tour URLs ─────────────────────────────────────────────────────────
TOUR_URLS = [
    "https://exploreegypttours.com/en/tours/luxury-felucca-dinner-experience-on-the-nile-in-cairo/",
    "https://exploreegypttours.com/en/tours/egyptian-archaeologists-experience-in-saqqara/",
    "https://exploreegypttours.com/en/tours/vip-tour-of-the-osiris-shaft-at-giza-pyramids/",
    "https://exploreegypttours.com/en/tours/vip-tour-inside-luxor-temple/",
    "https://exploreegypttours.com/en/tours/vip-tour-inside-karnak-temple/",
    "https://exploreegypttours.com/en/tours/vip-tour-inside-abdeen-palace/",
    "https://exploreegypttours.com/en/tours/vip-tour-to-discover-the-tomb-of-wahtye-in-saqqara/",
    "https://exploreegypttours.com/en/tours/vip-tour-inside-the-montazah-palace/",
    "https://exploreegypttours.com/en/tours/private-tour-inside-the-great-pyramid/",
    "https://exploreegypttours.com/en/tours/vip-tour-inside-great-sphinx-of-giza-area/",
    "https://exploreegypttours.com/en/tours/pyramids-egyptian-museum-old-cairo-day-tour-from-luxor-by-flight/",
    "https://exploreegypttours.com/en/tours/safari-at-white-desert-national-park-bahariya-oasis-1-day-tour/",
    "https://exploreegypttours.com/en/tours/abu-simbel-tour-from-aswan-by-car-day-trip/",
    "https://exploreegypttours.com/en/tours/kalabsha-temple-nubian-museum-tour-from-aswan/",
    "https://exploreegypttours.com/en/tours/sound-light-show-tour-at-philae-temple/",
    "https://exploreegypttours.com/en/tours/abu-simbel-temple-tour-from-aswan-by-bus/",
    "https://exploreegypttours.com/en/tours/jordan-petra-tour-from-taba-by-ferry-boat/",
    "https://exploreegypttours.com/en/tours/two-day-tour-to-cairo-luxor-from-taba/",
    "https://exploreegypttours.com/en/tours/cairo-tours-from-taba/",
    "https://exploreegypttours.com/en/tours/aswan-vacation-abu-simbel-trip-from-marsa-alam-2-days/",
    "https://exploreegypttours.com/en/tours/snorkeling-trip-at-sataya-dolphin-reef/",
    "https://exploreegypttours.com/en/tours/snorkeling-trip-at-hamata-islands-from-marsa-alam/",
    "https://exploreegypttours.com/en/tours/desert-super-safari-by-jeep-tour-in-marsa-alam/",
    "https://exploreegypttours.com/en/tours/philae-temple-obelisk-high-dam/",
    "https://exploreegypttours.com/en/tours/snorkeling-trip-at-port-ghalib-marina/",
    "https://exploreegypttours.com/en/tours/day-tour-to-luxor-from-aswan/",
    "https://exploreegypttours.com/en/tours/cairo-tour-from-marsa-alam-by-flight/",
    "https://exploreegypttours.com/en/tours/abu-simbel-sun-festival-tour-from-aswan/",
    "https://exploreegypttours.com/en/tours/mount-sinai-st-catherine-monastery-from-dahab-or-sharm-el-sheikh/",
    "https://exploreegypttours.com/en/tours/felucca-ride-tour-in-aswan/",
    "https://exploreegypttours.com/en/tours/blue-hole-tour-from-sharm-el-sheikh/",
    "https://exploreegypttours.com/en/tours/two-day-tour-to-cairo-luxor-from-dahab/",
    "https://exploreegypttours.com/en/tours/luxor-day-trip-from-dahab-by-flight/",
    "https://exploreegypttours.com/en/tours/alexandria-shopping-tour/",
    "https://exploreegypttours.com/en/tours/trip-to-cairo-from-alexandria/",
    "https://exploreegypttours.com/en/tours/day-tour-to-rosetta-from-alexandria/",
    "https://exploreegypttours.com/en/tours/alexandria-food-tour/",
    "https://exploreegypttours.com/en/tours/overnight-trip-to-alexandria-from-cairo/",
    "https://exploreegypttours.com/en/tours/el-alamein-day-tour-from-alexandria/",
    "https://exploreegypttours.com/en/tours/religious-complex-tour-in-alexandria/",
    "https://exploreegypttours.com/en/tours/day-tour-to-all-alexandria-sightseeing-from-cairo/",
    "https://exploreegypttours.com/en/tours/museum-cairo-tour-from-hurghada-2-days/",
    "https://exploreegypttours.com/en/tours/pyramids-and-cairo-day-tour-from-hurghada/",
    "https://exploreegypttours.com/en/tours/luxor-tour-from-hurghada-2-days/",
    "https://exploreegypttours.com/en/tours/alf-leila-wa-leila-show-in-hurghada/",
    "https://exploreegypttours.com/en/tours/snorkeling-tour-on-giftun-island/",
    "https://exploreegypttours.com/en/tours/hurghada-safari-bedouin-dinner-in-sunset-by-4x4-jeep/",
    "https://exploreegypttours.com/en/tours/cairo-tours-package-from-sharm-el-sheikh-by-flight-2-days/",
    "https://exploreegypttours.com/en/tours/mount-sinai-st-catherine-monastery-from-dahab-or-sharm-el-sheikh-2/",
    "https://exploreegypttours.com/en/tours/best-water-park-tour-in-sharm-el-sheikh/",
    "https://exploreegypttours.com/en/tours/colored-canyon-tour-from-sharm-el-sheikh/",
    "https://exploreegypttours.com/en/tours/blue-hole-tour-from-sharm-el-sheikh-2/",
    "https://exploreegypttours.com/en/tours/mount-sinai-st-catherine-monastery-from-dahab-or-sharm-el-sheikh-3/",
    "https://exploreegypttours.com/en/tours/ras-mohamed-snorkeling-tour-by-boat/",
    "https://exploreegypttours.com/en/tours/queen-nefer-dahabiya-nile-cruise-from-luxor-to-aswan-4-days-3-nights/",
    "https://exploreegypttours.com/en/tours/a-solo-womans-7-days-dahabiya-cairo-safe-adventure/",
    "https://exploreegypttours.com/en/tours/8-days-safe-trip-for-solo-traveller-women-by-women/",
    "https://exploreegypttours.com/en/tours/unveiling-vegetarian-tour-at-cairo-and-the-nile-banks-on-boarding-the-dahabiya/",
    "https://exploreegypttours.com/en/tours/accessible-shore-excursion-cairo-tour-from-sokhna-port/",
    "https://exploreegypttours.com/en/tours/accessible-shore-excursion-luxor-tour-from-safaga-port/",
    "https://exploreegypttours.com/en/tours/accessible-shore-excursion-cairo-tour-from-port-said/",
    "https://exploreegypttours.com/en/tours/accessible-shore-excursion-cairo-tour-from-alexandria-port/",
    "https://exploreegypttours.com/en/tours/an-accessible-day-tour-to-giza-pyramids-the-grand-egyptian-museum/",
    "https://exploreegypttours.com/en/tours/hiking-sinai-mount-desert-camping-adventure-trekking-7-days/",
    "https://exploreegypttours.com/en/tours/on-budget-dahabiya-nile-cruise-aswan-luxor-03-nights/",
    "https://exploreegypttours.com/en/tours/queen-cleopatra-dahabiya-nile-cruise/",
    "https://exploreegypttours.com/en/tours/ms-tuya-nile-cruise/",
    "https://exploreegypttours.com/en/tours/m-s-royal-esadora-blue-shadow-4-nile-cruise/",
    "https://exploreegypttours.com/en/tours/champollion-ii-nile-cruise/",
    "https://exploreegypttours.com/en/tours/safari-bahariya-oasis-camping-in-white-black-desert-2-days/",
    "https://exploreegypttours.com/en/tours/bahariya-oasis-tour-from-cairo-camping-white-desert-3-days/",
    "https://exploreegypttours.com/en/tours/white-desert-tour-black-desert-camping-safari-4-days/",
    "https://exploreegypttours.com/en/tours/lake-qarun-fayoum-oasis-tour-from-cairo/",
    "https://exploreegypttours.com/en/tours/abu-simbel-sun-festival-tour-from-aswan-2/",
    "https://exploreegypttours.com/en/tours/museum-cairo-tour-from-hurghada-2-days-2/",
    "https://exploreegypttours.com/en/tours/luxor-tour-from-hurghada-2-days-2/",
    "https://exploreegypttours.com/en/tours/cairo-tours-package-from-sharm-el-sheikh-by-flight-2-days-2/",
    "https://exploreegypttours.com/en/tours/red-sea-hurghada-snorkeling-trip-by-flight-2-day/",
    "https://exploreegypttours.com/en/tours/dahab-tour-blue-hole-snorkeling-trip-from-cairo-2-days/",
    "https://exploreegypttours.com/en/tours/amazing-tour-to-cairo-and-sharm-el-sheikh-8-days/",
    "https://exploreegypttours.com/en/tours/pyramids-oases-tours/",
    "https://exploreegypttours.com/en/tours/honeymoon-nile-cruisecairo-and-hurghada-tours-10-days/",
    "https://exploreegypttours.com/en/tours/m-s-amwaj-living-stone-nile-cruise-tour/",
    "https://exploreegypttours.com/en/tours/cairo-and-dahab-tour/",
    "https://exploreegypttours.com/en/tours/honeymoon-holidays-nile-cruise-cairo-tours-10-days/",
    "https://exploreegypttours.com/en/tours/pyramids-and-luxor-cheap-tour/",
    "https://exploreegypttours.com/en/tours/cairo-and-marsa-alam-tour/",
    "https://exploreegypttours.com/en/tours/moses-journey-steps-in-the-bible-tanis-goshen-sinai-cairo-tours-7-days/",
    "https://exploreegypttours.com/en/tours/cairo-and-alexandria-tour/",
    "https://exploreegypttours.com/en/tours/holy-family-journey-in-egypt-st-catherine-tours-7-days/",
    "https://exploreegypttours.com/en/tours/m-s-concerto-nile-cruise-tour/",
    "https://exploreegypttours.com/en/tours/cairo-luxor-and-alexandria-cheap-tour/",
    "https://exploreegypttours.com/en/tours/cairo-golf-tours-hurghada-all-inclusive-10-days/",
    "https://exploreegypttours.com/en/tours/cairo-and-hurghada-tour-cheap-package/",
    "https://exploreegypttours.com/en/tours/giza-pyramids-cairo-golf-tour-5-days/",
    "https://exploreegypttours.com/en/tours/cairo-aswan-luxor-hurghada-overland-on-budget/",
    "https://exploreegypttours.com/en/tours/cairo-and-sharm-holiday/",
    "https://exploreegypttours.com/en/tours/pyramidscairo-and-nile-cruise-holiday-8-days/",
    "https://exploreegypttours.com/en/tours/cairo-luxor-aswan-and-sharm-al-sheikh/",
    "https://exploreegypttours.com/en/tours/cairo-pyramids-sharm-diving-tours-8-days/",
    "https://exploreegypttours.com/en/tours/2-days-1-night-cairo-tour/",
    "https://exploreegypttours.com/en/tours/cairo-and-luxor-short-break/",
    "https://exploreegypttours.com/en/tours/cairo-nile-cruise-holiday-9-days/",
    "https://exploreegypttours.com/en/tours/cairo-and-red-sea-dahab-in-6-days/",
    "https://exploreegypttours.com/en/tours/cairo-city-break-02-days/",
    "https://exploreegypttours.com/en/tours/cairo-and-gouna-diving-tours/",
    "https://exploreegypttours.com/en/tours/cairo-layover-tour/",
    "https://exploreegypttours.com/en/tours/cairo-and-sharm-short-tour-6-days/",
    "https://exploreegypttours.com/en/tours/cairo-pyramids-hurghada-snorkeling-tour-8-days/",
    "https://exploreegypttours.com/en/tours/cairo-and-hurghada-short-tour/",
    "https://exploreegypttours.com/en/tours/giza-pyramids-cairo-city-break-tours-5-days/",
    "https://exploreegypttours.com/en/tours/wheelchair-accessible-nile-cruise-hurghada-cairo-tour-12-days/",
    "https://exploreegypttours.com/en/tours/egypt-cheap-tour/",
    "https://exploreegypttours.com/en/tours/m-s-farah-nile-cruise-tour/",
    "https://exploreegypttours.com/en/tours/m-s-ruby-nile-cruise-tour/",
    "https://exploreegypttours.com/en/tours/m-s-royal-esadora-blue-shadow-4-nile-cruise-2/",
    "https://exploreegypttours.com/en/tours/m-s-mayfair-nile-cruise-tour/",
    "https://exploreegypttours.com/en/tours/m-s-esplanade-nile-cruise-tour/",
    "https://exploreegypttours.com/en/tours/assouan-dahabiya-nile-cruise-tour/",
    "https://exploreegypttours.com/en/tours/royal-cleopatra-dahabiya-nile-cruise-tour/",
    "https://exploreegypttours.com/en/tours/hadeel-dahabiya-nile-cruise-tour/",
    "https://exploreegypttours.com/en/tours/merit-dahabiya-nile-cruise-tour/",
    "https://exploreegypttours.com/en/tours/amoura-dahabiya-nile-cruise-tour/",
    "https://exploreegypttours.com/en/tours/on-budget-dahabiya-nile-cruise-aswan-luxor-03-nights-2/",
    "https://exploreegypttours.com/en/tours/on-budget-dahabiya-boat-from-esna-to-aswan-5-days-tour/",
    "https://exploreegypttours.com/en/tours/nile-cruise-package-from-luxor-to-aswan-5-days/",
    "https://exploreegypttours.com/en/tours/cairo-over-day-tour-from-sokhna-cruise-ship/",
    "https://exploreegypttours.com/en/tours/relax-holiday-from-aswan-on-the-nile-by-felucca-tour-3-days/",
    "https://exploreegypttours.com/en/tours/relax-holiday-from-aswan-on-the-nile-by-felucca-tour-3-days-2/",
    "https://exploreegypttours.com/en/tours/adventure-on-board-queen-charlotte-dahabyia-nile-cruise/",
    "https://exploreegypttours.com/en/tours/zekryaat-dahabiya-cruise-tour/",
    "https://exploreegypttours.com/en/tours/rihana-dahabiya-nile-cruise-tour/",
    "https://exploreegypttours.com/en/tours/ms-prince-abbas-lake-nasser-cruise-tour/",
    "https://exploreegypttours.com/en/tours/ms-jaz-omar-el-khayam-lake-cruise-tour/",
    "https://exploreegypttours.com/en/tours/ms-nubian-sea-lake-nasser-cruise-tour/",
    "https://exploreegypttours.com/en/tours/giza-pyramids-cairo-vacation-handicap-tours-5-days/",
    "https://exploreegypttours.com/en/tours/ms-eugenie-cruise-lake-nasser-cruise-tour/",
    "https://exploreegypttours.com/en/tours/ms-kasr-ibrim-lake-nasser-cruise-tour/",
    "https://exploreegypttours.com/en/tours/movenpick-m-s-royal-lily-nile-cruise-tour/",
    "https://exploreegypttours.com/en/tours/sonesta-moon-goddess-nile-cruise-tour/",
    "https://exploreegypttours.com/en/tours/m-y-alyssa-nile-cruise-tour/",
    "https://exploreegypttours.com/en/tours/jordan-dead-sea-tour-from-aqaba-cruise-ship/",
    "https://exploreegypttours.com/en/tours/alexandria-city-break-day-tour-from-cruise-ship/",
    "https://exploreegypttours.com/en/tours/cairo-alexandria-tours-from-port-said-port-2-days/",
    "https://exploreegypttours.com/en/tours/luxor-cairo-handicap-seniors-tours-package-7-days/",
    "https://exploreegypttours.com/en/tours/petra-day-tour-from-aqaba-cruise-ship/",
    "https://exploreegypttours.com/en/tours/egypt-tourist-package-12-days/",
    "https://exploreegypttours.com/en/tours/st-catherine-monastery-tour-from-cruise-ship/",
    "https://exploreegypttours.com/en/tours/dahabiya-holiday-pyramids-tours-package-10-days/",
    "https://exploreegypttours.com/en/tours/nile-cruise-holiday-sharm-el-sheikh-tours-13-days/",
    "https://exploreegypttours.com/en/tours/pyramids-tours-luxor-red-sea-holiday-11-days/",
    "https://exploreegypttours.com/en/tours/ras-mohammed-island-tour-from-cruise-ship/",
    "https://exploreegypttours.com/en/tours/pyramids-museum-cairo-tour-from-sokhna-port-2-days/",
    "https://exploreegypttours.com/en/tours/luxor-tour-from-safaga-port/",
    "https://exploreegypttours.com/en/tours/karnak-luxor-day-tour-from-safaga-cruise-ship/",
    "https://exploreegypttours.com/en/tours/hurghada-snorkeling-tour-from-safaga-port/",
    "https://exploreegypttours.com/en/tours/giza-pyramids-memphis-day-tour-from-cruise-ship/",
    "https://exploreegypttours.com/en/tours/giza-pyramids-museum-cairo-tour-from-port-said-port-2-days/",
    "https://exploreegypttours.com/en/tours/cairo-pyramids-day-tour-from-port-said-port/",
    "https://exploreegypttours.com/en/tours/cairo-museum-pyramids-day-tour-from-alexandria-port/",
    "https://exploreegypttours.com/en/tours/giza-pyramids-museum-cairo-tour-from-port-said-port-2-days-2/",
    "https://exploreegypttours.com/en/tours/pyramids-cairo-tours-from-alexandria-port-2-days/",
    "https://exploreegypttours.com/en/tours/cairo-alexandria-tour-from-alexandria-port-2-days/",
    "https://exploreegypttours.com/en/tours/alexandria-sightseeing-full-day-tour-from-alexandria-port/",
    "https://exploreegypttours.com/en/tours/petra-day-trip-from-sharm-el-sheikh-by-ferry-boat/",
    "https://exploreegypttours.com/en/tours/cairo-nile-cruise-petra-dead-sea-vacation-14-days/",
    "https://exploreegypttours.com/en/tours/dubai-tour-cairo-nile-cruise-holiday-11-days/",
    "https://exploreegypttours.com/en/tours/dendera-temple-abydos-day-trip-from-luxor/",
    "https://exploreegypttours.com/en/tours/hurghada-snorkeling-trip-red-sea-day-tour-from-luxor-by-car/",
    "https://exploreegypttours.com/en/tours/pyramids-nile-cruise-hurghada-trip-12-days/",
    "https://exploreegypttours.com/en/tours/east-bank-karank-luxor-temple-tour/",
    "https://exploreegypttours.com/en/tours/all-luxor-sightseeing-tour-west-east-banks/",
    "https://exploreegypttours.com/en/tours/cairo-vacation-istanbul-holiday-13-days/",
    "https://exploreegypttours.com/en/tours/cairo-tours-nile-cruise-from-luxor-to-aswan-8-days/",
    "https://exploreegypttours.com/en/tours/holy-land-tour-cairo-nile-cruise-holiday-11-days/",
    "https://exploreegypttours.com/en/tours/cairo-aswan-luxor-hurghada-overland-10-days/",
    "https://exploreegypttours.com/en/tours/unforgettable-11-days-cairo-luxor-dahab-tour/",
    "https://exploreegypttours.com/en/tours/jerusalem-vacation-jordan-excursion-egypt-holiday-14-days/",
    "https://exploreegypttours.com/en/tours/egypt-cheap-tour-to-cairo-luxor-aswan-10-days/",
    "https://exploreegypttours.com/en/tours/pyramids-cairo-luxor-tour-6-days/",
    "https://exploreegypttours.com/en/tours/cairo-city-tour-citadel-old-cairo-and-khan-el-khalili/",
    "https://exploreegypttours.com/en/tours/giza-pyramids-egyptian-museum-khan-el-khalili-enjoying-camel-ride/",
    "https://exploreegypttours.com/en/tours/on-budget-dahabiya-boat-from-esna-to-aswan-5-days-tour-2/",
    "https://exploreegypttours.com/en/tours/long-river-cruise-from-cairo-to-luxor-aswan-16-days-tour/",
    "https://exploreegypttours.com/en/tours/long-nile-cruise-from-cairo-to-minya-luxor-13-days-tour/",
    "https://exploreegypttours.com/en/tours/deluxe-nile-cruise-from-luxor-to-aswan-8-days/",
]

# ─────────────────────────────────────────────────────────────────────────────
def get_db(): return pyodbc.connect(DB_CONN_STR)

def count_cat(cur, cat):
    cur.execute("SELECT COUNT(*) FROM Places WHERE category=?", cat)
    return cur.fetchone()[0]

def exists(cur, name):
    cur.execute("SELECT COUNT(*) FROM Places WHERE name_en=?", name)
    return cur.fetchone()[0] > 0

def translate_ar(text):
    if not text or len(text.strip()) < 3: return text
    try:
        return GoogleTranslator(source='en', target='ar').translate(text[:4500])
    except:
        return text

def clean_text(t):
    t = re.sub(r'\s+',' ', t or '')
    return t.strip()

def slug_to_name(url):
    """Convert URL slug to human-readable name"""
    slug = url.rstrip('/').split('/')[-1]
    # Remove trailing numbers like -2, -3
    slug = re.sub(r'-\d+$', '', slug)
    name = slug.replace('-', ' ').title()
    # Fix common words
    name = name.replace('Ms ', 'MS ').replace('M S ', 'MS ').replace('M Y ', 'MY ')
    return name

def scrape_tour(url, session):
    """Scrape a single tour page"""
    try:
        r = session.get(url, timeout=15)
        if r.status_code != 200:
            return None
        soup = BeautifulSoup(r.text, 'html.parser')

        # Title
        title = ''
        for sel in ['h1.entry-title', 'h1.tour-title', 'h1', '.tour-name']:
            el = soup.select_one(sel)
            if el:
                title = clean_text(el.get_text())
                if title: break
        if not title:
            title = slug_to_name(url)

        # Description - try multiple selectors
        desc = ''
        for sel in ['.tour-description', '.entry-content p', '.tour-excerpt',
                    'meta[name="description"]', '.description p',
                    '.overview-content', '.tab-content p']:
            if 'meta' in sel:
                el = soup.select_one(sel)
                if el: desc = el.get('content', '').strip()
            else:
                els = soup.select(sel)
                if els:
                    desc = ' '.join(clean_text(e.get_text()) for e in els[:3])
            if desc and len(desc) > 50: break

        # Fallback: meta description
        if not desc or len(desc) < 30:
            meta = soup.find('meta', attrs={'name': 'description'})
            if meta: desc = meta.get('content', '').strip()

        if not desc or len(desc) < 20:
            desc = f"Discover Egypt on this amazing tour: {title}"

        desc = desc[:3000]

        # Price
        price = 0.0
        price_el = soup.select_one('.price, .tour-price, [class*="price"]')
        if price_el:
            m = re.search(r'[\$€£]?\s*(\d[\d,]+)', price_el.get_text())
            if m:
                try: price = float(m.group(1).replace(',', ''))
                except: pass
        if not price:
            m = re.search(r'(?:from|starting)?\s*\$\s*(\d[\d,]+)', r.text, re.I)
            if m:
                try: price = float(m.group(1).replace(',', ''))
                except: pass

        # Images
        imgs = []
        seen = set()
        # Try og:image first
        og = soup.find('meta', property='og:image')
        if og:
            u = og.get('content', '')
            if u and u not in seen:
                seen.add(u); imgs.append(u)

        # Tour gallery images
        for img in soup.select('img[src]'):
            src = img.get('src', '') or img.get('data-src', '')
            if (src and src.startswith('http') and src not in seen
                    and any(x in src for x in ['uploads', 'wp-content', 'tour', 'egypt'])
                    and not any(x in src.lower() for x in ['logo', 'avatar', 'icon',
                                                             'flag', 'banner', 'header'])
                    and src.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))):
                seen.add(src); imgs.append(src)
            if len(imgs) >= 3: break

        # Coordinates (usually not on tour pages, use defaults per gov)
        lat, lng = 0.0, 0.0

        return {
            'name': title[:299],
            'desc': desc,
            'price': price,
            'imgs': imgs[:3],
            'lat': lat, 'lng': lng,
        }
    except Exception as e:
        print(f"  ERR scraping {url}: {e}")
        return None


def insert_place(cur, cat, gov, d):
    o_open, o_close = OPEN_MAP.get(cat, ('09:00', '18:00'))
    cur.execute("""
        INSERT INTO Places(name_en,name_ar,description_en,description_ar,
            category,governorate,latitude,longitude,address,
            admission_fee_egyptian,admission_fee_foreign,
            opening_hours_open,opening_hours_close,opening_hours_days,
            tags,is_featured,avg_rating,review_count,
            rating_1,rating_2,rating_3,rating_4,rating_5,created_at)
        OUTPUT INSERTED.id VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,GETDATE())
    """,
    d['name_en'], d['name_ar'], d['desc_en'], d['desc_ar'],
    cat, gov, d['lat'], d['lng'], gov+', Egypt',
    0.0, d['price'], o_open, o_close, 'Daily',
    TAGS_MAP.get(cat, 'Egypt,tourism'),
    d['price'] > 200, 4.3, 0,
    0, 0, 0, 0, 0)
    return cur.fetchone()[0]

def insert_imgs(cur, pid, imgs):
    for i, u in enumerate(imgs[:3]):
        if u and u.startswith('http'):
            cur.execute(
                "INSERT INTO PlaceImages(place_id,image_url,sort_order)VALUES(?,?,?)",
                pid, u, i)


def main():
    print("="*65)
    print("ExploreEgyptTours Scraper - 186 Tours → DB")
    print("="*65)

    conn = get_db()
    cursor = conn.cursor()

    # Show current counts
    cats = ['historical','museum','cruise','beach','desert','nature','market','religious','hotel']
    print("\nCurrent DB counts:")
    for c in cats:
        print(f"  {c:12}: {count_cat(cursor, c)}")
    print()

    session = requests.Session()
    session.headers.update(HEADERS)

    total_added = 0
    skipped = 0

    for i, url in enumerate(TOUR_URLS):
        # Determine category
        cat = map_category(url, '')
        current = count_cat(cursor, cat)

        if current >= TARGET:
            print(f"[{i+1}/186] SKIP (cat={cat} already {current}/100)")
            skipped += 1
            continue

        print(f"\n[{i+1}/186] {cat.upper()} ({current}/100)")
        print(f"  URL: {url.split('/tours/')[-1].rstrip('/')}")

        data = scrape_tour(url, session)
        if not data:
            print("  Failed to scrape"); continue

        name = data['name']
        cat = map_category(url, name)  # re-check with actual title
        gov = infer_gov(url, name)

        print(f"  Name: {name[:60]}")
        print(f"  Cat:  {cat} | Gov: {gov} | Imgs: {len(data['imgs'])}")

        if exists(cursor, name):
            print(f"  Exists - skip"); continue

        # Translate
        print(f"  Translating...")
        name_ar = translate_ar(name)
        desc_ar = translate_ar(data['desc'][:500])

        db_data = dict(
            name_en=name, name_ar=name_ar[:299],
            desc_en=data['desc'], desc_ar=desc_ar,
            lat=data['lat'], lng=data['lng'],
            price=data['price'],
        )

        try:
            pid = insert_place(cursor, cat, gov, db_data)
            insert_imgs(cursor, pid, data['imgs'])
            conn.commit()
            total_added += 1
            print(f"  [OK] ID:{pid}")
        except Exception as e:
            conn.rollback()
            print(f"  [ERR] {e}")

        time.sleep(random.uniform(0.5, 1.2))

    # Final summary
    print(f"\n{'='*65}")
    print(f"[DONE] Added: {total_added} | Skipped (full): {skipped}")
    print("\nFinal DB counts:")
    for c in cats:
        print(f"  {c:12}: {count_cat(cursor, c)}/100")
    print("="*65)

    cursor.close()
    conn.close()


if __name__ == '__main__':
    main()
