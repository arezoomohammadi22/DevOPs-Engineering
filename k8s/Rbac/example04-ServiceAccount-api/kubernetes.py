import requests

# Replace with your token and API server address
token = "YOUR_SERVICE_ACCOUNT_TOKEN"
api_server = "https://your-k8s-api-server"

# Example API call to get pods
headers = {
    "Authorization": f"Bearer {token}"
}
response = requests.get(f"{api_server}/api/v1/namespaces/core/pods", headers=headers, verify='/path/to/ca.crt')

# Print the response
print(response.json())
