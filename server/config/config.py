"""
Configuración centralizada del servidor
"""

# Ollama
OLLAMA_BASE_URL = 'http://localhost:11434'
OLLAMA_TIMEOUT = 60

# API
API_HOST = '0.0.0.0'
API_PORT = 8000
API_DEBUG = True

# Modelos
DEFAULT_MODEL = 'llama2'
AVAILABLE_MODELS = {
    'llama2': 'Llama 2',
    'mistral': 'Mistral',
    'neural-chat': 'Neural Chat'
}

# Logging
LOG_LEVEL = 'INFO'
