for VM in control-plane worker-1 worker-2 worker-3; do
  echo "Shutting down VM: $VM"
  virsh shutdown $VM
done
