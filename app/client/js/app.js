
// ======== Configuration ========
const API_BASE_URL = 'http://localhost:5000/api';

// ======== Elements ========
const modelSelect = document.getElementById('modelSelect');
const connectionStatus = document.getElementById('connectionStatus');
const chatMessages = document.getElementById('chatMessages');
const messageInput = document.getElementById('messageInput');
const sendBtn = document.getElementById('sendBtn');

// ======== Global vars ========
let selectedModel = null;
let conversationHistory = []; // To maintain history

// ======== Functions ========

// 1. Load available models
async function loadModels() {
  try {
    const response = await fetch(`${API_BASE_URL}/models`);
    const data = await response.json();

    if (data.success && data.models.length > 0) {
      // Clear previous options
      modelSelect.innerHTML = '';

      // Add model options
      data.models.forEach(model => {
        const option = document.createElement('option');
        option.value = model.name;
        option.textContent = `${model.name} (${Math.round(model.size / 1024 / 1024 / 1024)}GB)`;
        modelSelect.appendChild(option);
      });

      // Update status
      updateConnectionStatus(true);
      console.log('Models loaded:', data.models);
    } else {
      addSystemMessage('No models found in Ollama. Is it running?');
      updateConnectionStatus(false);
    }
  } catch (error) {
    addSystemMessage(`Error connecting to server: ${error.message}`);
    updateConnectionStatus(false);
    console.error('Error:', error);
  }
}

// 2. Update connection indicator
function updateConnectionStatus(isConnected) {
  if (isConnected) {
    connectionStatus.textContent = 'Connected';
    connectionStatus.classList.add('connected');
    connectionStatus.classList.remove('disconnected');
    sendBtn.disabled = false;
  } else {
    connectionStatus.textContent = 'Disconnected';
    connectionStatus.classList.add('disconnected');
    connectionStatus.classList.remove('connected');
    sendBtn.disabled = true;
  }
}

// 3. Add message to chat
function addMessage(text, sender) {
  const messageDiv = document.createElement('div');
  messageDiv.classList.add('message', sender);

  const paragraph = document.createElement('p');
  paragraph.textContent = text;

  messageDiv.appendChild(paragraph);
  chatMessages.appendChild(messageDiv);

  // Auto scroll to latest message
  chatMessages.scrollTop = chatMessages.scrollHeight;
}

// 4. Add system message
function addSystemMessage(text) {
  const messageDiv = document.createElement('div');
  messageDiv.classList.add('message', 'system');

  const paragraph = document.createElement('p');
  paragraph.textContent = text;

  messageDiv.appendChild(paragraph);
  chatMessages.appendChild(messageDiv);
  chatMessages.scrollTop = chatMessages.scrollHeight;
}

// 5. Add loading indicator
function addLoadingMessage() {
  const messageDiv = document.createElement('div');
  messageDiv.classList.add('message', 'loading');
  messageDiv.id = 'loadingMessage';

  const paragraph = document.createElement('p');
  const spinner = document.createElement('span');
  spinner.classList.add('spinner');
  
  paragraph.appendChild(spinner);
  paragraph.appendChild(document.createTextNode(' Waiting for response...'));

  messageDiv.appendChild(paragraph);
  chatMessages.appendChild(messageDiv);
  chatMessages.scrollTop = chatMessages.scrollHeight;
}

// 6. Remove loading indicator
function removeLoadingMessage() {
  const loadingMsg = document.getElementById('loadingMessage');
  if (loadingMsg) {
    loadingMsg.remove();
  }
}

// 7. Send message to server
async function sendMessage() {
  const userMessage = messageInput.value.trim();

  // Validate message and selected model
  if (!userMessage) {
    addSystemMessage('Write a message first');
    return;
  }

  if (!modelSelect.value) {
    addSystemMessage('Select a model first');
    return;
  }

  // Add user message to chat
  addMessage(userMessage, 'user');

  // Add to history
  conversationHistory.push({
    role: 'user',
    content: userMessage
  });

  // Clear input
  messageInput.value = '';
  messageInput.focus();

  // Show loading indicator
  addLoadingMessage();

  try {
    // Send request to server
    const response = await fetch(`${API_BASE_URL}/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: modelSelect.value,
        messages: conversationHistory
      })
    });

    const data = await response.json();

    // Remove loading indicator
    removeLoadingMessage();

    if (data.success) {
      const botReply = data.reply;

      // Add bot response
      addMessage(botReply, 'bot');

      // Add to history
      conversationHistory.push({
        role: 'assistant',
        content: botReply
      });

      console.log('Response received:', botReply);
    } else {
      addSystemMessage(`Error: ${data.error}`);
      removeLoadingMessage();
    }
  } catch (error) {
    removeLoadingMessage();
    addSystemMessage(`Connection error: ${error.message}`);
    console.error('Error:', error);
  }
}

// ======== EVENT LISTENERS ========

// Change selected model
modelSelect.addEventListener('change', (e) => {
  selectedModel = e.target.value;
  addSystemMessage(`Selected model: ${selectedModel}`);
});

// Send message with button
sendBtn.addEventListener('click', sendMessage);

// Send message with Enter (but not Shift+Enter for line breaks)
messageInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    sendMessage();
  }
});

// ======== INITIALIZATION ========
document.addEventListener('DOMContentLoaded', () => {
  console.log('Starting CORTEX Web UI...');
  loadModels();
  addSystemMessage('Connecting to server...');
});
