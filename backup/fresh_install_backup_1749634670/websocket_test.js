#!/usr/bin/env node

// Simple WebSocket test for ActionCable endpoint using Node.js built-in WebSocket
// Created: 2025-06-04 07:28:00
// Updated: 2025-06-04 07:29:00 - Switched to Node.js built-in WebSocket
// Purpose: Debug ActionCable connection issues

const { WebSocket } = require('undici');

const url = 'wss://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/cable';

console.log('🔌 Testing ActionCable WebSocket Connection...');
console.log(`📍 URL: ${url}`);
console.log('⏳ Connecting...\n');

const ws = new WebSocket(url, {
  headers: {
    'Origin': 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
  }
});

ws.onopen = function open() {
  console.log('✅ WebSocket Connection OPENED');
  console.log('🔍 ReadyState:', ws.readyState);
  
  // Send ActionCable subscribe message
  const subscribeMessage = {
    command: 'subscribe',
    identifier: JSON.stringify({
      channel: 'RoomChannel',
      pubsub_token: 'test-token'
    })
  };
  
  console.log('📤 Sending subscribe message:', JSON.stringify(subscribeMessage));
  ws.send(JSON.stringify(subscribeMessage));
};

ws.onmessage = function message(event) {
  console.log('📥 Received:', event.data);
};

ws.onerror = function error(err) {
  console.error('❌ WebSocket Error:', err);
};

ws.onclose = function close(event) {
  console.log(`🔌 WebSocket Connection CLOSED`);
  console.log(`🔍 Close Code: ${event.code}`);
  console.log(`🔍 Close Reason: ${event.reason}`);
  console.log(`🔍 Was Clean: ${event.wasClean}`);
};

// Timeout after 10 seconds
setTimeout(() => {
  if (ws.readyState === WebSocket.OPEN) {
    console.log('⏰ Timeout reached, closing connection...');
    ws.close();
  }
  process.exit(0);
}, 10000); 