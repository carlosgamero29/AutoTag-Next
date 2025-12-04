# AutoTag-Next

**AutoTag-Next** es un plugin para Adobe Lightroom Classic que utiliza inteligencia artificial (Google Gemini o Ollama local) para generar automáticamente metadatos de tus fotografías, incluyendo títulos, descripciones y palabras clave.

## 🌟 Características

- **Análisis con IA**: Utiliza modelos de Google Gemini (2.5 Flash, 2.5 Pro, 2.0 Flash) u Ollama local
- **Generación automática de metadatos**:
  - Títulos descriptivos
  - Descripciones detalladas
  - Palabras clave relevantes
- **Sistema de Presets de Datos**:
  - **Municipalidad**: Instituciones, Áreas, Actividades, Lugares
  - **Bodas**: Familia, Momentos, Tipo de Foto, Ubicación
  - **Prensa**: Sección, Alcance, Cobertura, Ciudad
  - **Personal**: Grupo, Contexto, Evento, Lugar
- **Selección Múltiple**: Selecciona múltiples valores para cada categoría (ej. varias instituciones o personas)
- **Interfaz Mejorada**:
  - Vista previa de imagen integrada
  - Navegación entre fotos (Anterior/Siguiente)
  - Layout optimizado lado a lado
- **Procesamiento por lotes**: Analiza múltiples fotos a la vez con barra de progreso
- **Personalización Total**: Edita nombres de categorías y listas de datos

## 📋 Requisitos

- Adobe Lightroom Classic (versión 6 o superior)
- API Key de Google Gemini (gratuita) o servidor Ollama local
- Conexión a Internet (para Gemini)

## 🚀 Instalación

1. Descarga el plugin completo (carpeta `AutoTag-Next.lrplugin`)
2. En Lightroom, ve a **Archivo > Administrador de complementos**
3. Haz clic en **Agregar** y selecciona la carpeta del plugin
4. Configura tu API Key de Gemini en la sección de configuración del plugin

## 🔑 Obtener API Key de Gemini

1. Visita [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Inicia sesión con tu cuenta de Google
3. Haz clic en "Create API Key"
4. Copia la clave y pégala en la configuración del plugin

> **🔒 Nota de Seguridad**: Tu API Key se guarda localmente en las preferencias de Lightroom, **no en archivos del plugin**. Nunca compartas tu API Key públicamente ni la incluyas en el código fuente.

## 📖 Uso

### Configuración Inicial (Presets)

1. Ve a **Archivo > Administrador de complementos > AutoTag Next**
2. En la sección **"Configuración de Metadatos y Contexto"**, selecciona tu **Preset de Datos** (Municipalidad, Bodas, Prensa, Personal)
3. (Opcional) Personaliza los nombres de las categorías si lo deseas
4. Cierra el administrador

### Análisis Individual

1. Selecciona una foto en Lightroom
2. Ve a **Archivo > Extras de módulo > AutoTag Next** (o Biblioteca > Extras de módulo)
3. Configura el contexto usando los dropdowns (puedes seleccionar múltiples valores y agregar nuevos con el botón `+`)
4. Haz clic en **🔍 Analizar Foto Actual**
5. Revisa los metadatos generados en el panel derecho
6. Haz clic en **💾 Guardar Actual** para aplicarlos a la foto

### Análisis por Lotes

1. Selecciona múltiples fotos en Lightroom
2. Abre el plugin
3. Configura el contexto compartido (se aplicará a todas las fotos)
4. Haz clic en **⚡ Analizar Todo el Lote**
5. Espera a que termine el procesamiento (verás una barra de progreso)
6. Los metadatos se guardarán automáticamente en cada foto

## ⚙️ Configuración

### Modelos de IA disponibles

- **gemini-2.5-flash** (recomendado): Rápido y eficiente
- **gemini-2.5-pro**: Mayor precisión, más lento
- **gemini-2.0-flash**: Versión experimental
- **Ollama local**: Usa modelos locales (llava, bakllava, etc.)

### Presets de Datos

El plugin incluye 4 presets predefinidos, cada uno con sus propias listas de datos:

1. **Municipalidad** (Default): Para gestión gubernamental
2. **Bodas**: Para fotógrafos de eventos sociales
3. **Prensa**: Para fotoperiodismo y medios
4. **Personal**: Para uso familiar y hobbies

Cada preset guarda sus propias listas de datos en un archivo JSON local.

## 🗂️ Estructura de Palabras Clave

El plugin organiza las palabras clave de forma jerárquica:

```
AutoTag Info
├── Institución
│   └── [Nombre de la institución]
├── Área
│   └── [Nombre del área]
├── Actividad
│   └── [Nombre de la actividad]
└── Lugar
    └── [Nombre del lugar]
```

Además, agrega las palabras clave generadas por la IA directamente en la raíz.

## 🛠️ Solución de Problemas

### El plugin no aparece en el menú
- Verifica que la carpeta termine en `.lrplugin`
- Reinicia Lightroom
- Revisa el Administrador de complementos

### Error de API Key inválida
- Verifica que copiaste la clave completa
- Asegúrate de que la API de Gemini esté habilitada en tu cuenta de Google
- Revisa que no haya espacios al inicio o final de la clave

### No se guardan los metadatos
- Verifica que la foto no esté en modo de solo lectura
- Asegúrate de hacer clic en "Guardar Actual" después del análisis
- Revisa que Lightroom tenga permisos de escritura en el catálogo

### Errores de conexión con Ollama
- Verifica que el servidor Ollama esté corriendo (`ollama serve`)
- Comprueba que la URL sea correcta (por defecto: `http://localhost:11434`)
- Asegúrate de tener el modelo descargado (`ollama pull llava`)

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Si encuentras un bug o tienes una sugerencia:

1. Abre un **Issue** describiendo el problema o la mejora
2. Si quieres contribuir código, haz un **Fork** y envía un **Pull Request**

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Consulta el archivo `LICENSE` para más detalles.

## 👨‍💻 Autor

Desarrollado por Carlos Gamero

## 🙏 Agradecimientos

- Google Gemini por la API de IA
- Ollama por el soporte de modelos locales
- La comunidad de Adobe Lightroom

---

**¿Necesitas ayuda?** Abre un issue en GitHub o contacta al autor.
