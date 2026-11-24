# Modelos ORM: cada clase representa una tabla de MySQL y cada atributo, una columna.
from sqlalchemy import (
    Column, Integer, String, Text,
    Date, DateTime, ForeignKey, func, text
)
from sqlalchemy.orm import relationship
from database import Base

# Tabla usuario: cuentas de la app.
class Usuario(Base):
    __tablename__ = "usuario"

    id_usr = Column(Integer, primary_key=True, index=True)
    nom_usr = Column(String(100), nullable=False)
    mail = Column(String(150), unique=True, nullable=False)
    # La columna se llama "pass" en MySQL, pero en Python es palabra reservada.
    # Guarda el hash Argon2id, nunca la contraseña en texto.
    pass_hash = Column("pass", String(255), nullable=False)
    dir_usr = Column(String(200), nullable=True)
    # 1 = Administrador, 2 = Usuario general (por omisión, Usuario general)
    tip_usu = Column(Integer, nullable=False, default=2)

# Tabla blog: publicaciones.
class Blog(Base):
    __tablename__ = "blog"
    id_blog = Column(Integer, primary_key=True, index=True)
    titulo = Column(String(150), nullable=False)
    descripcion = Column("desc", Text, nullable=True)
    img = Column(String(500), nullable=True)
    tags = Column(String(255), nullable=True)

    # Fecha de publicación (sin hora). La API no la envía al crear:
    # la pone la base con la fecha de hoy (DEFAULT CURRENT_DATE).
    fecha = Column(
        Date,
        nullable=False,
        server_default=text("(CURRENT_DATE)"),
    )

    # Id del usuario que creó la publicación.
    # Puede quedar vacío (NULL): publicaciones antiguas o de un usuario que
    # fue eliminado. ON DELETE SET NULL: si se elimina al autor, la base
    # conserva la publicación y solo le quita el autor.
    usr_id = Column(
        Integer,
        ForeignKey("usuario.id_usr", ondelete="SET NULL"),
        nullable=True,
    )

    # Relación con la tabla usuario: permite leer los datos del autor
    # (publicacion.usuario) sin escribir otra consulta. lazy="joined" hace
    # que el autor se lea en la MISMA consulta que la publicación (un JOIN).
    usuario = relationship("Usuario", lazy="joined")

    # Nombre del autor, listo para enviarlo en la respuesta de la API.
    @property
    def autor(self):
        if self.usuario is None:
            return None

        return self.usuario.nom_usr

# Tabla comentarios: comentarios de cada publicación.
class Comentario(Base):
    __tablename__ = "comentarios"
    id_com = Column(Integer, primary_key=True, index=True)
    comentario = Column(Text, nullable=False)
    fecha = Column(
        DateTime,
        nullable=False,
        server_default=func.current_timestamp(),
    )
    # 1 = visible.
    estatus = Column(Integer, nullable=False, default=1)
    usr_id = Column(
        Integer,
        ForeignKey("usuario.id_usr"),
        nullable=False,
    )
    blog_id = Column(
        Integer,
        ForeignKey("blog.id_blog"),
        nullable=False,
    )

    # Relación con la tabla usuario, para leer el nombre de
    # quien escribió el comentario en la misma consulta (un JOIN).
    usuario = relationship("Usuario", lazy="joined")

    # Nombre de quien escribió el comentario, listo para la respuesta.
    @property
    def autor(self):
        if self.usuario is None:
            return None

        return self.usuario.nom_usr