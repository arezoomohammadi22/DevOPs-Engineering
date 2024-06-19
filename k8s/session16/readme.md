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
