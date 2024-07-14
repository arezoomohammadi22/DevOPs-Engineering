import requests

# Replace with your GitLab personal access token
ACCESS_TOKEN = 'your_personal_access_token'
# Replace with your GitLab instance URL if it's self-hosted, otherwise use the default
GITLAB_URL = 'https://gitlab.com'

def get_all_project_ids():
    headers = {
        'Private-Token': ACCESS_TOKEN
    }
    
    project_ids = []
    page = 1

    while True:
        response = requests.get(f'{GITLAB_URL}/api/v4/projects', headers=headers, params={'page': page, 'per_page': 100})
        response.raise_for_status()
        projects = response.json()

        if not projects:
            break

        for project in projects:
            project_ids.append(project['id'])

        page += 1

    return project_ids

if __name__ == '__main__':
    project_ids = get_all_project_ids()
    print(f'Total projects: {len(project_ids)}')
    print('Project IDs:', project_ids)
