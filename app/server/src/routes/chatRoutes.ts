import { Router, Request, Response } from 'express';
import { getAvailableModels, chatWithOllama } from '../services/ollamaService';

const router = Router();

// Endpoint to get available models
router.get('/models', async (req: Request, res: Response) => {
  try {
    const models = await getAvailableModels();
    res.json({ success: true, models });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

// Endpoint to chat with Ollama
router.post('/chat', async (req: Request, res: Response) => {
  const { model, messages } = req.body;

  if (!model || !messages) {
    return res.status(400).json({
      success: false,
      error: 'model and messages are required'
    });
  }

  try {
    const response = await chatWithOllama(model, messages);
    res.json({
      success: true,
      reply: response
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: (error as Error).message
    });
  }
});

export default router;