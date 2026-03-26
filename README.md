# CORTEX - Self-hosted AI Workspace

Un workspace de IA local y autoalojado con arquitectura separada:
-  **Frontend simple** (HTML/CSS/JavaScript vanilla)
-  **Backend REST** (Flask + Python)
-  **Conexión a Ollama** para LLM local

##  Características

 Chat con IA local  
 API REST completa  
 Selector de modelos  
 Interfaz moderna (tema oscuro)  
 Frontend y Backend desacoplados  
 Lógica de negocio en el servidor  
 Fácil de escalar y extender

##  Estructura

```
CORTEX/
├── client/              ← Frontend (WebUI Simple)
│   ├── index.html       ← Página web
│   ├── css/
│   │   └── style.css    ← Estilos
│   └── js/
│       ├── config.js    ← URL de la API
│       ├── api.js       ← Cliente HTTP
│       └── app.js       ← Lógica de interfaz
│
└── server/              ← Backend (API REST)
    ├── main.py          ← Punto de entrada (Flask)
    ├── requirements.txt ← Dependencias Python
    ├── config/          ← Configuración
    ├── models/          ← Estructuras de datos
    ├── routes/          ← Endpoints de API
    └── services/        ← Lógica de negocio
```

##  Requisitos

- **Ollama** instalado y ejecutándose
  - Descargar: https://ollama.ai
  - Modelo: `ollama pull llama2`

- **Python 3.8+** (para el servidor)
  - Flask y requests se instalan con `requirements.txt`

##  Instalación Rápida (4 Pasos)

### Paso 1: Iniciar Ollama
```bash
ollama serve
```
Ollama escuchará en `http://localhost:11434`

### Paso 2: Instalar dependencias del servidor
```bash
cd /home/santi/Documents/CORTEX/server
pip install -r requirements.txt
```

### Paso 3: Iniciar el servidor backend (nueva terminal)
```bash
cd /home/santi/Documents/CORTEX/server
python main.py
```
Servidor disponible en `http://localhost:8000`

### Paso 4: Servir el cliente frontend (nueva terminal)
```bash
cd /home/santi/Documents/CORTEX/client
python3 -m http.server 8000
```

**Abrir en navegador:** `http://localhost:8000`

##  API REST

### Endpoints

| Método | URL | Descripción |
|--------|-----|-------------|
| `GET` | `/api/health` | Verificar estado del servidor |
| `GET` | `/api/models` | Listar modelos disponibles |
| `POST` | `/api/chat` | Enviar mensaje de chat |

### Ejemplo: Enviar un mensaje
```bash
curl -X POST http://localhost:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hola", "model": "llama2"}'
```

### Formato de Request
```json
{
    "message": "Tu pregunta aquí",
    "model": "llama2"
}
```

### Formato de Response
```json
{
    "success": true,
    "data": {
        "response": "Respuesta del modelo...",
        "model": "llama2",
        "timestamp": "2026-03-25T23:00:00"
    }
}
```

##  Configuración

### Cliente: `client/js/config.js`
```javascript
const CONFIG = {
    API_BASE_URL: 'http://localhost:8000',  // URL del servidor
    REQUEST_TIMEOUT: 60000                   // Timeout en ms
};
```

### Servidor: `server/config/config.py`
```python
OLLAMA_BASE_URL = 'http://localhost:11434'  # URL de Ollama
API_PORT = 8000                              # Puerto del server
DEFAULT_MODEL = 'llama2'                     # Modelo por defecto
```

##  Próximas Mejoras

**Frontend:**
- Historial de conversaciones
- Exportar/descargar chats
- Dark/Light mode toggle
- PWA (Progressive Web App)

**Backend:**
- RAG (Retrieval-Augmented Generation)
- Fine-tuning pipeline
- Chain-of-Thought reasoning
- Base de datos persistente
- Autenticación y sesiones
- Rate limiting y caché

##  Solución de Problemas

### "No puedo conectar al servidor"
```bash
# 1. Verifica que el servidor está corriendo
ps aux | grep "python main.py"

# 2. Instala las dependencias
pip install -r server/requirements.txt

# 3. Revisa que la URL es correcta en client/js/config.js
```

### "Ollama no responde"
```bash
# 1. Verifica que Ollama está ejecutándose
ps aux | grep ollama

# 2. Verifica que existe el modelo
ollama list

# 3. Descarga un modelo
ollama pull llama2
```

### "Puerto 8000 ya está en uso"
```bash
# Opción 1: Matar el proceso que usa el puerto
lsof -ti:8000 | xargs kill -9

# Opción 2: Cambiar el puerto en server/main.py
# Cambiar: app.run(host='0.0.0.0', port=8001)
```

##  Arquitectura

**Frontend Simple:**
- Sin modelos de datos complejos
- Sin lógica de negocio
- Solo comunica con la API del servidor
- Renderiza la interfaz de usuario

**Backend Completo:**
- Toda la lógica de negocio
- Modelos de datos y validación
- Comunicación con Ollama
- Manejo de errores centralizado


##  Licencia

MIT

##  Contribuir

Las contribuciones son bienvenidas. Por favor:
1. Fork el proyecto
2. Crea una rama (`git checkout -b feature/improvement`)
3. Commit tus cambios (`git commit -m 'Add improvement'`)
4. Push a la rama (`git push origin feature/improvement`)
5. Abre un Pull Request
