
import os

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from sqlalchemy.engine import URL

# Cargamos las variables de configuración del archivo .env
load_dotenv()

# Configuramos la conexión con MySQL
url = URL.create(
    drivername="mysql+pymysql",
    username=os.getenv("DB_USER", "root"),
    password=os.getenv("DB_PASSWORD", ""),
    host=os.getenv("DB_HOST", "127.0.0.1"),
    port=int(os.getenv("DB_PORT", "3306")),
    database=os.getenv("DB_NAME", "bd_aplicacion_movil"),
    query={"charset": "utf8mb4"},
)

# Creamos la conexión con la base de datos
engine = create_engine(url, pool_pre_ping=True)

# Configuramos las sesiones de MySQL
SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
)

class Base(DeclarativeBase):
    pass

# Proporcionamos una sesión para consultar MySQL
def obtener_sesion():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
