const express = require('express');
const app = express();
const port = 80;

app.get('/', (req, res) => {
  res.send('Hello World!');
});

app.get('/healthz', (req, res) => {
  // You can add custom health check logic here
  res.status(200).send('OK');
});

app.get('/ready', (req, res) => {
  // You can add custom readiness check logic here
  res.status(200).send('OK');
});

app.listen(port, () => {
  console.log(`Example app listening at http://localhost:${port}`);
});
