#!/bin/bash

# Accept TEMPLATE_VM_NAME from command line argument if provided
if [ -n "$1" ]; then
  TEMPLATE_VM_NAME="$1"
fi

# Check if TEMPLATE_VM_NAME is set (either from env var or argument)
if [ -z "$TEMPLATE_VM_NAME" ]; then
  echo "Error: TEMPLATE_VM_NAME is not provided" >&2
  echo "Usage: $0 <template-vm-name>" >&2
  echo "   or: TEMPLATE_VM_NAME=<template-vm-name> $0" >&2
  exit 1
fi

for VM in control-plane worker-1 worker-2 worker-3; do
  sudo virt-clone --original $TEMPLATE_VM_NAME \
    --name $VM \
    --auto-clone

  sudo virt-sysprep -d $VM \
    --hostname $VM \
    --keep /home/ro/.ssh/authorized_keys \
    --run-command 'ssh-keygen -A' \
    --run-command 'systemctl enable ssh' \
    --run-command 'echo "192.168.122.10 control-plane" >> /etc/hosts' \
    --run-command 'echo "192.168.122.11 worker-1" >> /etc/hosts' \
    --run-command 'echo "192.168.122.12 worker-2" >> /etc/hosts' \
    --run-command 'echo "192.168.122.13 worker-3" >> /etc/hosts'
done

sudo virsh list --all
