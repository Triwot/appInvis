# InvitaPro 🎉

Aplicación móvil para Android desarrollada en **Flutter** que automatiza la generación masiva de invitaciones personalizadas (videos `.mp4` e imágenes `.jpg/.png`) para eventos, fiestas y discotecas.

## 🚀 Problema que resuelve
Los organizadores de eventos suelen recibir listas de cientos de invitados por WhatsApp y editan cada flyer manualmente uno por uno. **InvitaPro** permite cargar una sola plantilla, ubicar visualmente dónde irá el nombre, pegar la lista cruda de WhatsApp y renderizar todas las invitaciones en lote manteniendo el audio original del video.

## 🛠️ Tecnologías usadas
* **Framework:** Flutter (Dart)
* **Procesamiento de video:** `ffmpeg_kit_flutter_new` (overlay de PNG transparente + copia de audio `-c:a copy` + validación con FFprobe)
* **Renderizado de texto e imágenes:** `dart:ui` (`Canvas`, `PictureRecorder`)
* **Reproducción y selección de archivos:** `video_player`, `file_picker`
* **Nativo Android (Kotlin):**
  * `MediaStore` para guardar videos en `Movies/InvitaPro/` e imágenes en `Pictures/InvitaPro/`
  * `BatchForegroundService.kt` (Foreground Service con `dataSync` y `WakeLock` parcial) para procesar lotes en segundo plano con notificación de progreso
* **Utilidades:** `wakelock_plus`, `permission_handler`, `path_provider`, `path`

## 📱 Guía de menú (Pantallas)

1. **Plantilla (Editor visual WYSIWYG):**
   * Selecciona un video o imagen desde la galería.
   * Arrastra el nombre de prueba hasta el espacio deseado (incluye imán al centro horizontal).
   * Personaliza tamaño, tipografía, color de relleno, color y grosor del contorno.
   * Autoajuste automático si un nombre supera el 94% del ancho de la plantilla.

2. **Lista (Limpiador de WhatsApp):**
   * Pega la lista cruda copiada directo de WhatsApp.
   * **Borrar todo:** limpia el cuadro de pegado superior.
   * **Organizar invitados:** limpia numeraciones (`1.`, `2.`, `1️⃣`), viñetas, emojis, formatos de WhatsApp y líneas vacías, y pasa los nombres a la lista editable inferior.
   * **Limpiar lista:** vacía todos los invitados organizados (con confirmación).

3. **Generar (Renderizado por lotes):**
   * Muestra el resumen de la plantilla y cantidad de invitados.
   * Inicia el procesamiento secuencial en segundo plano con notificación de progreso en tiempo real.
   * Guarda automáticamente cada lote en `Movies/InvitaPro/Lote_AAAAMMDD_HHMM` (o `Pictures/InvitaPro/...` si son imágenes).

## 💻 Instalación y compilación (Android)

### Requisitos previos
* Flutter SDK (3.50+)
* Android SDK (API 37) y NDK (`28.2.13676358`)
* Modo desarrollador activado en Windows (`start ms-settings:developers`)

### Pasos

# 1. Clonar el repositorio
```bash
git clone [https://github.com/Triwot/appInvis.git]
cd appInvis
```
# 2. Instalar dependencias
```bash
flutter pub get
```
# 3. Ejecutar en un dispositivo Android conectado por USB
```bash
flutter run
```
# 4. Compilar APK de producción
```bash
flutter build apk --release
```
El APK generado quedará en: build/app/outputs/flutter-apk/app-release.apk.
