import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import path from 'path';
import chatRoutes from './routes/chatRoutes';

const app: Express = express();

// Middlewares
app.use(cors()); 
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

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});

export default app;