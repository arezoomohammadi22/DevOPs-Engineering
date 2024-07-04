import os
import subprocess
from flask import Flask, request
from flask_mail import Mail, Message
import requests
app = Flask(__name__)

app.config['MAIL_SERVER'] = 'Mail.sananetco.com'
app.config['MAIL_PORT'] = 587
app.config['MAIL_USERNAME'] = 'notification@syoudomain'
app.config['MAIL_PASSWORD'] = 'password'
app.config['MAIL_USE_TLS'] = True
app.config['MAIL_USE_SSL'] = False

mail = Mail(app)


@app.route('/renew', methods=['GET'])
def run_script():
    # Path to your Python script file
    script_path = 'renew_ip.py'
    # Run the script as a subprocess
    output = subprocess.check_output(['python3', script_path])
    return output.decode('utf-8')


@app.route('/sendmail', methods=['POST'])
def email():
    data = request.get_json()
    recipients = data.get('recipients', [])
    body = data.get('body', '')
    subject = data.get('subject', 'notification')
    if not recipients:
        return 'Please provide at least one recipient.', 400
    msg = Message(
        subject=subject,
        sender='notification@yourdomain',
        recipients=recipients
    )
    msg.body = body or 'Hello Flask message sent from Flask-Mail'
    mail.send(msg)
    return 'Sent'


@app.route('/attach', methods=['POST'])
def attach():
    data = request.get_json()
    recipients = data.get('recipients', [])
    body = data.get('body', '')
    subject = data.get('subject', 'notification')
    if not recipients:
        return 'Please provide at least one recipient.', 400

    # Path to the config file to be sent as an attachment
    file_path = 'config'

    # Create the message object
    msg = Message(
        subject=subject,
        sender='notification@yourdomain',
        recipients=recipients
    )
    msg.body = body or 'Hello Flask message sent from Flask-Mail'

    # Attach the config file to the email
    with app.open_resource(file_path) as fp:
        msg.attach(os.path.basename(file_path), 'text/plain', fp.read())

    # Send the email
    mail.send(msg)

    return 'Sent'


@app.route('/access', methods=['POST'])
def createuser():
    data = request.get_json()
    username = data.get('username')
    namespace = data.get('namespace')
    email = data.get('email')
    # Run the script to create the user
    script_path = 'accesstouser.py'
    output = subprocess.check_output(['python3', script_path, username, namespace])
    result = output.decode('utf-8')

    # Call the attach() endpoint to send the config file as an attachment
    attach_data = {
        'recipients': [email],
        'subject': 'Config file',
        'body': 'Please find attached the config file for your project'
    }
    response = requests.post('http://localhost:3000/attach', json=attach_data)
    if response.status_code == 200:
     return 'Config file has been sent successfully'
    else:
        if response.status_code != 200:
            return 'Error sending config file', response.status_code
    return 'Unknown error occurred'


@app.route('/rbac', methods=['POST'])
def rbac():
    data = request.get_json()
    username = data.get('username')
    namespace = data.get('namespace')
    # Run the script to create the user
    script_path = 'rbac.py'
    output = subprocess.check_output(['python3', script_path, username, namespace])
    result = output.decode('utf-8')
    return result

@app.route('/telegram', methods=['POST'])
def handle_telegram_alert():
    alert = request.json
    handle_alert(alert)
    return 'OK'

@app.route('/createvm', methods=['POST'])
def create():
    script_path = 'crawler.py'
    # Run the script as a subprocess
    output = subprocess.check_output(['python3', script_path])
    return output.decode('utf-8')



if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port="3000")
