const express = require('express');
const app = express();
const port = 3000;

app.get('/health', (req, res) => {
  res.send('✅ Backend is healthy');
});

app.get('/api', (req, res) => {
  res.json({ message: 'Hello from Backend API!' });
});

app.listen(port, () => {
  console.log(`Backend running on port ${port}`);
});
