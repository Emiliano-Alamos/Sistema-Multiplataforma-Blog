# Blog de Tecnologías Emergentes – Flutter + FastAPI + MySQL

Sistema de divulgación y aprendizaje sobre tecnologías emergentes, especialmente **Inteligencia Artificial (IA)**. Presenta publicaciones, explicaciones, recomendaciones y aplicaciones prácticas para personas interesadas en aprender tecnología. Se desarrolló para la materia **Desarrollo de Aplicaciones Móviles** de la Universidad Tecnológica de Querétaro (UTEQ).

- **Cliente móvil:** Flutter (Material 3).
- **API REST:** FastAPI (Python) con SQLAlchemy.
- **Base de datos compartida:** MySQL / MariaDB.
- **Complemento web:** PHP + Bootstrap, desarrollado por separado y conectado a la misma base de datos.

**Integrantes:** Ricardo Esteban Ramos Rodríguez y Emiliano Martínez Alamos · Grupo: LITIID014

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
  - Tienen título, descripción, imagen (cámara, galería o dirección de imagen), etiquetas, fecha y autor.
  - Se ven en orden de la más reciente a la más antigua.
- Buscador por texto (título, descripción o etiquetas) y filtro por etiquetas como IA, Robótica y Tecnología.
- Comentarios en las publicaciones y moderación por el administrador.
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
        ├── config/            Dirección de la API (un solo lugar)
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
- **Android Studio** con un emulador (opcional), para ejecutarla como app de Android.

---

## Instalación

Los comandos son para Windows (PowerShell o CMD).

1. Descarga el repositorio desde GitHub (opción **Code → Download ZIP**) y descomprímelo, o clónalo con Git.
2. Abre una terminal dentro de la carpeta principal del repositorio: `Sistema-Multiplataforma-Blog-main` si lo descargaste en ZIP, o `Sistema-Multiplataforma-Blog` si lo clonaste.
3. Sigue los pasos en este orden: **MySQL → FastAPI → Flutter**.

### 1. Base de datos

1. Enciende MySQL (por ejemplo, desde el panel de XAMPP).
2. Ejecuta el script `database/base_de_datos.sql`. Crea la base `bd_aplicacion_movil` con sus tres tablas. Puedes hacerlo de dos formas:
   - En phpMyAdmin: pestaña **Importar**.
   - Desde la consola de MySQL:
     ```sql
     SOURCE C:/ruta/al/proyecto/database/base_de_datos.sql;
     ```

El script usa `CREATE ... IF NOT EXISTS`: no elimina los registros de una base existente, pero tampoco actualiza la estructura de tablas antiguas. Para una instalación desde cero, ejecútalo antes de iniciar la API. No incluye publicaciones de ejemplo.

**Importante:** el nombre escrito en el script SQL y el valor `DB_NAME` de `.env` deben coincidir. Si agregas la web PHP, su conexión debe apuntar también a esa misma base.

### 2. API (FastAPI) – terminal 1

```powershell
cd backend_API
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

Copia `.env.example` como `.env` (en la misma carpeta) con `Copy-Item .env.example .env` en PowerShell y ajusta los valores a tu computadora:

| Variable                 | Qué es                                                                                        |
| ------------------------ | --------------------------------------------------------------------------------------------- |
| `DB_HOST`, `DB_PORT`     | Servidor y puerto de MySQL. XAMPP usa 3306 por defecto; cámbialo si el tuyo usa otro.         |
| `DB_USER`, `DB_PASSWORD` | Usuario y contraseña de MySQL.                                                                |
| `DB_NAME`                | `bd_aplicacion_movil`                                                                     |
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

> El archivo `.env` contiene contraseñas: **nunca lo subas a GitHub ni lo incluyas en archivos ZIP que compartas**. Está indicado en `.gitignore`, pero eso no lo excluye automáticamente de un ZIP creado manualmente. Comparte únicamente `.env.example`.

### 3. App móvil (Flutter) – terminal 2

```powershell
cd flutter_application_3
flutter pub get
```

Después elige dónde ejecutarla:

| Dónde                 | Comando                                     | Dirección de la API que usa la app |
| --------------------- | ------------------------------------------- | ---------------------------------- |
| Chrome                | `flutter run -d chrome`                     | `http://127.0.0.1:8000`            |
| Emulador de Android   | `flutter run -d emulator-5554`              | `http://10.0.2.2:8000`             |

La dirección se elige sola según dónde corre la app y está en un solo archivo: `lib/config/api_config.dart`. En el emulador, `10.0.2.2` es la computadora donde corre la API; la API se enciende igual que en el paso 2.

Para el emulador:

1. En Android Studio, crea un dispositivo en **Device Manager** y enciéndelo.
2. Ejecuta `flutter devices` y usa el nombre que aparezca (normalmente `emulator-5554`).
3. Opcional: en la configuración del dispositivo, **Camera → Back = Webcam0** permite usar la webcam de la computadora como cámara.

> En Chrome de escritorio, el botón **Cámara** abre el explorador de archivos. Para usar la cámara, ejecuta la app en Android.

**Celular físico (opcional):** la computadora y el celular deben estar en la misma red Wi-Fi.

1. Enciende la API para toda la red: `uvicorn main:app --reload --host 0.0.0.0 --port 8000`. Si Windows pregunta por el firewall, permite el acceso en redes privadas.
2. Busca la IP de la computadora con `ipconfig` (por ejemplo, `192.168.1.50`).
3. Ejecuta la app indicando esa dirección:
   ```powershell
   flutter run --dart-define=API_URL=http://192.168.1.50:8000
   ```

### 4. Componente web PHP (si se instala por separado)

La parte web que desarrollamos utiliza PHP, Bootstrap y MySQL. **No está dentro de este repositorio**, por lo que debes disponer también de `blog_web/` para instalarla.

1. Instala o enciende Apache y MySQL desde XAMPP.
2. Copia la carpeta `blog_web` a `C:\xampp\htdocs\blog_web`.
3. Configura `blog_web/config/conexion.php` para que use la **misma base de datos** que FastAPI, sin publicar contraseñas.
4. Mantén FastAPI ejecutándose si las imágenes del blog se muestran desde `/uploads`.
5. Abre `http://localhost/blog_web/` en el navegador.

La web tiene vistas para el administrador y el usuario general; ambas consultan las publicaciones y comentarios almacenados en MySQL. Las fotografías que se suban a `backend_API/uploads/` no se incluyen automáticamente en GitHub, porque esa carpeta está excluida en `.gitignore`.

### 5. Primer administrador

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
  - Busca por título, descripción o etiqueta, y puede filtrar por etiquetas.
  - Abre una publicación y comenta.
  - Cierra sesión desde el menú de su avatar.
- **Administrador:**
  - Usa el menú lateral para moverse entre usuarios, publicaciones y su perfil.
  - Entra al panel de usuarios y da de alta, edita o elimina usuarios. Siempre debe quedar al menos un administrador.
  - Crea publicaciones con imagen y etiquetas.
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
