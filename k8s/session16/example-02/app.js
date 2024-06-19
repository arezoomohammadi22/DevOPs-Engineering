const express = require('express');
const mysql = require('mysql');
const app = express();
const port = 8080;

const dbUser = process.env.MYSQL_USER || 'Not Set';
const dbPassword = process.env.MYSQL_PASSWORD || 'Not Set';
const dbHost = process.env.MYSQL_HOST || 'mysql';
const dbPort = process.env.MYSQL_PORT || '3306';
const dbName = process.env.MYSQL_DATABASE || 'Not Set';
const dbUrl = `mysql://${dbUser}:${dbPassword}@${dbHost}:${dbPort}/${dbName}`;

const appEnv = process.env.APP_ENV || 'Not Set';
const logLevel = process.env.LOG_LEVEL || 'Not Set';

const pool = mysql.createPool({
  connectionLimit: 10,
  host: dbHost,
  user: dbUser,
  password: dbPassword,
  database: dbName,
  port: dbPort
});

app.get('/write', (req, res) => {
  const query = 'INSERT INTO test_table (data) VALUES (?)';
  const data = 'Hello, Kubernetes!';

  pool.query(query, [data], (error, results) => {
    if (error) {
      res.status(500).send('Error writing to database: ' + error.message);
      return;
    }
    res.send('Data written to database, ID: ' + results.insertId);
  });
});

app.get('/read', (req, res) => {
  const query = 'SELECT * FROM test_table';

  pool.query(query, (error, results) => {
    if (error) {
      res.status(500).send('Error reading from database: ' + error.message);
      return;
    }
    res.send(results);
  });
});

app.get('/', (req, res) => {
  res.send(`
    <h1>Node.js Web Application</h1>
    <p>Database URL: ${dbUrl}</p>
    <p>App Environment: ${appEnv}</p>
    <p>Log Level: ${logLevel}</p>
    <p><a href="/write">Write to Database</a></p>
    <p><a href="/read">Read from Database</a></p>
  `);
});

app.listen(port, () => {
  console.log(`App running on http://localhost:${port}`);
});
