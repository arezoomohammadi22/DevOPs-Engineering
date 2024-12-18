from flask import Flask, request, jsonify
import mysql.connector

app = Flask(__name__)

# MySQL configuration
db_config = {
    'host': 'mysql',
    'user': 'user',
    'password': 'password',
    'database': 'dbname'
}

@app.route('/api/data', methods=['POST'])
def insert_data():
    data = request.json.get('data')
    if not data:
        return jsonify({'error': 'Data is required'}), 400

    try:
        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor()
        cursor.execute("INSERT INTO test_table (data) VALUES (%s)", (data,))
        connection.commit()
        cursor.close()
        connection.close()
        return jsonify({'message': 'Data inserted successfully'}), 201
    except mysql.connector.Error as err:
        return jsonify({'error': str(err)}), 500

@app.route('/api/data', methods=['GET'])
def fetch_data():
    try:
        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor()
        cursor.execute("SELECT * FROM test_table")
        rows = cursor.fetchall()
        cursor.close()
        connection.close()
        return jsonify({'data': rows}), 200
    except mysql.connector.Error as err:
        return jsonify({'error': str(err)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
