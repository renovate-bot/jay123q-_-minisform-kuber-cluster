#!/bin/bash

RELEASE_NAME="my-release"
CHART_NAME="Cilium" # Replace with your chart name
VALUES_FILE="chart-version-0-0-1/values.yaml"
DIR_PATH=/home/jclapp/Documents/github/minisform-kuber-cluster/clusters/my-cluster/

echo "Adding Helm chart repository..."
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium --namespace kube-system -f $VALUES_FILE
# helm install cilium cilium/cilium --namespace kube-system -f helmValues/ciliumValues.yaml
helm install cilium cilium/cilium --namespace kube-system -f $DIR_PATH+$VALUES_FILE



echo "Installing Helm chart $CHART_NAME with values from $VALUES_FILE..."
helm install "$RELEASE_NAME" "$CHART_NAME" -f "$VALUES_FILE"

echo "Installation complete."
