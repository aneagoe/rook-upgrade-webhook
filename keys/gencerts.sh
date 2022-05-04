#!/bin/bash
WORKDIR=`dirname $0`
openssl genrsa -out ${WORKDIR}/ca.key 4096
openssl req -x509 -new -nodes -key ${WORKDIR}/ca.key -days 365 -out ${WORKDIR}/ca.crt -subj '/CN=webhook.rook-upgrade.svc'
openssl req -newkey rsa:4096 -nodes -keyout ${WORKDIR}/server.key -subj "/CN=webhook.rook-upgrade.svc" -out ${WORKDIR}/server.csr
openssl x509 -req -extfile <(printf "subjectAltName=DNS:webhook.rook-upgrade.svc") -days 365 -in ${WORKDIR}/server.csr -CA ${WORKDIR}/ca.crt -CAkey ${WORKDIR}/ca.key -CAcreateserial -out ${WORKDIR}/server.crt

SERVERCERT=`cat ${WORKDIR}/server.crt | base64 -w0`
SERVERKEY=`cat ${WORKDIR}/server.key | base64 -w0`
CABUNDLE=`cat ${WORKDIR}/ca.crt | base64 -w0`

sed -i "s/server.crt.*$/server.crt: ${SERVERCERT}/;s/server.key.*$/server.key: ${SERVERKEY}/" ${WORKDIR}/../manifests/certs.yaml
sed -i "s/caBundle.*$/caBundle: ${CABUNDLE}/" ${WORKDIR}/../manifests/mutatingwebhook.yaml
