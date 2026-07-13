const axios = require('axios');

class WeatherService {
  constructor() {
    this.apiKey = process.env.WEATHER_API_KEY || process.env.WEATHER_API || ''; // Needs to be configured in .env
    this.cache = new Map();
    this.CACHE_DURATION = 3 * 60 * 60 * 1000; // 3 hours
  }

  async getWeather(lat, lng) {
    if (!this.apiKey) return 'không rõ'; // Fallback if no API key
    
    // Default to Ho Chi Minh City if no coordinates are provided
    const query = (lat && lng) ? `${lat},${lng}` : '10.8231,106.6297';
    
    const now = Date.now();
    const cacheKey = query;
    if (this.cache.has(cacheKey)) {
      const cached = this.cache.get(cacheKey);
      if (now - cached.timestamp < this.CACHE_DURATION) {
        return cached.condition;
      }
    }

    try {
      const response = await axios.get(`http://api.weatherapi.com/v1/current.json?key=${this.apiKey}&q=${query}&lang=vi`);
      const condition = response.data?.current?.condition?.text?.toLowerCase() || 'bình thường';
      
      this.cache.set(cacheKey, {
        condition,
        timestamp: now
      });
      
      return condition;
    } catch (error) {
      console.error('Weather API Error:', error.message);
      return 'không rõ';
    }
  }
}

module.exports = new WeatherService();
