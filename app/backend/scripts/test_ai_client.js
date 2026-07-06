const axios = require('axios');

async function test() {
  const url = 'https://maikhang160504--expense-ocr-nlu-fastapi-app.modal.run/api/v1/nlu/infer';
  console.log('Sending request to:', url);
  try {
    const res = await axios.post(url, {
      text: 'tôi đã mua 1 ly cà phê sữa 20k',
      run_llm: true
    }, {
      timeout: 120000
    });
    console.log('Success! Status:', res.status);
    console.log('Data:', JSON.stringify(res.data, null, 2));
  } catch (err) {
    console.error('Error occurred!');
    if (err.response) {
      console.error('Response Status:', err.response.status);
      console.error('Response Data:', err.response.data);
    } else {
      console.error('Error Message:', err.message);
      console.error('Error Code:', err.code);
    }
  }
}

test();
