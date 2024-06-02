const express = require('express');
const app = express();
const port = 80;

app.get('/', (req, res) => {
  res.send('Hello World!');
});

app.get('/healthz', (req, res) => {
  res.status(200).send('OK');
});

app.get('/ready', (req, res) => {
  res.status(200).send('OK');
});

app.get('/load', (req, res) => {
  const end = Date.now() + 10000; // 10 seconds
  while (Date.now() < end) {
    Math.sqrt(Math.random());
  }
  res.send('Load generated');
});

app.listen(port, () => {
  console.log(`Example app listening at http://localhost:${port}`);
});

