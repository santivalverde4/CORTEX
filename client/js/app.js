/**
 * Aplicación Cliente
 * Lógica simple de la interfaz
 */

class ChatApp {
    constructor() {
        // Referencias al DOM
        this.messageInput = document.getElementById('message-input');
        this.sendBtn = document.getElementById('send-btn');
        this.messagesContainer = document.getElementById('messages');
        this.typingIndicator = document.getElementById('typing-indicator');
        this.statusDiv = document.getElementById('status');
        this.modelSelect = document.getElementById('model-select');

        this.isLoading = false;
        this.currentModel = 'llama2';

        this._initializeEventListeners();
    }

    /**
     * Inicializa los listeners de eventos
     */
    _initializeEventListeners() {
        this.sendBtn.addEventListener('click', () => this.sendMessage());
        this.messageInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && !this.isLoading) {
                this.sendMessage();
            }
        });
        this.modelSelect.addEventListener('change', (e) => {
            this.currentModel = e.target.value;
            this.updateStatus(`Modelo: ${e.target.options[e.target.selectedIndex].text}`, 'success');
        });
    }

    /**
     * Inicializa la aplicación
     */
    async initialize() {
        this.updateStatus(CONFIG.MESSAGES.CONNECTING);

        const isConnected = await apiClient.checkHealth();
        if (isConnected) {
            this.updateStatus(CONFIG.MESSAGES.CONNECTED, 'success', 3000);
            this.showWelcomeMessage();
        } else {
            this.updateStatus(CONFIG.MESSAGES.DISCONNECTED, 'error');
        }
    }

    /**
     * Envía un mensaje
     */
    async sendMessage() {
        const message = this.messageInput.value.trim();
        if (!message) return;

        // Mostrar mensaje del usuario
        this.displayMessage(message, 'user');
        this.messageInput.value = '';
        this.messageInput.focus();

        // Actualizar estado
        this.isLoading = true;
        this.sendBtn.disabled = true;
        this.typingIndicator.style.display = 'flex';

        try {
            // Llamar al servidor
            const response = await apiClient.sendMessage(message, this.currentModel);
            this.displayMessage(response, 'assistant');
            this.updateStatus(CONFIG.MESSAGES.COMPLETED, 'success', 3000);
        } catch (error) {
            this.displayMessage(`Error: ${error.message}`, 'error');
            this.updateStatus(CONFIG.MESSAGES.ERROR, 'error');
        } finally {
            this.isLoading = false;
            this.sendBtn.disabled = false;
            this.typingIndicator.style.display = 'none';
        }
    }

    /**
     * Muestra un mensaje en el chat
     */
    displayMessage(content, role) {
        const messageEl = document.createElement('div');
        messageEl.className = `message ${role}`;

        const contentEl = document.createElement('div');
        contentEl.className = 'message-content';
        contentEl.textContent = content;

        messageEl.appendChild(contentEl);
        this.messagesContainer.appendChild(messageEl);
        this.messagesContainer.scrollTop = this.messagesContainer.scrollHeight;
    }

    /**
     * Muestra mensaje de bienvenida
     */
    showWelcomeMessage() {
        this.displayMessage(CONFIG.MESSAGES.WELCOME, 'assistant');
    }

    /**
     * Actualiza el estado
     */
    updateStatus(message, type = 'default', duration = 0) {
        this.statusDiv.textContent = message;
        this.statusDiv.className = `status ${type}`;

        if (duration > 0) {
            setTimeout(() => {
                this.statusDiv.textContent = '';
                this.statusDiv.className = 'status';
            }, duration);
        }
    }
}

// Inicializar cuando el DOM esté listo
document.addEventListener('DOMContentLoaded', () => {
    const app = new ChatApp();
    app.initialize();
    
    // Guardar referencia global para debugging
    window.chatApp = app;
});
