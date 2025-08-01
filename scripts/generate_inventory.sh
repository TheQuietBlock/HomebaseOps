#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT"

# Fetch VM IPs from Terraform outputs
TF_OUTPUT=$(terraform -chdir=terraform output -json vm_ips)

# Get VM names from Terraform (with fallback to vm-server-KEY pattern)
get_vm_name() {
  local key=$1
  case $key in
    "zabbix") echo "Monitor-o-saurus";;
    "docker1") echo "port-o-party-1";;
    "docker2") echo "port-o-party-2";;
    "docker3") echo "port-o-party-3";;
    *) echo "vm-server-$key";;
  esac
}

{
  echo "# Automatically generated by Terraform"
  echo
  echo "[all]"
  echo "$TF_OUTPUT" | jq -r 'to_entries[] | "\(.key) \(.value)"' | while read key ip; do
    name=$(get_vm_name "$key")
    echo "$name ansible_host=$ip"
  done
  echo
  
  # Create individual groups for each VM type
  echo "$TF_OUTPUT" | jq -r 'to_entries[] | "\(.key) \(.value)"' | while read key ip; do
    name=$(get_vm_name "$key")
    echo "[$key]"
    echo "$name ansible_host=$ip"
    echo
  done
  
  echo "[docker]"
  echo "$TF_OUTPUT" | jq -r 'to_entries[] | select(.key|test("^docker[0-9]+$")) | "\(.key) \(.value)"' | while read key ip; do
    name=$(get_vm_name "$key")
    echo "$name ansible_host=$ip"
  done
  
  echo
  echo "[all_servers:children]"
  echo "$TF_OUTPUT" | jq -r 'keys[]'
} > ansible/inventory.ini

