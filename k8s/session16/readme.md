# Kubernetes Node.js Application with MySQL

This project demonstrates how to deploy a Node.js application with a MySQL backend on Kubernetes. The setup includes using Kubernetes ConfigMaps for managing application configurations.

## Project Structure
```sh
k8s-webapp/
├── app.js
├── Dockerfile
├── package.json
├── package-lock.json
├── mysql-deployment.yaml
├── webapp-config.yaml
├── webapp-deployment.yaml
├── webapp-service.yaml
└── mysql-init-job.yaml
```

## Prerequisites

- Docker
- Kubernetes cluster (Minikube, GKE, EKS, AKS, etc.)
- kubectl configured to interact with your Kubernetes cluster
- MySQL client tool (optional for local database verification)



###  Create the Node.js Application

Initialize a new Node.js project and install the required dependencies:

```sh
mkdir k8s-webapp
cd k8s-webapp
npm init -y
npm install express mysql

```

## test
```sh
mysql -h mysql -uuser -ppassword dbname
SELECT * FROM test_table;
exit
kubectl delete pod mysql-client
```
or
```sh
kubectl get svc mysql
NAME    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
mysql   ClusterIP   10.96.0.100     <none>        3306/TCP   5m
kubectl port-forward svc/mysql 3306:3306
```
Connect to MySQL using a client tool:

Use the MySQL client tool of your choice to connect to 127.0.0.1:3306 with the following credentials:
```sh
Username: user
Password: password
Database: dbname

SELECT * FROM test_table;
```

