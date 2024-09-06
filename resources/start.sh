#!/bin/bash

apply_resource() {
  resource_file=$1
  namespace=$2
  echo "Applying $resource_file..."
  kubectl apply -f "$resource_file" -n "$namespace" || { echo "Failed to apply $resource_file"; exit 1; }
  echo "$resource_file applied successfully."
}

create_secret_if_not_exists() {
  secret_name=$1
  namespace=$2
  secret_file=$3

  if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
    echo "Secret '$secret_name' already exists. Skipping creation."
  else
    echo "Creating secret '$secret_name'..."
    kubectl apply -f "$secret_file" -n "$namespace" || { echo "Failed to create secret '$secret_name'"; exit 1; }
    echo "Secret '$secret_name' created successfully."
  fi
}

create_pvc_if_not_exists() {
  pvc_name=$1
  namespace=$2
  pvc_file=$3

  if kubectl get pvc "$pvc_name" -n "$namespace" >/dev/null 2>&1; then
    echo "PVC '$pvc_name' already exists. Skipping creation."
  else
    echo "Applying $pvc_file..."
    kubectl apply -f "$pvc_file" -n "$namespace" || { echo "Failed to apply $pvc_file"; exit 1; }
    echo "$pvc_file applied successfully."
  fi
}

create_volume_if_not_exists() {
  pv_name=$1
  pv_file=$2

  if kubectl get pv "$pv_name" >/dev/null 2>&1; then
    echo "PV '$pv_name' already exists. Skipping creation."
  else
    echo "Applying $pv_file..."
    kubectl apply -f "$pv_file"|| { echo "Failed to apply $pv_file"; exit 1; }
    echo "$pv_file applied successfully."
  fi
}

echo "Checking if namespace 'devops' exists..."
if kubectl get namespace devops >/dev/null 2>&1; then
  echo "Namespace 'devops' already exists. Skipping creation."
else
  kubectl create namespace devops || { echo "Failed to create namespace 'devops'"; exit 1; }
  echo "Namespace 'devops' created."
fi

echo "Do you want to deploy the ELK stack (Elasticsearch, Logstash, Kibana, APM server)? (y/n)"
read -r deploy_elk

if [ "$deploy_elk" == "y" ]; then
  echo "Starting ELK stack deployment..."

  cd elk/ || { echo "ELK directory not found"; exit 1; }

  chmod +x elk-secrets.sh
  ./elk-secrets.sh

  create_secret_if_not_exists "elk-secrets" "devops" "elk-secrets.yaml"

  echo "Applying ELK stack resources..."
  apply_resource "elastic-config.yaml" "devops"
  apply_resource "elasticsearch-service.yaml" "devops"
  apply_resource "kibana-config.yaml" "devops"
  apply_resource "kibana-service.yaml" "devops"
  apply_resource "logstash-config.yaml" "devops"
  apply_resource "logstash-service.yaml" "devops"
  apply_resource "apm-config.yaml" "devops"
  apply_resource "apm-service.yaml" "devops"

  echo "ELK stack resources applied successfully."

  echo "Waiting for Elasticsearch to be ready..."
  kubectl wait --namespace devops --for=condition=ready pod --selector=app=elasticsearch --timeout=300s

  echo "Waiting for Kibana to be ready..."
  kubectl wait --namespace devops --for=condition=ready pod --selector=app=kibana --timeout=300s

  cd ../
else
  echo "Skipping ELK stack deployment."
fi

echo "Do you want to deploy Filebeat? (y/n)"
read -r deploy_filebeat

if [ "$deploy_filebeat" == "y" ]; then
  echo "Starting Filebeat deployment..."

  cd elk/ || { echo "ELK directory not found"; exit 1; }

  echo "Applying Filebeat resources..."
  apply_resource "filebeat-clusterRole.yaml" "devops"
  apply_resource "filebeat-config.yaml" "devops"
  apply_resource "filebeat-service.yaml" "devops"

  echo "Filebeat resources applied successfully."
  cd ../
else
  echo "Skipping Filebeat deployment."
fi

cd postgres/ || { echo "PostgreSQL directory not found"; exit 1; }
echo "Applying PostgreSQL resources..."
create_volume_if_not_exists "postgres-pv" "postgres-data-volume.yaml"
create_pvc_if_not_exists "postgresql-data" "devops" "postgres-data-pvc.yaml"
apply_resource "postgres.yaml" "devops"

echo "Waiting for PostgreSQL to be ready..."
kubectl wait --namespace devops --for=condition=ready pod --selector=app=postgres --timeout=300s

cd ../rabbitmq/ || { echo "RabbitMQ directory not found"; exit 1; }
echo "Applying RabbitMQ resources..."
create_volume_if_not_exists "rabbitmq-pv" "rabbitmq-data-volume.yaml"
create_pvc_if_not_exists "rabbitmq-data" "devops" "rabbitmq-data-pvc.yaml"
apply_resource "rabbitmq.yaml" "devops"

echo "Waiting for RabbitMQ to be ready..."
kubectl wait --namespace devops --for=condition=ready pod --selector=app=rabbitmq --timeout=300s

cd ../client/ || { echo "Client service directory not found"; exit 1; }
echo "Applying Client resources..."
apply_resource "client.yaml" "devops"

cd ../user-service/ || { echo "User service directory not found"; exit 1; }
echo "Applying User service resources..."
apply_resource "user-service-config.yaml" "devops"
create_secret_if_not_exists "user-service-secrets" "devops" "user-service-secrets.yaml"
apply_resource "user-service.yaml" "devops"

cd ../accommodation-service/ || { echo "Accommodation service directory not found"; exit 1; }
echo "Applying Accommodation service resources..."
apply_resource "accommodation-service-config.yaml" "devops"
apply_resource "accommodation-service.yaml" "devops"


cd ../notification-service/ || { echo "Notification service directory not found"; exit 1; }
echo "Applying Notification service resources..."
apply_resource "notification-service-config.yaml" "devops"
apply_resource "notification-service.yaml" "devops"

cd ../review-service/ || { echo "Review service directory not found"; exit 1; }
echo "Applying Review service resources..."
apply_resource "review-service-config.yaml" "devops"
apply_resource "review-service.yaml" "devops"

echo "Applying NGINX Ingress Controller..."

kubectl patch configmap ingress-nginx-controller -n ingress-nginx --type merge -p '{"data":{"allow-snippet-annotations":"true"}}'

cd ../ingress/ || { echo "Ingress directory not found"; exit 1; }
echo "Applying Ingress resources..."
apply_resource "ingress.yaml" "devops"

echo "Deployment completed successfully."