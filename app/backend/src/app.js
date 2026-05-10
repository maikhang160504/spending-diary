const express = require('express');
const cors = require('cors');
const helmet = require('helmet'); // B?o m?t Header

// const storyRoutes = require('./routes/storyRoutes');
// const authRoutes = require('./routes/authRoutes');
const { errorHandler } = require('./middlewares/errorHandler');

const app = express();

// Middlewares
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
// app.use('/api/v1/auth', authRoutes);
// app.use('/api/v1/stories', storyRoutes);

// Error Handling (Luôn d?t cu?i cùng)
app.use(errorHandler);

module.exports = app;
