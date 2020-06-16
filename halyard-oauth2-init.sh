!/usr/bin/env bash

kubectl exec -it $(kubectl get pods -l component=halyard | awk 'NR==2 {print $1}') -- bash -c "hal config security authn oauth2 edit \
--client-id <client id> \
--client-secret <client secret> \
--provider other \
--user-authorization-uri https://<your keycloak domain>/auth/realms/<your realm>/protocol/openid-connect/auth \
--access-token-uri https://<your keycloak domain>/auth/realms/<your realm>/protocol/openid-connect/token \
--user-info-uri https://<your keycloak domain>/auth/realms/<your realm>/protocol/openid-connect/userinfo \
&& hal config security authn oauth2 enable \
&& hal deploy apply"