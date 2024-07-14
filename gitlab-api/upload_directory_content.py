import os
import base64
import requests

# Set your GitLab Personal Access Token and the GitLab API endpoint
GITLAB_TOKEN = 'your_personal_access_token'
GITLAB_API = 'https://gitlab.sananetco.com'
PROJECT_ID = 'your_project_id'
BRANCH_NAME = 'main'  # Replace with the branch you want to upload to

# Directory to upload
DIRECTORY_PATH = 'deploy'

# Set the headers
headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}

def get_files_in_directory(directory):
    file_paths = []
    for root, _, files in os.walk(directory):
        for file in files:
            file_path = os.path.join(root, file)
            file_paths.append(file_path)
    return file_paths

def upload_file_to_gitlab(api_url, headers, project_id, branch_name, file_path, target_path):
    with open(file_path, 'rb') as file:
        file_content = file.read()
    
    encoded_content = base64.b64encode(file_content).decode('utf-8')
    file_name = os.path.relpath(target_path, DIRECTORY_PATH)

    data = {
        'branch': branch_name,
        'content': encoded_content,
        'commit_message': f'Add {file_name}',
        'encoding': 'base64'
    }

    response = requests.post(f"{api_url}/api/v4/projects/{project_id}/repository/files/{file_name}", headers=headers, json=data)
    
    if response.status_code == 201:
        print(f"Successfully uploaded {file_name}")
    elif response.status_code == 400 and 'A file with this name already exists' in response.json().get('message', ''):
        print(f"File {file_name} already exists. Updating file.")
        data['commit_message'] = f'Update {file_name}'
        response = requests.put(f"{api_url}/api/v4/projects/{project_id}/repository/files/{file_name}", headers=headers, json=data)
        if response.status_code == 200:
            print(f"Successfully updated {file_name}")
        else:
            print(f"Failed to update {file_name}. Status code: {response.status_code}, Message: {response.json()}")
    else:
        print(f"Failed to upload {file_name}. Status code: {response.status_code}, Message: {response.json()}")

# Retrieve all files in the directory
files_to_upload = get_files_in_directory(DIRECTORY_PATH)

# Upload each file to GitLab
for file_path in files_to_upload:
    upload_file_to_gitlab(GITLAB_API, headers, PROJECT_ID, BRANCH_NAME, file_path, file_path)
