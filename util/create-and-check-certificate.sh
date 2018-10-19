#!/bin/bash
set -o errexit

if [ "$#" -ne 3 ]; then
    cat << EOF
This is a script for checking that certificate started to sync in cert-manager
example run: $0 demoapps 12 cert-manager-example
explanation:  $0 <issuer namespace> <certificate suffix> <cert-manager namespace>

For creating multiple certificate run in a loop:
for i in {1..100}; do $0 demoapps \$i az-cert-manager-example ; sleep 60; done
EOF
    exit 0
fi

issuer_namespace=$1
certificate_suffix=$2
cert_manager_namespace=$3
issuer=tppvenafiissuer

cert_cn=cert-manager-tpp-test
cert_domain=venafi.example.com

kubectl --namespace=${issuer_namespace} create -f - << EOF
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
        name: ${cert_cn}${certificate_suffix}.${cert_domain}
spec:
        secretName: ${cert_cn}${certificate_suffix}.${cert_domain}
        issuerRef:
                name: ${issuer}
        kind: Issuer
        commonName: ${cert_cn}${certificate_suffix}.${cert_domain}
        keySize: 4096
EOF

sleep 5

kubectl --namespace=${cert_manager_namespace} logs \
    $(kubectl get pods -o go-template \
        --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' \
        --namespace=${cert_manager_namespace} | grep cert-manager \
        ) cert-manager --tail=20000|grep "Preparing certificate ${issuer_namespace}/${cert_cn}${certificate_suffix}.${cert_domain} with issuer"|| \
        echo "`date` Certificate weren't created"

