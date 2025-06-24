import os
import uuid
import json
import shutil
from fastapi import FastAPI, UploadFile, File, Form, Request
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_DIR = os.path.join(BASE_DIR, "static", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

DB_PATH = os.path.join(BASE_DIR, "annonces.db")
engine = create_engine(f"sqlite:///{DB_PATH}", connect_args={"check_same_thread": False})
Base = declarative_base()
SessionLocal = sessionmaker(bind=engine)

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.mount("/static", StaticFiles(directory=os.path.join(BASE_DIR, "static")), name="static")
templates = Jinja2Templates(directory=os.path.join(BASE_DIR, "templates"))

class AnnonceCreee(Base):
    __tablename__ = "annonces_creees"
    id = Column(Integer, primary_key=True)
    titre = Column(String)
    contenu = Column(String)
    images = Column(String)  # JSON array
    adresse = Column(String, nullable=True)
    youtube = Column(String, nullable=True)     # <-- ajouté

class AnnoncePubliee(Base):
    __tablename__ = "annonces_publiees"
    id = Column(Integer, primary_key=True)
    titre = Column(String)
    contenu = Column(String)
    images = Column(String)  # JSON array
    adresse = Column(String, nullable=True)
    youtube = Column(String, nullable=True)     # <-- ajouté

Base.metadata.create_all(bind=engine)

# Page racine qui sert le HTML (pour dev local)
@app.get("/", response_class=HTMLResponse)
def serve_home(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

# === CRUD API ===

@app.post("/api/annonces")
async def create_annonce(
    titre: str = Form(...),
    contenu: str = Form(...),
    adresse: str = Form(None),
    youtube: str = Form(None),
    images: list[UploadFile] = File(None)
):
    image_paths = []
    if images:
        for img in images:
            if not img.filename:
                continue
            ext = img.filename.split('.')[-1]
            filename = f"{uuid.uuid4()}.{ext}"
            dest = os.path.join(UPLOAD_DIR, filename)
            with open(dest, "wb") as buffer:
                shutil.copyfileobj(img.file, buffer)
            image_paths.append(f"/static/uploads/{filename}")

    db = SessionLocal()
    a = AnnonceCreee(
        titre=titre,
        contenu=contenu,
        images=json.dumps(image_paths),
        adresse=adresse,
        youtube=youtube
    )
    db.add(a)
    db.commit()
    db.close()
    return {"success": True}

@app.get("/api/annonces_creees")
def get_annonces_creees():
    db = SessionLocal()
    annonces = db.query(AnnonceCreee).all()
    db.close()
    return [{
        "id": a.id,
        "titre": a.titre,
        "contenu": a.contenu,
        "images": json.loads(a.images or "[]"),
        "adresse": a.adresse,
        "youtube": a.youtube
    } for a in annonces]

@app.get("/api/annonces_publiees")
def get_annonces_publiees():
    db = SessionLocal()
    annonces = db.query(AnnoncePubliee).all()
    db.close()
    return [{
        "id": a.id,
        "titre": a.titre,
        "contenu": a.contenu,
        "images": json.loads(a.images or "[]"),
        "adresse": a.adresse,
        "youtube": a.youtube
    } for a in annonces]

@app.post("/api/annonces_creees/{id}/delete")
def delete_annonce_creee(id: int):
    db = SessionLocal()
    a = db.query(AnnonceCreee).filter(AnnonceCreee.id == id).first()
    if a:
        for img in json.loads(a.images or "[]"):
            p = os.path.join(BASE_DIR, img.lstrip("/"))
            if os.path.exists(p):
                os.remove(p)
        db.delete(a)
        db.commit()
    db.close()
    return {"success": True}

@app.post("/api/annonces_publiees/{id}/delete")
def delete_annonce_publiee(id: int):
    db = SessionLocal()
    a = db.query(AnnoncePubliee).filter(AnnoncePubliee.id == id).first()
    if a:
        for img in json.loads(a.images or "[]"):
            p = os.path.join(BASE_DIR, img.lstrip("/"))
            if os.path.exists(p):
                os.remove(p)
        db.delete(a)
        db.commit()
    db.close()
    return {"success": True}

@app.post("/api/annonces_creees/{id}/publish")
def publier_annonce(id: int):
    db = SessionLocal()
    a = db.query(AnnonceCreee).filter(AnnonceCreee.id == id).first()
    if not a:
        db.close()
        return {"error": "Not found"}
    annonce_pub = AnnoncePubliee(
        titre=a.titre,
        contenu=a.contenu,
        images=a.images,
        adresse=a.adresse,
        youtube=a.youtube
    )
    db.add(annonce_pub)
    db.delete(a)
    db.commit()
    db.close()
    return {"success": True}

# Edition d’une annonce créée (brouillon)
@app.post("/api/annonces_creees/{id}/edit")
async def edit_annonce(
    id: int,
    titre: str = Form(...),
    contenu: str = Form(...),
    adresse: str = Form(None),
    youtube: str = Form(None),
    keep_images: str = Form("[]"),
    images: list[UploadFile] = File(None)
):
    db = SessionLocal()
    annonce = db.query(AnnonceCreee).filter(AnnonceCreee.id == id).first()
    if not annonce:
        db.close()
        return {"error": "Not found"}
    old_images = json.loads(annonce.images or "[]")
    keep = set(json.loads(keep_images))
    # Supprime les images décochées
    for img in old_images:
        if img not in keep:
            p = os.path.join(BASE_DIR, img.lstrip("/"))
            if os.path.exists(p):
                os.remove(p)
    image_paths = list(keep)
    if images:
        for img in images:
            if not img.filename:
                continue
            ext = img.filename.split('.')[-1]
            filename = f"{uuid.uuid4()}.{ext}"
            dest = os.path.join(UPLOAD_DIR, filename)
            with open(dest, "wb") as buffer:
                shutil.copyfileobj(img.file, buffer)
            image_paths.append(f"/static/uploads/{filename}")
    annonce.titre = titre
    annonce.contenu = contenu
    annonce.images = json.dumps(image_paths)
    annonce.adresse = adresse
    annonce.youtube = youtube
    db.commit()
    db.close()
    return {"success": True}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
