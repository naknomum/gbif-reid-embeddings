from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from psycopg2.extras import RealDictCursor
import psycopg2
import os

app = FastAPI()

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "db"),
    "port": os.getenv("DB_PORT", 5432),
    "dbname": os.getenv("DB_NAME", "mydb"),
    "user": os.getenv("DB_USER", "myuser"),
    "password": os.getenv("DB_PASSWORD", "mypassword"),
}


def get_connection():
    return psycopg2.connect(**DB_CONFIG)


@app.get("/", response_class=HTMLResponse)
def index():
    with open("/static/index.html") as f:
        return f.read()

@app.get("/about", response_class=HTMLResponse)
def about():
    with open("/static/about.html") as f:
        return f.read()

@app.get("/test")
def get_test_rows():
    try:
        conn = get_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM image LIMIT 100;")
            rows = cur.fetchall()
        conn.close()
        return {"data": [dict(row) for row in rows]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/match/{id}")
def get_matching_row(id: int):
    try:
        conn = get_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT annotation.id AS annot_id, bbox, image_id, uri, gbif_id, (embedding <=> (SELECT embedding FROM annotation WHERE id=%s)) AS score FROM annotation JOIN image ON (image_id = image.id) WHERE bbox::text != '{}' ORDER BY score LIMIT 10;", (id, ));
            rows = cur.fetchall()
        conn.close()
        return {"data": [dict(row) for row in rows]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
def health():
    return {"status": "ok"}
