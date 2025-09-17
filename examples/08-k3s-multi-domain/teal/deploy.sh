NAMESPACE="teal"

kubectl create namespace $NAMESPACE

cd ssl

# Check if certificate file doesn't exist, generate it
if [ ! -f "$NAMESPACE-neoteroi-xyz-tls.crt" ]; then
  echo "Generating self-signed certificate…"
  chmod +x gen.sh && ./gen.sh
fi

kubectl create secret tls $NAMESPACE-neoteroi-xyz-tls \
  --cert=$NAMESPACE-neoteroi-xyz-tls.crt \
  --key=$NAMESPACE-neoteroi-xyz-tls.key \
  -n $NAMESPACE

cd ../
kubectl apply -f $NAMESPACE.yaml
