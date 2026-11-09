from contextlib import asynccontextmanager

from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form
from fastapi.staticfiles import StaticFiles
from pathlib import Path
import shutil
import uuid
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from pwdlib import PasswordHash

from database import Base, engine, obtener_sesion
from models import Usuario, Blog, Comentario
from schemas import (
    UsuarioCrear,
    UsuarioActualizar,
    UsuarioRespuesta,
    BlogRespuesta,
    BlogCrear,
    ComentarioCrear,
    ComentarioRespuesta,
    LoginRequest,
)


password_hash = PasswordHash.recommended()


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield


app = FastAPI(
    title="API de aplicación móvil",
    lifespan=lifespan,
)


# PERMITIR COMUNICACIÓN CON FLUTTER WEB
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1):\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# CARPETA PARA GUARDAR Y MOSTRAR FOTOGRAFÍAS
UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")


# INICIO

@app.get("/")
def inicio():
    return {"mensaje": "API funcionando correctamente"}


# LOGIN

@app.post("/login", response_model=UsuarioRespuesta)
def iniciar_sesion(
    datos: LoginRequest,
    db: Session = Depends(obtener_sesion),
):
    correo = datos.mail.strip().lower()

    usuario = db.scalar(
        select(Usuario).where(Usuario.mail == correo)
    )

    if usuario is None or not password_hash.verify(
        datos.password,
        usuario.pass_hash,
    ):
        raise HTTPException(
            status_code=401,
            detail="Correo o contraseña incorrectos",
        )

    return usuario


# USUARIOS

@app.get("/usuarios", response_model=list[UsuarioRespuesta])
def listar_usuarios(
    db: Session = Depends(obtener_sesion),
):
    return db.scalars(
        select(Usuario).order_by(Usuario.id_usr)
    ).all()


@app.post(
    "/usuarios",
    response_model=UsuarioRespuesta,
    status_code=201,
)
def crear_usuario(
    datos: UsuarioCrear,
    db: Session = Depends(obtener_sesion),
):
    usuario = Usuario(
        nom_usr=datos.nom_usr.strip(),
        mail=datos.mail.strip().lower(),
        pass_hash=password_hash.hash(datos.password),
        dir_usr=datos.dir_usr,
        tip_usu=datos.tip_usu,
    )

    db.add(usuario)

    try:
        db.commit()
        db.refresh(usuario)

    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=409,
            detail="El correo ya está registrado",
        )

    return usuario


@app.put(
    "/usuarios/{usuario_id}",
    response_model=UsuarioRespuesta,
)
def actualizar_usuario(
    usuario_id: int,
    datos: UsuarioActualizar,
    db: Session = Depends(obtener_sesion),
):
    usuario = db.get(Usuario, usuario_id)

    if usuario is None:
        raise HTTPException(
            status_code=404,
            detail="Usuario no encontrado",
        )

    usuario.nom_usr = datos.nom_usr.strip()
    usuario.mail = datos.mail.strip().lower()
    usuario.dir_usr = datos.dir_usr
    usuario.tip_usu = datos.tip_usu

    try:
        db.commit()
        db.refresh(usuario)

    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=409,
            detail="El correo ya está registrado",
        )

    return usuario


@app.delete("/usuarios/{usuario_id}")
def eliminar_usuario(
    usuario_id: int,
    db: Session = Depends(obtener_sesion),
):
    usuario = db.get(Usuario, usuario_id)

    if usuario is None:
        raise HTTPException(
            status_code=404,
            detail="Usuario no encontrado",
        )

    db.delete(usuario)
    db.commit()

    return {
        "mensaje": "Usuario eliminado correctamente"
    }


# BLOG

@app.get(
    "/blog",
    response_model=list[BlogRespuesta])
def listar_blog(
    db: Session = Depends(obtener_sesion),
):
    return db.scalars(
        select(Blog).order_by(Blog.id_blog)
    ).all()

@app.post("/blog", response_model=BlogRespuesta, status_code=201)
def crear_blog(
    datos:BlogCrear,
    db: Session = Depends(obtener_sesion),
):
    publicacion = Blog(
        titulo= datos.titulo.strip(),
        descripcion=datos.descripcion.strip(),
        img=datos.img.strip() if datos.img and datos.img.strip() else None,
        tags=datos.tags.strip() if datos.tags and datos.tags.strip() else None,
    )
    db.add(publicacion)
    db.commit()
    db.refresh(publicacion)
    return publicacion

# NUEVO ENDPOINT: FORMULARIO CON FOTO
# Se conserva el POST /blog original para no afectar a Flutter.
@app.post("/blog/foto")
async def crear_blog_con_foto(
    titulo: str = Form(...),
    descripcion: str = Form(...),
    tags: str | None = Form(None),
    imagen: UploadFile = File(...),
    db: Session = Depends(obtener_sesion),
):
    if not titulo.strip() or not descripcion.strip():
        raise HTTPException(400, "El título y la descripción son obligatorios")

    extension = Path(imagen.filename or "").suffix.lower()
    if extension not in [".jpg", ".jpeg", ".png", ".webp"]:
        raise HTTPException(400, "Formato de imagen no permitido")

    nombre_archivo = f"{uuid.uuid4().hex}{extension}"
    ruta_archivo = UPLOAD_DIR / nombre_archivo

    with ruta_archivo.open("wb") as destino:
        shutil.copyfileobj(imagen.file, destino)

    ruta_publica = f"/uploads/{nombre_archivo}"

    # Guardar los datos y la ruta en la tabla blog ya existente.
    publicacion = Blog(
        titulo=titulo.strip(),
        descripcion=descripcion.strip(),
        img=ruta_publica,
        tags=tags.strip() if tags and tags.strip() else None,
    )
    db.add(publicacion)
    db.commit()
    db.refresh(publicacion)

    return {
        "mensaje": "Archivo recibido",
        "titulo": publicacion.titulo,
        "descripcion": publicacion.descripcion,
        "imagen": publicacion.img,
    }


@app.get(
    "/blog/{blog_id}",
    response_model=BlogRespuesta,
)
def obtener_blog(
    blog_id: int,
    db: Session = Depends(obtener_sesion),
):
    publicacion = db.get(Blog, blog_id)

    if publicacion is None:
        raise HTTPException(
            status_code=404,
            detail="Publicación no encontrada",
        )

    return publicacion


# COMENTARIOS

@app.get(
    "/comentarios",
    response_model=list[ComentarioRespuesta],
)
def listar_comentarios(
    db: Session = Depends(obtener_sesion),
):
    return db.scalars(
        select(Comentario).order_by(Comentario.id_com)
    ).all()


@app.post(
    "/comentarios",
    response_model=ComentarioRespuesta,
    status_code=201,
)
def crear_comentario(
    datos: ComentarioCrear,
    db: Session = Depends(obtener_sesion),
):
    if not datos.comentario.strip():
        raise HTTPException(
            status_code=422,
            detail="El comentario no puede estar vacío",
        )

    if db.get(Usuario, datos.usr_id) is None:
        raise HTTPException(
            status_code=404,
            detail="Usuario no encontrado",
        )

    if db.get(Blog, datos.blog_id) is None:
        raise HTTPException(
            status_code=404,
            detail="Publicación no encontrada",
        )

    nuevo = Comentario(
        comentario=datos.comentario.strip(),
        usr_id=datos.usr_id,
        blog_id=datos.blog_id,
        estatus=1,
    )

    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)

    return nuevo