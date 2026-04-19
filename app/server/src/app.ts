import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import path from 'path';
import 'dotenv/config';
import chatRoutes from './routes/chatRoutes';

const app: Express = express();

// Basic hardening
app.disable('x-powered-by');

// Middlewares
// CORS is opt-in; same-origin requests (default UI flow) don't need it.
const corsOrigin = process.env.CORS_ORIGIN;
if (corsOrigin) {
  const allowedOrigins = corsOrigin
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
  app.use(cors({ origin: allowedOrigins }));
}

app.use(express.json()); 

// Serve static files from the client folder
const clientPath = path.resolve(__dirname, '../../client');
app.use(express.static(clientPath));

// Root route to serve the main HTML file
app.get('/', (req: Request, res: Response) => {
  res.sendFile(path.join(clientPath, 'index.html'));
});

// Test endpoint
app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'Server is running!' });
});

// API routes
app.use('/api', chatRoutes);

const PORT = Number(process.env.PORT) || 5000;
const HOST = process.env.HOST || '127.0.0.1';
app.listen(PORT, HOST, () => {
  console.log(`Server running on http://${HOST}:${PORT}`);
});

export default app;
