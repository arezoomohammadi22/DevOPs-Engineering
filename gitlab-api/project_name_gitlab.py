import requests

# Set your GitLab Personal Access Token and the GitLab API endpoint
GITLAB_TOKEN = "glpat-PnHg6DaXRek64HxVrLwR"
GITLAB_API = "https://gitlab.sananetco.com/api/v4"

# Set the headers
headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}

# Make the GET request to retrieve the list of projects
response = requests.get(f"{GITLAB_API}/projects", headers=headers)

# Check the response
if response.status_code == 200:
    projects = response.json()
    # Extract project names from the response
    project_names = [project['name'] for project in projects]
    print("Project Names:")
    for name in project_names:
        print(name)
else:
    print(f"Failed to retrieve projects. Status code: {response.status_code}")
