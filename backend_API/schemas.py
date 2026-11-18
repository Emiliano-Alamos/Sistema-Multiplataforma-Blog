from datetime import date, datetime
from pydantic import BaseModel, ConfigDict, Field


class UsuarioCrear(BaseModel):
    nom_usr: str = Field(min_length=2, max_length=100)
    mail: str = Field(min_length=5, max_length=150)
    password: str = Field(min_length=8, max_length=128)
    dir_usr: str | None = None
    # 1 = Administrador, 2 = Usuario general. Por omisión, Usuario general.
    # Solo se respeta si quien crea al usuario es un administrador.
    tip_usu: int = Field(default=2, ge=1, le=2)


class UsuarioRespuesta(BaseModel):
    id_usr: int
    nom_usr: str
    mail: str
    dir_usr: str | None
    tip_usu: int

    model_config = ConfigDict(from_attributes=True)
class UsuarioActualizar(BaseModel):
    nom_usr: str = Field(min_length=2, max_length=100)
    mail: str = Field(min_length=5, max_length=150)
    dir_usr: str | None = None
    tip_usu: int = Field(default=2, ge=1, le=2)
    
class BlogCrear(BaseModel):
    titulo: str = Field(min_length=2, max_length=150)
    descripcion: str = Field(min_length=1)
    img: str | None = Field(default=None, max_length=500)
    tags: str | None = Field(default=None, max_length=255)
    

class BlogRespuesta(BaseModel):
    id_blog: int
    titulo: str
    descripcion: str | None = None
    img: str | None = None
    tags: str | None = None
    # FECHA de publicación (AAAA-MM-DD).
    fecha: date | None = None
    # AUTOR: id y nombre de quien creó la publicación (None = sin autor).
    usr_id: int | None = None
    autor: str | None = None

    model_config = ConfigDict(from_attributes=True)


class ComentarioCrear(BaseModel):
    # COMENTARIOS: de 1 a 1000 caracteres.
    comentario: str = Field(min_length=1, max_length=1000)
    # SESIONES: ya no se recibe usr_id. El autor se toma del token.
    blog_id: int


class ComentarioRespuesta(BaseModel):
    id_com: int
    comentario: str
    fecha: datetime
    estatus: int
    usr_id: int
    blog_id: int
    # COMENTARIOS: nombre de quien escribió el comentario.
    autor: str | None = None

    model_config = ConfigDict(from_attributes=True
    )
    
class LoginRequest(BaseModel):
    mail: str = Field(min_length=5, max_length=150)
    password: str = Field(min_length=1, max_length=128)


# SESIONES: respuesta de POST /login.
class LoginRespuesta(BaseModel):
    access_token: str            # el token que la app debe guardar y enviar
    token_type: str = "bearer"
    usuario: UsuarioRespuesta    # datos del usuario (sin la contraseña)
