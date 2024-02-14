import requests

# Set your GitLab Personal Access Token and the GitLab API endpoint
GITLAB_TOKEN = "YOUR_PERSONAL_ACCESS_TOKEN"
GITLAB_API = "https://gitlab.com/api/v4"

# Set the project ID and branch name
PROJECT_ID = "YOUR_PROJECT_ID"
BRANCH_NAME = "new-branch-name"

# Set the headers
headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}

# Set the data for the POST request
data = {"branch": BRANCH_NAME, "ref": "master"}

# Make the POST request to create the branch
response = requests.post(f"{GITLAB_API}/projects/{PROJECT_ID}/repository/branches", headers=headers, data=data)

# Check the response
if response.status_code == 201:
    print("Branch created successfully.")
else:
    print(f"Failed to create branch. Status code: {response.status_code}")

