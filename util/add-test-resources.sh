#!/bin/bash
set -o errexit
cd "$(dirname "$0")"
helm template ../charts/venafi-issuer/ -x templates/test-resources.yaml | kubectl --namespace=cert-manager-example apply -f -
echo "Ingress configured to: `kubectl --namespace=cert-manager-example get ingress cert-manager-ingress -o jsonpath='{.spec.tls[].secretName}'`"
