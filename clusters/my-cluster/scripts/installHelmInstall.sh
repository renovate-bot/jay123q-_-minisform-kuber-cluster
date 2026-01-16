#!/bin/bash

RELEASE_NAME="my-release"
CHART_NAME="Cilium" # Replace with your chart name
VALUES_FILE="helmValues/ciliumValues.yaml"

helm install cilium cilium/cilium --namespace kube-system -f $VALUES_FILE

echo "Adding Helm chart repository..."
helm repo add bitnami https://charts.bitnami.com
helm repo update

echo "Installing Helm chart $CHART_NAME with values from $VALUES_FILE..."
helm install "$RELEASE_NAME" "$CHART_NAME" -f "$VALUES_FILE"

echo "Installation complete."
