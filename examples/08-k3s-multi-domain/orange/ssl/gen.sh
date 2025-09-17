openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout orange-neoteroi-xyz-tls.key \
  -out orange-neoteroi-xyz-tls.crt \
  -config san.cnf
