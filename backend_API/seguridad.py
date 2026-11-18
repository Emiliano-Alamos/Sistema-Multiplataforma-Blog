# ============================================================================
# ARCHIVO: seguridad.py
# Manejo seguro de sesiones con token (JWT) y control de acceso por rol.
#
# IDEA GENERAL
#   1. El usuario inicia sesión (POST /login) con correo y contraseña.
#   2. Si son correctos, la API le entrega un TOKEN firmado.
#   3. La app envía ese token en cada petición, en el encabezado:
#          Authorization: Bearer <token>
#   4. Antes de responder, la API revisa el token. Si falta, es falso o ya
#      venció, responde 401. Si el usuario no tiene el rol necesario, 403.
#
# REGLAS DE TIEMPO (las mismas que la web, más un tope)
#   - Inactividad: el token vence 30 minutos después de la última petición.
#     Cada petición válida devuelve un token renovado con otros 30 minutos.
#   - Tope absoluto: la sesión nunca dura más de 8 horas desde el inicio de
#     sesión, aunque el usuario siga activo.
# ============================================================================

import os
import time

import jwt
from dotenv import load_dotenv
from fastapi import Depends, HTTPException, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from database import obtener_sesion
from models import Usuario

load_dotenv()


# CONFIGURACIÓN

# Clave secreta con la que se firman los tokens. Se lee del archivo .env y
# NO tiene valor por omisión: quien conozca esta clave puede fabricar tokens.
JWT_SECRET = os.getenv("JWT_SECRET", "")

if len(JWT_SECRET) < 32:
    raise RuntimeError(
        "Falta JWT_SECRET en el archivo .env (mínimo 32 caracteres). "
        "Revisa .env.example para ver cómo generarla."
    )

ALGORITMO = "HS256"

MINUTOS_INACTIVIDAD = 30
HORAS_TOPE = 8

# Encabezado de la respuesta donde viaja el token renovado.
ENCABEZADO_TOKEN_RENOVADO = "X-Token-Renovado"

# Roles (iguales a los de la web).
ROL_ADMIN = 1
ROL_USUARIO = 2

# Lee el encabezado "Authorization: Bearer <token>" de la petición.
# auto_error=False: si no viene el encabezado, nosotros decidimos qué responder.
esquema_bearer = HTTPBearer(auto_error=False)


# CREAR Y LEER TOKENS

def crear_token(id_usr: int, inicio: int) -> str:
    """
    Crea un token firmado para el usuario.

    inicio: momento (en segundos) en que el usuario inició sesión. Se guarda
            dentro del token para poder aplicar el tope de 8 horas.
    """
    ahora = int(time.time())

    vence_por_inactividad = ahora + MINUTOS_INACTIVIDAD * 60
    vence_por_tope = inicio + HORAS_TOPE * 60 * 60

    # El token vence en lo que ocurra primero: 30 minutos a partir de ahora
    # o las 8 horas contadas desde el inicio de sesión.
    vence = min(vence_por_inactividad, vence_por_tope)

    datos = {
        "sub": str(id_usr),   # a quién pertenece el token (id del usuario)
        "inicio": inicio,     # cuándo inició sesión
        "exp": vence,         # cuándo vence (la librería lo revisa sola)
    }

    return jwt.encode(datos, JWT_SECRET, algorithm=ALGORITMO)


def leer_token(token: str) -> dict:
    """
    Comprueba la firma y la vigencia del token y devuelve sus datos.
    Si el token venció o fue alterado, responde 401.
    """
    try:
        datos = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=[ALGORITMO],
            options={"require": ["sub", "inicio", "exp"]},
        )

    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=401,
            detail="Tu sesión expiró. Inicia sesión nuevamente.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=401,
            detail="Sesión no válida. Inicia sesión nuevamente.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return datos


def usuario_desde_token(token: str, respuesta: Response, db: Session) -> Usuario:
    """
    Devuelve el usuario dueño del token y renueva la sesión.
    """
    datos = leer_token(token)

    try:
        id_usr = int(datos["sub"])
        inicio = int(datos["inicio"])
    except (TypeError, ValueError):
        raise HTTPException(
            status_code=401,
            detail="Sesión no válida. Inicia sesión nuevamente.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Se vuelve a leer al usuario en la base en CADA petición. Así, si un
    # administrador lo eliminó o le cambió el rol, el cambio aplica de
    # inmediato aunque su token todavía no haya vencido.
    usuario = db.get(Usuario, id_usr)

    if usuario is None:
        raise HTTPException(
            status_code=401,
            detail="Sesión no válida. Inicia sesión nuevamente.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # RENOVACIÓN POR ACTIVIDAD: como el usuario acaba de hacer una petición,
    # se le entrega un token nuevo con otros 30 minutos. Se conserva el mismo
    # "inicio", por eso el tope de 8 horas no se mueve.
    respuesta.headers[ENCABEZADO_TOKEN_RENOVADO] = crear_token(id_usr, inicio)

    return usuario


# DEPENDENCIAS PARA PROTEGER ENDPOINTS
# Se usan igual que obtener_sesion:  usuario: Usuario = Depends(usuario_actual)

def usuario_actual(
    respuesta: Response,
    credenciales: HTTPAuthorizationCredentials | None = Depends(esquema_bearer),
    db: Session = Depends(obtener_sesion),
) -> Usuario:
    """
    Exige una sesión válida. Sin token responde 401.
    """
    if credenciales is None:
        raise HTTPException(
            status_code=401,
            detail="Debes iniciar sesión.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return usuario_desde_token(credenciales.credentials, respuesta, db)


def usuario_opcional(
    respuesta: Response,
    credenciales: HTTPAuthorizationCredentials | None = Depends(esquema_bearer),
    db: Session = Depends(obtener_sesion),
) -> Usuario | None:
    """
    Para endpoints públicos que cambian su comportamiento si hay sesión
    (el registro). Sin token devuelve None; con token, lo valida igual.
    """
    if credenciales is None:
        return None

    return usuario_desde_token(credenciales.credentials, respuesta, db)


def requiere_admin(
    usuario: Usuario = Depends(usuario_actual),
) -> Usuario:
    """
    Exige una sesión válida Y que el usuario sea administrador.
    401 = no hay sesión.  403 = hay sesión, pero no tiene permiso.
    """
    if usuario.tip_usu != ROL_ADMIN:
        raise HTTPException(
            status_code=403,
            detail="No tienes permiso para realizar esta acción.",
        )

    return usuario
