/**
 * Copyright 2025 Amazon.com, Inc. and its affiliates. All Rights Reserved.
 *
 * Licensed under the Amazon Software License (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *   http://aws.amazon.com/asl/
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

import { WebSocketEventManager } from "./websocketEvents.js";
import { getCognitoAuth } from "./cognito.js";

async function startMicStreaming(wsManager) {
  console.log("DEBUG: WebSocket open — now requesting microphone access");

  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        channelCount: 1,
        sampleSize: 16,
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
      },
    });
    console.log("DEBUG: Microphone access granted");
    addSystemMessage("You are now connected! Please state your query.");
    const audioCtx = new AudioContext({ latencyHint: "interactive", sampleRate: 16000 });
    console.log(`DEBUG: AudioContext sampleRate: ${audioCtx.sampleRate}Hz`);
    await audioCtx.audioWorklet.addModule('/processor.js');
    const processor = new AudioWorkletNode(audioCtx, 'pcm-processor');
    processor.port.onmessage = (event) => {
      const int16 = new Int16Array(event.data);
      const b64 = btoa(String.fromCharCode(...new Uint8Array(int16.buffer)));
      wsManager.sendAudioChunk(b64);
    };
    const source = audioCtx.createMediaStreamSource(stream);
    source.connect(processor);
    // Cleanup helper
    window.audioCleanup = () => {
      processor.disconnect();
      source.disconnect();
      stream.getTracks().forEach((t) => t.stop());
      if (audioCtx && audioCtx.state !== "closed") {
        audioCtx.close().catch((err) => {
          console.warn("Failed to close AudioContext:", err);
        });
      }
    };
    // Start your session timer after mic is live
    startSessionTimer();
  } catch (err) {
    console.error("Error accessing microphone after socket open:", err);
    updateStatus(`Error: ${err.message}`, "error");
  }
}

// Global variables
let wsManager;
let sessionTime = 0;
let sessionTimer;
let isRecording = false;
let conversationData = [];
let currentMessageId = 1;
let cognitoAuth;
let systemPrompt = ""; // Store system prompt content
let uiInitialized = false; // Track if UI has been initialized
let isStopped = false;

// Initialize on page load
document.addEventListener("DOMContentLoaded", async () => {
  try {
    // Attempt authentication
    const isAuthenticated = await doCognitoAuthentication();

    if (isAuthenticated) {
      // Create HTML structure if not already created
      if (!uiInitialized) {
        createHtmlStructure();
        uiInitialized = true;
      }

      // Load saved system prompt
      loadSystemPrompt();

      // Initialize the app
      initializeApp();
    } else {
      // Just waiting for redirect to Cognito login
      if (!uiInitialized) {
        createMinimalAuthUI();
        updateStatus("Authenticating...", "authenticating");
      }
    }
  } catch (error) {
    console.error("Error during authentication:", error);
    if (!uiInitialized) {
      createMinimalAuthUI();
      updateStatus("Authentication Error", "error");
    }
  }
});

// Create minimal UI during authentication
function createMinimalAuthUI() {
  document.body.innerHTML = `
    <div id="app">
      <div id="status" class="authenticating">Authenticating...</div>
    </div>
  `;
}

// Load system prompt from localStorage if available
function loadSystemPrompt() {
  console.log("Loading system prompt...");
  const savedPrompt = localStorage.getItem("systemPrompt");
  if (savedPrompt) {
    console.log("Loaded prompt from localStorage");
    systemPrompt = savedPrompt;
    const promptTextarea = document.getElementById("system-prompt-textarea");
    if (promptTextarea) {
      promptTextarea.value = systemPrompt;
    }
  } else {
    // Default system prompt
    console.log("No saved prompt found, fetching default...");
    fetch("system_prompt.txt")
      .then((response) => response.text())
      .then((text) => {
        console.log("Loaded default prompt from file");
        systemPrompt = text;
        const promptTextarea = document.getElementById(
          "system-prompt-textarea"
        );
        if (promptTextarea) {
          promptTextarea.value = systemPrompt;
        }
      })
      .catch((error) => {
        console.error("Error loading system prompt:", error);
        systemPrompt =
          "You're friendly customer support voice assistant.";
        const promptTextarea = document.getElementById(
          "system-prompt-textarea"
        );
        if (promptTextarea) {
          promptTextarea.value = systemPrompt;
        }
      });
  }
}

// Save system prompt to localStorage
function saveSystemPrompt() {
  const promptTextarea = document.getElementById("system-prompt-textarea");
  if (promptTextarea) {
    systemPrompt = promptTextarea.value;
    localStorage.setItem("systemPrompt", systemPrompt);

    // Show save confirmation
    showSaveConfirmation();
  }
}

// Show save confirmation
function showSaveConfirmation() {
  const saveConfirmationElement = document.getElementById("save-confirmation");
  if (saveConfirmationElement) {
    saveConfirmationElement.textContent = "Saved!";
    saveConfirmationElement.style.display = "block";

    // Hide after 2 seconds
    setTimeout(() => {
      saveConfirmationElement.style.display = "none";
    }, 2000);
  }
}

// Handle authentication process
async function doCognitoAuthentication() {
  // Bypass authentication in development mode
  if (import.meta.env.DEV) {
    console.log("Running in local development mode, bypassing authentication.");
    return true;
  }

  cognitoAuth = getCognitoAuth();
  const isAuthenticated = await cognitoAuth.handleAuth();
  return isAuthenticated;
}

// Logout function
function handleLogout() {
  if (cognitoAuth) {
    cognitoAuth.logout();
  }
}

// Initialize the application
function initializeApp() {
  // Give the DOM a moment to fully render
  setTimeout(() => {
    // Set up event listeners for main controls
    const startButton = document.getElementById("start");
    const stopButton = document.getElementById("stop");

    if (startButton) {
      startButton.addEventListener("click", () => {
        console.log("DEBUG: Call me button clicked!");
        startStreaming();

        // Show End Call button
        const stopButton = document.getElementById("stop");
        if (stopButton) stopButton.classList.remove("hidden");
      });
    } else {
      console.error("Start button not found");
    }

    if (stopButton) {
      stopButton.addEventListener("click", stopStreaming);
    } else {
      console.error("Stop button not found");
    }
    const hint = document.querySelector('.call-hint');
    document.getElementById('start').addEventListener('click', () => {
      if (hint) hint.style.display = 'none';
    });
    document.getElementById('stop').addEventListener('click', () => {
      if (hint) hint.style.display = 'inline-block';
    });
    const closePromptButton = document.getElementById("close-prompt-button");
    if (closePromptButton) {
      closePromptButton.addEventListener("click", () => {
        const editorContainer = document.getElementById("system-prompt-container");
        const toggleButton = document.getElementById("show-prompt-button");
        if (editorContainer) {
          editorContainer.style.display = "none";
          if (toggleButton) toggleButton.textContent = "Show Prompt";
        }
      });
    }
    // Set up system prompt editor listeners
    const showPromptButton = document.getElementById("show-prompt-button");
    const savePromptButton = document.getElementById("save-prompt-button");
    const logoutButton = document.getElementById("logout-button");
    const settingsToggle = document.getElementById("settings-toggle");
    const settingsMenu = document.getElementById("settings-menu");

    if (settingsToggle && settingsMenu) {
      settingsToggle.addEventListener("click", () => {
        settingsMenu.classList.toggle("hidden");
      });

      // Optional: Hide dropdown when clicking outside
      document.addEventListener("click", (event) => {
        if (!event.target.closest(".settings-dropdown")) {
          settingsMenu.classList.add("hidden");
        }
      });
    }
    if (showPromptButton) {
      showPromptButton.addEventListener("click", togglePromptEditor);
    }

    if (savePromptButton) {
      savePromptButton.addEventListener("click", saveSystemPrompt);
    }

    if (logoutButton) {
      logoutButton.addEventListener("click", handleLogout);
    }

    // Initialize UI components
    updateStatus("Disconnected", "disconnected");
    updateTimerDisplay();

    console.log("App initialization complete");
  }, 100); // Small delay to ensure DOM is ready
}

// Toggle prompt editor visibility
function togglePromptEditor() {
  const editorContainer = document.getElementById("system-prompt-container");
  const toggleButton = document.getElementById("show-prompt-button");

  if (!editorContainer) {
    console.error("Editor container not found");
    return;
  }

  const isVisible = editorContainer.style.display !== "none";

  if (isVisible) {
    editorContainer.style.display = "none";
    if (toggleButton) toggleButton.textContent = "Show Prompt";
  } else {
    editorContainer.style.display = "block";
    if (toggleButton) toggleButton.textContent = "Hide Prompt";
  }
}

// Update status indicator
function updateStatus(message, status) {
  const statusElement = document.getElementById("status");
  if (statusElement) {
    statusElement.textContent = message;
    statusElement.className = status;
  } else {
    console.error("Status element not found");
  }
}

// Format time display
function formatTime(seconds) {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins}:${secs < 10 ? "0" + secs : secs}`;
}

// Update the timer display
function updateTimerDisplay() {
  const timerElement = document.getElementById("timer");
  if (timerElement) {
    timerElement.textContent = formatTime(sessionTime);
  } else {
    console.error("Timer element not found");
  }
}

// Start streaming audio
async function startStreaming() {
  console.log("DEBUG: startStreaming() called");
  // Disable controls, update UI
  const startButton = document.getElementById("start");
  const stopButton = document.getElementById("stop");
  if (startButton) startButton.disabled = true;
  if (stopButton) stopButton.disabled = false;
  isRecording = true;
  isStopped = false;
  updateStatus("Connected", "connected");
  console.log("DEBUG: About to create WebSocketEventManager");
  wsManager = new WebSocketEventManager();
  wsManager.onUpdateTranscript = updateTranscript;
  wsManager.onAudioReceived = handleAudioReceived;
  // Wrap onUpdateStatus so we can kick off the mic only when connected
  wsManager.onUpdateStatus = (msg, cls) => {
    console.log("DEBUG: About to create WebSocketEventManager");
    updateStatus(msg, cls);
    const appEl = document.getElementById("app");
    const hint = document.querySelector(".call-hint");
    if (msg === "Connected") {
      // WebSocket is open, sessionStart/promptStart/contentStart have run
      wsManager.audioReady.then(() => startMicStreaming(wsManager));
    }
    appEl.classList.remove("pre-call");
    appEl.classList.add("in-call");
    hint?.setAttribute("style", "display:none;");

  };
  // Send system prompt into the session
  wsManager.setSystemPrompt(systemPrompt);
  console.log("System prompt passed to WebSocketManager");

}

// Handoff-specific cleanup: stop mic & timer, keep chat visible
function handoffCleanup() {
  // stop the mic/audio pipeline if active
  if (window.audioCleanup) {
    try { window.audioCleanup(); } catch (e) { console.warn("audioCleanup failed", e); }
  }

  // stop the session timer
  if (sessionTimer) {
    clearInterval(sessionTimer);
    sessionTimer = null;
  }


  // update buttons / status but DON'T hide the chat or switch layout
  const startButton = document.getElementById("start");
  const stopButton = document.getElementById("stop");

  // During live-agent call: disable Nova's "Call me", hide End Call
  if (startButton) startButton.disabled = false;
  if (stopButton) {
    stopButton.disabled = true;
    stopButton.classList.add("hidden");
  }

  isRecording = false;

  updateStatus("Transferred to live agent", "connected");
  if (window.removeThinkingMessage) window.removeThinkingMessage();
}

window.handoffCleanup = handoffCleanup;

// Stop streaming audio
function stopStreaming() {

  if (isStopped) return;
  isStopped = true;
  const startButton = document.getElementById("start");
  const stopButton = document.getElementById("stop");
  const chatContainer = document.getElementById("chat-container");
  // Cleanup audio processing
  if (window.audioCleanup) {
    window.audioCleanup();
  }

  if (wsManager) {
    wsManager.cleanup();
  }

  // Clear timer
  if (sessionTimer) {
    clearInterval(sessionTimer);
  }

  // Update UI
  if (startButton) startButton.disabled = false;
  if (stopButton) {
    stopButton.disabled = true;
    stopButton.classList.add("hidden");
  }

  isRecording = false;

  // FORCE the UI back into “pre-call” mode
  const appEl = document.getElementById("app");
  const hint = document.querySelector(".call-hint");
  appEl.classList.add("pre-call");
  appEl.classList.remove("in-call");
  hint && (hint.style.display = "inline-block");
  addSystemMessage("Call disconnected — connection closed.");
  updateStatus("Disconnected", "disconnected");
  
}
window.stopStreaming = stopStreaming;
// Update transcript with the conversation history
async function updateTranscript(history) {
  if (!history || history.length === 0) return;

  const chatContainer = document.getElementById("chat-container");
  if (!chatContainer) {
    console.error("Chat container not found");
    return;
  }

  // Clear the container
  chatContainer.innerHTML = "";

  // Add all messages to the chat container
  for (let i = 0; i < history.length; i++) {
    const item = history[i];

    // Skip if no role or message or if it's a system message
    if (!item.role || !item.message || item.role.toLowerCase() === "system") {
      continue;
    }

    // Create message element
    const messageElement = document.createElement("div");
    let messageClass = "";

    if (item.role.toLowerCase() === "user") {
      messageClass = "user";
    } else if (item.role.toLowerCase() === "assistant") {
      messageClass = "assistant";
    }

    messageElement.className = `message ${messageClass}`;

    // Create message content
    const contentElement = document.createElement("div");
    contentElement.className = "message-content";

    // For assistant messages, extract emotion tag if present
    let messageText = item.message;
    if (item.role.toLowerCase() === "assistant") {
      const match = messageText.match(/^\[(.*?)\](.*)/);
      if (match) {
        // Extract emotion and message
        const emotion = match[1];
        const text = match[2];

        // Add emotion as a prefix
        messageText = `[${emotion}]${text}`;
      }
    }

    contentElement.textContent = messageText;
    messageElement.appendChild(contentElement);

    chatContainer.appendChild(messageElement);
  }
  chatContainer.scrollTop = chatContainer.scrollHeight;
}
function startWebRTCSession({ conversationId, phoneNumber } = {}) {

  (function (w, d, x, id) {
    if (!d.getElementById(id)) {
      const s = d.createElement('script');
      s.src = 'https://agenticaidemo.my.connect.aws/connectwidget/static/amazon-connect-chat-interface-client.js';
      s.async = 1;
      s.id = id;
      d.getElementsByTagName('head')[0].appendChild(s);
      w[x] = w[x] || function () { (w[x].ac = w[x].ac || []).push(arguments); };
    }
  })(window, document, 'amazon_connect', 'e884ff33-15ac-443a-abc4-fabbad1b6769');

  amazon_connect('styles', {
    iconType: 'VOICE',
    openChat: { color: '#ffffff', backgroundColor: '#1D1F71' },
    closeChat: { color: '#ffffff', backgroundColor: '#DA1884' }
  });

  amazon_connect('snippetId', 'QVFJREFIaXdlaTllQXR1SnQyK1JZc1Z3dWE3clBZQjQvWm15emlVb25scEltc3BJNmdGMUk1RithaU00QWhNbVBqODg4YjBqQUFBQWJqQnNCZ2txaGtpRzl3MEJCd2FnWHpCZEFnRUFNRmdHQ1NxR1NJYjNEUUVIQVRBZUJnbGdoa2dCWlFNRUFTNHdFUVFNZkQxU2tMRGFNM0VhcElic0FnRVFnQ3V4dTBMMnRBTEVFTGRKcThiWXVQTG9pVk5xRmhjOEdSUkdRU3oxSWxxcmR0eXIrYnhKclErTkhjNmU6OldkZGVMOU9ncW5GdllVSFR0bFJxL2h6UkpIWlp6dWRLSkRHWUllZDh6aldXV25neXZnU1BQSVpWUDlxMGh4T3UxTXlodEo5VW9Ca2p0UmV4blFxOFBLVno2VlR2eHNvWkk2RHdyeEhIMnU1ZlJmTU4xTitvcEpWT252VjRJaWl3alZzNFROS2NIZEZ0NUxYaUQvSGREWGgwWmxvWTFYYz0=');

  amazon_connect('customLaunchBehavior', {
    skipIconButtonAndAutoLaunch: true,
    alwaysHideWidgetButton: true
  });

  // Pass attributes from NovaSonic → Connect
  const attrs = {};
  if (conversationId) attrs.session_id = conversationId;
  if (phoneNumber) attrs.CustomerPhoneNumber = phoneNumber;

  amazon_connect('contactAttributes', attrs);

  amazon_connect('supportedMessagingContentTypes', [
    'text/plain',
    'text/markdown',
    'application/vnd.amazonaws.connect.message.interactive',
    'application/vnd.amazonaws.connect.message.interactive.response'
  ]);

  if (!window.__connectMessageListenerAdded) {
    window.addEventListener("message", (evt) => {
      try {
        const data = evt.data;
        if (!data) return;

        // Normalize to a string for broad matching; also check common fields
        const asText = typeof data === "string" ? data : JSON.stringify(data);

        const ended =
          /call[_\s-]?ended|call[_\s-]?disconnected|contact[_\s-]?ended|chat[_\s-]?completed|widget[_\s-]?closed/i.test(asText) ||
          (data?.eventName && /ended|complete|disconnect/i.test(data.eventName)) ||
          (data?.action && /close|end|dismiss/i.test(data.action)) ||
          (data?.state && /ended|completed|disconnected/i.test(data.state));

        if (ended) {
          // Flip UI back to ready
          handleLiveAgentCallEnded();
        }
      } catch (e) {
        console.warn("Connect widget message parse error:", e);
      }
    });
    window.__connectMessageListenerAdded = true;
   if (window.removeThinkingMessage) window.removeThinkingMessage();
  }

}

// make callable from websocketEvents.js
window.startWebRTCSession = startWebRTCSession;
function showThinkingMessage() {
  const chatContainer = document.getElementById("chat-container");
  if (!chatContainer) return;

  const messageElement = document.createElement("div");
  messageElement.className = "message systemthinking";
  messageElement.innerHTML = `
    <div class="message-content">
      🤖 Agent is processing<span class="dots"><span>.</span><span>.</span><span>.</span></span>
    </div>
  `;
  chatContainer.appendChild(messageElement);
  chatContainer.scrollTop = chatContainer.scrollHeight;
}
window.showThinkingMessage = showThinkingMessage;

function removeThinkingMessage() {
  const chatContainer = document.getElementById("chat-container");
  if (!chatContainer) return;

  const systemMessages = chatContainer.querySelectorAll(".message.systemthinking");
  for (let msg of systemMessages) {
      msg.remove();
  }
}
window.removeThinkingMessage = removeThinkingMessage;
function addSystemMessage(text) {
  const chatContainer = document.getElementById("chat-container");
  if (!chatContainer) return;

  const messageElement = document.createElement("div");
  messageElement.className = "message system";

  const contentElement = document.createElement("div");
  contentElement.className = "message-content";
  contentElement.textContent = text;

  messageElement.appendChild(contentElement);
  chatContainer.appendChild(messageElement);

  chatContainer.scrollTop = chatContainer.scrollHeight;
}
// Start the session timer
function startSessionTimer() {
  console.log("DEBUG: startSessionTimer() called");
  sessionTime = 0;

  sessionTimer = setInterval(() => {
    // Update session time
    sessionTime++;
    console.log("DEBUG: Timer tick, sessionTime:", sessionTime);

    // Update the timer display
    updateTimerDisplay();
  }, 1000);

  console.log("DEBUG: Timer interval created with ID:", sessionTimer);
}

// Handle audio received from the websocket
function handleAudioReceived(audioData) {
  // In a real implementation, the WebSocketEventManager already takes care of audio playback
  // console.log("Audio data received, length:", audioData.length);
}
const CONNECT_TAG_ID = 'a8c18774-534e-4148-979b-df46be067b7f';

function teardownWebRTCWidget() {
  // Remove Connect widget iframes
  const iframes = Array.from(document.querySelectorAll('iframe'))
    .filter(f => (f.src || '').includes('connectwidget'));
  iframes.forEach(f => f.parentNode?.removeChild(f));

  // Remove injected widget script so a new transfer can re-inject it
  const s = document.getElementById(CONNECT_TAG_ID);
  if (s && s.parentNode) s.parentNode.removeChild(s);

  // Reset global queue to avoid stale state
  try { delete window.amazon_connect; } catch {}
}
window.teardownWebRTCWidget = teardownWebRTCWidget;



function handleLiveAgentCallEnded() {
 window.__handoffInProgress = false;

  if (sessionTimer) { clearInterval(sessionTimer); sessionTimer = null; }

  // Remove widget/script so a fresh transfer works next time
  teardownWebRTCWidget();

  const startButton = document.getElementById("start");
  const stopButton  = document.getElementById("stop");
  if (startButton) startButton.disabled = false;
  if (stopButton)  { stopButton.disabled = true; stopButton.classList.add("hidden"); }

  updateStatus("Disconnected", "disconnected");
  addSystemMessage("Call disconnected — live agent ended the call.");

  // Remove any thinking bubble that might be lingering
  if (window.removeThinkingMessage) window.removeThinkingMessage();

  const appEl = document.getElementById("app");
  const hint  = document.querySelector(".call-hint");
  if (appEl) { appEl.classList.add("pre-call"); appEl.classList.remove("in-call"); }
  hint && (hint.style.display = "inline-block");
}
window.handleLiveAgentCallEnded = handleLiveAgentCallEnded;
// Creates the HTML structure for the interface
function createHtmlStructure() {
  document.body.innerHTML = `
   <div id="app" class="pre-call">
    <!-- HEADER -->
    <header class="header" style="display:flex; justify-content:space-between; align-items:center; padding:1rem; background:#fff; box-shadow:0 2px 4px rgba(0,0,0,0.05);">
      <div class="header-left">
        <a href="/"><img src="/white_caag_logo.png" alt="Logo" class="logo"/></a>
        <h1 style="margin:0; font-size:1.5rem;">Voice Assistant</h1>
      </div>
      <div class="header-right">
       <div class="timer-container">🕐 <span id="timer">0:00</span></div>
        <div id="status" class="disconnected">Disconnected</div>

        <!-- ↓ CALL-BOX MOVED HERE ↓ -->
        <div class="call-box">
          <span class="call-hint">Press “Call me” to speak your request</span>
          <button id="start" class="button">Call me</button>
          <button id="stop"  class="button hidden" disabled>End Call</button>
        </div>
         <iframe id="connect-widget"></iframe>
        <div class="settings-dropdown" style="position:relative;">
          <button id="settings-toggle" class="icon-button">⚙️</button>
          <div id="settings-menu" class="dropdown-menu hidden" style="position:absolute; right:0; top:100%; background:#fff; border:1px solid #ccc; border-radius:4px; box-shadow:0 2px 6px rgba(0,0,0,0.1);">
            <div class="dropdown-item" id="show-prompt-button" style="padding:0.5rem 1rem; cursor:pointer;">Show Prompt</div>
            <div class="dropdown-item" id="logout-button"     style="padding:0.5rem 1rem; cursor:pointer;">Logout</div>
          </div>
        </div>
      </div>
    </header>
 <!-- WELCOME BANNER (new) -->
      <div id="welcome-container" class="welcome-container">
        <h2 id="welcome-text">Digital Support Assistant</h2>
      </div>
    <!-- CHAT -->
    <div id="chat-container">
      <!-- Conversation messages will appear here -->
    </div>
    <!-- SYSTEM PROMPT EDITOR (hidden until toggled) -->
    <div id="system-prompt-container" style="display:none; max-width:600px; margin:1rem auto; background:#fff3e0; padding:1rem; border:1px solid #ccc; border-radius:4px;">
      <div style="display:flex; justify-content:space-between; align-items:center;">
    <h2>System Prompt Editor</h2>
    <!-- ✅ New Close Button -->
    <button id="close-prompt-button"  style="background:none; border:none; font-size:1.2rem; cursor:pointer;" title="Close Prompt Editor">
    <span style="color:#333;">✖</span>
            </button>
  </div>
      <div id="save-confirmation" style="display:none; color:#4caf50; margin-bottom:0.5rem;">Saved!</div>
      <textarea id="system-prompt-textarea" class="system-prompt-textarea" style="width:100%; min-height:150px;"></textarea>
      <div class="prompt-controls" style="text-align:right; margin-top:0.5rem;">
        <button id="save-prompt-button" class="button">Save Prompt</button>
      </div>
    </div>
    </div>
          <div class="footer">
        <div>CAAG Voice Chat Interface v1.0</div>
      </div>
    </div>
  </div>

  `;
  // Ensure audio context is resumed after user interaction
  document.addEventListener(
    "click",
    () => {
      if (
        wsManager &&
        wsManager.audioContext &&
        wsManager.audioContext.state === "suspended"
      ) {
        wsManager.audioContext.resume();
      }
    },
    { once: true }
  );
}
