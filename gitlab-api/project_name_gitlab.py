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

# Retrieve all projects
all_projects = get_all_projects(GITLAB_API, headers)

# Extract project names from the response
project_names = [project['name'] for project in all_projects]

# Print the project names
print("Project Names:")
for name in project_names:
    print(name)
