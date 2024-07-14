import requests

# Set your GitLab Personal Access Token and the GitLab API endpoint
GITLAB_TOKEN = 'your_personal_access_token'
GITLAB_API = 'https://gitlab.sananetco.com'

# Set the headers
headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}

def get_all_projects(api_url, headers):
    projects = []
    page = 1
    per_page = 100  # Number of projects per page (maximum is 100)

    while True:
        response = requests.get(f"{api_url}/api/v4/projects", headers=headers, params={'page': page, 'per_page': per_page})
        if response.status_code != 200:
            print(f"Failed to retrieve projects. Status code: {response.status_code}")
            break
        
        page_projects = response.json()
        if not page_projects:
            break
        
        projects.extend(page_projects)
        page += 1

    return projects

def create_branch(api_url, headers, project_id, branch_name, ref):
    payload = {
        'branch': branch_name,
        'ref': ref
    }
    response = requests.post(f"{api_url}/api/v4/projects/{project_id}/repository/branches", headers=headers, json=payload)
    
    if response.status_code == 201:
        print(f"Successfully created branch '{branch_name}' in project ID {project_id}")
    elif response.status_code == 400 and 'Branch already exists' in response.json().get('message', ''):
        print(f"Branch '{branch_name}' already exists in project ID {project_id}")
    else:
        print(f"Failed to create branch '{branch_name}' in project ID {project_id}. Status code: {response.status_code}, Message: {response.json()}")

# Retrieve all projects
all_projects = get_all_projects(GITLAB_API, headers)

# Create a new branch named 'test' for each project
branch_name = 'test'
ref = 'main'  # Replace with the branch or tag you want to base the new branch on (e.g., 'master', 'main', etc.)

for project in all_projects:
    create_branch(GITLAB_API, headers, project['id'], branch_name, ref)
