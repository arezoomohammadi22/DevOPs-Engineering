# Monitoring Kubernetes with Zabbix via HTTP API

This guide provides step-by-step instructions to configure Kubernetes monitoring using Zabbix HTTP templates. It includes setting up a **ServiceAccount**, **Secret**, and necessary **RBAC permissions** to allow Zabbix to query the Kubernetes API.

## **Step 1: Create a ServiceAccount for Zabbix**

Run the following command to create a ServiceAccount named `zabbix-monitoring`:

```bash
kubectl create serviceaccount zabbix-monitoring
```

## **Step 2: Assign Permissions with ClusterRoleBinding**

Zabbix needs access to Kubernetes API resources. Grant it permissions using a **ClusterRoleBinding**:

### **For Full Cluster Access (Admin Rights)**
```bash
kubectl create clusterrolebinding zabbix-monitoring-binding \
    --clusterrole=cluster-admin \
    --serviceaccount=default:zabbix-monitoring
```

### **For Read-Only Access**
If you want **read-only access**, use the `view` role instead:

```bash
kubectl create clusterrolebinding zabbix-monitoring-binding \
    --clusterrole=view \
    --serviceaccount=default:zabbix-monitoring
```

## **Step 3: Manually Create a Secret for API Authentication**

Since Kubernetes 1.24+, secrets are no longer automatically created for ServiceAccounts. Manually create a **Secret** to store the authentication token:

### **Create a YAML File for the Secret**
Create a file called `zabbix-sa-secret.yaml` with the following content:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: zabbix-monitoring-secret
  annotations:
    kubernetes.io/service-account.name: zabbix-monitoring
type: kubernetes.io/service-account-token
```

### **Apply the Secret**
```bash
kubectl apply -f zabbix-sa-secret.yaml
```

## **Step 4: Retrieve the API Token**

Extract the token from the newly created secret:

```bash
kubectl get secret zabbix-monitoring-secret -o jsonpath="{.data.token}" | base64 --decode
```

Copy the output of this command; this is the token required for Zabbix to authenticate with the Kubernetes API.

## **Step 5: Configure Zabbix to Use the Token**

1. **Go to Zabbix Web UI** → **Configuration** → **Hosts**.
2. Select your **Kubernetes Cluster** host.
3. Navigate to the **Macros** tab.
4. Click **Add**, and enter:
   - **Macro:** `{KUBERNETES.API.TOKEN}`
   - **Value:** *(Paste the token copied from Step 4)*.
5. Click **Update**.

## **Step 6: Test API Access from Zabbix Server**

Run the following command from the Zabbix Server to verify API access:

```bash
curl -k -H "Authorization: Bearer <PASTE_YOUR_TOKEN_HERE>" \
 https://10.211.55.50:6443/api/v1/nodes
```

If the command returns JSON output, Zabbix can successfully query the Kubernetes API.

## **Next Steps**
- Link **Kubernetes HTTP templates** in Zabbix.
- Configure **Triggers and Dashboards** for monitoring.
- Set up **Alerts and Notifications** in Zabbix.

Your Kubernetes cluster is now ready to be monitored via Zabbix HTTP API! 🎉

