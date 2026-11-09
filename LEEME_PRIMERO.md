# Blog UTEQ – Flutter + FastAPI (proyecto combinado)

Este zip trae el trabajo de los dos integrantes ya integrado:
- Pantallas de usuario (login, registro, blog, detalle) y el tema central: Ricardo.
- Panel de administrador (gestión de usuarios, agregar blog, perfil, menú lateral): compañero.

No incluye entornos ni archivos generados (venv, build, .dart_tool). Cada quien los crea en su computadora.

## 1. Base de datos
1. Enciende MySQL (XAMPP).
2. Crea una base vacía, por ejemplo `bd_aplicacion_movil`.
3. Abre `backend_API/.env` y ajusta a TU computadora: DB_PORT (3306 por defecto en XAMPP), DB_PASSWORD y DB_NAME.

## 2. Backend (terminal 1)
```powershell
cd backend_API
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
Al arrancar crea las tablas solas. Prueba http://127.0.0.1:8000

## 3. App Flutter (terminal 2)
```powershell
cd flutter_application_3
flutter pub get
flutter run -d chrome
```
Requiere Dart 3.13.4 o superior (revisa con `flutter --version`).

## 4. Primer usuario administrador
Regístrate desde la app (se crea como usuario general) y en MySQL ejecuta:
```sql
UPDATE usuario SET tip_usu = 1 WHERE mail = 'tu_correo@ejemplo.com';
```
Cierra sesión y vuelve a entrar.

## Al compartir el proyecto otra vez
Comprime SIN: `backend_API/venv`, `backend_API/.env`, `flutter_application_3/build`, `flutter_application_3/.dart_tool`.
