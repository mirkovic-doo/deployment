kubectl create secret generic elasticsearch-secrets \
  --from-file=elasticsearch.keystore=../../../ELK-stack/secrets/keystore/elasticsearch.keystore \
  --from-file=elasticsearch.service_tokens=../../../ELK-stack/secrets/service_tokens \
  --from-file=elastic.ca=../../../ELK-stack/secrets/certs/ca/ca.crt \
  --from-file=elasticsearch.certificate=../../../ELK-stack/secrets/certs/elasticsearch/elasticsearch.crt \
  --from-file=elasticsearch.key=../../../ELK-stack/secrets/certs/elasticsearch/elasticsearch.key \
  --from-file=kibana.certificate=../../../ELK-stack/secrets/certs/kibana/kibana.crt \
  --from-file=kibana.key=../../../ELK-stack/secrets/certs/kibana/kibana.key \
  --from-file=apm-server.certificate=../../../ELK-stack/secrets/certs/apm-server/apm-server.crt \
  --from-file=apm-server.key=../../../ELK-stack/secrets/certs/apm-server/apm-server.key \
  -n devops

kubectl create secret generic kibana-token-secret \
  --from-env-file=../../../ELK-stack/secrets/.env.kibana.token \
  -n devops