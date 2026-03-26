/**
 * Configuración del Cliente
 * URLs y constantes de la aplicación
 */

const CONFIG = {
    // API del servidor
    API_BASE_URL: 'http://localhost:8000',
    
    // URLs de los endpoints
    ENDPOINTS: {
        chat: '/api/chat',
        models: '/api/models',
        health: '/api/health'
    },
    
    // Timeout para requests
    REQUEST_TIMEOUT: 60000,
    
    // Mensajes
    MESSAGES: {
        CONNECTING: 'Conectando al servidor...',
        CONNECTED: 'Conectado ✓',
        DISCONNECTED: '⚠️ No se puede conectar al servidor',
        WELCOME: '¡Hola! Bienvenido a CORTEX. ¿En qué puedo ayudarte?',
        COMPLETED: '✓ Listo',
        ERROR: '✗ Error',
        LOADING: 'Procesando...'
    }
};
