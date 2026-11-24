
# Conexión de la API con MySQL mediante SQLAlchemy.
# Los datos de acceso se leen del archivo .env para no escribirlos en el código.
import os

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from sqlalchemy.engine import URL

# Carga las variables del archivo .env (usuario, contraseña, host, puerto, base).
load_dotenv()

# Dirección de conexión a MySQL; utf8mb4 permite acentos, ñ y emojis.
url = URL.create(
    drivername="mysql+pymysql",
    username=os.getenv("DB_USER", "root"),
    password=os.getenv("DB_PASSWORD", ""),
    host=os.getenv("DB_HOST", "127.0.0.1"),
    port=int(os.getenv("DB_PORT", "3306")),
    database=os.getenv("DB_NAME", "bd_aplicacion_movil"),
    query={"charset": "utf8mb4"},
)

# Motor de conexión; pool_pre_ping revisa que la conexión siga viva antes de usarla.
engine = create_engine(url, pool_pre_ping=True)

# Fábrica de sesiones de base de datos (una por petición).
SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
)

# Clase base de la que heredan los modelos (tablas) de models.py.
class Base(DeclarativeBase):
    pass

# Dependencia de FastAPI: abre una sesión para la petición y siempre la cierra al terminar.
def obtener_sesion():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
