# Esquemas de Pydantic: definen y validan los datos que entran y salen de la API.
# Si un dato no cumple (falta, es muy corto, tipo incorrecto), FastAPI responde 422.
from datetime import date, datetime
from pydantic import BaseModel, ConfigDict, Field


# Datos para registrar un usuario (POST /usuarios).
class UsuarioCrear(BaseModel):
    nom_usr: str = Field(min_length=2, max_length=100)
    mail: str = Field(min_length=5, max_length=150)
    password: str = Field(min_length=8, max_length=128)
    dir_usr: str | None = None
    # 1 = Administrador, 2 = Usuario general. Por omisión, Usuario general.
    # Solo se respeta si quien crea al usuario es un administrador.
    tip_usu: int = Field(default=2, ge=1, le=2)


# Datos de un usuario que devuelve la API. No incluye la contraseña.
class UsuarioRespuesta(BaseModel):
    id_usr: int
    nom_usr: str
    mail: str
    dir_usr: str | None
    tip_usu: int

    # Permite crear la respuesta directamente desde un objeto de models.py.
    model_config = ConfigDict(from_attributes=True)

# Datos para editar un usuario (PUT /usuarios/{id}). La contraseña no se edita aquí.
class UsuarioActualizar(BaseModel):
    nom_usr: str = Field(min_length=2, max_length=100)
    mail: str = Field(min_length=5, max_length=150)
    dir_usr: str | None = None
    tip_usu: int = Field(default=2, ge=1, le=2)
    
# Datos para crear o editar una publicación sin foto (JSON).
class BlogCrear(BaseModel):
    titulo: str = Field(min_length=2, max_length=150)
    descripcion: str = Field(min_length=1)
    img: str | None = Field(default=None, max_length=500)
    tags: str | None = Field(default=None, max_length=255)
    

# Datos de una publicación que devuelve la API.
class BlogRespuesta(BaseModel):
    id_blog: int
    titulo: str
    descripcion: str | None = None
    img: str | None = None
    tags: str | None = None
    # Fecha de publicación (AAAA-MM-DD).
    fecha: date | None = None
    # Id y nombre de quien creó la publicación (None = sin autor).
    usr_id: int | None = None
    autor: str | None = None

    model_config = ConfigDict(from_attributes=True)


# Datos para crear un comentario (POST /comentarios).
class ComentarioCrear(BaseModel):
    # De 1 a 1000 caracteres.
    comentario: str = Field(min_length=1, max_length=1000)
    # No se recibe usr_id: el autor se toma del token, para que nadie comente a nombre de otro.
    blog_id: int


# Datos de un comentario que devuelve la API.
class ComentarioRespuesta(BaseModel):
    id_com: int
    comentario: str
    fecha: datetime
    estatus: int
    usr_id: int
    blog_id: int
    # Nombre de quien escribió el comentario.
    autor: str | None = None

    model_config = ConfigDict(from_attributes=True
    )
    
# Datos que envía la app para iniciar sesión (POST /login).
class LoginRequest(BaseModel):
    mail: str = Field(min_length=5, max_length=150)
    password: str = Field(min_length=1, max_length=128)


# Respuesta de POST /login: el token de la sesión y los datos del usuario.
class LoginRespuesta(BaseModel):
    access_token: str            # el token que la app debe guardar y enviar
    token_type: str = "bearer"
    usuario: UsuarioRespuesta    # datos del usuario (sin la contraseña)
