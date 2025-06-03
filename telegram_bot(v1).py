import requests

# Global dictionary to store the mapping of "firing" alerts to their message IDs
alert_message_ids = {}
prometheus_message_id = {}
team_dict = {"hotel": "", "devops": "", "ticket": "", "shared": "	", "data": ""}
bot_token = ""


def send_telegram_message(bot_token, chat_id, message, reply_to_message_id=None):
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    params = {
        "chat_id": chat_id,
        "text": message,
        "reply_to_message_id": reply_to_message_id
    }

    response = requests.post(url, params=params)

    if response.status_code != 200:
        print(f"Failed to send Telegram message. Error: {response.text}")
    else:
        print("Telegram message sent successfully!")
    
    return response

def send_telegram_message_devops(bot_token, chat_id_devops, message, reply_to_message_id=None):
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    params = {
        "chat_id": chat_id_devops,
        "text": message,
        "reply_to_message_id": reply_to_message_id
    }

    response = requests.post(url, params=params)

    if response.status_code != 200:
        print(f"Failed to send Telegram message. Error: {response.text}")
    else:
        print("Telegram message sent successfully!")
    
    return response


def handle_telegram_alert(alert):
    # Check if the alert is from Prometheus or Zabbix
    if 'EVENT.STATUS' in alert:
        # Zabbix alert format
        send_zabbix_alert_to_telegram(alert)
    elif 'alerts' in alert:
        handle_alert(alert)
    else:
        print("Unknown alert format.")

def handle_alert(alert):
    global alert_message_ids

    alerts = alert.get('alerts', [])

    for alert in alerts:
        team = alert['labels'].get('teamname')

        chat_id = team_dict[team]

        status = alert.get('status', '')
        alertname = alert['labels'].get('alertname', '')
        instance = alert['labels'].get('instance', 'N/A')
        job = alert['labels'].get('job', 'N/A')
        summary = alert['annotations'].get('summary', '')
        description = alert['annotations'].get('description', '')

        # Customize the alert message as per your requirement
        status_emoji = "🛑" if status == 'firing' else "✅"
        message = f"Prometheus Alert:\n\nStatus: {status_emoji} {status.capitalize()}\nAlert Name: {alertname}\nHost: {instance}\nJob: {job}\nSummary: {summary}\n\nDescription: {description}"

        print("Sending message to Telegram...")
        print(f"Message: {message}")

        if status == 'firing':
            # Send the "firing" alert message
            response = send_telegram_message(bot_token, chat_id, message)
            chat_id_devops = -1001960208571
            response = send_telegram_message_devops(bot_token, chat_id_devops, message)

            if response.status_code == 200:
                # Store the message ID in the dictionary
                alert_message_ids[alertname] = response.json().get('result', {}).get('message_id', '')
            else:
                print(f"Failed to send Telegram message for firing alert: {alertname}")
        elif status == 'resolved':
            # Check if the corresponding "firing" alert's message ID exists
            firing_message_id = alert_message_ids.get(alertname)

            if firing_message_id:
                # Create the "resolved" message and send it as a reply to the "firing" message
                resolved_message = f"Resolved Alert:\n\nStatus: {status_emoji} {status.capitalize()}\nAlert Name: {alertname}\nHost: {instance}\nJob: {job}\nSummary: {summary}\n\nDescription: {description}"

                print("Sending resolved message to Telegram...")
                print(f"Message: {resolved_message}")

                send_telegram_message(bot_token, chat_id, resolved_message, reply_to_message_id=firing_message_id)
                send_telegram_message(bot_token, chat_id_devops, resolved_message, reply_to_message_id=firing_message_id)

                alert_message_ids.pop(alertname)
            else:
                print(f"Failed to find corresponding firing message ID for resolved alert: {alertname}")
        else:
            print(f"Unknown status '{status}' received for alert: {alertname}")


def send_zabbix_alert_to_telegram(alert):
    # Extract Zabbix alert data from the 'alert' dictionary
    status = alert.get('EVENT.STATUS', '')
    event_message = alert.get('EVENT.MESSAGE', '')
    event_id = alert.get('EVENT.ID', '')

    print(event_id)
    print(event_message)

    # Customize the alert message as per your requirement
    status_emoji = "🛑" if status == 'firing' else "✅"
    message = f"Zabbix Alert:\n\nStatus: {status_emoji} {status.capitalize()}\n{event_message}"

    if status == 'firing':
        chat_id = -1001960208571
        response = send_telegram_message(bot_token, chat_id, message)

        if response.status_code == 200:
            # Store the message ID in the dictionary
            alert_message_ids[event_id] = response.json().get('result', {}).get('message_id', '')
            print(f"alert message id event_message is : {alert_message_ids[event_id]}")
            print(f"response json is: {response.json().get('result', {})}")
        else:
            print(f"Failed to send Telegram message for firing alert: {event_id}")
    elif status == 'resolved':
        # Check if the corresponding "firing" alert's message ID exists
        firing_message_id = alert_message_ids.get(event_id)
        # event = (f"event message is {event_message}")

        print(f"firing message id is:{firing_message_id}")
        print(alert_message_ids)

        if firing_message_id:
            # Create the "resolved" message and send it as a reply to the "firing" message
            resolved_message = f"Zabbix Alert:\n\nStatus: {status_emoji} {status.capitalize()}\n{event_message}"

            print("Sending resolved message to Telegram...")
            print(f"Message: {resolved_message}")

            response = send_telegram_message(bot_token, chat_id, resolved_message, reply_to_message_id=firing_message_id)
            if response.status_code == 200:
                print("Reply message sent successfully!")
                alert_message_ids.pop(event_id)
            else:
                print(f"Failed to send reply message for resolved alert: {event_message}")
        else:
            print(f"Failed to find corresponding firing message ID for resolved alert: {event_message}")
    else:
        print(f"Unknown status '{status}' received for alert: {event_message}")


if __name__ == '__main__':
    # Example Prometheus Alert
    example_prometheus_alert = {
        'alerts': [
            {
                'status': 'firing',
                'labels': {
                    'teamname': 'data',
                    'alertname': 'HighErrorRate',
                    'instance': 'server1.example.com',
                    'job': 'web-server',
                },
                'annotations': {
                    'summary': 'High error rate detected!',
                    'description': 'The error rate is above the threshold.',
                },
            }
        ]
    }
    
    handle_alert(example_prometheus_alert)

    # Example Zabbix Alert
    example_zabbix_alert = {
        'EVENT.STATUS': 'firing',
        'EVENT.DATE': '2023-07-29',
        'EVENT.TIME': '12:34:56',
        'EVENT.NAME': 'High CPU Usage',
        'HOST.NAME': 'Server1',
        'EVENT.SEVERITY': 'High',
        'EVENT.OPDATA': 'Some operational data here...',
        'EVENT.ID': '12345',
        'TRIGGER.URL': 'https://your_zabbix_instance/triggers/12345',
    }

    handle_telegram_alert(example_zabbix_alert)
