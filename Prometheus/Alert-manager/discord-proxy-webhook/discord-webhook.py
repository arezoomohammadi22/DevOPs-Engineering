from flask import Flask, request, jsonify
import requests
import os

app = Flask(__name__)

DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/yourtoken"
@app.route("/webhook", methods=["POST"])
def webhook():
    data = request.json
    if not data or "alerts" not in data:
        return jsonify({"error": "Invalid data"}), 400

    messages = []
    for alert in data["alerts"]:
        message = f"**🔥 ALERT 🔥**\n"
        message += f"**🔴 Status:** {alert['status']}\n"
        message += f"**🚨 Alert Name:** {alert['labels'].get('alertname', 'N/A')}\n"
        message += f"**📍 Instance:** {alert['labels'].get('instance', 'N/A')}\n"
        message += f"**📝 Description:** {alert['annotations'].get('summary', 'No description')}\n"
        messages.append(message)

    payload = {"content": "\n\n".join(messages)}
    response = requests.post(DISCORD_WEBHOOK_URL, json=payload)

    if response.status_code != 204:
        return jsonify({"error": "Failed to send message", "discord_response": response.text}), response.status_code

    return jsonify({"success": True}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
