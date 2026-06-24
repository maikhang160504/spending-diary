'use strict';
require('dotenv').config();
const aiClient = require('../src/services/aiClient');

async function test() {
  console.log('Testing connection to AI Service...');
  try {
    const health = await aiClient.health();
    console.log('AI Service Health Check:', health);

    console.log('Sending test message to NLU...');
    const result = await aiClient.aiChat(
      [
        { role: 'user', content: 'xem phim 50k' }
      ],
      'test-user-123'
    );
    console.log('NLU Inference Result:', JSON.stringify(result, null, 2));

    const comment = result.gemini_json?.response || result.gemini_json?.story || result.nlg_response;
    console.log('Extracted Comment:', comment);
    if (comment) {
      console.log('SUCCESS: Comment generation is working!');
    } else {
      console.log('WARNING: Comment field is empty, fallback will be used.');
    }
  } catch (err) {
    console.error('ERROR during testing:', err.message, err.stack);
  }
}

test();
