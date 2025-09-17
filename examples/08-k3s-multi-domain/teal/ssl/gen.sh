openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout teal-neoteroi-xyz-tls.key \
  -out teal-neoteroi-xyz-tls.crt \
  -config san.cnf
