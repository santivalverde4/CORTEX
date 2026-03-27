# CORTEX - Self-hosted AI Workspace

A local and self-hosted AI workspace with separated architecture:
-  **Simple Frontend** (HTML/CSS/Vanilla JavaScript)
-  **REST Backend** (Flask + Python)
-  **Ollama Connection** for local LLM

##  Features

 Chat with local AI  
 Complete REST API  
 Model selector  
 Simple WebUI inspired by Pewdiepie's WebUI 
 Decoupled Frontend and Backend  
 Business logic on the server  
 Easy to scale and extend

##  Structure

```
CORTEX/
├── client/              ← Frontend 
│   ├── index.html       ← Web page
│   ├── css/
│   │   └── style.css    ← Styles
│   └── js/
│       ├── config.js    ← API URL
│       ├── api.js       ← HTTP Client
│       └── app.js       ← Interface logic
│
└── server/              ← Backend (REST API)
    ├── main.py          ← Entry point (Flask)
    ├── requirements.txt ← Python dependencies
    ├── config/          ← Configuration
    ├── models/          ← Data structures
    ├── routes/          ← API endpoints
    └── services/        ← Business logic
```

##  Requirements

- **Ollama** installed and running
  - Download: https://ollama.ai
  - Model: `ollama pull llama2`

- **Python 3.8+** (for the server)
  - Dependencies are installed from `server/requirements.txt`
  - Recommended: use a local virtualenv in `server/.venv`

##  Quick Installation (4 Steps)

### Step 1: Start Ollama
```bash
ollama serve
```
Ollama will listen on `http://localhost:11434`

### Step 2: Install server dependencies
```bash
cd server

# Create a local virtualenv (recommended)
python3 -m venv .venv

# If you see "ensurepip is not available" on Ubuntu/Debian:
#   sudo apt install python3-venv

. .venv/bin/activate
pip install -r requirements.txt
```

### Step 3: Start the backend server (new terminal)
```bash
cd server
. .venv/bin/activate
python3 main.py
```
Server available at `http://localhost:8000`

### Step 4: Serve the frontend client (new terminal)
```bash
cd client
python3 -m http.server 8080
```

**Open in browser:** `http://localhost:8080`

Note: the backend API already uses port `8000`. The frontend must use a different port (like `8080`) to avoid the browser sending `/api/*` requests to the static server.

## Daily usage (run + stop)

### Ports (important)
- Backend API (Flask): `http://localhost:8000`
- Ollama: `http://localhost:11434`
- Frontend (static server): `http://localhost:8080`

If you serve the frontend on `8000`, the browser will hit the static server for `/api/*` and you can see errors like `OPTIONS 501 Unsupported method`.

### Start (recommended: 3 terminals)

#### Terminal 1 — Ollama
If Ollama is not already running:
```bash
ollama serve
```

If Ollama runs as a system service:
```bash
sudo systemctl start ollama
```

#### Terminal 2 — Backend API
```bash
cd server
. .venv/bin/activate
python3 main.py
```

Quick check:
```bash
curl http://localhost:8000/api/health
```

#### Terminal 3 — Frontend
```bash
cd client
python3 -m http.server 8080
```

Open in browser:
- `http://localhost:8080`

### Stop (clean)

If you started them in terminals:
- In the Backend terminal: press `Ctrl+C`
- In the Frontend terminal: press `Ctrl+C`
- Ollama:
  - If you started it manually: press `Ctrl+C` in that terminal
  - If it’s a service: `sudo systemctl stop ollama`

### Stop (if you closed a terminal and it’s still running)

See what is listening on the ports:
```bash
sudo lsof -iTCP:11434 -sTCP:LISTEN
sudo lsof -iTCP:8000  -sTCP:LISTEN
sudo lsof -iTCP:8080  -sTCP:LISTEN
```

Kill by port (targeted):
```bash
sudo kill $(sudo lsof -t -iTCP:11434 -sTCP:LISTEN)
sudo kill $(sudo lsof -t -iTCP:8000  -sTCP:LISTEN)
sudo kill $(sudo lsof -t -iTCP:8080  -sTCP:LISTEN)
```

If something refuses to stop:
```bash
sudo kill -9 $(sudo lsof -t -iTCP:11434 -sTCP:LISTEN)
```

##  REST API

### Endpoints

| Method | URL | Description |
|--------|-----|-------------|
| `GET` | `/api/health` | Check server status |
| `GET` | `/api/models` | List available models |
| `POST` | `/api/chat` | Send chat message |

### Example: Send a message
```bash
curl -X POST http://localhost:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello", "model": "llama2"}'
```

### Request Format
```json
{
    "message": "Your question here",
    "model": "llama2"
}
```

### Response Format
```json
{
    "success": true,
    "data": {
        "response": "Model response...",
        "model": "llama2",
        "timestamp": "2026-03-25T23:00:00"
    }
}
```

##  Configuration

### Client: `client/js/config.js`
```javascript
const CONFIG = {
    API_BASE_URL: 'http://localhost:8000',  // Server URL
    REQUEST_TIMEOUT: 60000                   // Timeout in ms
};
```

### Server: `server/config/config.py`
```python
OLLAMA_BASE_URL = 'http://localhost:11434'  # Ollama URL
API_PORT = 8000                              # Server port
DEFAULT_MODEL = 'llama2'                     # Default model
```

##  Upcoming Improvements

**Frontend:**
- Conversation history
- Export/download chats
- Dark/Light mode toggle
- PWA (Progressive Web App)

**Backend:**
- RAG (Retrieval-Augmented Generation)
- Fine-tuning pipeline
- Chain-of-Thought reasoning
- Persistent database
- Authentication and sessions
- Rate limiting and caching

##  Troubleshooting

### "I can't connect to the server"
```bash
# 1. Check that the server is running
ps aux | grep "python3 main.py"

# 2. Install the dependencies (recommended: inside a venv)
cd server
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt

# 3. Check that the URL is correct in client/js/config.js
```

### "Ollama doesn't respond"
```bash
# 1. Check that Ollama is running
ps aux | grep ollama

# 2. Check that the model exists
ollama list

# 3. Download a model
ollama pull llama2
```

### "Port 8000 is already in use"
```bash
# Option 1: Kill the process using the port
lsof -ti:8000 | xargs kill -9

# Option 2: Change the port in server/main.py
# Change: app.run(host='0.0.0.0', port=8001)
```

##  Architecture

**Simple Frontend:**
- No complex data models
- No business logic
- Only communicates with the server API
- Renders the user interface

**Complete Backend:**
- All business logic
- Data models and validation
- Communication with Ollama
- Centralized error handling


##  License

MIT

##  Contributing

Contributions are welcome. Please:
1. Fork the project
2. Create a branch (`git checkout -b feature/improvement`)
3. Commit your changes (`git commit -m 'Add improvement'`)
4. Push to the branch (`git push origin feature/improvement`)
5. Open a Pull Request
