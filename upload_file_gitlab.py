import requests

# Set your GitLab Personal Access Token and the GitLab API endpoint
GITLAB_TOKEN = ""
GITLAB_API = "https://gitlab.sananetco.com/api/v4"

# Set the project ID and file details
PROJECT_ID = "YOUR_PROJECT_ID"
FILE_PATH = "path/to/new/file.txt"
BRANCH_NAME = "master"  # or any other branch name
COMMIT_MESSAGE = "Upload new file via API"
CONTENT = "Content of the new file"

# Set the headers
headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}

# Prepare the data for the API request
data = {
    "branch": BRANCH_NAME,
    "commit_message": COMMIT_MESSAGE,
    "content": CONTENT
}

# Make the POST request to create the file
response = requests.post(
    f"{GITLAB_API}/projects/{PROJECT_ID}/repository/files/{FILE_PATH}",
    headers=headers,
    json=data
)

# Check the response
if response.status_code == 201:
    print("File uploaded successfully.")
else:
    print(f"Failed to upload file. Status code: {response.status_code}")
    print(response.json())
