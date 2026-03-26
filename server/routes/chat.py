"""
Rutas para el chat (endpoints de la API)
"""

from ..models.message import Message, ChatRequest, ChatResponse
from ..services.ollama import OllamaService


class ChatRoutes:
    """Manejador de rutas del chat"""
    
    def __init__(self):
        self.ollama_service = OllamaService()
    
    def handle_chat_request(self, request_data: dict) -> dict:
        """
        Maneja una solicitud de chat
        
        Args:
            request_data: Diccionario con 'message' y 'model'
            
        Returns:
            dict: Respuesta con el mensaje generado
        """
        try:
            # Validar solicitud
            chat_request = ChatRequest(
                message=request_data.get('message', ''),
                model=request_data.get('model', '')
            )
            chat_request.validate()
            
            # Generar respuesta
            response_text = self.ollama_service.generate(
                chat_request.message,
                chat_request.model
            )
            
            # Crear respuesta
            chat_response = ChatResponse(
                response=response_text,
                model=chat_request.model
            )
            
            return {
                'success': True,
                'data': chat_response.to_dict()
            }
        
        except ValueError as e:
            return {
                'success': False,
                'error': str(e)
            }
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_models(self) -> dict:
        """
        Obtiene la lista de modelos disponibles
        
        Returns:
            dict: Lista de modelos
        """
        try:
            models = self.ollama_service.get_available_models()
            return {
                'success': True,
                'data': {'models': models}
            }
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }
    
    def check_health(self) -> dict:
        """
        Verifica la salud del servidor
        
        Returns:
            dict: Estado de salud
        """
        ollama_available = self.ollama_service.check_connection()
        return {
            'success': True,
            'data': {
                'ollama_connected': ollama_available,
                'server_running': True
            }
        }
