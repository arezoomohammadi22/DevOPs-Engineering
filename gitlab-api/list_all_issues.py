import requests

# Replace with your GitLab personal access token
ACCESS_TOKEN = 'your_personal_access_token'
# Replace with your GitLab instance URL if it's self-hosted, otherwise use the default
GITLAB_URL = 'https://gitlab.com'
# Replace with the ID of your GitLab project
PROJECT_ID = 'your_project_id'

def get_all_issues(project_id):
    headers = {
        'Private-Token': ACCESS_TOKEN
    }
    
    issues = []
    page = 1

    while True:
        response = requests.get(f'{GITLAB_URL}/api/v4/projects/{project_id}/issues', headers=headers, params={'page': page, 'per_page': 100})
        response.raise_for_status()
        issues_page = response.json()

        if not issues_page:
            break

        issues.extend(issues_page)
        page += 1

    return issues

if __name__ == '__main__':
    issues = get_all_issues(PROJECT_ID)
    print(f'Total issues: {len(issues)}')
    for issue in issues:
        print(f"Issue ID: {issue['id']}, Title: {issue['title']}, State: {issue['state']}")
