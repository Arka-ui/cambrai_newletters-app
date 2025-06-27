import os
import sqlite3
from fastapi import FastAPI, Request, UploadFile, File, Form
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi import status
from typing import List
import atexit
from starlette.requests import Request as StarletteRequest
from starlette.responses import Response
import mimetypes
import re

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "annonces.db")
UPLOAD_DIR = os.path.join(BASE_DIR, "static", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.mount("/static", StaticFiles(directory=os.path.join(BASE_DIR, "static")), name="static")
templates = Jinja2Templates(directory=os.path.join(BASE_DIR, "templates"))

# --- DB INIT ---
def init_db():
    with sqlite3.connect(DB_PATH) as conn:
        c = conn.cursor()
        c.execute('''CREATE TABLE IF NOT EXISTS annonces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            titre TEXT,
            contenu TEXT,
            adresse TEXT,
            youtube TEXT,
            images TEXT,
            publiee INTEGER DEFAULT 0,
            epingle INTEGER DEFAULT 0,
            tags TEXT,
            lieux TEXT,
            adresses TEXT,
            youtubes TEXT
        )''')
        conn.commit()

# Appel DB INIT au démarrage FastAPI
@app.on_event("startup")
def on_startup():
    init_db()

# --- Sécurité globale ---
ALLOWED_IMAGE_TYPES = {"image/png", "image/jpeg", "image/gif", "image/webp"}
MAX_IMAGE_SIZE = 5 * 1024 * 1024  # 5 Mo
FILENAME_SAFE = re.compile(r'^[\w\-. ]+$')

def is_safe_filename(filename):
    return bool(FILENAME_SAFE.match(filename))

# --- API CRUD ---
@app.get("/api/annonces")
def get_annonces():
    # Sécurité : on ne retourne que les champs attendus
    with sqlite3.connect(DB_PATH) as conn:
        c = conn.cursor()
        c.execute("SELECT * FROM annonces WHERE publiee=0 ORDER BY epingle DESC, id DESC")
        creees = [row_to_dict(row) for row in c.fetchall()]
        c.execute("SELECT * FROM annonces WHERE publiee=1 ORDER BY epingle DESC, id DESC")
        publiees = [row_to_dict(row) for row in c.fetchall()]
    # Log les adresses de toutes les annonces publiées
    for annonce in publiees:
        print(f"[DEBUG BACKEND] Annonce: {annonce['titre']} | Adresses: {repr(annonce['adresses'])}")
    return {"creees": creees, "publiees": publiees}

def row_to_dict(row):
    return {
        "id": row[0],
        "titre": row[1],
        "contenu": row[2],
        "adresse": row[3],
        "youtube": row[4],
        "images": row[5].split(',') if row[5] else [],
        "publiee": bool(row[6]),
        "epingle": bool(row[7]) if len(row) > 7 else False,
        "tags": row[8] if len(row) > 8 else '',
        "lieux": row[9] if len(row) > 9 else '',
        "adresses": row[10] if len(row) > 10 else '',
        "youtubes": row[11] if len(row) > 11 else ''
    }

@app.post("/api/annonces")
async def create_annonce(
    titre: str = Form(...),
    contenu: str = Form(...),
    adresse: str = Form(None),
    youtube: str = Form(None),
    images: List[UploadFile] = File([]),
    epingle: str = Form('off'),
    tags: str = Form(''),
    lieux: str = Form(''),
    adresses: str = Form(''),
    youtubes: str = Form(''),
    request: StarletteRequest = None
):
    print("[DEBUG] Reçu POST /api/annonces")
    print("[DEBUG] titre:", titre)
    print("[DEBUG] contenu:", contenu)
    print("[DEBUG] adresse:", adresse)
    print("[DEBUG] youtube:", youtube)
    print("[DEBUG] epingle:", epingle)
    print("[DEBUG] tags:", tags)
    print("[DEBUG] lieux:", lieux)
    print("[DEBUG] adresses:", adresses)
    print("[DEBUG] youtubes:", youtubes)
    print("[DEBUG] images reçues:", [img.filename for img in images])
    image_urls = []
    for img in images:
        if not img.filename or img.filename.strip() == "":
            continue  # Ignore les fichiers sans nom
        if not is_safe_filename(img.filename):
            continue  # Ignore noms de fichiers suspects
        content = await img.read()
        if not content or len(content) > MAX_IMAGE_SIZE:
            continue  # Ignore fichiers vides ou trop gros
        mime, _ = mimetypes.guess_type(img.filename)
        if img.content_type not in ALLOWED_IMAGE_TYPES or (mime and mime not in ALLOWED_IMAGE_TYPES):
            continue  # Ignore types non autorisés
        fname = f"{os.urandom(8).hex()}_{img.filename}"
        fpath = os.path.join(UPLOAD_DIR, fname)
        with open(fpath, "wb") as f:
            f.write(content)
        image_urls.append(f"/static/uploads/{fname}")
    with sqlite3.connect(DB_PATH) as conn:
        c = conn.cursor()
        c.execute("INSERT INTO annonces (titre, contenu, adresse, youtube, images, epingle, tags, lieux, adresses, youtubes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                  (titre, contenu, adresse, youtube, ','.join(image_urls), 1 if epingle == 'on' else 0, tags, lieux, adresses, youtubes))
        conn.commit()
    return {"ok": True}

@app.post("/api/annonces/{id}/publier")
def publier_annonce(id: int):
    # Sécurité : publication uniquement si l'annonce existe
    with sqlite3.connect(DB_PATH) as conn:
        c = conn.cursor()
        c.execute("SELECT id FROM annonces WHERE id=?", (id,))
        if not c.fetchone():
            return {"ok": False, "error": "Annonce introuvable"}
        c.execute("UPDATE annonces SET publiee=1 WHERE id=?", (id,))
        conn.commit()
    return {"ok": True}

@app.post("/api/annonces/{id}/supprimer")
def supprimer_annonce(id: int):
    # Sécurité : suppression uniquement si l'annonce existe
    with sqlite3.connect(DB_PATH) as conn:
        c = conn.cursor()
        c.execute("SELECT id FROM annonces WHERE id=?", (id,))
        if not c.fetchone():
            return {"ok": False, "error": "Annonce introuvable"}
        c.execute("DELETE FROM annonces WHERE id=?", (id,))
        conn.commit()
    return {"ok": True}

@app.post("/api/annonces/{id}/edit")
async def edit_annonce(
    id: int,
    titre: str = Form(...),
    contenu: str = Form(...),
    adresse: str = Form(None),
    youtube: str = Form(None),
    images: List[UploadFile] = File([]),
    epingle: str = Form('off'),
    tags: str = Form(''),
    lieux: str = Form(''),
    adresses: str = Form(''),
    youtubes: str = Form(''),
    request: StarletteRequest = None
):
    image_urls = []
    for img in images:
        if not img.filename or img.filename.strip() == "":
            continue  # Ignore les fichiers sans nom
        if not is_safe_filename(img.filename):
            continue  # Ignore noms de fichiers suspects
        content = await img.read()
        if not content or len(content) > MAX_IMAGE_SIZE:
            continue  # Ignore fichiers vides ou trop gros
        mime, _ = mimetypes.guess_type(img.filename)
        if img.content_type not in ALLOWED_IMAGE_TYPES or (mime and mime not in ALLOWED_IMAGE_TYPES):
            continue  # Ignore types non autorisés
        fname = f"{os.urandom(8).hex()}_{img.filename}"
        fpath = os.path.join(UPLOAD_DIR, fname)
        with open(fpath, "wb") as f:
            f.write(content)
        image_urls.append(f"/static/uploads/{fname}")
    with sqlite3.connect(DB_PATH) as conn:
        c = conn.cursor()
        c.execute("UPDATE annonces SET titre=?, contenu=?, adresse=?, youtube=?, images=?, epingle=?, tags=?, lieux=?, adresses=?, youtubes=? WHERE id=?",
                  (titre, contenu, adresse, youtube, ','.join(image_urls), 1 if epingle == 'on' else 0, tags, lieux, adresses, youtubes, id))
        conn.commit()
    return {"ok": True}

# Page racine qui sert le HTML (pour dev local)
@app.get("/", response_class=HTMLResponse)
def serve_home(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
