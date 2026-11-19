from contextlib import asynccontextmanager

import time

from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form
from fastapi.staticfiles import StaticFiles
from pathlib import Path
import shutil
import uuid
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import select, delete, func, or_  # BUSCADOR: or_ para «título O descripción»
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
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
    LoginRespuesta,
)
# SESIONES: funciones y dependencias definidas en seguridad.py
from seguridad import (
    ENCABEZADO_TOKEN_RENOVADO,
    ROL_ADMIN,
    ROL_USUARIO,
    crear_token,
    usuario_actual,
    usuario_opcional,
    requiere_admin,
)


password_hash = PasswordHash.recommended()


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
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
    # SESIONES: sin esta línea el navegador no deja que Flutter Web lea
    # el encabezado donde viaja el token renovado.
    expose_headers=[ENCABEZADO_TOKEN_RENOVADO],
)


# CARPETA PARA GUARDAR Y MOSTRAR FOTOGRAFÍAS
# Usamos la ubicación del propio main.py, no la carpeta donde abrimos la terminal.
UPLOAD_DIR = Path(__file__).resolve().parent / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")


# INICIO

# Público: solo sirve para comprobar que la API está encendida.
@app.get("/")
def inicio():
    return {"mensaje": "API funcionando correctamente"}


# LOGIN

# Público: es la puerta de entrada. Valida las credenciales y entrega el token.
@app.post("/login", response_model=LoginRespuesta)
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

    # SESIONES: las credenciales son correctas, se crea el token.
    # "inicio" es el momento del inicio de sesión (para el tope de 8 horas).
    inicio = int(time.time())
    token = crear_token(usuario.id_usr, inicio)

    return {
        "access_token": token,
        "token_type": "bearer",
        "usuario": usuario,
    }


# USUARIOS

@app.get("/usuarios", response_model=list[UsuarioRespuesta])
def listar_usuarios(
    db: Session = Depends(obtener_sesion),
    admin: Usuario = Depends(requiere_admin),  # SESIONES: solo administrador
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
    actual: Usuario | None = Depends(usuario_opcional),
):
    # CONTROL DE ACCESO: el registro es público, pero SIEMPRE crea un
    # Usuario general. El rol que envía el cliente solo se respeta cuando
    # quien hace la petición es un administrador con sesión iniciada.
    tipo = ROL_USUARIO

    if actual is not None and actual.tip_usu == ROL_ADMIN:
        tipo = datos.tip_usu

    usuario = Usuario(
        nom_usr=datos.nom_usr.strip(),
        mail=datos.mail.strip().lower(),
        pass_hash=password_hash.hash(datos.password),
        dir_usr=datos.dir_usr,
        tip_usu=tipo,
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
    actual: Usuario = Depends(usuario_actual),  # SESIONES: exige sesión
):
    es_admin = actual.tip_usu == ROL_ADMIN

    # CONTROL DE ACCESO: un Usuario general solo puede editar su propio perfil.
    if not es_admin and usuario_id != actual.id_usr:
        raise HTTPException(
            status_code=403,
            detail="No tienes permiso para realizar esta acción.",
        )

    usuario = db.get(Usuario, usuario_id)

    if usuario is None:
        raise HTTPException(
            status_code=404,
            detail="Usuario no encontrado",
        )

    usuario.nom_usr = datos.nom_usr.strip()
    usuario.mail = datos.mail.strip().lower()
    usuario.dir_usr = datos.dir_usr

    # CONTROL DE ACCESO: el rol solo cambia si un administrador edita a OTRO
    # usuario. Nadie puede cambiarse el rol a sí mismo (igual que en la web);
    # por eso siempre queda al menos un administrador: el que hace el cambio.
    if es_admin and usuario_id != actual.id_usr:
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
    admin: Usuario = Depends(requiere_admin),  # SESIONES: solo administrador
):
    # REGLA 1: un administrador no puede eliminar su propia cuenta.
    # "admin" es el usuario dueño del token (quien hace la petición).
    if usuario_id == admin.id_usr:
        raise HTTPException(
            status_code=409,
            detail="No puedes eliminar tu propia cuenta.",
        )

    usuario = db.get(Usuario, usuario_id)

    if usuario is None:
        raise HTTPException(
            status_code=404,
            detail="Usuario no encontrado",
        )

    # REGLA 2: siempre debe quedar al menos un administrador.
    # Se cuentan los administradores SIN contar al que se va a eliminar.
    if usuario.tip_usu == ROL_ADMIN:
        otros_admins = db.scalar(
            select(func.count())
            .select_from(Usuario)
            .where(
                Usuario.tip_usu == ROL_ADMIN,
                Usuario.id_usr != usuario_id,
            )
        )

        if otros_admins < 1:
            raise HTTPException(
                status_code=409,
                detail="Debe quedar al menos un administrador en el sistema.",
            )

    # TRANSACCIÓN: la base no borra en cascada, por eso primero se eliminan
    # los comentarios del usuario y después el usuario. Las dos operaciones
    # se confirman juntas con un solo commit; si algo falla, el rollback
    # deshace todo y no queda nada a medias.
    try:
        resultado = db.execute(
            delete(Comentario).where(Comentario.usr_id == usuario_id)
        )
        comentarios_eliminados = resultado.rowcount

        db.delete(usuario)
        db.commit()

    except SQLAlchemyError:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail="No se pudo eliminar el usuario. Intenta de nuevo.",
        )

    return {
        "mensaje": "Usuario eliminado correctamente",
        "comentarios_eliminados": comentarios_eliminados,
    }


# BLOG

# BUSCADOR DEL BLOG DE TECNOLOGÍAS EMERGENTES
BUSQUEDA_MAX = 100        # largo máximo del texto escrito
BUSQUEDA_PALABRAS = 8     # máximo de palabras que se buscan


@app.get(
    "/blog",
    response_model=list[BlogRespuesta])
def listar_blog(
    q: str | None = None,         # BUSCADOR: texto a buscar (opcional)
    etiqueta: str | None = None,  # BUSCADOR: etiqueta a filtrar (opcional)
    db: Session = Depends(obtener_sesion),
    actual: Usuario = Depends(usuario_actual),  # SESIONES: exige sesión
):
    consulta = select(Blog)

    # BUSCADOR 1. Texto: se quitan los espacios de los extremos y se recorta a 100 caracteres.
    texto = (q or "").strip()[:BUSQUEDA_MAX]

    # Buscamos cada palabra en el título, la descripción o las etiquetas.
    # La búsqueda parcial permite encontrar "robót" en "Robótica".
    # Las mayúsculas dependen de la collation de MySQL.
    for palabra in texto.split()[:BUSQUEDA_PALABRAS]:
        # En LIKE, % y _ son comodines. Para buscarlos como texto normal se usa
        # "|" como carácter de escape y se antepone a | % _ (igual que la web).
        palabra = palabra.replace("|", "||").replace("%", "|%").replace("_", "|_")
        patron = f"%{palabra}%"
        consulta = consulta.where(
            or_(
                Blog.titulo.like(patron, escape="|"),
                Blog.descripcion.like(patron, escape="|"),
                Blog.tags.like(patron, escape="|"),
            )
        )

    # BUSCADOR 2. Filtramos por la etiqueta escrita, aunque no esté en una
    # lista fija. FIND_IN_SET busca entre las etiquetas separadas por coma.
    etiqueta = (etiqueta or "").strip()
    if etiqueta:
        consulta = consulta.where(
            func.find_in_set(
                func.lower(etiqueta),
                func.lower(func.replace(Blog.tags, ", ", ",")),
            ) > 0
        )

    # BUSCADOR 3. Orden igual que la web: la más reciente primero
    # (por fecha y, si la fecha es la misma, por id).
    consulta = consulta.order_by(Blog.fecha.desc(), Blog.id_blog.desc())

    return db.scalars(consulta).all()

@app.post("/blog", response_model=BlogRespuesta, status_code=201)
def crear_blog(
    datos:BlogCrear,
    db: Session = Depends(obtener_sesion),
    admin: Usuario = Depends(requiere_admin),  # SESIONES: solo administrador
):
    publicacion = Blog(
        titulo= datos.titulo.strip(),
        descripcion=datos.descripcion.strip(),
        img=datos.img.strip() if datos.img and datos.img.strip() else None,
        tags=datos.tags.strip() if datos.tags and datos.tags.strip() else None,
        # AUTOR: es el administrador dueño del token, no un dato del cliente.
        usr_id=admin.id_usr,
    )
    db.add(publicacion)
    db.commit()
    db.refresh(publicacion)
    return publicacion

# Guarda la fotografía recibida en la carpeta uploads con un nombre al azar
# y devuelve su ruta pública (/uploads/archivo.jpg). La usan crear y editar.
def guardar_imagen(imagen: UploadFile) -> str:
    extension = Path(imagen.filename or "").suffix.lower()
    if extension not in [".jpg", ".jpeg", ".png", ".webp"]:
        raise HTTPException(400, "Formato de imagen no permitido")

    nombre_archivo = f"{uuid.uuid4().hex}{extension}"
    ruta_archivo = UPLOAD_DIR / nombre_archivo

    with ruta_archivo.open("wb") as destino:
        shutil.copyfileobj(imagen.file, destino)

    return f"/uploads/{nombre_archivo}"


# NUEVO ENDPOINT: FORMULARIO CON FOTO
# Se conserva el POST /blog original para no afectar a Flutter.
@app.post("/blog/foto")
async def crear_blog_con_foto(
    titulo: str = Form(...),
    descripcion: str = Form(...),
    imagen: UploadFile = File(...),
    tags: str | None = Form(None),  # CORRECCIÓN TAGS
    db: Session = Depends(obtener_sesion),
    admin: Usuario = Depends(requiere_admin),  # SESIONES: solo administrador
):
    if not titulo.strip() or not descripcion.strip():
        raise HTTPException(400, "El título y la descripción son obligatorios")

    ruta_publica = guardar_imagen(imagen)

    # Guardar los datos y la ruta en la tabla blog ya existente.
    publicacion = Blog(
        titulo=titulo.strip(),
        descripcion=descripcion.strip(),
        img=ruta_publica,
        tags=tags.strip() if tags and tags.strip() else None,  # CORRECCIÓN TAGS
        # AUTOR: es el administrador dueño del token, no un dato del cliente.
        usr_id=admin.id_usr,
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
    actual: Usuario = Depends(usuario_actual),  # SESIONES: exige sesión
):
    publicacion = db.get(Blog, blog_id)

    if publicacion is None:
        raise HTTPException(
            status_code=404,
            detail="Publicación no encontrada",
        )

    return publicacion


# EDITAR: actualiza una publicación con JSON (sin fotografía nueva).
# La imagen queda con el valor de "img": para conservar la actual, la app
# envía la misma ruta; si envía vacío, la publicación queda sin imagen.
@app.put(
    "/blog/{blog_id}",
    response_model=BlogRespuesta,
)
def actualizar_blog(
    blog_id: int,
    datos: BlogCrear,
    db: Session = Depends(obtener_sesion),
    admin: Usuario = Depends(requiere_admin),  # SESIONES: solo administrador
):
    publicacion = db.get(Blog, blog_id)

    if publicacion is None:
        raise HTTPException(
            status_code=404,
            detail="Publicación no encontrada",
        )

    # Cualquier administrador puede editar cualquier publicación.
    # El autor (usr_id) y la fecha NO cambian al editar.
    publicacion.titulo = datos.titulo.strip()
    publicacion.descripcion = datos.descripcion.strip()
    publicacion.img = datos.img.strip() if datos.img and datos.img.strip() else None
    publicacion.tags = datos.tags.strip() if datos.tags and datos.tags.strip() else None

    db.commit()
    db.refresh(publicacion)

    return publicacion


# EDITAR: actualiza una publicación y le pone una fotografía nueva.
@app.put(
    "/blog/{blog_id}/foto",
    response_model=BlogRespuesta,
)
async def actualizar_blog_con_foto(
    blog_id: int,
    titulo: str = Form(...),
    descripcion: str = Form(...),
    imagen: UploadFile = File(...),
    tags: str | None = Form(None),
    db: Session = Depends(obtener_sesion),
    admin: Usuario = Depends(requiere_admin),  # SESIONES: solo administrador
):
    publicacion = db.get(Blog, blog_id)

    if publicacion is None:
        raise HTTPException(
            status_code=404,
            detail="Publicación no encontrada",
        )

    if len(titulo.strip()) < 2 or len(titulo.strip()) > 150 or not descripcion.strip():
        raise HTTPException(400, "El título y la descripción son obligatorios")

    publicacion.titulo = titulo.strip()
    publicacion.descripcion = descripcion.strip()
    publicacion.img = guardar_imagen(imagen)
    publicacion.tags = tags.strip() if tags and tags.strip() else None

    db.commit()
    db.refresh(publicacion)

    return publicacion


# ELIMINAR PUBLICACIÓN
@app.delete("/blog/{blog_id}")
def eliminar_blog(
    blog_id: int,
    db: Session = Depends(obtener_sesion),
    admin: Usuario = Depends(requiere_admin),  # SESIONES: solo administrador
):
    publicacion = db.get(Blog, blog_id)

    if publicacion is None:
        raise HTTPException(
            status_code=404,
            detail="Publicación no encontrada",
        )

    # TRANSACCIÓN: la base no borra en cascada, por eso primero se eliminan
    # los comentarios de la publicación y después la publicación. Un solo
    # commit confirma las dos operaciones; si algo falla, el rollback
    # deshace todo. (El archivo de imagen no se borra, igual que en la web.)
    try:
        resultado = db.execute(
            delete(Comentario).where(Comentario.blog_id == blog_id)
        )
        comentarios_eliminados = resultado.rowcount

        db.delete(publicacion)
        db.commit()

    except SQLAlchemyError:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail="No se pudo eliminar la publicación. Intenta de nuevo.",
        )

    return {
        "mensaje": "Publicación eliminada correctamente",
        "comentarios_eliminados": comentarios_eliminados,
    }


# COMENTARIOS

# MODERAR: TODOS los comentarios de una publicación (visibles y ocultos),
# del más reciente al más antiguo. Solo para el administrador.
@app.get(
    "/blog/{blog_id}/comentarios/moderacion",
    response_model=list[ComentarioRespuesta],
)
def listar_comentarios_para_moderar(
    blog_id: int,
    db: Session = Depends(obtener_sesion),
    admin: Usuario = Depends(requiere_admin),  # SESIONES: solo administrador
):
    if db.get(Blog, blog_id) is None:
        raise HTTPException(
            status_code=404,
            detail="Publicación no encontrada",
        )

    return db.scalars(
        select(Comentario)
        .where(Comentario.blog_id == blog_id)
        .order_by(Comentario.fecha.desc(), Comentario.id_com.desc())
    ).all()


# COMENTARIOS: los comentarios de UNA publicación. Es el que usa la app en
# la pantalla de detalle.
@app.get(
    "/blog/{blog_id}/comentarios",
    response_model=list[ComentarioRespuesta],
)
def listar_comentarios_de_blog(
    blog_id: int,
    db: Session = Depends(obtener_sesion),
    actual: Usuario = Depends(usuario_actual),  # SESIONES: exige sesión
):
    if db.get(Blog, blog_id) is None:
        raise HTTPException(
            status_code=404,
            detail="Publicación no encontrada",
        )

    # Solo los visibles (estatus = 1), del más reciente al más antiguo:
    # la misma regla y el mismo orden que usa la web en el detalle.
    return db.scalars(
        select(Comentario)
        .where(
            Comentario.blog_id == blog_id,
            Comentario.estatus == 1,
        )
        .order_by(Comentario.fecha.desc(), Comentario.id_com.desc())
    ).all()


@app.get(
    "/comentarios",
    response_model=list[ComentarioRespuesta],
)
def listar_comentarios(
    db: Session = Depends(obtener_sesion),
    actual: Usuario = Depends(usuario_actual),  # SESIONES: exige sesión
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
    actual: Usuario = Depends(usuario_actual),  # SESIONES: exige sesión
):
    if not datos.comentario.strip():
        raise HTTPException(
            status_code=422,
            detail="El comentario no puede estar vacío",
        )

    if db.get(Blog, datos.blog_id) is None:
        raise HTTPException(
            status_code=404,
            detail="Publicación no encontrada",
        )

    nuevo = Comentario(
        comentario=datos.comentario.strip(),
        # SESIONES: el autor es el dueño del token, no lo que diga el
        # cliente. Así nadie puede comentar a nombre de otra persona.
        usr_id=actual.id_usr,
        blog_id=datos.blog_id,
        # estatus = 1 (visible): la web solo muestra comentarios con estatus 1.
        estatus=1,
    )

    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)

    return nuevo


# MODERAR: elimina un comentario de forma DEFINITIVA (igual que la web).
@app.delete("/comentarios/{comentario_id}")
def eliminar_comentario(
    comentario_id: int,
    db: Session = Depends(obtener_sesion),
    admin: Usuario = Depends(requiere_admin),  # SESIONES: solo administrador
):
    comentario = db.get(Comentario, comentario_id)

    if comentario is None:
        raise HTTPException(
            status_code=404,
            detail="Comentario no encontrado",
        )

    db.delete(comentario)
    db.commit()

    return {
        "mensaje": "Comentario eliminado correctamente"
    }
