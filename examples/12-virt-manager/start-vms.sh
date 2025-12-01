for VM in control-plane worker-1 worker-2 worker-3; do
  echo "Starting VM: $VM"
  sudo virsh start $VM
done
