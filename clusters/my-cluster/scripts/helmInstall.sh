#!/bin/bash

CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

#TODO
# see if you can get helm logs out of this, i wonder why we cant install at runtime


# RELEASE_NAME="my-release"
# CHART_NAME="Cilium" # Replace with your chart name
# #VALUES_FILE="chart-version-0-0-2/values.yaml"
# VALUES_FILE="scripts/values.yaml"
# DIR_PATH=/home/jclapp/Documents/github/minisform-kuber-cluster/clusters/my-cluster/

# echo "Adding Helm chart repository..."
# helm repo add cilium https://helm.cilium.io/
# helm repo update

# # helm install cilium cilium/cilium --namespace kube-system -f $VALUES_FILE
# # helm install cilium cilium/cilium --namespace kube-system -f helmValues/ciliumValues.yaml
# # helm install cilium cilium/cilium --namespace kube-system -f $DIR_PATH+$VALUES_FILE
# # helm install cilium cilium/cilium --namespace kube-system -f $DIR_PATH+$VALUES_FILE


# echo "Installing Helm chart $CHART_NAME with values from $VALUES_FILE..."
# helm install cilium cilium/cilium --version 1.18.5 --namespace kube-system
# #helm install "$RELEASE_NAME" "$CHART_NAME" -f "$VALUES_FILE"

echo "Installation complete."
# retrying