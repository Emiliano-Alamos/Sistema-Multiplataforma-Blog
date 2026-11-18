# Blog de Educación Financiera – App móvil (Flutter + FastAPI + MySQL)

Aplicación de blog sobre educación financiera desarrollada para la materia **Desarrollo de Aplicaciones Móviles** de la Universidad Tecnológica de Querétaro (UTEQ).

- **Cliente móvil:** Flutter (Material 3).
- **API REST:** FastAPI (Python) con SQLAlchemy.
- **Base de datos:** MySQL / MariaDB.

**Integrantes:** Ricardo Esteban Ramos Rodríguez y Emiliano Martínez Alamos · Grupo: [LITIID014]

---

## Funcionalidades

- Registro e inicio de sesión desde la app.
- Contraseñas encriptadas con **Argon2id**.
- Sesiones con **token JWT**:
  - Se cierran tras 30 minutos sin actividad, con un tope de 8 horas.
  - El token se renueva solo en cada petición (encabezado `X-Token-Renovado`).
- Dos roles (`tip_usu`):
  - **1 = Administrador:** gestiona usuarios, publicaciones y comentarios.
  - **2 = Usuario general:** lee publicaciones y comenta. El registro público siempre crea este rol.
- Publicaciones:
  - Tienen título, descripción, imagen (cámara o galería), etiqueta de una lista fija, fecha y autor.
  - Se ven en orden de la más reciente a la más antigua.
- Buscador por texto (título o descripción) y filtro por etiqueta.
- Comentarios en las publicaciones y moderación (eliminación) por el administrador.
- Edición y eliminación de publicaciones por el administrador.

## Arquitectura

Arquitectura en capas **cliente–servidor** con un patrón **MVC adaptado**:

- **Vista:** `screens/` y `widgets/` de Flutter.
- **Modelo:** `models/` en Flutter, y `models.py` (ORM) y `schemas.py` en la API.
- **Control:** repartido entre las pantallas y los servicios (`services/`). Los servicios llaman a la API por HTTP/JSON.

```
Flutter (screens, widgets, services, models)
        │  HTTP / JSON + token JWT
        ▼
FastAPI (main.py, seguridad.py, schemas.py, models.py, database.py)
        │  SQL (SQLAlchemy + PyMySQL)
        ▼
MySQL (usuario, blog, comentarios)
```

## Estructura del repositorio

```
├── backend_API/               API en FastAPI
│   ├── main.py                Rutas (endpoints)
│   ├── seguridad.py           Tokens JWT, sesión y control de acceso por rol
│   ├── models.py              Modelos ORM (tablas)
│   ├── schemas.py             Validación de datos de entrada y salida
│   ├── database.py            Conexión a MySQL (lee el archivo .env)
│   ├── requirements.txt       Dependencias de la API
│   ├── requirements-pruebas.txt  Dependencias de las pruebas
│   ├── .env.example           Plantilla de configuración (copiar a .env)
│   └── tests/test_api.py      Pruebas automatizadas
├── database/
│   └── base_de_datos.sql      Script de creación de la base de datos
└── flutter_application_3/     App móvil en Flutter
    └── lib/
        ├── main.dart          Rutas de la app
        ├── models/            Usuario, publicación y comentario
        ├── screens/           Pantallas
        ├── services/          Llamadas a la API y sesión
        ├── theme/             Tema visual (colores y tipografía)
        ├── utils/             Etiquetas y URL de imágenes
        └── widgets/           Componentes reutilizables
```

## Requisitos

- **Python** 3.10 o superior.
- **Flutter** con Dart 3.13.4 o superior (revisa con `flutter --version`).
- **MySQL** o MariaDB. Por ejemplo, el de XAMPP.
- **Google Chrome**, para ejecutar la app con `flutter run -d chrome`.

---

## Instalación

Los comandos son para Windows (PowerShell o CMD).

### 1. Base de datos

1. Enciende MySQL (por ejemplo, desde el panel de XAMPP).
2. Ejecuta el script `database/base_de_datos.sql`. Crea la base `bd_aplicacion_movil_pro` con sus tres tablas. Puedes hacerlo de dos formas:
   - En phpMyAdmin: pestaña **Importar**.
   - Desde la consola de MySQL:
     ```sql
     SOURCE C:/ruta/al/proyecto/database/base_de_datos.sql;
     ```

El script no borra nada si la base ya existe. Además, la API crea las tablas que falten al arrancar.

### 2. API (FastAPI) – terminal 1

```powershell
cd backend_API
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

Copia `.env.example` como `.env` (en la misma carpeta) y ajusta los valores a tu computadora:

| Variable                 | Qué es                                                                                        |
| ------------------------ | --------------------------------------------------------------------------------------------- |
| `DB_HOST`, `DB_PORT`     | Servidor y puerto de MySQL. XAMPP usa 3306 por defecto; cámbialo si el tuyo usa otro.         |
| `DB_USER`, `DB_PASSWORD` | Usuario y contraseña de MySQL.                                                                |
| `DB_NAME`                | `bd_aplicacion_movil_pro`                                                                     |
| `JWT_SECRET`             | Clave para firmar los tokens. Debe tener 32 caracteres o más. **Sin ella la API no arranca.** |

Para generar `JWT_SECRET`, ejecuta este comando y pega el resultado en el `.env`:

```powershell
python -c "import secrets; print(secrets.token_hex(32))"
```

Enciende la API:

```powershell
uvicorn main:app --reload --port 8000
```

Comprueba que funciona:

- http://127.0.0.1:8000 debe responder `{"mensaje": "API funcionando correctamente"}`.
- La documentación interactiva está en http://127.0.0.1:8000/docs.

> El archivo `.env` contiene contraseñas: **nunca lo subas al repositorio**. Ya está en `.gitignore`.

### 3. App móvil (Flutter) – terminal 2

```powershell
cd flutter_application_3
flutter pub get
flutter run -d chrome
```

La app se conecta a la API en `http://127.0.0.1:8000`. Esa dirección está en la constante `baseUrl` de los archivos de `lib/services/`.

Para ejecutarla en un emulador de Android o en un celular, hay que cambiar esa dirección en todos los servicios:

- **Emulador de Android:** `http://10.0.2.2:8000`.
- **Celular:** la IP de la computadora en la red local, encendiendo la API con `--host 0.0.0.0`.

### 4. Primer administrador

El registro desde la app siempre crea un **Usuario general**. Para tener el primer administrador:

1. Regístrate en la app.
2. Ejecuta en MySQL, con tu correo:
   ```sql
   UPDATE usuario SET tip_usu = 1 WHERE mail = 'tu_correo@ejemplo.com';
   ```
3. Cierra sesión y vuelve a entrar.

Desde ese momento, ese administrador puede crear otros usuarios y administradores desde la app.

---

## Uso

- **Usuario general:**
  - Inicia sesión y ve el blog.
  - Busca por texto o filtra por etiqueta.
  - Abre una publicación y comenta.
  - Cierra sesión desde el menú de su avatar.
- **Administrador:**
  - Usa el menú lateral para moverse entre usuarios, publicaciones y su perfil.
  - Entra al panel de usuarios y da de alta, edita o elimina usuarios. Siempre debe quedar al menos un administrador.
  - Crea publicaciones con imagen y etiqueta.
  - En **Editar publicaciones**, edita o elimina publicaciones y modera sus comentarios.

## Seguridad implementada

- **Contraseñas:** hash Argon2id (`pwdlib`). Nunca se guardan ni se devuelven en texto plano.
- **Sesión:** token JWT firmado con `JWT_SECRET`. Se cierra tras 30 minutos de inactividad, con un máximo de 8 horas por sesión.
- **Control de acceso:**
  - Sin sesión válida, la API responde **401**.
  - Sin el rol necesario, responde **403**.
  - Un usuario general solo puede editar su propio perfil.
  - Nadie puede cambiarse el rol a sí mismo.
- **Validación:** los datos de entrada se validan con esquemas Pydantic. Un correo repetido responde **409**.
- **Configuración:** credenciales y clave secreta fuera del código, en el archivo `.env`.

## Endpoints principales

| Método | Ruta                                | Acceso                                                               |
| ------ | ----------------------------------- | -------------------------------------------------------------------- |
| POST   | `/login`                            | Público                                                              |
| POST   | `/usuarios`                         | Público (crea Usuario general); el administrador puede elegir el rol |
| GET    | `/usuarios`                         | Administrador                                                        |
| PUT    | `/usuarios/{id}`                    | Con sesión (el propio perfil) o administrador                        |
| DELETE | `/usuarios/{id}`                    | Administrador                                                        |
| GET    | `/blog?q=&etiqueta=`                | Con sesión                                                           |
| GET    | `/blog/{id}`                        | Con sesión                                                           |
| POST   | `/blog`, `/blog/foto`               | Administrador                                                        |
| PUT    | `/blog/{id}`, `/blog/{id}/foto`     | Administrador                                                        |
| DELETE | `/blog/{id}`                        | Administrador                                                        |
| GET    | `/blog/{id}/comentarios`            | Con sesión                                                           |
| POST   | `/comentarios`                      | Con sesión                                                           |
| GET    | `/blog/{id}/comentarios/moderacion` | Administrador                                                        |
| DELETE | `/comentarios/{id}`                 | Administrador                                                        |

La lista completa, con ejemplos, está en http://127.0.0.1:8000/docs.

## Pruebas automatizadas

Desde `backend_API`, con el entorno virtual activado:

```powershell
pip install -r requirements-pruebas.txt
python -m pytest tests -q
```

Cómo funcionan:

- Usan una base **aparte**, `bd_blog_pruebas`, que se borra y se vuelve a crear en cada ejecución.
- **No tocan** la base configurada en `DB_NAME`.
- Del `.env` solo toman el servidor (`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`).

## Librerías utilizadas

- **API:**
  - `fastapi` y `uvicorn`: servidor de la API.
  - `SQLAlchemy` y `PyMySQL`: acceso a MySQL.
  - `pwdlib[argon2]`: hash de contraseñas.
  - `PyJWT`: tokens de sesión.
  - `python-dotenv`: lectura del `.env`.
  - `python-multipart`: subida de imágenes.
- **App:**
  - `http`: llamadas a la API.
  - `image_picker`: imagen desde la cámara o la galería.
  - `cupertino_icons`.
