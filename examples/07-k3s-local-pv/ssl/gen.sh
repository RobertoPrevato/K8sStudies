openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout neoteroi-xyz-tls.key \
  -out neoteroi-xyz-tls.crt \
  -config san.cnf
