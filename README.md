# CORTEX

Self-hosted AI workspace with local LLM inference, custom Web UI, RAG, fine-tuning pipeline, and chain-of-thought reasoning. Built on Ubuntu with CUDA.

## What is CORTEX?

A complete AI workspace that runs locally on your machine:
- **Backend API** - Express.js server that proxies Ollama API
- **Web UI** - Clean HTML/CSS/JS interface for chatting with local LLMs
- **Local LLM** - Full control using Ollama (no external APIs, complete privacy)
- **Scalable** - Built with a clean MVC architecture for future expansions

---

## Prerequisites

Before running CORTEX, you need:

1. **Ollama** - Download and install from [ollama.ai](https://ollama.ai)
2. **Node.js** - v16+ from [nodejs.org](https://nodejs.org)
3. **A local LLM model** - Run `ollama pull qwen2` (or any other model)

### Check if everything is installed:
```bash
ollama --version
node --version
npm --version
```

---

## How to Run CORTEX (Every Time)

### Step 1: Start Ollama (Terminal 1)
```bash
ollama serve
```
You should see: `[llm server] listening on ...`

### Step 2: Start the Backend Server (Terminal 2)
```bash
cd app/server
npm install  # Only on first run
npm run dev
```
You should see: `Server running on http://localhost:5000`

### Step 3: Open in Browser (Terminal 3 or Browser)
Open this URL in your web browser:
```
http://localhost:5000
```

**That's it! ** You should see:
- The CORTEX header
- A dropdown to select your model
- A chat interface

---

## Project Structure

```
CORTEX/
├── app/
│   ├── client/                    # Frontend (HTML/CSS/JS)
│   │   ├── index.html             # Main page
│   │   ├── css/
│   │   │   └── style.css          # Styles
│   │   └── js/
│   │       └── app.js             # Logic & Ollama connection
│   │
│   └── server/                    # Backend (Express + TypeScript)
│       ├── src/
│       │   ├── app.ts             # Express server setup
│       │   ├── routes/
│       │   │   └── chatRoutes.ts  # API endpoints (/api/chat, /api/models)
│       │   └── services/
│       │       └── ollamaService.ts # Ollama API integration
│       ├── package.json
│       └── tsconfig.json
│
├── README.md                      # This file
├── .gitignore                     # Git ignore config
└── .git/                          # Git repository

```

---

## How It Works (Architecture)

```
Web Browser (http://localhost:5000)
        ↓
    HTML/CSS/JS (app.js)
        ↓ HTTP Requests
Express Server (localhost:5000)
        ↓ HTTP Requests
Ollama API (localhost:11434)
        ↓
Your Local LLM Model
```

### Data Flow Example:
1. User types message in web UI
2. JavaScript sends POST to `http://localhost:5000/api/chat`
3. Express server receives it and forwards to `http://localhost:11434/api/chat`
4. Ollama processes with your local model
5. Express returns response to browser
6. UI displays bot's response

---

## Available API Endpoints

### Get Available Models
```bash
curl http://localhost:5000/api/models
```
Response:
```json
{
  "success": true,
  "models": [
    { "name": "qwen2", "size": 5000000000 },
    { "name": "llama2", "size": 4000000000 }
  ]
}
```

### Send a Chat Message
```bash
curl -X POST http://localhost:5000/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'
```

---

## Development & Troubleshooting

### Server won't start?
```bash
# Check if port 5000 is in use
lsof -i :5000

# Kill any existing process on port 5000
kill -9 <PID>

# Then try npm run dev again
```

### Ollama not connecting?
```bash
# Make sure Ollama is running
ollama serve

# Check if it's listening on localhost:11434
curl http://localhost:11434/api/tags
```

### Models not loading in UI?
```bash
# Check browser console (F12 → Console)
# Check server terminal for errors
# Make sure you have at least one model: ollama pull qwen2
```

### Need to install dependencies again?
```bash
cd app/server
rm -rf node_modules package-lock.json
npm install
```

---

## Next Steps (Roadmap)

- [ ] Add streaming responses (real-time token generation)
- [ ] Implement chat history persistence (localStorage)
- [ ] Add RAG (document upload & retrieval)
- [ ] Fine-tuning pipeline
- [ ] Multiple model comparison (council voting system)
- [ ] System prompts & model parameters UI
- [ ] Dark/Light theme toggle

---

## License

MIT License - Feel free to use this project however you want.

---

## Contributing

Want to improve CORTEX? Feel free to fork and submit pull requests!

---

