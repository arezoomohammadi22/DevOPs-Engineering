const express = require('express');
const mysql = require('mysql');
const app = express();
const port = 8080;

// Get environment variables from the ConfigMap
const dbUrl = process.env.DATABASE_URL || 'Not Set';
const appEnv = process.env.APP_ENV || 'Not Set';
const logLevel = process.env.LOG_LEVEL || 'Not Set';

// Parse the DATABASE_URL for MySQL connection parameters
const dbUrlRegex = /mysql:\/\/(.*):(.*)@(.*):(.*)\/(.*)/;
const [ , dbUser, dbPassword, dbHost, dbPort, dbName ] = dbUrl.match(dbUrlRegex);

// Create a MySQL connection pool
const pool = mysql.createPool({
  connectionLimit: 10,
  host: dbHost,
  user: dbUser,
  password: dbPassword,
  database: dbName,
  port: dbPort
});

// Endpoint to insert a record into the database
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

// Endpoint to read records from the database
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

// Main endpoint
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
