import axios from 'axios';

// URL Ollama
const OLLAMA_API_URL = 'http://localhost:11434/api';

// Obtain available models from Ollama
export async function getAvailableModels() {
  try {
    const response = await axios.get(`${OLLAMA_API_URL}/tags`);
    return response.data.models || [];
  } catch (error) {
    console.error('Error obtaining models:', error);
    throw new Error('Could not connect to Ollama');
  }
}

// Send chat message to Ollama and get response
export async function chatWithOllama(
  model: string,
  messages: Array<{ role: string; content: string }>
) {
  try {
    const response = await axios.post(
      `${OLLAMA_API_URL}/chat`,
      {
        model: model,
        messages: messages,
        stream: false // 
      },
      { timeout: 60000 } // 60s timeout
    );

    return response.data.message.content; 
  } catch (error) {
    console.error('Error calling Ollama:', error);
    throw new Error('Error when processing request in Ollama');
  }
}