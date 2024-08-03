# import os
import yaml
import base64
import subprocess
from kubernetes import client, config


# Load kubeconfig file
config.load_kube_config()


# Set context to specific cluster
config.current_context = ''
# Create Kubernetes API client
v1 = client.CoreV1Api()


# Prompt the user for input
username = input("Enter username: ")
namespace = input("Enter namespace: ")

# Generate a new certificate and private key for the user
subprocess.run(f"openssl genrsa -out '{username}.key' 2048;", shell=True)
subprocess.run(f"openssl req -new -key {username}.key -out {username}.csr -subj '/CN={username}';", shell=True)
subprocess.run(f"openssl x509 -req -in {username}.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out {username}.crt -days 500;", shell=True)
subprocess.run(f"kubectl config set-credentials {username} --client-certificate={username}.crt --client-key={username}.key", shell=True)


# Read the certificate and private key into memory
with open(f"{username}.crt", "r") as f:
    cert_data = f.read()

with open(f"{username}.key", "r") as f:
    key_data = f.read()


# Encode certificate and private key as base64 strings
cert_b64 = base64.b64encode(cert_data.encode('ascii')).decode('ascii')
key_b64 = base64.b64encode(key_data.encode('ascii')).decode('ascii')


# Create a new Kubernetes Secret with the user's certificate and private key
v1.create_namespaced_secret(namespace, {
    "metadata": {
        "name": f"{username}-tls",
        "namespace": namespace
    },
    "type": "tls",
    "data": {
        "tls.crt": cert_b64,
        "tls.key": key_b64
    }
})

# Grant the user access to the specified namespace and resources
rbac_api = client.RbacAuthorizationV1Api()
role = {
    "apiVersion": "rbac.authorization.k8s.io/v1",
    "kind": "Role",
    "metadata": {
        "name": f"{username}-role",
        "namespace": namespace
    },
    "rules": [
        {
            "apiGroups": ["*"],
            "resources": ["*"],
            "verbs": ["*"]
        }
    ]
}

rbac_api.create_namespaced_role(namespace, role)

role_binding = {
    "apiVersion": "rbac.authorization.k8s.io/v1",
    "kind": "RoleBinding",
    "metadata": {
        "name": f"{username}-rolebinding",
        "namespace": namespace
    },
    "subjects": [
        {
            "kind": "User",
            "name": username
        }
    ],
    "roleRef": {
        "kind": "Role",
        "name": f"{username}-role",
        "apiGroup": "rbac.authorization.k8s.io"
    }
}

rbac_api.create_namespaced_role_binding(namespace, role_binding)

print(f"User {username} has been created and granted access to namespace {namespace}.")

# Generate kubeconfig file for the user
kubeconfig = {
    "apiVersion": "v1",
    "kind": "Config",
    "clusters": [
        {
            "name": "",
            "cluster": {
                "certificate-authority-data": "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMvakNDQWVhZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJeU1USXlNREV6TWpFd04xb1hEVE15TVRJeE56RXpNakV3TjFvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTkpnClEwL2tUMDNNU2g1TCtHRlppRzNNZ1JwSHYvUkRMRnR5L3lNZFVkT0lXZzJJcmpBRUlDVXp6bnZYbWJoUkliS04KbXJxczNVM1FkYWZjR0lwZVlDcnRHUjFBaFVVb05FS0E5cVZ0MEhLQUpkem1hNFlQcHZNTnk0RTRHL1ZPWFp0dApVcHhoZHRyZ3JpT0R3dG9tbXk4QkEwTStjbWFYalgxZFprbm92eHpZaEJIMDg1ZjFGc2M5eTBhOWVxVUdhd094CnFMYTFLSEZ4NWsvcmZ6RndOMzNaYkNaSGVJWmlnVWdraTVkclQ5YkIvK21Bd0lTMTZsUDh0S0xMdHpyU2xabk8KN05BdVZlaXd3ZmNDTDlUNjBTbXRwYlgxY2FnWk9WN2h3bzVMcCtqa0ZIYXJ3cW9oUFdtaGdWQmZHaVFpb0V1OQp3TFQ5bFpBVEpUZFpkVUZST1kwQ0F3RUFBYU5aTUZjd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0hRWURWUjBPQkJZRUZDMDA2MUpabmJxYVpYVXNyRWZEY1RieEx4c3JNQlVHQTFVZEVRUU8KTUF5Q0NtdDFZbVZ5Ym1WMFpYTXdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBR1Vvc04xcXdkcytJZzRMZ2JUOQpaRmVaazM4Yys2SldtM1I4VEVidWNGazJpTlVPci9JbTJvT3NaK1Q0YkM5dGh3aHdVTUo1aXd3YlJaOVZKM3FrCk9lc3RZZ3BJZlE1QnlaNGlHN00zelFLelp5eSsyTTFRaWJvZm43R1Zod3RzNHEvNW5BMWNCem10YzhjaHdlTmsKbktDbW1HOEQrOGZoRW5xYnppS2NqNTdmNEwwNUFrbW1PcDlWQ2Z5ZGYzcHVyb3lWc0ttYmgzWG5tK0VaL1VZbwoyb2VTRWZBZzQxS1dhZXlRb0xXa284SGdiZDhKalU0ZTByVWVpRFVXY0M1d2JoUFVqQk5MUWFJZTZjQzNKYUt5CjVyNWNXNFIzRWluMHozOURCekRWQTRzcEFQY1JoU3JXSnUxMzFBK0pHaW9GVDBtMTVjcURLTnpnYUxRTThyR0YKOHowPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==",
                "server": "https://:6443"
            }
        }
    ],
    "contexts": [
        {
            "name": f"{username}@{namespace}",
            "context": {
                "cluster": "",
                "user": username,
                "namespace": namespace
            }
        }
    ],
    "current-context": f"{username}@{namespace}",
    "users": [
        {
            "name": username,
            "user": {
                "client-certificate-data": cert_b64,
                "client-key-data": key_b64
            }
        }
    ]
}

# Encode kubeconfig as YAML and save to file
with open(f"config", "w") as f:
    f.write(yaml.dump(kubeconfig))

print(f"Kubeconfig file for user {username} has been created.")
