# -*- coding: utf-8 -*-
"""
Export DiscoverEgypt data from SQL Server → SQLite
Output: discover_egypt.db (to be bundled in Flutter assets)
"""
import sys, os, sqlite3, pyodbc, json

sys.stdout.reconfigure(encoding='utf-8')

DB_CONN_STR = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost,1433;DATABASE=DiscoverEgypt;"
    "UID=sa;PWD=YourPassword123!;TrustServerCertificate=yes;"
)

OUTPUT_PATH = r"C:\Users\Master\discover_egypt_production\assets\db\discover_egypt.db"

def main():
    print("="*60)
    print("SQL Server → SQLite Export")
    print("="*60)

    # Connect SQL Server
    print("Connecting to SQL Server...")
    sql_conn = pyodbc.connect(DB_CONN_STR)
    sql_cur  = sql_conn.cursor()

    # Create output directory
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)

    # Remove old SQLite file
    if os.path.exists(OUTPUT_PATH):
        os.remove(OUTPUT_PATH)
        print("Removed old SQLite file")

    # Create SQLite
    print(f"Creating SQLite: {OUTPUT_PATH}")
    lite = sqlite3.connect(OUTPUT_PATH)
    lite_cur = lite.cursor()

    # ── Create tables ─────────────────────────────────────────
    lite_cur.executescript("""
    CREATE TABLE IF NOT EXISTS places (
        id              INTEGER PRIMARY KEY,
        name_en         TEXT NOT NULL,
        name_ar         TEXT,
        desc_en         TEXT,
        desc_ar         TEXT,
        category        TEXT,
        governorate     TEXT,
        latitude        REAL DEFAULT 0,
        longitude       REAL DEFAULT 0,
        address         TEXT,
        fee_egyptian    REAL DEFAULT 0,
        fee_foreign     REAL DEFAULT 0,
        hours_open      TEXT DEFAULT '09:00',
        hours_close     TEXT DEFAULT '18:00',
        hours_days      TEXT DEFAULT 'Daily',
        tags            TEXT,
        is_featured     INTEGER DEFAULT 0,
        avg_rating      REAL DEFAULT 0,
        review_count    INTEGER DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS place_images (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        place_id    INTEGER NOT NULL,
        image_url   TEXT NOT NULL,
        sort_order  INTEGER DEFAULT 0,
        FOREIGN KEY (place_id) REFERENCES places(id)
    );

    CREATE INDEX IF NOT EXISTS idx_places_category   ON places(category);
    CREATE INDEX IF NOT EXISTS idx_places_gov        ON places(governorate);
    CREATE INDEX IF NOT EXISTS idx_places_featured   ON places(is_featured);
    CREATE INDEX IF NOT EXISTS idx_place_images_pid  ON place_images(place_id);
    """)

    # ── Export Places ─────────────────────────────────────────
    print("\nExporting Places...")
    sql_cur.execute("""
        SELECT id, name_en, name_ar, description_en, description_ar,
               category, governorate, latitude, longitude, address,
               admission_fee_egyptian, admission_fee_foreign,
               opening_hours_open, opening_hours_close, opening_hours_days,
               tags, is_featured, avg_rating, review_count
        FROM Places
        ORDER BY id
    """)

    places = sql_cur.fetchall()
    print(f"  Found {len(places)} places")

    lite_cur.executemany("""
        INSERT INTO places VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    """, [
        (
            row[0],                          # id
            row[1] or '',                    # name_en
            row[2] or '',                    # name_ar
            row[3] or '',                    # desc_en
            row[4] or '',                    # desc_ar
            row[5] or '',                    # category
            row[6] or '',                    # governorate
            float(row[7] or 0),             # latitude
            float(row[8] or 0),             # longitude
            row[9] or '',                    # address
            float(row[10] or 0),            # fee_egyptian
            float(row[11] or 0),            # fee_foreign
            row[12] or '09:00',             # hours_open
            row[13] or '18:00',             # hours_close
            row[14] or 'Daily',             # hours_days
            row[15] or '',                   # tags
            1 if row[16] else 0,            # is_featured
            float(row[17] or 0),            # avg_rating
            int(row[18] or 0),              # review_count
        )
        for row in places
    ])

    # ── Export PlaceImages ────────────────────────────────────
    print("Exporting PlaceImages...")
    sql_cur.execute("""
        SELECT id, place_id, image_url, sort_order
        FROM PlaceImages
        ORDER BY place_id, sort_order
    """)

    images = sql_cur.fetchall()
    print(f"  Found {len(images)} images")

    lite_cur.executemany("""
        INSERT INTO place_images(id, place_id, image_url, sort_order)
        VALUES (?,?,?,?)
    """, [(row[0], row[1], row[2] or '', row[3] or 0) for row in images])

    lite.commit()

    # ── Stats ─────────────────────────────────────────────────
    lite_cur.execute("SELECT COUNT(*) FROM places")
    p_count = lite_cur.fetchone()[0]
    lite_cur.execute("SELECT COUNT(*) FROM place_images")
    i_count = lite_cur.fetchone()[0]

    # Per category
    lite_cur.execute("SELECT category, COUNT(*) FROM places GROUP BY category ORDER BY category")
    cats = lite_cur.fetchall()

    print(f"\n{'='*60}")
    print(f"SQLite created: {OUTPUT_PATH}")
    print(f"  Places:  {p_count}")
    print(f"  Images:  {i_count}")
    print(f"\nBy category:")
    for cat, cnt in cats:
        print(f"  {cat:14}: {cnt}")

    size_mb = os.path.getsize(OUTPUT_PATH) / (1024*1024)
    print(f"\nFile size: {size_mb:.2f} MB")
    print("="*60)

    lite.close()
    sql_conn.close()

if __name__ == '__main__':
    main()
