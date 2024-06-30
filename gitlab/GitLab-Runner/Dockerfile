# Use the official Docker image as the base image
FROM docker:latest

# Set the working directory
WORKDIR /root

# Copy the Helm tarball to the container
COPY helm.tar.gz .

# Extract the Helm tarball and move the Helm binary to the system path
RUN tar -zxvf helm.tar.gz \
    && mv linux-amd64/helm /usr/local/bin/ \
    && rm -rf linux-amd64 helm.tar.gz

# Create the necessary directories for Kubernetes configuration
RUN mkdir -p /home/gitlab-runner/.kube \
    && mkdir -p /root/.kube

# Copy the kubeconfig file to the container
COPY kubeconfig /root/.kube/config
COPY kubeconfig /home/gitlab-runner/.kube/config
