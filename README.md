# Blog de Tecnologías Emergentes – Flutter + FastAPI + MySQL

Sistema de divulgación y aprendizaje sobre tecnologías emergentes, especialmente **Inteligencia Artificial (IA)**. Presenta publicaciones, explicaciones, recomendaciones y aplicaciones prácticas para personas interesadas en aprender tecnología. Se desarrolló para la materia **Desarrollo de Aplicaciones Móviles** de la Universidad Tecnológica de Querétaro (UTEQ).

- **Aplicación móvil:** Flutter (Material 3).
- **API REST:** FastAPI (Python) con SQLAlchemy.
- **Base de datos:** MySQL / MariaDB (la que incluye XAMPP).

**Integrantes:** Ricardo Esteban Ramos Rodríguez y Emiliano Martínez Alamos · Grupo: LITIID014

> La versión web del blog (PHP) es un trabajo aparte y **no forma parte de este repositorio**.

Este documento explica, desde una computadora sin nada instalado, todo lo necesario para crear, ejecutar y probar la aplicación.

---

## Contenido

1. [Funcionalidades](#funcionalidades)
2. [Arquitectura](#arquitectura)
3. [Estructura del repositorio](#estructura-del-repositorio)
4. [Versiones con las que se probó](#versiones-con-las-que-se-probó)
5. [Parte 1. Instalar las herramientas](#parte-1-instalar-las-herramientas)
6. [Parte 2. Descargar el proyecto](#parte-2-descargar-el-proyecto)
7. [Parte 3. Crear la base de datos](#parte-3-crear-la-base-de-datos)
8. [Parte 4. API con FastAPI](#parte-4-api-con-fastapi)
9. [Parte 5. Aplicación en Flutter](#parte-5-aplicación-en-flutter)
10. [Parte 6. Primer administrador](#parte-6-primer-administrador)
11. [Parte 7. Probar la aplicación](#parte-7-probar-la-aplicación)
12. [Uso](#uso)
13. [Seguridad implementada](#seguridad-implementada)
14. [Endpoints principales](#endpoints-principales)
15. [Librerías utilizadas](#librerías-utilizadas)
16. [Problemas comunes](#problemas-comunes)

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
  - Cada una muestra a su autor; el administrador puede filtrar **Todas / Mis publicaciones**.
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

## Versiones con las que se probó

| Herramienta                | Versión probada              | Mínimo necesario                |
| -------------------------- | ---------------------------- | ------------------------------- |
| Windows                    | Windows 11                   | Windows 10 de 64 bits           |
| Python                     | 3.13.5                       | 3.10                            |
| Flutter                    | 3.47.5 (canal stable)        | El que incluya Dart 3.13.4      |
| Dart                       | 3.13.4                       | 3.13.4                          |
| XAMPP                      | 8.2.12                       | —                               |
| MySQL de XAMPP             | MariaDB 10.4.32              | MariaDB 10.4 o MySQL 8.0.13     |
| Google Chrome              | 157                          | —                               |
| Emulador de Android        | Pixel con Android 17 (API 37) | —                              |

---

## Parte 1. Instalar las herramientas

Instálalas en este orden. Al terminar cada una, **cierra y vuelve a abrir** las terminales para que reconozcan los programas nuevos.

| #  | Herramienta            | Para qué se usa                                         | Obligatoria                     |
| -- | ---------------------- | ------------------------------------------------------- | ------------------------------- |
| 1  | Git                    | Descargar el proyecto; Flutter también lo necesita      | Sí                              |
| 2  | Visual Studio Code     | Editar el código y abrir terminales                     | Sí                              |
| 3  | Google Chrome          | Ejecutar la app en el navegador                         | Sí                              |
| 4  | XAMPP                  | Servidor MySQL (MariaDB) para la base de datos          | Sí                              |
| 5  | Python                 | Ejecutar la API                                         | Sí                              |
| 6  | Flutter SDK            | Compilar y ejecutar la app (incluye Dart)               | Sí                              |
| 7  | Android Studio         | SDK de Android y emulador                               | Solo para ejecutarla en Android |

### 1.1 Git

1. Descárgalo de https://git-scm.com/downloads (opción **Windows**).
2. Instálalo con las opciones predeterminadas.
3. Comprueba en una terminal nueva: `git --version`.

### 1.2 Visual Studio Code

1. Descárgalo de https://code.visualstudio.com/ e instálalo. Durante la instalación marca **«Agregar a PATH»**.
2. Abre VS Code, entra a **Extensiones** (`Ctrl` + `Shift` + `X`) e instala:
   - **Flutter** (instala también la extensión **Dart**).
   - **Python** (de Microsoft).
3. Las terminales se abren en **Terminal → Nueva terminal**. En Windows, VS Code usa PowerShell.

> No se necesita **Visual Studio** (el IDE morado, distinto de VS Code). Solo sirve para crear apps de escritorio de Windows, y este proyecto no tiene esa plataforma.

### 1.3 Google Chrome

1. Descárgalo de https://www.google.com/chrome/ e instálalo.
2. Flutter lo detecta solo; no hay que configurar nada.

### 1.4 XAMPP (MySQL / MariaDB)

1. Descárgalo de https://www.apachefriends.org/ (versión para Windows).
2. En el instalador deja marcados al menos **MySQL** y **phpMyAdmin** (phpMyAdmin necesita también **Apache**).
3. Instálalo en `C:\xampp`, la ruta predeterminada. Si Windows muestra un aviso sobre el Control de cuentas de usuario, continúa.
4. Abre el **XAMPP Control Panel** y presiona **Start** en la fila de **MySQL**. Debe ponerse en verde.

Datos de MySQL en XAMPP:

- Puerto: **3306**.
- Usuario: **root**.
- Contraseña: **vacía**.

Si cambiaste el puerto o la contraseña, usa tus valores en los pasos siguientes.

### 1.5 Python

1. Descárgalo de https://www.python.org/downloads/ (3.10 o superior).
2. En la primera pantalla del instalador marca **«Add python.exe to PATH»** y luego **Install Now**.
3. Comprueba en una terminal nueva:
   ```powershell
   python --version
   ```

### 1.6 Flutter SDK

1. Entra a https://docs.flutter.dev/ y descarga el SDK de Flutter para **Windows**, canal **stable**, en archivo ZIP.
2. Descomprímelo en `C:\src`, de modo que quede `C:\src\flutter`. **No** lo pongas en `C:\Program Files` ni en rutas con espacios.
3. Agrega Flutter al PATH:
   1. En Inicio, busca **«Editar las variables de entorno de esta cuenta»**.
   2. Selecciona **Path → Editar → Nuevo** y escribe `C:\src\flutter\bin`.
   3. Acepta todas las ventanas.
4. Abre una terminal nueva y comprueba:
   ```powershell
   flutter --version
   ```
   Debe mostrar **Dart 3.13.4** o superior.

### 1.7 Android Studio, SDK y emulador

Solo es necesario para ejecutar la app en Android. Para Chrome puedes saltarte esta sección.

1. Descárgalo de https://developer.android.com/studio e instálalo.
2. Ábrelo y sigue el asistente con la opción **Standard**. Instala el SDK de Android, el emulador y Platform-Tools.
3. En la pantalla de bienvenida: **More Actions → SDK Manager → SDK Tools**. Marca:
   - **Android SDK Build-Tools**
   - **Android SDK Command-line Tools (latest)**
   - **Android Emulator**
   - **Android SDK Platform-Tools**

   Presiona **Apply**.
4. **NDK:** el proyecto lo necesita para compilar en Android. Si al ejecutar la app aparece el error *«Android sdkmanager did not install NDK …»*, vuelve a **SDK Tools**, marca **Show Package Details**, despliega **NDK (Side by side)** e instala la versión exacta que pide el mensaje (con Flutter 3.47.5 fue la **28.2.13676358**).
5. **Virtualización:** el emulador la necesita.
   - En el Administrador de tareas → **Rendimiento → CPU** debe decir **«Virtualización: Habilitado»**. Si no, actívala en la BIOS (Intel VT-x o AMD-V).
   - En **«Activar o desactivar las características de Windows»**, marca **Plataforma del hipervisor de Windows** y reinicia.
6. **Crear el emulador:** **More Actions → Virtual Device Manager → Create Virtual Device**.
   1. Elige un teléfono **Pixel**.
   2. Elige una imagen de sistema **x86_64 con Google Play** de una versión reciente (se probó con API 37).
   3. En **Additional settings → Camera → Back** elige **Webcam0**, para usar la webcam de la computadora como cámara del teléfono.
   4. Presiona **Finish**.
7. Acepta las licencias de Android desde una terminal:
   ```powershell
   flutter doctor --android-licenses
   ```
   Responde `y` a todas.

### 1.8 Verificar con `flutter doctor`

En una terminal nueva:

```powershell
flutter doctor
```

Deben salir con **✓**: Flutter, Windows Version, Android toolchain (si instalaste Android Studio), Chrome y Network resources.

La línea **Visual Studio** puede salir con **✗**: no se necesita para este proyecto (ver 1.2).

---

## Parte 2. Descargar el proyecto

Elige una carpeta sin espacios, por ejemplo `C:\proyectos`.

**Opción A: con Git**

```powershell
cd C:\proyectos
git clone https://github.com/Emiliano-Alamos/Sistema-Multiplataforma-Blog.git
```

**Opción B: en ZIP**

En GitHub, **Code → Download ZIP**, y descomprímelo en `C:\proyectos`. La carpeta se llamará `Sistema-Multiplataforma-Blog-main`.

Después abre la carpeta del proyecto en VS Code con **Archivo → Abrir carpeta**. En adelante, la carpeta principal del repositorio se llama **raíz del proyecto**.

Orden de trabajo: **base de datos → API → app**.

---

## Parte 3. Crear la base de datos

El script `database/base_de_datos.sql` crea la base **`bd_aplicacion_movil`** con tres tablas: `usuario`, `blog` y `comentarios`. No incluye publicaciones de ejemplo.

### Opción principal: shell de MySQL

1. En el **XAMPP Control Panel**, comprueba que **MySQL** esté encendido y presiona el botón **Shell** (columna derecha). Se abre una consola.
2. Conéctate a MySQL:
   ```
   mysql -u root -p
   ```
   Cuando pida la contraseña, presiona **Enter** (en XAMPP está vacía). Si tu MySQL usa otro puerto, agrégalo con `-P`, por ejemplo `mysql -u root -p -P 3309`.
3. Ejecuta el script. Usa la ruta completa de tu proyecto, con `/` en lugar de `\`:
   ```sql
   SOURCE C:/proyectos/Sistema-Multiplataforma-Blog/database/base_de_datos.sql;
   ```
4. Comprueba que se creó:
   ```sql
   SHOW DATABASES;
   USE bd_aplicacion_movil;
   SHOW TABLES;
   DESCRIBE usuario;
   DESCRIBE blog;
   DESCRIBE comentarios;
   ```
   `SHOW TABLES` debe listar `blog`, `comentarios` y `usuario`.
5. Deja esta consola abierta: se usa otra vez en la Parte 6.

> En **PowerShell** no funciona `mysql ... < archivo.sql`, porque PowerShell no acepta el símbolo `<`. Por eso se usa `SOURCE` dentro del shell de MySQL.

### Alternativa: phpMyAdmin

1. En el XAMPP Control Panel enciende **Apache** y **MySQL**.
2. Abre http://localhost/phpmyadmin.
3. Pestaña **Importar → Seleccionar archivo** → `database/base_de_datos.sql` → **Importar**.

### Notas

- El script usa `CREATE ... IF NOT EXISTS`: si la base ya existe, no borra sus registros, pero tampoco actualiza la estructura de tablas antiguas.
- El nombre de la base del script y el valor `DB_NAME` del archivo `.env` (Parte 4) deben coincidir.

---

## Parte 4. API con FastAPI

### 4.1 Cómo se construyó

Esta sección explica cómo se creó la API. **No es necesario repetirlo**: el código ya está en `backend_API/`. Para ejecutarla, ve a 4.2.

1. Se creó la carpeta `backend_API` con un entorno virtual de Python:
   ```powershell
   mkdir backend_API
   cd backend_API
   python -m venv venv
   venv\Scripts\activate
   ```
2. Se instalaron las librerías. Las versiones exactas quedaron fijadas en `requirements.txt`:
   ```powershell
   pip install fastapi "uvicorn[standard]" SQLAlchemy PyMySQL cryptography python-dotenv python-multipart "pwdlib[argon2]" PyJWT
   ```
3. Se escribió un archivo por responsabilidad:

   | Archivo          | Responsabilidad                                                                 |
   | ---------------- | ------------------------------------------------------------------------------- |
   | `database.py`    | Conexión a MySQL con SQLAlchemy; lee los datos del archivo `.env`.              |
   | `models.py`      | Clases ORM de las tablas `usuario`, `blog` y `comentarios`.                     |
   | `schemas.py`     | Esquemas Pydantic que validan lo que entra y sale de la API.                    |
   | `seguridad.py`   | Creación y verificación de tokens JWT, sesión y control de acceso por rol.      |
   | `main.py`        | Endpoints: login, usuarios, publicaciones, imágenes y comentarios.              |
   | `tests/test_api.py` | 59 pruebas automatizadas con `pytest`.                                       |

### 4.2 Instalar y encender la API (terminal 1)

En VS Code abre una terminal (**Terminal → Nueva terminal**). Desde la raíz del proyecto:

```powershell
cd backend_API
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

Al activar el entorno, el inicio de la línea muestra `(venv)`. Si PowerShell dice que la ejecución de scripts está deshabilitada, consulta [Problemas comunes](#problemas-comunes).

**Archivo de configuración `.env`.** Cópialo de la plantilla:

```powershell
Copy-Item .env.example .env
```

Genera la clave de las sesiones y copia el resultado:

```powershell
python -c "import secrets; print(secrets.token_hex(32))"
```

Abre `backend_API/.env` en VS Code y revisa estos valores:

| Variable       | Valor con XAMPP sin cambios        | Qué es                                                     |
| -------------- | ---------------------------------- | ---------------------------------------------------------- |
| `DB_HOST`      | `127.0.0.1`                        | Servidor de MySQL.                                          |
| `DB_PORT`      | `3306`                             | Puerto de MySQL. Cámbialo si el tuyo usa otro.              |
| `DB_USER`      | `root`                             | Usuario de MySQL.                                           |
| `DB_PASSWORD`  | *(vacío)*                          | Contraseña de MySQL.                                        |
| `DB_NAME`      | `bd_aplicacion_movil`              | Base creada en la Parte 3.                                  |
| `JWT_SECRET`   | *(la clave que generaste)*         | Firma los tokens. Mínimo 32 caracteres; **sin ella la API no arranca**. |

Enciende la API:

```powershell
uvicorn main:app --reload --port 8000
```

Comprueba en el navegador:

- http://127.0.0.1:8000 debe responder `{"mensaje": "API funcionando correctamente"}`.
- http://127.0.0.1:8000/docs muestra la documentación interactiva de todos los endpoints.

**Deja esta terminal abierta** mientras uses la app.

Las imágenes de las publicaciones se guardan en `backend_API/uploads/`. La carpeta se crea sola al encender la API y no se sube a GitHub (está en `.gitignore`).

> El archivo `.env` contiene contraseñas: **nunca lo subas a GitHub ni lo incluyas en archivos ZIP que compartas**. Está en `.gitignore`, pero eso no lo excluye de un ZIP creado a mano. Comparte únicamente `.env.example`.

---

## Parte 5. Aplicación en Flutter

### 5.1 Cómo se construyó

Esta sección explica cómo se creó la app. **No es necesario repetirlo**: el código ya está en `flutter_application_3/`. Para ejecutarla, ve a 5.2.

1. Se creó el proyecto con las plataformas Android, iOS y web:
   ```powershell
   flutter create --project-name flutter_application_uteq --org com.example --platforms android,ios,web flutter_application_3
   ```
2. Se agregaron las dependencias (quedan en `pubspec.yaml`):
   ```powershell
   cd flutter_application_3
   flutter pub add http image_picker
   ```
3. Se organizó `lib/` por capas: `models/`, `services/`, `screens/`, `widgets/`, `theme/`, `utils/` y `config/` (ver [Estructura del repositorio](#estructura-del-repositorio)).
4. La dirección de la API quedó en un solo archivo, `lib/config/api_config.dart`. Se elige sola según dónde corre la app:
   - Chrome: `http://127.0.0.1:8000`.
   - Emulador de Android: `http://10.0.2.2:8000` (dentro del emulador, `10.0.2.2` es la computadora).
   - Otra dirección: se indica al ejecutar con `--dart-define=API_URL=...`.
5. Se configuraron los permisos:
   - **Android** (`android/app/src/main/AndroidManifest.xml`): permiso de Internet y `usesCleartextTraffic`, porque la API local usa `http://`.
   - **iOS** (`ios/Runner/Info.plist`): textos de permiso para la cámara y la galería.

### 5.2 Preparar y ejecutar la app (terminal 2)

Con la API encendida en la terminal 1, abre **otra** terminal en VS Code. Desde la raíz del proyecto:

```powershell
cd flutter_application_3
flutter pub get
```

Después elige dónde ejecutarla:

| Dónde                 | Comando                                     | Dirección de la API que usa la app |
| --------------------- | ------------------------------------------- | ---------------------------------- |
| Chrome                | `flutter run -d chrome`                     | `http://127.0.0.1:8000`            |
| Emulador de Android   | `flutter run -d emulator-5554`              | `http://10.0.2.2:8000`             |

**Chrome:** se abre una ventana con la app. La primera compilación tarda un poco.

**Emulador de Android:**

1. Enciende el emulador desde **Virtual Device Manager** (botón ▶) y espera a que aparezca la pantalla de inicio de Android.
2. Comprueba que Flutter lo vea:
   ```powershell
   flutter devices
   ```
   Usa el nombre que aparezca; normalmente `emulator-5554`.
3. Ejecuta `flutter run -d emulator-5554`. La primera compilación de Android puede tardar de 5 a 15 minutos.

> En Chrome de escritorio, el botón **Tomar foto** abre el explorador de archivos. Para usar la cámara, ejecuta la app en Android.

**Celular físico (opcional):** la computadora y el celular deben estar en la misma red Wi-Fi, y el celular debe tener activada la **depuración USB** (Opciones de desarrollador).

1. Enciende la API para toda la red:
   ```powershell
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```
   Si Windows pregunta por el firewall, permite el acceso en redes privadas.
2. Busca la IP de la computadora con `ipconfig` (por ejemplo, `192.168.1.50`).
3. Conecta el celular por USB y ejecuta la app indicando esa dirección:
   ```powershell
   flutter run --dart-define=API_URL=http://192.168.1.50:8000
   ```

Para detener la app, presiona `q` en la terminal 2. Para detener la API, `Ctrl` + `C` en la terminal 1.

---

## Parte 6. Primer administrador

El registro desde la app siempre crea un **Usuario general**. Para tener el primer administrador:

1. Abre la app y regístrate con **Registrarse**.
2. En el shell de MySQL (Parte 3), ejecuta con tu correo:
   ```sql
   USE bd_aplicacion_movil;
   UPDATE usuario SET tip_usu = 1 WHERE mail = 'tu_correo@ejemplo.com';
   ```
3. Cierra sesión en la app y vuelve a entrar.

Desde ese momento, ese administrador puede crear otros usuarios y administradores desde la app.

---

## Parte 7. Probar la aplicación

### 7.1 Pruebas manuales

Con la API y la app encendidas. Después de cada prueba puedes confirmar en el shell de MySQL que el dato llegó a la base.

| #  | Prueba                       | Pasos en la app                                                              | Comprobación en MySQL                                                                 |
| -- | ---------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| 1  | Registro                     | **Registrarse**, llenar el formulario y enviarlo.                            | `SELECT id_usr, nom_usr, mail, LEFT(pass, 30), tip_usu FROM usuario;` → `tip_usu = 2` y `pass` empieza con `$argon2id$`. |
| 2  | Inicio de sesión             | Entrar con el correo y la contraseña registrados.                            | Debe abrir el blog con «Bienvenido, *nombre*».                                        |
| 3  | Contraseña incorrecta        | Entrar con una contraseña equivocada.                                        | Debe mostrar «Correo o contraseña incorrectos».                                       |
| 4  | Crear publicación con cámara | Como administrador: menú lateral → **Agregar blog → Tomar foto**, llenar y guardar. | `SELECT id_blog, titulo, tags, img, usr_id FROM blog;` → aparece con `img = /uploads/...`. |
| 5  | Crear publicación con galería | **Elegir foto** y guardar.                                                  | Igual que la prueba 4.                                                                |
| 6  | Propias y de otros           | Como administrador, alternar **Todas / Mis publicaciones**.                  | «Mis publicaciones» muestra solo las del administrador que inició sesión.             |
| 7  | Comentar                     | Abrir una publicación → **Agregar comentario**.                              | `SELECT id_com, comentario, usr_id, blog_id FROM comentarios;` → aparece el comentario. |
| 8  | Buscar y filtrar             | Escribir en **Buscar** y elegir una **Etiqueta**.                            | Solo aparecen las publicaciones que coinciden.                                        |
| 9  | Editar, eliminar y moderar   | Como administrador: menú lateral → **Editar publicaciones**.                 | Los cambios se reflejan en las tablas `blog` y `comentarios`.                         |
| 10 | Permisos                     | Entrar como usuario general.                                                 | No ve las opciones de administración.                                                 |

Para que la cámara del emulador funcione en la prueba 4, configura **Camera → Back = Webcam0** (Parte 1.7). Para la prueba 5, arrastra antes una imagen desde Windows a la pantalla del emulador: se guarda en su carpeta de Descargas.

### 7.2 Pruebas automatizadas

Comprueban la API contra una base MySQL real. En la terminal de la API (con `(venv)` activo y MySQL encendido; si la API está corriendo, detenla con `Ctrl` + `C` o abre otra terminal):

```powershell
pip install -r requirements-pruebas.txt
python -m pytest tests -q
```

Resultado esperado: **`59 passed`**.

Cómo funcionan:

- Usan una base **aparte**, `bd_blog_pruebas`, que se borra y se vuelve a crear en cada ejecución.
- **No tocan** la base configurada en `DB_NAME`.
- Del `.env` solo toman el servidor (`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`). El usuario de MySQL debe poder crear bases de datos (`root` de XAMPP puede).

---

## Uso

- **Usuario general:**
  - Inicia sesión y ve el blog. Cada publicación muestra a su autor («Por …»).
  - Busca por título, descripción o etiqueta, y puede filtrar por etiquetas.
  - Abre una publicación y comenta.
  - Cierra sesión desde el menú de su avatar.
- **Administrador:**
  - Usa el menú lateral para moverse entre usuarios, publicaciones y su perfil.
  - En el blog, usa el filtro **Todas / Mis publicaciones** para ver las publicaciones de todos los administradores o solo las que él creó.
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
| GET    | `/`                                 | Público (comprueba que la API está encendida)                        |
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
| GET    | `/comentarios`                      | Con sesión                                                           |
| POST   | `/comentarios`                      | Con sesión                                                           |
| GET    | `/blog/{id}/comentarios/moderacion` | Administrador                                                        |
| DELETE | `/comentarios/{id}`                 | Administrador                                                        |

La lista completa, con ejemplos, está en http://127.0.0.1:8000/docs.

## Librerías utilizadas

- **API** (`backend_API/requirements.txt`):
  - `fastapi` y `uvicorn`: servidor de la API.
  - `SQLAlchemy` y `PyMySQL`: acceso a MySQL.
  - `cryptography`: la usa PyMySQL para el método de autenticación de MySQL 8.
  - `pwdlib[argon2]`: hash de contraseñas.
  - `PyJWT`: tokens de sesión.
  - `python-dotenv`: lectura del `.env`.
  - `python-multipart`: subida de imágenes.
- **Pruebas** (`backend_API/requirements-pruebas.txt`): `pytest` y `httpx`.
- **App** (`flutter_application_3/pubspec.yaml`):
  - `http`: llamadas a la API.
  - `image_picker`: imagen desde la cámara o la galería.
  - `cupertino_icons`: íconos.

## Problemas comunes

| Problema | Solución |
| -------- | -------- |
| `python` abre la Microsoft Store o no se reconoce | Reinstala Python marcando **«Add python.exe to PATH»**. Si aún abre la Store, en Inicio busca **«Alias de ejecución de aplicaciones»** y desactiva los de `python.exe` y `python3.exe`. |
| `flutter` no se reconoce como comando | Falta `C:\src\flutter\bin` en el PATH (Parte 1.6). Después de agregarlo, abre una terminal nueva. |
| Al activar el entorno: *«la ejecución de scripts está deshabilitada en este sistema»* | Ejecuta una sola vez `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, responde `S` y vuelve a activar el entorno. |
| MySQL no enciende en XAMPP (el puerto 3306 está ocupado) | Otro programa usa ese puerto. En el XAMPP Control Panel, **MySQL → Config → my.ini**, cambia `port=3306` por otro (por ejemplo, `3309`) en las secciones `[client]` y `[mysqld]`, guarda y enciende MySQL. Usa ese puerto en `mysql -P` y en `DB_PORT`. |
| La API no arranca y menciona `JWT_SECRET` | Falta la clave en `.env` o tiene menos de 32 caracteres. Genérala con el comando de la Parte 4.2. |
| La API no se conecta a MySQL | Revisa que MySQL esté encendido en XAMPP y que `DB_PORT`, `DB_USER`, `DB_PASSWORD` y `DB_NAME` del `.env` sean correctos. |
| Al compilar para Android: *«Android sdkmanager did not install NDK …»* | Instala el NDK a mano con la versión exacta que pide el mensaje (Parte 1.7, paso 4) y vuelve a ejecutar `flutter run`. |
| `flutter devices` dice que el emulador está *offline* | Espera a que Android termine de arrancar y vuelve a ejecutar `flutter devices`. Si sigue igual, reinicia el emulador desde Virtual Device Manager con **Cold Boot Now**. |
| En el emulador, el inicio de sesión da error de conexión | Revisa que la API siga encendida en la terminal 1, en el puerto 8000. |
| Las publicaciones salen sin imagen | Las imágenes están en `backend_API/uploads/` de la computadora donde se subieron. En una copia nueva del repositorio esa carpeta empieza vacía: copia ahí las imágenes o crea publicaciones nuevas. |
| En Chrome, al recargar la página (F5) se cierra la sesión | Es lo esperado: el token se guarda en memoria. Vuelve a iniciar sesión. |
| `flutter doctor` marca **Visual Studio** con ✗ | No afecta: solo se necesita para apps de escritorio de Windows (ver Parte 1.2). |
