# MySQL Group Replication in Kubernetes

## Overview
This project sets up a **MySQL Group Replication cluster** using Kubernetes **StatefulSet**. The setup ensures high availability and fault tolerance with a **multi-master MySQL cluster**, where each node can accept writes and automatically failover if a node crashes.

## Features
- **MySQL Group Replication** for high availability.
- **StatefulSet** ensures stable pod identities.
- **Persistent storage** so data is not lost when pods restart.
- **Automatic failover** when a node crashes.
- **Headless service** for stable DNS resolution.

## Architecture
The cluster consists of:
- A **headless service (`mysql`)** to enable stable DNS.
- A **StatefulSet (`mysql`)** with at least 3 replicas.
- Each MySQL pod starts as part of the Group Replication cluster.

## Deployment

### **1. Clone the Repository**

### **2. Deploy MySQL Headless Service**
```bash
kubectl apply -f mysql-service.yaml
```

### **3. Deploy MySQL StatefulSet**
```bash
kubectl apply -f mysql-statefulset.yaml
```

### **4. Verify MySQL Group Replication**
Check if all nodes joined the replication group:
```bash
kubectl exec -it mysql-0 -- mysql -uroot -prootpassword -e "SELECT * FROM performance_schema.replication_group_members;"
```

If successful, you will see all **3 MySQL nodes** listed in the group.

### **5. Simulate a Node Failure**
To test automatic failover, delete a pod:
```bash
kubectl delete pod mysql-0
```
Then, check the group members again:
```bash
kubectl exec -it mysql-1 -- mysql -uroot -prootpassword -e "SELECT * FROM performance_schema.replication_group_members;"
```
The cluster should still be operational with the remaining nodes.

## Files Structure
```plaintext
/
├── mysql-service.yaml      # Headless Service for MySQL
├── mysql-statefulset.yaml  # StatefulSet for MySQL Group Replication
├── README.md               # Project documentation
```

## Scaling Up
To add more replicas to the cluster:
```bash
kubectl scale statefulset mysql --replicas=5
```

## Next Steps
- **Use MySQL Router** for efficient load balancing.
- **Add monitoring** using Prometheus and Grafana.
- **Implement scheduled backups** for data safety.


