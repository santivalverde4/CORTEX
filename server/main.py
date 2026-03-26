"""
CORTEX - Backend Server
API REST que comunica con Ollama
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
from typing import Dict
from routes.chat import ChatRoutes
from services.ollama import OllamaService

app = Flask(__name__)
CORS(app)  # Habilitar CORS para requests desde el cliente

# Inicializar rutas
chat_routes = ChatRoutes()


# ============ RUTAS DE LA API ============

@app.route('/api/health', methods=['GET'])
def health():
    """Verifica la salud del servidor y la conexión con Ollama"""
    result = chat_routes.check_health()
    response_code = 200 if result['success'] else 500
    return jsonify(result), response_code


@app.route('/api/models', methods=['GET'])
def get_models():
    """Obtiene la lista de modelos disponibles"""
    result = chat_routes.get_models()
    response_code = 200 if result['success'] else 500
    return jsonify(result), response_code


@app.route('/api/chat', methods=['POST'])
def chat():
    """Procesa un mensaje de chat"""
    data = request.get_json()
    
    # Validar que vinieron los datos
    if not data:
        return jsonify({
            'success': False,
            'error': 'No se recibieron datos'
        }), 400
    
    result = chat_routes.handle_chat_request(data)
    response_code = 200 if result['success'] else 400
    return jsonify(result), response_code


# ============ MANEJO DE ERRORES ============

@app.errorhandler(404)
def not_found(error):
    return jsonify({
        'success': False,
        'error': 'Endpoint no encontrado'
    }), 404


@app.errorhandler(500)
def server_error(error):
    return jsonify({
        'success': False,
        'error': 'Error interno del servidor'
    }), 500


# ============ PUNTO DE ENTRADA ============

if __name__ == '__main__':
    print("🚀 CORTEX Server iniciando...")
    print("📡 API disponible en http://0.0.0.0:8000")
    print("🔗 CORS habilitado para requests del cliente")
    app.run(
        host='0.0.0.0',
        port=8000,
        debug=True
    )
