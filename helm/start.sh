#!/bin/bash


echo "Checking if namespace 'devops' exists..."
if kubectl get namespace devops >/dev/null 2>&1; then
  echo "Namespace 'devops' already exists. Skipping creation."
else
  kubectl create namespace devops || { echo "Failed to create namespace 'devops'"; exit 1; }
  echo "Namespace 'devops' created."
fi

cd ../resources/elk/ || { echo "ELK directory not found"; exit 1; }

chmod +x elk-secrets.sh
./elk-secrets.sh

kubectl apply -f filebeat-clusterRole.yaml -n devops

cd ../../helm/

helm install devops ./bukiteasy