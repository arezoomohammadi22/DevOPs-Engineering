
# Tea & Coffee Shop - Docker Swarm Deployment

This project is designed to help you learn how to deploy a simple **Tea & Coffee Shop** application using **Docker Swarm** and **Stack**. The project consists of four main services: **Frontend**, **Backend**, **Database** (PostgreSQL), and **Cache** (Redis).

### Project Overview

The application consists of the following components:

- **Frontend**: A simple static webpage displaying products (tea and coffee) using **Nginx**.
- **Backend**: A **Node.js** API server that provides product data from a **PostgreSQL** database.
- **Database**: A **PostgreSQL** database that stores tea and coffee products.
- **Cache**: A **Redis** instance used for caching data and improving performance.

### Project Structure

```bash
tea-coffee-shop/
├── backend/
│   ├── Dockerfile
│   ├── server.js
│   └── package.json
├── frontend/
│   ├── Dockerfile
│   ├── index.html
│   └── style.css
├── database/
│   └── init.sql
├── cache/
├── docker-stack.yml
└── README.md
```

### Setup Instructions

1. **Clone the Repository**

   First, clone the project repository to your local machine:

   ```bash
   git clone https://github.com/arezoomohammadi22/DevOPs-Engineering/tree/main/tea-coffee-shop
   cd tea-coffee-shop
   ```

2. **Write Dockerfiles**

   You will need to create Dockerfiles for each of the following services:

   - **Frontend**: Use Nginx to serve a static webpage (`index.html`) with tea and coffee products.
   - **Backend**: Create a Node.js application that serves an API with product data from the database.
   - **Database**: Use PostgreSQL and initialize it with predefined product data from the `init.sql` script.
   - **Cache**: Use Redis to provide a caching mechanism for better performance.

3. **Create the Docker Stack File**

   Create a `docker-stack.yml` file that defines all services:

   - **Frontend**: Define service for Nginx to serve the static files.
   - **Backend**: Define the Node.js API service.
   - **Database**: Use the official PostgreSQL image and mount the `init.sql` file to initialize the database.
   - **Cache**: Use Redis to provide a caching mechanism for the backend.

   Make sure to include:

   - **Volumes** for persistent storage (e.g., for the database).
   - A **shared network** for communication between the services.
   - Proper **ports** for the frontend, backend, and monitoring.
   - Use **depends_on** to control service startup order.

4. **Deploy the Project on Docker Swarm**

   Once you have created the Dockerfiles and `docker-stack.yml` file, deploy the stack with the following command:

   ```bash
   docker stack deploy -c docker-stack.yml tea-coffee-shop
   ```

   This will start the services in Docker Swarm.

5. **Implement Monitoring**

   You can add **Prometheus** and **Grafana** to monitor the application’s health and performance:

   - Set up Prometheus to scrape metrics from your backend.
   - Create a Grafana dashboard to visualize the metrics.

6. **Test the Application**

   After deployment, visit **http://localhost:8080** to see the frontend displaying tea and coffee products. Also, check if the backend API is accessible at **http://localhost:3000/products**.

7. **Troubleshoot and Optimize**

   As you deploy the stack, you might encounter issues. Troubleshoot and optimize your configurations to ensure everything runs smoothly. Use Docker logs and monitor service statuses to help with this.

### Learning Outcomes

By completing this project, you will:

- Learn how to deploy a multi-service application with **Docker Swarm** and **Docker Stack**.
- Gain practical experience in writing **Dockerfiles** for different services.
- Understand how to use **Docker Compose** and Swarm to manage a distributed application.
- Implement basic **monitoring** using **Prometheus** and **Grafana**.
- Improve your troubleshooting skills while working with Docker containers.

### Prerequisites

Before you start, make sure you have:

- **Docker** and **Docker Compose** installed on your machine.
- A **Docker Swarm** cluster (you can use a single-node Swarm for testing).
- Basic knowledge of **Node.js**, **Nginx**, **PostgreSQL**, and **Redis**.

### Additional Resources

- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)

---

Enjoy learning and deploying your Tea & Coffee Shop application with Docker Swarm!
