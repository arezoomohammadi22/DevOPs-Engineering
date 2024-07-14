curl --request POST --header "PRIVATE-TOKEN: your_personal_access_token" \
     --header "Content-Type: application/json" \
     --data '{
       "branch": "test",
       "ref": "main"
     }' \
     "https://gitlab.sananetco.com/api/v4/projects/your_project_id/repository/branches"
