"""
Pruebas automatizadas de la API (FastAPI) del Blog de Tecnologías Emergentes.

Cómo ejecutarlas, desde la carpeta backend_API y con el entorno activado:

    pip install -r requirements-pruebas.txt
    python -m pytest tests -q

IMPORTANTE
- Usan una base de datos APARTE, llamada bd_blog_pruebas, que se BORRA y se
  vuelve a crear en cada ejecución con database/base_de_datos.sql.
- Nunca tocan la base indicada en DB_NAME del archivo .env.
- Del .env solo toman el servidor: DB_HOST, DB_PORT, DB_USER y DB_PASSWORD.
- Las fotografías de prueba se guardan en una carpeta temporal, no en uploads real.
- Las pruebas se ejecutan en orden: algunas usan datos creados por las anteriores.
"""

import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import jwt
import pymysql
import pytest
from dotenv import load_dotenv

BACKEND = Path(__file__).resolve().parent.parent
SCRIPT_SQL = BACKEND.parent / "database" / "base_de_datos.sql"
BASE_PRUEBAS = "bd_blog_pruebas"
SECRETO = "s" * 64

load_dotenv(BACKEND / ".env")

if os.getenv("DB_NAME") == BASE_PRUEBAS:
    raise RuntimeError(
        "DB_NAME no puede llamarse bd_blog_pruebas: esa base se borra en cada prueba."
    )

CONEXION = {
    "host": os.getenv("DB_HOST", "127.0.0.1"),
    "port": int(os.getenv("DB_PORT", "3306")),
    "user": os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", ""),
    "charset": "utf8mb4",
    "autocommit": True,
}


def preparar_base():
    """Recrea exclusivamente bd_blog_pruebas; nunca modifica la base principal."""
    texto = SCRIPT_SQL.read_text(encoding="utf-8")

    # Comprobamos el nombre del SQL ANTES de borrar la base de pruebas.
    # Si cambia la configuración del proyecto, detenemos las pruebas.
    if (
        "CREATE DATABASE IF NOT EXISTS `bd_aplicacion_movil`" not in texto
        or "USE `bd_aplicacion_movil`;" not in texto
    ):
        raise RuntimeError("El SQL no tiene el nombre de base esperado. No se ejecutaron pruebas.")

    # Redirigimos el SQL a la base de pruebas, nunca a la de la aplicación.
    texto = texto.replace("`bd_aplicacion_movil`", f"`{BASE_PRUEBAS}`")

    # Ignoramos las líneas de comentarios del archivo SQL.
    lineas = [l for l in texto.splitlines() if not l.strip().startswith("--")]
    instrucciones = [i.strip() for i in "\n".join(lineas).split(";") if i.strip()]

    # Comprobación adicional para no ejecutar instrucciones en otra base.
    if (
        not any(i.startswith(f"CREATE DATABASE IF NOT EXISTS `{BASE_PRUEBAS}`") for i in instrucciones)
        or f"USE `{BASE_PRUEBAS}`" not in instrucciones
        or "`bd_aplicacion_movil`" in " ".join(instrucciones)
    ):
        raise RuntimeError("El SQL de pruebas no es seguro. No se modificó ninguna base.")

    con = pymysql.connect(**CONEXION)
    try:
        with con.cursor() as cur:
            cur.execute(f"DROP DATABASE IF EXISTS `{BASE_PRUEBAS}`")
            for instruccion in instrucciones:
                cur.execute(instruccion)
    finally:
        con.close()


def sql(consulta, args=None):
    """Ejecuta una consulta directa en la base de pruebas y devuelve las filas."""
    con = pymysql.connect(database=BASE_PRUEBAS, **CONEXION)
    with con.cursor() as cur:
        cur.execute(consulta, args)
        filas = cur.fetchall()
    con.close()
    return filas


preparar_base()

# El backend se carga apuntando a la base de pruebas y con una clave de prueba.
os.environ["DB_NAME"] = BASE_PRUEBAS
os.environ["JWT_SECRET"] = SECRETO

# Las imágenes de pruebas se guardan en una carpeta temporal separada.
# main.py usa ahora una ruta absoluta, así que ajustamos también su montaje /uploads.
carpeta_temporal = Path(tempfile.mkdtemp(prefix="pruebas_blog_"))
os.chdir(carpeta_temporal)
sys.path.insert(0, str(BACKEND))

from fastapi.testclient import TestClient  # noqa: E402
from fastapi.staticfiles import StaticFiles  # noqa: E402

import main  # noqa: E402
import seguridad  # noqa: E402

main.UPLOAD_DIR = carpeta_temporal
for ruta in main.app.routes:
    if ruta.path == "/uploads":
        ruta.app = StaticFiles(directory=carpeta_temporal)
        break
else:
    raise RuntimeError("No se encontró el montaje /uploads para las pruebas.")

# Confirmamos que FastAPI quedó apuntando a la base de pruebas.
if main.engine.url.database != BASE_PRUEBAS:
    raise RuntimeError("FastAPI no apunta a la base de pruebas; se detuvo la ejecución.")


@pytest.fixture(scope="session")
def c():
    with TestClient(main.app) as cliente:
        yield cliente


def h(token):
    return {"Authorization": f"Bearer {token}"}


def login(c, mail, password="Clave12345"):
    r = c.post("/login", json={"mail": mail, "password": password})
    assert r.status_code == 200, r.text
    return r.json()


@pytest.fixture(scope="session")
def admin(c):
    r = c.post(
        "/usuarios", json={"nom_usr": "Admin Uno", "mail": "admin@x.com", "password": "Clave12345"}
    )
    assert r.status_code == 201 and r.json()["tip_usu"] == 2
    sql("UPDATE usuario SET tip_usu = 1 WHERE mail = 'admin@x.com'")
    return login(c, "admin@x.com")


@pytest.fixture(scope="session")
def general(c):
    r = c.post(
        "/usuarios",
        json={"nom_usr": "Usuario Gral", "mail": "gral@x.com", "password": "Clave12345"},
    )
    assert r.status_code == 201
    return login(c, "gral@x.com")


@pytest.fixture(scope="session")
def post_id(c, admin):
    r = c.post(
        "/blog",
        json={"titulo": "Introducción a la Robótica", "descripcion": "Texto", "tags": "Robótica"},
        headers=h(admin["access_token"]),
    )
    assert r.status_code == 201
    return r.json()["id_blog"]


# ============================================================================
# PASO A · Sesiones con token y control de acceso
# ============================================================================


def test_sin_jwt_secret_no_arranca():
    env = dict(os.environ)
    env["JWT_SECRET"] = ""
    r = subprocess.run(
        [sys.executable, "-c", "import seguridad"],
        cwd=str(BACKEND),
        env=env,
        capture_output=True,
        text=True,
    )
    assert r.returncode != 0 and "JWT_SECRET" in r.stderr
    env["JWT_SECRET"] = "corta"
    r = subprocess.run(
        [sys.executable, "-c", "import seguridad"],
        cwd=str(BACKEND),
        env=env,
        capture_output=True,
        text=True,
    )
    assert r.returncode != 0


def test_login_devuelve_token_y_usuario(admin):
    assert admin["token_type"] == "bearer" and admin["access_token"].count(".") == 2
    assert admin["usuario"] == {
        "id_usr": admin["usuario"]["id_usr"],
        "nom_usr": "Admin Uno",
        "mail": "admin@x.com",
        "dir_usr": None,
        "tip_usu": 1,
    }
    datos = jwt.decode(admin["access_token"], SECRETO, algorithms=["HS256"])
    assert set(datos) == {"sub", "inicio", "exp"} and datos["sub"] == str(
        admin["usuario"]["id_usr"]
    )
    assert 1790 <= datos["exp"] - datos["inicio"] <= 1800


def test_login_incorrecto(c, admin):
    a = c.post("/login", json={"mail": "admin@x.com", "password": "mala"})
    b = c.post("/login", json={"mail": "noexiste@x.com", "password": "Clave12345"})
    assert a.status_code == b.status_code == 401 and a.json() == b.json() == {
        "detail": "Correo o contraseña incorrectos"
    }


def test_login_mayusculas_y_espacios(c, admin):
    assert (
        c.post("/login", json={"mail": "  ADMIN@X.com ", "password": "Clave12345"}).status_code
        == 200
    )


PROTEGIDOS = [
    ("get", "/usuarios"),
    ("put", "/usuarios/1"),
    ("delete", "/usuarios/1"),
    ("get", "/blog"),
    ("post", "/blog"),
    ("post", "/blog/foto"),
    ("get", "/blog/1"),
    ("get", "/comentarios"),
    ("post", "/comentarios"),
]


@pytest.mark.parametrize("metodo,ruta", PROTEGIDOS)
def test_sin_token_401(c, metodo, ruta):
    r = getattr(c, metodo)(ruta)
    assert r.status_code == 401 and r.json()["detail"] == "Debes iniciar sesión."
    assert r.headers["www-authenticate"] == "Bearer" and "x-token-renovado" not in r.headers


def test_publicos(c):
    assert c.get("/").status_code == 200


def tok(datos, secreto=SECRETO, alg="HS256"):
    return jwt.encode(datos, secreto, algorithm=alg)


def test_tokens_invalidos(c, admin):
    ahora = int(time.time())
    uid = str(admin["usuario"]["id_usr"])
    malos = {
        "basura": "abc.def.ghi",
        "otra clave": tok({"sub": uid, "inicio": ahora, "exp": ahora + 600}, secreto="x" * 64),
        "sin inicio": tok({"sub": uid, "exp": ahora + 600}),
        "sin exp": tok({"sub": uid, "inicio": ahora}),
        "sin sub": tok({"inicio": ahora, "exp": ahora + 600}),
        "sub no numerico": tok({"sub": "abc", "inicio": ahora, "exp": ahora + 600}),
        "usuario inexistente": tok({"sub": "999999", "inicio": ahora, "exp": ahora + 600}),
        "otro algoritmo": tok({"sub": uid, "inicio": ahora, "exp": ahora + 600}, alg="HS512"),
        "alterado": admin["access_token"][:-3]
        + ("AAA" if not admin["access_token"].endswith("AAA") else "BBB"),
    }
    sin_firma = jwt.encode(
        {"sub": uid, "inicio": ahora, "exp": ahora + 600}, None, algorithm="none"
    )
    malos["alg none"] = sin_firma
    for nombre, t in malos.items():
        r = c.get("/blog", headers=h(t))
        assert r.status_code == 401, nombre
        assert r.json()["detail"] == "Sesión no válida. Inicia sesión nuevamente.", nombre
    assert c.get("/blog", headers={"Authorization": "Basic abc"}).status_code == 401
    assert c.get("/blog", headers={"Authorization": admin["access_token"]}).status_code == 401


def test_token_vencido_por_inactividad(c, admin):
    ahora = int(time.time())
    t = tok({"sub": str(admin["usuario"]["id_usr"]), "inicio": ahora - 3600, "exp": ahora - 5})
    r = c.get("/blog", headers=h(t))
    assert (
        r.status_code == 401 and r.json()["detail"] == "Tu sesión expiró. Inicia sesión nuevamente."
    )


def test_renovacion_por_actividad(c, admin):
    ahora = int(time.time())
    uid = admin["usuario"]["id_usr"]
    viejo = tok({"sub": str(uid), "inicio": ahora - 3600, "exp": ahora + 60})
    r = c.get("/blog", headers=h(viejo))
    assert r.status_code == 200
    nuevo = jwt.decode(r.headers["x-token-renovado"], SECRETO, algorithms=["HS256"])
    assert nuevo["sub"] == str(uid) and nuevo["inicio"] == ahora - 3600
    assert 1795 <= nuevo["exp"] - ahora <= 1805
    assert c.get("/blog", headers=h(r.headers["x-token-renovado"])).status_code == 200


def test_tope_de_8_horas(c, admin):
    ahora = int(time.time())
    uid = admin["usuario"]["id_usr"]
    inicio = ahora - (7 * 3600 + 50 * 60)
    r = c.get("/blog", headers=h(seguridad.crear_token(uid, inicio)))
    assert r.status_code == 200
    nuevo = jwt.decode(r.headers["x-token-renovado"], SECRETO, algorithms=["HS256"])
    assert nuevo["exp"] == inicio + 8 * 3600 and 590 <= nuevo["exp"] - ahora <= 600
    pasado = seguridad.crear_token(uid, ahora - 8 * 3600 - 1)
    r = c.get("/blog", headers=h(pasado))
    assert r.status_code == 401 and "expiró" in r.json()["detail"]


def test_cors_expone_encabezado(c, admin):
    r = c.get("/blog", headers={**h(admin["access_token"]), "Origin": "http://localhost:54321"})
    assert r.headers["access-control-allow-origin"] == "http://localhost:54321"
    assert "X-Token-Renovado" in r.headers["access-control-expose-headers"]
    pre = c.options(
        "/blog",
        headers={
            "Origin": "http://localhost:54321",
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "authorization,content-type",
        },
    )
    assert (
        pre.status_code == 200
        and "authorization" in pre.headers["access-control-allow-headers"].lower()
    )


def test_usuario_general_permisos(c, admin, general, post_id):
    t = h(general["access_token"])
    yo = general["usuario"]["id_usr"]
    assert c.get("/blog", headers=t).status_code == 200
    assert c.get(f"/blog/{post_id}", headers=t).status_code == 200
    assert c.get("/comentarios", headers=t).status_code == 200
    for r in [
        c.get("/usuarios", headers=t),
        c.post("/blog", json={"titulo": "xx", "descripcion": "d"}, headers=t),
        c.post(
            "/blog/foto",
            data={"titulo": "t", "descripcion": "d"},
            files={"imagen": ("a.jpg", b"x", "image/jpeg")},
            headers=t,
        ),
        c.delete(f"/usuarios/{admin['usuario']['id_usr']}", headers=t),
        c.put(
            f"/usuarios/{admin['usuario']['id_usr']}",
            json={"nom_usr": "Hack", "mail": "admin@x.com", "tip_usu": 2},
            headers=t,
        ),
    ]:
        assert (
            r.status_code == 403
            and r.json()["detail"] == "No tienes permiso para realizar esta acción."
        )
    assert sql("SELECT nom_usr, tip_usu FROM usuario WHERE mail='admin@x.com'") == (
        ("Admin Uno", 1),
    )
    assert sql("SELECT COUNT(*) FROM blog")[0][0] == 1


def test_general_edita_su_perfil_pero_no_su_rol(c, general):
    t = h(general["access_token"])
    yo = general["usuario"]["id_usr"]
    r = c.put(
        f"/usuarios/{yo}",
        json={
            "nom_usr": "Usuario Editado",
            "mail": "gral@x.com",
            "dir_usr": "Calle 1",
            "tip_usu": 1,
        },
        headers=t,
    )
    assert (
        r.status_code == 200
        and r.json()["nom_usr"] == "Usuario Editado"
        and (r.json()["tip_usu"] == 2)
    )
    assert sql("SELECT tip_usu FROM usuario WHERE id_usr=%s", (yo,))[0][0] == 2
    assert c.get("/usuarios", headers=t).status_code == 403


def test_registro_publico_siempre_tipo_2(c):
    a = c.post(
        "/usuarios",
        json={
            "nom_usr": "Intruso",
            "mail": "intruso@x.com",
            "password": "Clave12345",
            "tip_usu": 1,
        },
    )
    b = c.post(
        "/usuarios", json={"nom_usr": "Sin tipo", "mail": "sintipo@x.com", "password": "Clave12345"}
    )
    assert a.status_code == b.status_code == 201 and a.json()["tip_usu"] == b.json()["tip_usu"] == 2
    assert sql("SELECT COUNT(*) FROM usuario WHERE tip_usu = 1")[0][0] == 1
    assert (
        c.post(
            "/usuarios",
            json={"nom_usr": "Intruso", "mail": "intruso@x.com", "password": "Clave12345"},
        ).status_code
        == 409
    )
    assert (
        c.post(
            "/usuarios",
            json={
                "nom_usr": "Rol raro",
                "mail": "raro@x.com",
                "password": "Clave12345",
                "tip_usu": 3,
            },
        ).status_code
        == 422
    )


def test_registro_con_token_de_general_o_invalido(c, general):
    r = c.post(
        "/usuarios",
        json={"nom_usr": "Amigo", "mail": "amigo@x.com", "password": "Clave12345", "tip_usu": 1},
        headers=h(general["access_token"]),
    )
    assert r.status_code == 201 and r.json()["tip_usu"] == 2
    r = c.post(
        "/usuarios",
        json={"nom_usr": "Falso", "mail": "falso@x.com", "password": "Clave12345", "tip_usu": 1},
        headers=h("abc.def.ghi"),
    )
    assert (
        r.status_code == 401
        and sql("SELECT COUNT(*) FROM usuario WHERE mail='falso@x.com'")[0][0] == 0
    )


def test_admin_gestiona_usuarios(c, admin):
    t = h(admin["access_token"])
    yo = admin["usuario"]["id_usr"]
    assert c.get("/usuarios", headers=t).status_code == 200
    r = c.post(
        "/usuarios",
        json={
            "nom_usr": "Admin Dos",
            "mail": "admin2@x.com",
            "password": "Clave12345",
            "tip_usu": 1,
        },
        headers=t,
    )
    assert r.status_code == 201 and r.json()["tip_usu"] == 1
    r = c.post(
        "/usuarios",
        json={"nom_usr": "Lector", "mail": "lector@x.com", "password": "Clave12345", "tip_usu": 2},
        headers=t,
    )
    lector = r.json()["id_usr"]
    assert r.json()["tip_usu"] == 2
    r = c.put(
        f"/usuarios/{lector}",
        json={"nom_usr": "Lector", "mail": "lector@x.com", "tip_usu": 1},
        headers=t,
    )
    assert r.status_code == 200 and r.json()["tip_usu"] == 1
    r = c.put(
        f"/usuarios/{yo}",
        json={"nom_usr": "Admin Uno", "mail": "admin@x.com", "tip_usu": 2},
        headers=t,
    )
    assert r.status_code == 200 and r.json()["tip_usu"] == 1
    assert (
        c.put(
            "/usuarios/999999", json={"nom_usr": "Nadie", "mail": "n@x.com"}, headers=t
        ).status_code
        == 404
    )
    assert (
        c.put(
            f"/usuarios/{lector}", json={"nom_usr": "Lector", "mail": "admin@x.com"}, headers=t
        ).status_code
        == 409
    )


def test_cambio_de_rol_y_eliminacion_aplican_de_inmediato(c, admin):
    t = h(admin["access_token"])
    dos = login(c, "admin2@x.com")
    t2 = h(dos["access_token"])
    id2 = dos["usuario"]["id_usr"]
    assert c.get("/usuarios", headers=t2).status_code == 200
    c.put(
        f"/usuarios/{id2}",
        json={"nom_usr": "Admin Dos", "mail": "admin2@x.com", "tip_usu": 2},
        headers=t,
    )
    assert c.get("/usuarios", headers=t2).status_code == 403
    assert c.delete(f"/usuarios/{id2}", headers=t).status_code == 200
    r = c.get("/blog", headers=t2)
    assert (
        r.status_code == 401 and r.json()["detail"] == "Sesión no válida. Inicia sesión nuevamente."
    )


def test_comentario_usa_el_usuario_del_token(c, admin, general, post_id):
    yo = general["usuario"]["id_usr"]
    r = c.post(
        "/comentarios",
        json={
            "comentario": "  Muy útil  ",
            "blog_id": post_id,
            "usr_id": admin["usuario"]["id_usr"],
        },
        headers=h(general["access_token"]),
    )
    assert (
        r.status_code == 201
        and r.json()["usr_id"] == yo
        and (r.json()["estatus"] == 1)
        and (r.json()["comentario"] == "Muy útil")
    )
    assert sql(
        "SELECT usr_id, estatus, blog_id FROM comentarios WHERE id_com=%s", (r.json()["id_com"],)
    ) == (
        (yo, 1, post_id),
    )
    assert (
        c.post(
            "/comentarios",
            json={"comentario": "x", "blog_id": 999999},
            headers=h(general["access_token"]),
        ).status_code
        == 404
    )
    assert (
        c.post(
            "/comentarios",
            json={"comentario": "   ", "blog_id": post_id},
            headers=h(general["access_token"]),
        ).status_code
        == 422
    )


def test_blog_con_foto_admin(c, admin):
    r = c.post(
        "/blog/foto",
        data={"titulo": "Con foto", "descripcion": "d", "tags": "Robótica"},
        files={"imagen": ("a.jpg", b"\xff\xd8\xff", "image/jpeg")},
        headers=h(admin["access_token"]),
    )
    assert r.status_code == 200 and r.json()["imagen"].startswith("/uploads/")
    assert c.get(r.json()["imagen"]).status_code == 200


# ============================================================================
# PASO B · Eliminar usuarios (transacción, propia cuenta, último administrador)
# ============================================================================


def nuevo(c, admin, mail, tipo=2):
    r = c.post(
        "/usuarios",
        json={"nom_usr": "Temporal", "mail": mail, "password": "Clave12345", "tip_usu": tipo},
        headers=h(admin["access_token"]),
    )
    assert r.status_code == 201 and r.json()["tip_usu"] == tipo
    return r.json()["id_usr"]


def comentar(c, mail, post_id, texto):
    t = login(c, mail)["access_token"]
    assert (
        c.post(
            "/comentarios", json={"comentario": texto, "blog_id": post_id}, headers=h(t)
        ).status_code
        == 201
    )
    return t


def test_b_eliminar_usuario_con_comentarios(c, admin, general, post_id):
    uid = nuevo(c, admin, "borrar@x.com")
    token = comentar(c, "borrar@x.com", post_id, "uno")
    comentar(c, "borrar@x.com", post_id, "dos")
    comentar(c, "gral@x.com", post_id, "de otro usuario")
    otros = sql("SELECT COUNT(*) FROM comentarios WHERE usr_id <> %s", (uid,))[0][0]
    r = c.delete(f"/usuarios/{uid}", headers=h(admin["access_token"]))
    assert r.status_code == 200 and r.json() == {
        "mensaje": "Usuario eliminado correctamente",
        "comentarios_eliminados": 2,
    }
    assert sql("SELECT COUNT(*) FROM usuario WHERE id_usr=%s", (uid,))[0][0] == 0
    assert sql("SELECT COUNT(*) FROM comentarios WHERE usr_id=%s", (uid,))[0][0] == 0
    assert sql("SELECT COUNT(*) FROM comentarios")[0][0] == otros >= 1
    assert c.get("/blog", headers=h(token)).status_code == 401
    assert (
        c.post("/login", json={"mail": "borrar@x.com", "password": "Clave12345"}).status_code == 401
    )


def test_b_eliminar_usuario_sin_comentarios(c, admin):
    uid = nuevo(c, admin, "limpio@x.com")
    r = c.delete(f"/usuarios/{uid}", headers=h(admin["access_token"]))
    assert r.status_code == 200 and r.json()["comentarios_eliminados"] == 0


def test_b_no_puede_eliminarse_a_si_mismo(c, admin):
    yo = admin["usuario"]["id_usr"]
    r = c.delete(f"/usuarios/{yo}", headers=h(admin["access_token"]))
    assert r.status_code == 409 and r.json()["detail"] == "No puedes eliminar tu propia cuenta."
    assert sql("SELECT tip_usu FROM usuario WHERE id_usr=%s", (yo,)) == ((1,),)


def test_b_admin_elimina_a_otro_admin_y_queda_uno(c, admin, post_id):
    uid = nuevo(c, admin, "admin3@x.com", tipo=1)
    comentar(c, "admin3@x.com", post_id, "de admin")
    assert c.delete(f"/usuarios/{uid}", headers=h(admin["access_token"])).status_code == 200
    assert sql("SELECT COUNT(*) FROM usuario WHERE tip_usu = 1")[0][0] >= 1


def test_b_ultimo_admin_no_se_elimina(c, admin):
    yo = admin["usuario"]["id_usr"]
    uid = nuevo(c, admin, "unico@x.com", tipo=1)
    otros = [
        f[0]
        for f in sql(
            "SELECT id_usr FROM usuario WHERE tip_usu = 1 AND id_usr NOT IN (%s, %s)", (yo, uid)
        )
    ]
    import seguridad as s

    original = s.requiere_admin
    main.app.dependency_overrides[original] = lambda: type("U", (), {"id_usr": -1, "tip_usu": 1})()
    try:
        sql("UPDATE usuario SET tip_usu = 2 WHERE id_usr = %s", (yo,))
        for o in otros:
            sql("UPDATE usuario SET tip_usu = 2 WHERE id_usr = %s", (o,))
        r = c.delete(f"/usuarios/{uid}")
        assert (
            r.status_code == 409
            and r.json()["detail"] == "Debe quedar al menos un administrador en el sistema."
        )
        assert sql("SELECT COUNT(*) FROM usuario WHERE id_usr=%s", (uid,))[0][0] == 1
    finally:
        main.app.dependency_overrides.clear()
        sql("UPDATE usuario SET tip_usu = 1 WHERE id_usr = %s", (yo,))
        for o in otros:
            sql("UPDATE usuario SET tip_usu = 1 WHERE id_usr = %s", (o,))
    assert c.delete(f"/usuarios/{uid}", headers=h(admin["access_token"])).status_code == 200


def test_b_inexistente_sin_sesion_y_sin_permiso(c, admin, general):
    assert c.delete("/usuarios/999999", headers=h(admin["access_token"])).status_code == 404
    assert c.delete("/usuarios/999999").status_code == 401
    assert (
        c.delete(
            f"/usuarios/{admin['usuario']['id_usr']}", headers=h(general["access_token"])
        ).status_code
        == 403
    )


def test_b_si_falla_no_queda_a_medias(c, admin, post_id):
    uid = nuevo(c, admin, "atado@x.com")
    comentar(c, "atado@x.com", post_id, "debe sobrevivir")
    sql(
        "CREATE TABLE tmp_ref (id INT PRIMARY KEY, usr_id INT NOT NULL, FOREIGN KEY (usr_id) REFERENCES usuario (id_usr)) ENGINE=InnoDB"
    )
    sql("INSERT INTO tmp_ref VALUES (1, %s)", (uid,))
    try:
        r = c.delete(f"/usuarios/{uid}", headers=h(admin["access_token"]))
        assert (
            r.status_code == 500
            and r.json()["detail"] == "No se pudo eliminar el usuario. Intenta de nuevo."
        )
        assert sql("SELECT COUNT(*) FROM usuario WHERE id_usr=%s", (uid,))[0][0] == 1
        assert sql("SELECT COUNT(*) FROM comentarios WHERE usr_id=%s", (uid,))[0][0] == 1
    finally:
        sql("DROP TABLE tmp_ref")
    assert (
        c.delete(f"/usuarios/{uid}", headers=h(admin["access_token"])).json()[
            "comentarios_eliminados"
        ]
        == 1
    )


# ============================================================================
# PASO E · Autor de la publicación
# ============================================================================


def test_e_crear_guarda_al_autor_del_token(c, admin):
    yo = admin["usuario"]["id_usr"]
    r = c.post(
        "/blog",
        json={"titulo": "Con autor", "descripcion": "d", "tags": "Robótica", "usr_id": 999},
        headers=h(admin["access_token"]),
    )
    assert r.status_code == 201 and r.json()["usr_id"] == yo and (r.json()["autor"] == "Admin Uno")
    assert sql("SELECT usr_id FROM blog WHERE id_blog=%s", (r.json()["id_blog"],)) == ((yo,),)
    r = c.post(
        "/blog/foto",
        data={"titulo": "Foto con autor", "descripcion": "d"},
        files={"imagen": ("a.png", b"x", "image/png")},
        headers=h(admin["access_token"]),
    )
    assert r.status_code == 200
    assert sql("SELECT usr_id FROM blog WHERE titulo='Foto con autor'") == ((yo,),)


def test_e_listado_y_detalle_traen_autor(c, admin, general):
    sql("INSERT INTO blog (titulo, `desc`) VALUES ('Antigua sin autor', 'd')")
    vieja = sql("SELECT id_blog FROM blog WHERE titulo='Antigua sin autor'")[0][0]
    for quien in (admin, general):
        lista = c.get("/blog", headers=h(quien["access_token"])).json()
        por_titulo = {p["titulo"]: p for p in lista}
        assert (
            por_titulo["Con autor"]["autor"] == "Admin Uno"
            and por_titulo["Con autor"]["usr_id"] == admin["usuario"]["id_usr"]
        )
        assert (
            por_titulo["Antigua sin autor"]["autor"] is None
            and por_titulo["Antigua sin autor"]["usr_id"] is None
        )
        assert set(lista[0]) == {
            "id_blog",
            "titulo",
            "descripcion",
            "img",
            "tags",
            "fecha",
            "usr_id",
            "autor",
        }
    d = c.get(f"/blog/{vieja}", headers=h(general["access_token"])).json()
    assert d["autor"] is None


def test_e_propias_y_de_otros(c, admin):
    t = h(admin["access_token"])
    otro = nuevo(c, admin, "autor2@x.com", tipo=1)
    t2 = h(login(c, "autor2@x.com")["access_token"])
    c.put(
        f"/usuarios/{otro}",
        json={"nom_usr": "Autora Dos", "mail": "autor2@x.com", "tip_usu": 1},
        headers=t,
    )
    r = c.post("/blog", json={"titulo": "De otra autora", "descripcion": "d"}, headers=t2)
    assert r.json()["autor"] == "Autora Dos"
    lista = c.get("/blog", headers=t).json()
    yo = admin["usuario"]["id_usr"]
    mias = [p for p in lista if p["usr_id"] == yo]
    ajenas = [p for p in lista if p["usr_id"] == otro]
    assert len(mias) >= 2 and [p["titulo"] for p in ajenas] == ["De otra autora"]


def test_e_eliminar_autor_conserva_sus_publicaciones(c, admin, post_id):
    otro = sql("SELECT id_usr FROM usuario WHERE mail='autor2@x.com'")[0][0]
    comentar(c, "autor2@x.com", post_id, "comentario de la autora")
    antes = sql("SELECT COUNT(*) FROM blog")[0][0]
    r = c.delete(f"/usuarios/{otro}", headers=h(admin["access_token"]))
    assert r.status_code == 200 and r.json()["comentarios_eliminados"] == 1
    assert sql("SELECT COUNT(*) FROM blog")[0][0] == antes
    assert sql("SELECT usr_id FROM blog WHERE titulo='De otra autora'") == ((None,),)
    p = [
        x
        for x in c.get("/blog", headers=h(admin["access_token"])).json()
        if x["titulo"] == "De otra autora"
    ][0]
    assert p["autor"] is None and p["usr_id"] is None


# ============================================================================
# PASO C · Crear y leer comentarios
# ============================================================================


@pytest.fixture(scope="session")
def pub_c(c, admin):
    r = c.post(
        "/blog",
        json={"titulo": "Publicación con comentarios", "descripcion": "d"},
        headers=h(admin["access_token"]),
    )
    return r.json()["id_blog"]


def test_c_sin_sesion_y_publicacion_inexistente(c, general, pub_c):
    assert c.get(f"/blog/{pub_c}/comentarios").status_code == 401
    r = c.get("/blog/999999/comentarios", headers=h(general["access_token"]))
    assert r.status_code == 404 and r.json()["detail"] == "Publicación no encontrada"
    assert c.get(f"/blog/{pub_c}/comentarios", headers=h(general["access_token"])).json() == []


def test_c_crear_y_leer(c, admin, general, pub_c, post_id):
    tg, ta = (h(general["access_token"]), h(admin["access_token"]))
    r = c.post(
        "/comentarios",
        json={"comentario": "Primero, del usuario general", "blog_id": pub_c},
        headers=tg,
    )
    assert (
        r.status_code == 201
        and r.json()["autor"] == "Usuario Editado"
        and (r.json()["estatus"] == 1)
    )
    assert set(r.json()) == {
        "id_com",
        "comentario",
        "fecha",
        "estatus",
        "usr_id",
        "blog_id",
        "autor",
    }
    primero = r.json()["id_com"]
    segundo = c.post(
        "/comentarios",
        json={"comentario": "Segundo, del administrador", "blog_id": pub_c},
        headers=ta,
    ).json()["id_com"]
    c.post(
        "/comentarios", json={"comentario": "En otra publicación", "blog_id": post_id}, headers=tg
    )
    sql(
        "INSERT INTO comentarios (comentario, estatus, usr_id, blog_id) VALUES ('Oculto', 0, %s, %s)",
        (general["usuario"]["id_usr"], pub_c),
    )
    sql(
        "INSERT INTO comentarios (comentario, fecha, estatus, usr_id, blog_id) VALUES ('Antiguo', '2020-01-01 10:00:00', 1, %s, %s)",
        (general["usuario"]["id_usr"], pub_c),
    )
    for t in (tg, ta):
        lista = c.get(f"/blog/{pub_c}/comentarios", headers=t).json()
        assert [x["comentario"] for x in lista] == [
            "Segundo, del administrador",
            "Primero, del usuario general",
            "Antiguo",
        ]
        assert [x["autor"] for x in lista] == ["Admin Uno", "Usuario Editado", "Usuario Editado"]
        assert (
            lista[0]["id_com"] == segundo
            and lista[1]["id_com"] == primero
            and (lista[2]["fecha"] == "2020-01-01T10:00:00")
        )
        assert all((x["blog_id"] == pub_c and x["estatus"] == 1 for x in lista))


def test_c_validaciones(c, general, pub_c):
    t = h(general["access_token"])
    antes = sql("SELECT COUNT(*) FROM comentarios")[0][0]
    assert (
        c.post(
            "/comentarios", json={"comentario": "a" * 1000, "blog_id": pub_c}, headers=t
        ).status_code
        == 201
    )
    assert (
        c.post(
            "/comentarios", json={"comentario": "a" * 1001, "blog_id": pub_c}, headers=t
        ).status_code
        == 422
    )
    assert (
        c.post("/comentarios", json={"comentario": "", "blog_id": pub_c}, headers=t).status_code
        == 422
    )
    r = c.post("/comentarios", json={"comentario": "   ", "blog_id": pub_c}, headers=t)
    assert r.status_code == 422 and r.json()["detail"] == "El comentario no puede estar vacío"
    assert (
        c.post("/comentarios", json={"comentario": "x", "blog_id": 999999}, headers=t).status_code
        == 404
    )
    assert c.post("/comentarios", json={"comentario": "x", "blog_id": pub_c}).status_code == 401
    assert sql("SELECT COUNT(*) FROM comentarios")[0][0] == antes + 1


def test_c_texto_con_acentos_y_emojis(c, general, pub_c):
    texto = "¡Qué útil! Probé IA 😀 <b>ñandú</b>"
    idc = c.post(
        "/comentarios",
        json={"comentario": texto, "blog_id": pub_c},
        headers=h(general["access_token"]),
    ).json()["id_com"]
    assert (
        c.get(f"/blog/{pub_c}/comentarios", headers=h(general["access_token"])).json()[0][
            "comentario"
        ]
        == texto
    )
    assert sql("SELECT comentario FROM comentarios WHERE id_com=%s", (idc,))[0][0] == texto


def test_c_listado_general_tambien_trae_autor(c, admin):
    lista = c.get("/comentarios", headers=h(admin["access_token"])).json()
    assert lista and all((x["autor"] for x in lista))


def test_c_eliminar_usuario_que_comento(c, admin, pub_c):
    uid = nuevo(c, admin, "comentador@x.com")
    comentar(c, "comentador@x.com", pub_c, "Me voy")
    assert (
        c.delete(f"/usuarios/{uid}", headers=h(admin["access_token"])).json()[
            "comentarios_eliminados"
        ]
        == 1
    )
    assert "Me voy" not in [
        x["comentario"]
        for x in c.get(f"/blog/{pub_c}/comentarios", headers=h(admin["access_token"])).json()
    ]


FOTO = {"imagen": ("nueva.png", b"\x89PNG", "image/png")}


# ============================================================================
# PASO D · Editar y eliminar publicaciones, moderar comentarios
# ============================================================================


@pytest.fixture()
def pub(c, admin):
    r = c.post(
        "/blog",
        json={
            "titulo": "Original",
            "descripcion": "Texto original",
            "img": "/uploads/vieja.jpg",
            "tags": "Inteligencia Artificial",
        },
        headers=h(admin["access_token"]),
    )
    return r.json()


def test_d_editar_con_json(c, admin, pub):
    t = h(admin["access_token"])
    idp = pub["id_blog"]
    fecha = sql("SELECT fecha FROM blog WHERE id_blog=%s", (idp,))[0][0]
    r = c.put(
        f"/blog/{idp}",
        json={
            "titulo": "  Editada  ",
            "descripcion": " Nuevo texto ",
            "img": "/uploads/vieja.jpg",
            "tags": "Programación",
        },
        headers=t,
    )
    assert r.status_code == 200
    assert r.json() == {
        "id_blog": idp,
        "titulo": "Editada",
        "descripcion": "Nuevo texto",
        "img": "/uploads/vieja.jpg",
        "tags": "Programación",
        "fecha": str(fecha),
        "usr_id": admin["usuario"]["id_usr"],
        "autor": "Admin Uno",
    }
    assert sql(
        "SELECT titulo, `desc`, img, tags, usr_id, fecha FROM blog WHERE id_blog=%s", (idp,)
    ) == (
        (
            "Editada",
            "Nuevo texto",
            "/uploads/vieja.jpg",
            "Programación",
            admin["usuario"]["id_usr"],
            fecha,
        ),
    )
    r = c.put(
        f"/blog/{idp}",
        json={"titulo": "Editada", "descripcion": "Nuevo texto", "img": "", "tags": None},
        headers=t,
    )
    assert r.json()["img"] is None and r.json()["tags"] is None


def test_d_otro_admin_edita_y_el_autor_no_cambia(c, admin, pub):
    nuevo(c, admin, "editor@x.com", tipo=1)
    t2 = h(login(c, "editor@x.com")["access_token"])
    r = c.put(
        f"/blog/{pub['id_blog']}",
        json={"titulo": "Editada por otro", "descripcion": "d", "usr_id": 999},
        headers=t2,
    )
    assert (
        r.status_code == 200
        and r.json()["usr_id"] == admin["usuario"]["id_usr"]
        and (r.json()["autor"] == "Admin Uno")
    )


def test_d_editar_validaciones_y_permisos(c, admin, general, pub):
    t = h(admin["access_token"])
    idp = pub["id_blog"]
    ok = {"titulo": "Bien", "descripcion": "d"}
    assert (
        c.put(f"/blog/{idp}", json={"titulo": "x", "descripcion": "d"}, headers=t).status_code
        == 422
    )
    assert (
        c.put(f"/blog/{idp}", json={"titulo": "t" * 151, "descripcion": "d"}, headers=t).status_code
        == 422
    )
    assert (
        c.put(f"/blog/{idp}", json={"titulo": "Bien", "descripcion": ""}, headers=t).status_code
        == 422
    )
    assert c.put("/blog/999999", json=ok, headers=t).status_code == 404
    assert c.put(f"/blog/{idp}", json=ok).status_code == 401
    assert c.put(f"/blog/{idp}", json=ok, headers=h(general["access_token"])).status_code == 403
    assert c.put(f"/blog/{idp}/foto", data=ok, files=FOTO).status_code == 401
    assert (
        c.put(
            f"/blog/{idp}/foto", data=ok, files=FOTO, headers=h(general["access_token"])
        ).status_code
        == 403
    )
    assert c.delete(f"/blog/{idp}").status_code == 401
    assert c.delete(f"/blog/{idp}", headers=h(general["access_token"])).status_code == 403
    assert sql("SELECT titulo FROM blog WHERE id_blog=%s", (idp,)) == (("Original",),)


def test_d_editar_con_foto(c, admin, pub):
    t = h(admin["access_token"])
    idp = pub["id_blog"]
    r = c.put(
        f"/blog/{idp}/foto",
        data={"titulo": "Con foto nueva", "descripcion": "d", "tags": "Tecnología"},
        files=FOTO,
        headers=t,
    )
    assert (
        r.status_code == 200
        and r.json()["titulo"] == "Con foto nueva"
        and (r.json()["tags"] == "Tecnología")
    )
    assert (
        r.json()["img"].startswith("/uploads/")
        and r.json()["img"].endswith(".png")
        and (r.json()["img"] != "/uploads/vieja.jpg")
    )
    assert (
        c.get(r.json()["img"]).status_code == 200
        and r.json()["usr_id"] == admin["usuario"]["id_usr"]
    )
    antes = sql("SELECT titulo, img FROM blog WHERE id_blog=%s", (idp,))
    assert (
        c.put(
            f"/blog/{idp}/foto",
            data={"titulo": "T2", "descripcion": "d"},
            files={"imagen": ("virus.exe", b"x", "application/octet-stream")},
            headers=t,
        ).status_code
        == 400
    )
    assert (
        c.put(
            f"/blog/{idp}/foto", data={"titulo": "  ", "descripcion": "d"}, files=FOTO, headers=t
        ).status_code
        == 400
    )
    assert (
        c.put(
            "/blog/999999/foto", data={"titulo": "T2", "descripcion": "d"}, files=FOTO, headers=t
        ).status_code
        == 404
    )
    assert sql("SELECT titulo, img FROM blog WHERE id_blog=%s", (idp,)) == antes


def test_d_crear_con_foto_sigue_igual(c, admin):
    r = c.post(
        "/blog/foto",
        data={"titulo": "Foto D", "descripcion": "d"},
        files={"imagen": ("a.webp", b"x", "image/webp")},
        headers=h(admin["access_token"]),
    )
    assert (
        r.status_code == 200
        and set(r.json()) == {"mensaje", "titulo", "descripcion", "imagen"}
        and r.json()["imagen"].endswith(".webp")
    )
    assert (
        c.post(
            "/blog/foto",
            data={"titulo": "Foto D", "descripcion": "d"},
            files={"imagen": ("a.gif", b"x", "image/gif")},
            headers=h(admin["access_token"]),
        ).status_code
        == 400
    )


def test_d_eliminar_publicacion_con_comentarios(c, admin, general, pub, post_id):
    t = h(admin["access_token"])
    idp = pub["id_blog"]
    for texto in ("uno", "dos"):
        c.post(
            "/comentarios",
            json={"comentario": texto, "blog_id": idp},
            headers=h(general["access_token"]),
        )
    otros = sql("SELECT COUNT(*) FROM comentarios WHERE blog_id <> %s", (idp,))[0][0]
    r = c.delete(f"/blog/{idp}", headers=t)
    assert r.status_code == 200 and r.json() == {
        "mensaje": "Publicación eliminada correctamente",
        "comentarios_eliminados": 2,
    }
    assert sql("SELECT COUNT(*) FROM blog WHERE id_blog=%s", (idp,))[0][0] == 0
    assert sql("SELECT COUNT(*) FROM comentarios")[0][0] == otros >= 1
    assert (
        c.get(f"/blog/{idp}", headers=t).status_code == 404
        and c.delete(f"/blog/{idp}", headers=t).status_code == 404
    )


def test_d_moderar_lista_y_elimina(c, admin, general, pub):
    ta, tg = (h(admin["access_token"]), h(general["access_token"]))
    idp = pub["id_blog"]
    a = c.post("/comentarios", json={"comentario": "Visible", "blog_id": idp}, headers=tg).json()[
        "id_com"
    ]
    b = c.post(
        "/comentarios", json={"comentario": "Para borrar", "blog_id": idp}, headers=tg
    ).json()["id_com"]
    sql(
        "INSERT INTO comentarios (comentario, fecha, estatus, usr_id, blog_id) VALUES ('Oculto antiguo', '2020-01-01 10:00:00', 0, %s, %s)",
        (general["usuario"]["id_usr"], idp),
    )
    assert c.get(f"/blog/{idp}/comentarios/moderacion").status_code == 401
    assert c.get(f"/blog/{idp}/comentarios/moderacion", headers=tg).status_code == 403
    assert c.get("/blog/999999/comentarios/moderacion", headers=ta).status_code == 404
    lista = c.get(f"/blog/{idp}/comentarios/moderacion", headers=ta).json()
    assert (
        [x["comentario"] for x in lista] == ["Para borrar", "Visible", "Oculto antiguo"]
        and lista[2]["estatus"] == 0
        and (lista[0]["autor"] == "Usuario Editado")
    )
    assert c.delete(f"/comentarios/{b}").status_code == 401
    assert c.delete(f"/comentarios/{b}", headers=tg).status_code == 403
    r = c.delete(f"/comentarios/{b}", headers=ta)
    assert r.status_code == 200 and r.json() == {"mensaje": "Comentario eliminado correctamente"}
    assert sql("SELECT COUNT(*) FROM comentarios WHERE id_com=%s", (b,))[0][0] == 0
    assert c.delete(f"/comentarios/{b}", headers=ta).status_code == 404
    assert [x["id_com"] for x in c.get(f"/blog/{idp}/comentarios", headers=tg).json()] == [a]
    assert sql("SELECT COUNT(*) FROM blog WHERE id_blog=%s", (idp,))[0][0] == 1


def test_d_si_falla_eliminar_publicacion_no_queda_a_medias(c, admin, general, pub):
    idp = pub["id_blog"]
    c.post(
        "/comentarios",
        json={"comentario": "sobrevive", "blog_id": idp},
        headers=h(general["access_token"]),
    )
    sql(
        "CREATE TABLE tmp_ref_b (id INT PRIMARY KEY, blog_id INT NOT NULL, FOREIGN KEY (blog_id) REFERENCES blog (id_blog)) ENGINE=InnoDB"
    )
    sql("INSERT INTO tmp_ref_b VALUES (1, %s)", (idp,))
    try:
        r = c.delete(f"/blog/{idp}", headers=h(admin["access_token"]))
        assert (
            r.status_code == 500
            and r.json()["detail"] == "No se pudo eliminar la publicación. Intenta de nuevo."
        )
        assert sql("SELECT COUNT(*) FROM comentarios WHERE blog_id=%s", (idp,))[0][0] == 1
    finally:
        sql("DROP TABLE tmp_ref_b")


# ============================================================================
# PASO F · Fecha de la publicación
# ============================================================================


def test_f_api_devuelve_la_fecha(c, admin, general):
    r = c.post(
        "/blog", json={"titulo": "Con fecha", "descripcion": "d"}, headers=h(admin["access_token"])
    )
    hoy = str(sql("SELECT CURDATE()")[0][0])
    assert r.status_code == 201 and r.json()["fecha"] == hoy
    idp = r.json()["id_blog"]
    sql("UPDATE blog SET fecha='2025-03-09' WHERE id_blog=%s", (idp,))
    assert c.get(f"/blog/{idp}", headers=h(general["access_token"])).json()["fecha"] == "2025-03-09"
    r = c.put(
        f"/blog/{idp}",
        json={"titulo": "Con fecha editada", "descripcion": "d", "fecha": "1999-01-01"},
        headers=h(admin["access_token"]),
    )
    assert r.json()["fecha"] == "2025-03-09"
    assert all(
        (
            "fecha" in p and p["fecha"]
            for p in c.get("/blog", headers=h(general["access_token"])).json()
        )
    )


# ============================================================================
# PASO G · Buscador y filtro por etiqueta en GET /blog (mismas reglas que la web)
# ============================================================================


def ids_de(c, token, **parametros):
    """Ids que devuelve GET /blog con los parámetros dados (q, etiqueta)."""
    r = c.get("/blog", params=parametros, headers=h(token))
    assert r.status_code == 200, r.text
    return [p["id_blog"] for p in r.json()]


@pytest.fixture(scope="session")
def pubs_g(c, admin):
    """Publicaciones de prueba. Todas llevan la palabra «Zqx» para aislarlas del resto."""
    datos = {
        "basico": ("Zqx robot básico", "Guía para el año nuevo", "Inteligencia Artificial"),
        "interes_pct": ("Zqx precisión 50%", "Mediciones de precisión", "Ciberseguridad"),
        "interes_sin": ("Zqx Precision 50 puntos", "Sin decimales", "IA"),
        "guion": ("Zqx mi_robot", "Con guion bajo", "Programación"),
        "barra": ("Zqx a|b", "Con barra vertical", "Tecnología"),
        "varias": ("Zqx múltiples etiquetas", "d", "Ciberseguridad, Inteligencia Artificial"),
        "nueve": ("Zqx ocho uno dos tres cuatro cinco seis", "d", None),
    }
    ids = {}
    for clave, (titulo, desc, tags) in datos.items():
        r = c.post(
            "/blog",
            json={"titulo": titulo, "descripcion": desc, "tags": tags},
            headers=h(admin["access_token"]),
        )
        assert r.status_code == 201, r.text
        ids[clave] = r.json()["id_blog"]
    return ids


def test_g_sin_filtros_trae_todo_ordenado_como_la_web(c, admin, general, pubs_g):
    # Fechas distintas para comprobar el orden: más reciente primero y, si empatan, id mayor.
    sql("UPDATE blog SET fecha='2020-01-01' WHERE id_blog=%s", (pubs_g["basico"],))
    sql("UPDATE blog SET fecha='2030-12-31' WHERE id_blog=%s", (pubs_g["guion"],))
    esperado = [f[0] for f in sql("SELECT id_blog FROM blog ORDER BY fecha DESC, id_blog DESC")]
    for token in (admin["access_token"], general["access_token"]):
        assert ids_de(c, token) == esperado
    assert esperado[0] == pubs_g["guion"]
    # Vacío o solo espacios equivale a no filtrar.
    assert ids_de(c, general["access_token"], q="   ") == esperado
    assert ids_de(c, general["access_token"], q="", etiqueta="") == esperado


def test_g_busqueda_mayusculas_acentos_y_parcial(c, general, pubs_g):
    t = general["access_token"]
    assert ids_de(c, t, q="zqx BASICO") == [pubs_g["basico"]]           # mayúsculas y acento
    assert ids_de(c, t, q="zqx ano") == [pubs_g["basico"]]              # «ano» encuentra «año» (descripción)
    assert ids_de(c, t, q="básico ZQX") == [pubs_g["basico"]]           # cualquier orden
    assert set(ids_de(c, t, q="zqx robot")) == {pubs_g["basico"], pubs_g["guion"]}  # parcial
    assert set(ids_de(c, t, q="ZQX PRECISIÓN")) == {pubs_g["interes_pct"], pubs_g["interes_sin"]}
    assert ids_de(c, t, q="zqx noexiste") == []                         # todas las palabras deben estar
    # El buscador también revisa las etiquetas de MySQL.
    assert pubs_g["interes_sin"] in ids_de(c, t, q="IA")


def test_g_caracteres_especiales_son_texto(c, general, pubs_g):
    t = general["access_token"]
    assert ids_de(c, t, q="zqx 50%") == [pubs_g["interes_pct"]]         # % no es comodín
    assert ids_de(c, t, q="zqx i_r") == [pubs_g["guion"]]               # _ no es comodín
    assert ids_de(c, t, q="zqx a|b") == [pubs_g["barra"]]               # | (carácter de escape)
    assert ids_de(c, t, q="%") == ids_de(c, t, q="50%")                  # solo «%» no trae todo
    assert ids_de(c, t, q="zqx ' OR 1=1 --") == []                       # sin inyección SQL
    assert ids_de(c, t, q="zqx 😀 \\") == []


def test_g_limites_de_largo_y_de_palabras(c, general, pubs_g):
    t = general["access_token"]
    # Solo se usan las primeras 8 palabras: la 9.ª («noexiste») se ignora.
    q = "zqx ocho uno dos tres cuatro cinco seis noexiste"
    assert ids_de(c, t, q=q) == [pubs_g["nueve"]]
    # Más de 100 caracteres: se recorta, no da error.
    assert ids_de(c, t, q="zqx " + "x" * 300) == []
    assert ids_de(c, t, q="zqx básico" + " " * 95 + "noexiste") == [pubs_g["basico"]]


def test_g_filtro_por_etiqueta(c, admin, general, pubs_g):
    t = general["access_token"]
    con_etiqueta = ids_de(c, t, etiqueta="Inteligencia Artificial")
    esperado = [
        f[0]
        for f in sql(
            "SELECT id_blog FROM blog WHERE FIND_IN_SET(%s, REPLACE(tags, ', ', ',')) > 0 "
            "ORDER BY fecha DESC, id_blog DESC",
            ("Inteligencia Artificial",),
        )
    ]
    assert con_etiqueta == esperado
    assert pubs_g["basico"] in con_etiqueta and pubs_g["varias"] in con_etiqueta  # admite varias etiquetas
    assert set(ids_de(c, t, q="zqx", etiqueta="Ciberseguridad")) == {
        pubs_g["interes_pct"], pubs_g["varias"]
    }
    # Texto y etiqueta se combinan (las dos condiciones).
    assert ids_de(c, t, q="zqx precisión", etiqueta="IA") == [pubs_g["interes_sin"]]
    # Si no existe la etiqueta, no se muestran publicaciones.
    assert ids_de(c, t, etiqueta="Etiqueta inexistente") == []
    # La API ignora los espacios de los extremos y no distingue mayúsculas.
    assert ids_de(c, t, etiqueta="inteligencia artificial ") == con_etiqueta
    assert ids_de(c, t, etiqueta=" Inteligencia Artificial ") == con_etiqueta


def test_g_buscador_exige_sesion(c, pubs_g):
    assert c.get("/blog", params={"q": "zqx"}).status_code == 401
