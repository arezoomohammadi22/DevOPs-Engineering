import requests

# Set your GitLab Personal Access Token and the GitLab API endpoint
GITLAB_TOKEN = ""
GITLAB_API = "https://gitlab.sananetco.com/api/v4"

# Set the project path
PROJECT_PATH = "root/app"

# Set the headers
headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}

# Make the GET request to retrieve project information
response = requests.get(f"{GITLAB_API}/projects/{PROJECT_PATH.replace('/', '%2F')}", headers=headers)

# Check the response
if response.status_code == 200:
    project_data = response.json()
    project_id = project_data["id"]
    print(f"Project ID: {project_id}")
else:
    print(f"Failed to retrieve project information. Status code: {response.status_code}")

