"""
Servicio de comunicación con Ollama
"""

import requests
from typing import Optional
from ..config.config import OLLAMA_BASE_URL, OLLAMA_TIMEOUT


class OllamaService:
    """Servicio para comunicarse con la API de Ollama"""
    
    def __init__(self, base_url: str = OLLAMA_BASE_URL):
        self.base_url = base_url
        self.timeout = OLLAMA_TIMEOUT
    
    def check_connection(self) -> bool:
        """
        Verifica si Ollama está disponible
        
        Returns:
            bool: True si está disponible, False en caso contrario
        """
        try:
            response = requests.get(
                f"{self.base_url}/api/tags",
                timeout=5
            )
            return response.status_code == 200
        except requests.exceptions.RequestException:
            return False
    
    def get_available_models(self) -> list:
        """
        Obtiene la lista de modelos disponibles
        
        Returns:
            list: Lista de modelos disponibles
        """
        try:
            response = requests.get(
                f"{self.base_url}/api/tags",
                timeout=self.timeout
            )
            data = response.json()
            return [model['name'] for model in data.get('models', [])]
        except Exception as e:
            print(f"Error al obtener modelos: {e}")
            return []
    
    def generate(self, prompt: str, model: str) -> str:
        """
        Genera una respuesta usando Ollama
        
        Args:
            prompt: El mensaje del usuario
            model: El modelo a usar
            
        Returns:
            str: La respuesta generada
            
        Raises:
            Exception: Si hay error en la solicitud
        """
        payload = {
            "model": model,
            "prompt": prompt,
            "stream": False
        }
        
        try:
            response = requests.post(
                f"{self.base_url}/api/generate",
                json=payload,
                timeout=self.timeout
            )
            
            if response.status_code != 200:
                raise Exception(f"Error de Ollama: {response.status_code}")
            
            data = response.json()
            return data.get('response', '').strip()
        
        except requests.exceptions.Timeout:
            raise Exception("Solicitud agotada. El modelo tardó demasiado.")
        except requests.exceptions.ConnectionError:
            raise Exception("No se puede conectar a Ollama. ¿Está ejecutándose?")
        except Exception as e:
            raise Exception(f"Error al generar respuesta: {str(e)}")
