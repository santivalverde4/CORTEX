/**
 * Cliente API HTTP
 * Comunica con el servidor backend
 */

class APIClient {
    constructor(baseUrl, timeout = CONFIG.REQUEST_TIMEOUT) {
        this.baseUrl = baseUrl;
        this.timeout = timeout;
    }

    /**
     * Verifica la salud del servidor
     */
    async checkHealth() {
        try {
            const response = await this._fetch(CONFIG.ENDPOINTS.health);
            return response.data?.ollama_connected || false;
        } catch (error) {
            console.error('Error al verificar servidor:', error);
            return false;
        }
    }

    /**
     * Envía un mensaje de chat al servidor
     * @param {string} message - Mensaje del usuario
     * @param {string} model - Modelo a usar
     * @returns {Promise<string>} Respuesta del servidor
     */
    async sendMessage(message, model) {
        try {
            const response = await this._fetch(CONFIG.ENDPOINTS.chat, {
                method: 'POST',
                body: JSON.stringify({
                    message: message,
                    model: model
                })
            });

            if (response.data?.response) {
                return response.data.response;
            } else {
                throw new Error('Respuesta vacía del servidor');
            }
        } catch (error) {
            throw new Error(`Error en chat: ${error.message}`);
        }
    }

    /**
     * Obtiene la lista de modelos disponibles
     */
    async getModels() {
        try {
            const response = await this._fetch(CONFIG.ENDPOINTS.models);
            return response.data?.models || [];
        } catch (error) {
            console.error('Error al obtener modelos:', error);
            return [];
        }
    }

    /**
     * Realiza una solicitud HTTP
     * @private
     */
    async _fetch(endpoint, options = {}) {
        const url = `${this.baseUrl}${endpoint}`;
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), this.timeout);

        const defaultOptions = {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json'
            },
            signal: controller.signal
        };

        const finalOptions = { ...defaultOptions, ...options };

        try {
            const response = await fetch(url, finalOptions);
            clearTimeout(timeoutId);

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const data = await response.json();

            if (!data.success) {
                throw new Error(data.error || 'Error desconocido');
            }

            return data;
        } catch (error) {
            clearTimeout(timeoutId);
            throw error;
        }
    }
}

// Instancia global del cliente API
const apiClient = new APIClient(CONFIG.API_BASE_URL);
