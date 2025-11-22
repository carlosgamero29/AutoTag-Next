# AutoTag-Next

**AutoTag-Next** es un plugin para Adobe Lightroom Classic que utiliza inteligencia artificial (Google Gemini o Ollama local) para generar automáticamente metadatos de tus fotografías, incluyendo títulos, descripciones y palabras clave.

## 🌟 Características

- **Análisis con IA**: Utiliza modelos de Google Gemini (2.5 Flash, 2.5 Pro, 2.0 Flash) u Ollama local
- **Generación automática de metadatos**:
  - Títulos descriptivos
  - Descripciones detalladas
  - Palabras clave relevantes
- **Contexto personalizable**: Agrega información institucional, área, actividad y ubicación
- **Procesamiento por lotes**: Analiza múltiples fotos a la vez
- **Palabras clave jerárquicas**: Organiza automáticamente las palabras clave en categorías

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

### Análisis Individual

1. Selecciona una foto en Lightroom
2. Ve a **Biblioteca > Complementos > AutoTag Next**
3. Configura el contexto (opcional): institución, área, actividad, ubicación
4. Haz clic en **🔍 Analizar Foto Actual**
5. Revisa los metadatos generados
6. Haz clic en **💾 Guardar Actual** para aplicarlos a la foto

### Análisis por Lotes

1. Selecciona múltiples fotos en Lightroom
2. Ve a **Biblioteca > Complementos > AutoTag Next**
3. Configura el contexto compartido (se aplicará a todas las fotos)
4. Haz clic en **📦 Analizar Lote**
5. Espera a que termine el procesamiento
6. Los metadatos se guardarán automáticamente

## ⚙️ Configuración

### Modelos de IA disponibles

- **gemini-2.5-flash** (recomendado): Rápido y eficiente
- **gemini-2.5-pro**: Mayor precisión, más lento
- **gemini-2.0-flash**: Versión experimental
- **Ollama local**: Usa modelos locales (llava, bakllava, etc.)

### Campos de contexto

- **Contexto de usuario**: Información general sobre el tipo de fotografías
- **Institución**: Organización relacionada con las fotos
- **Área**: Departamento o área específica
- **Actividad**: Tipo de evento o actividad
- **Ubicación**: Lugar donde se tomaron las fotos

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
