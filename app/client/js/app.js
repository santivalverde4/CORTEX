
// ======== Configuration ========
const API_BASE_URL = '/api';

// ======== Elements ========
const modelSelect = document.getElementById('modelSelect');
const connectionStatus = document.getElementById('connectionStatus');
const conversationList = document.getElementById('conversationList');
const newChatBtn = document.getElementById('newChatBtn');
const chatMessages = document.getElementById('chatMessages');
const messageInput = document.getElementById('messageInput');
const sendBtn = document.getElementById('sendBtn');

// Start in a safe disabled state; we'll enable when connected + model selected.
sendBtn.disabled = true;

// ======== Global vars ========
let selectedModel = null;
let isServerConnected = false;

const STORAGE_KEYS = {
  conversations: 'cortex.conversations.v1',
  activeConversationId: 'cortex.activeConversationId.v1'
};

let conversations = [];
let activeConversationId = null;

function generateId() {
  if (window.crypto && typeof window.crypto.randomUUID === 'function') {
    return window.crypto.randomUUID();
  }

  return `c_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
}

function loadAppState() {
  try {
    const saved = localStorage.getItem(STORAGE_KEYS.conversations);
    const savedActiveId = localStorage.getItem(STORAGE_KEYS.activeConversationId);

    conversations = saved ? JSON.parse(saved) : [];
    activeConversationId = savedActiveId || null;
  } catch (e) {
    conversations = [];
    activeConversationId = null;
  }

  // Minimal validation
  if (!Array.isArray(conversations)) {
    conversations = [];
  }

  // Lightweight migration: translate old Spanish defaults.
  conversations = conversations.map((conv) => {
    if (!conv || typeof conv !== 'object') return conv;

    if (conv.title === 'Nueva conversación') {
      return { ...conv, title: 'New chat' };
    }

    return conv;
  });
}

function saveAppState() {
  localStorage.setItem(STORAGE_KEYS.conversations, JSON.stringify(conversations));
  localStorage.setItem(STORAGE_KEYS.activeConversationId, activeConversationId || '');
}

function getConversationById(id) {
  return conversations.find((c) => c.id === id) || null;
}

function getActiveConversation() {
  return activeConversationId ? getConversationById(activeConversationId) : null;
}

function touchConversation(conv) {
  conv.updatedAt = new Date().toISOString();
}

function createConversation() {
  const now = new Date().toISOString();
  const conv = {
    id: generateId(),
    title: 'New chat',
    createdAt: now,
    updatedAt: now,
    messages: []
  };

  conversations.unshift(conv);
  activeConversationId = conv.id;
  saveAppState();
  renderConversationList();
  renderActiveConversation();
}

function setActiveConversation(id) {
  if (!getConversationById(id)) return;
  activeConversationId = id;
  saveAppState();
  renderConversationList();
  renderActiveConversation();
}

function renderConversationList() {
  // Sort by most recently updated
  conversations.sort((a, b) => (b.updatedAt || '').localeCompare(a.updatedAt || ''));

  conversationList.innerHTML = '';
  conversations.forEach((conv) => {
    const li = document.createElement('li');

    const btn = document.createElement('button');
    btn.type = 'button';
    btn.classList.add('conversation-item');
    if (conv.id === activeConversationId) {
      btn.classList.add('active');
    }
    btn.textContent = conv.title || 'Conversation';
    btn.addEventListener('click', () => setActiveConversation(conv.id));

    li.appendChild(btn);
    conversationList.appendChild(li);
  });
}

function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function renderMarkdownSafely(markdownText) {
  const raw = String(markdownText ?? '');

  // Prefer proper Markdown rendering when libraries are available.
  if (window.marked && window.DOMPurify) {
    const html = window.marked.parse(raw, {
      breaks: true,
      gfm: true
    });

    return window.DOMPurify.sanitize(html, {
      USE_PROFILES: { html: true }
    });
  }

  // Fallback: preserve line breaks without allowing HTML injection.
  return escapeHtml(raw).replace(/\n/g, '<br>');
}

function clearMessages() {
  chatMessages.innerHTML = '';
}

function renderActiveConversation() {
  const conv = getActiveConversation();
  clearMessages();

  if (!conv) {
    return;
  }

  if (!Array.isArray(conv.messages) || conv.messages.length === 0) {
    addSystemMessage('Send a message to start.');
    return;
  }

  conv.messages.forEach((m) => {
    if (m.role === 'user') addMessage(m.content, 'user');
    else if (m.role === 'assistant') addMessage(m.content, 'bot');
    else addSystemMessage(m.content);
  });
}

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
  isServerConnected = isConnected;
  if (isConnected) {
    connectionStatus.textContent = 'Online';
    connectionStatus.classList.add('connected');
    connectionStatus.classList.remove('disconnected');
  } else {
    connectionStatus.textContent = 'Offline';
    connectionStatus.classList.add('disconnected');
    connectionStatus.classList.remove('connected');
  }

  // Enable only when connected and a model is selected
  sendBtn.disabled = !(isServerConnected && !!modelSelect.value);
}

// 3. Add message to chat
function addMessage(text, sender) {
  const messageDiv = document.createElement('div');
  messageDiv.classList.add('message', sender);

  const content = document.createElement('div');
  content.classList.add('message-content');

  if (sender === 'bot') {
    content.innerHTML = renderMarkdownSafely(text);
  } else {
    content.textContent = text;
  }

  messageDiv.appendChild(content);
  chatMessages.appendChild(messageDiv);

  // Auto scroll to latest message
  chatMessages.scrollTop = chatMessages.scrollHeight;
}

// 4. Add system message
function addSystemMessage(text) {
  const messageDiv = document.createElement('div');
  messageDiv.classList.add('message', 'system');

  const content = document.createElement('div');
  content.classList.add('message-content');
  content.textContent = text;

  messageDiv.appendChild(content);
  chatMessages.appendChild(messageDiv);
  chatMessages.scrollTop = chatMessages.scrollHeight;
}

// 5. Add loading indicator
function addLoadingMessage() {
  const messageDiv = document.createElement('div');
  messageDiv.classList.add('message', 'loading');
  messageDiv.id = 'loadingMessage';

  const content = document.createElement('div');
  content.classList.add('message-content');
  const spinner = document.createElement('span');
  spinner.classList.add('spinner');
  
  content.appendChild(spinner);
  content.appendChild(document.createTextNode(' Waiting for response...'));

  messageDiv.appendChild(content);
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

  const conv = getActiveConversation();
  if (!conv) {
    createConversation();
  }

  const activeConv = getActiveConversation();
  if (!activeConv) {
    addSystemMessage('Could not create a conversation.');
    return;
  }

  const isFirstUserMessage = !activeConv.messages || activeConv.messages.length === 0;

  // If this is the first user message, use it as conversation title.
  if (isFirstUserMessage) {
    activeConv.title = userMessage.slice(0, 48);
  }

  // Clear placeholder message for a fresh conversation
  if (isFirstUserMessage) {
    clearMessages();
  }

  // Add user message to UI + conversation
  addMessage(userMessage, 'user');
  activeConv.messages = Array.isArray(activeConv.messages) ? activeConv.messages : [];
  activeConv.messages.push({ role: 'user', content: userMessage });
  touchConversation(activeConv);
  saveAppState();
  renderConversationList();

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
        messages: activeConv.messages
      })
    });

    const data = await response.json();

    // Remove loading indicator
    removeLoadingMessage();

    if (data.success) {
      const botReply = data.reply;

      // Add bot response
      addMessage(botReply, 'bot');

      // Add to conversation
      activeConv.messages.push({ role: 'assistant', content: botReply });
      touchConversation(activeConv);
      saveAppState();
      renderConversationList();

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
  sendBtn.disabled = !(isServerConnected && !!selectedModel);
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
  loadAppState();

  if (!conversations.length) {
    createConversation();
  } else {
    // Ensure we have an active conversation
    const exists = activeConversationId && getConversationById(activeConversationId);
    if (!exists) {
      activeConversationId = conversations[0]?.id || null;
    }

    saveAppState();
    renderConversationList();
    renderActiveConversation();
  }

  loadModels();
  newChatBtn.addEventListener('click', createConversation);
});
