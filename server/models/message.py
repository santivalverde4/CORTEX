"""
Modelos de datos para la aplicación
"""

from dataclasses import dataclass
from typing import Optional
from datetime import datetime


@dataclass
class Message:
    """Estructura de un mensaje"""
    content: str
    role: str  # 'user' o 'assistant'
    timestamp: datetime = None
    model: Optional[str] = None
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now()
    
    def to_dict(self):
        return {
            'content': self.content,
            'role': self.role,
            'timestamp': self.timestamp.isoformat(),
            'model': self.model
        }


@dataclass
class ChatRequest:
    """Estructura de una solicitud de chat"""
    message: str
    model: str
    
    def validate(self):
        if not self.message or not self.message.strip():
            raise ValueError("El mensaje no puede estar vacío")
        if not self.model:
            raise ValueError("El modelo es requerido")
        return True


@dataclass
class ChatResponse:
    """Estructura de la respuesta del chat"""
    response: str
    model: str
    timestamp: datetime = None
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now()
    
    def to_dict(self):
        return {
            'response': self.response,
            'model': self.model,
            'timestamp': self.timestamp.isoformat()
        }
