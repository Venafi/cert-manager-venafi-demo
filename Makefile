INGRESS_CERT := $$(kubectl --namespace=cert-manager-example get secret |grep ingress-site|awk '{print $$1}')
TPP_CERT := $$(kubectl --namespace=cert-manager-example get secret |grep tppvenafiissuer|awk '{print $$1}')
CLOUD_CERT := $$(kubectl --namespace=cert-manager-example get secret |grep cloudvenafiissuer|awk '{print $$1}')
FAKE_CERT := $$(kubectl --namespace=cert-manager-example get secret |grep fakevenafiissuer|awk '{print $$1}')
NAMESPACE := cert-manager-example
NODE_IP := $$(kubectl cluster-info |head -n 1|awk -F'[/:]' '{print $$4}')

#nginx ingress helm values
INGRESS_PORT_HTTPS := 32443
INGRESS_PORT_HTTP := 32080

#cert manager helm values
IMAGE_REPOSITORY := arykalin/cert-manager-controller
IMAGE_TAG := build
IMAGE_POLICY := Never

#Issuer which will be used by ingress controller to genrate certificates
INGRESS_DEFAULT_ISSUER=cloudvenafiissuer

INGRESS_SHIM_IMAGE_REPOSITORY := arykalin/cert-manager-ingress-shim
INGRESS_SHIM_IMAGE_POLICY := Never

#Credentials
TPPUSER := 'admin'
TPPPASSWORD := 'password'
CLOUDAPIKEY := 'xxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxx'

TPPSECRET := 'tppsecret'
CLOUDSECRET := 'cloudsecret'

namespace:
	kubectl create namespace $(NAMESPACE) || echo "Namespace $(NAMESPACE) already exists"

credentials:
	@kubectl delete secret $(TPPSECRET) --namespace $(NAMESPACE) || echo "Secret $(TPPSECRET) does not exists"
	@kubectl delete secret $(CLOUDSECRET) --namespace $(NAMESPACE) || echo "Secret $(CLOUDSECRET) does not exists"
	@kubectl create secret generic $(TPPSECRET) --from-literal=user=$(TPPUSER) --from-literal=password=$(TPPPASSWORD) --namespace $(NAMESPACE)
	@kubectl create secret generic $(CLOUDSECRET) --from-literal=apikey=$(CLOUDAPIKEY) --namespace $(NAMESPACE)

ingress:
	helm upgrade --install $(NAMESPACE)-nginx-ingress stable/nginx-ingress --namespace $(NAMESPACE) \
            --set controller.service.type="NodePort" \
            --set controller.service.nodePorts.https="$(INGRESS_PORT_HTTPS)" \
            --set controller.service.nodePorts.http="$(INGRESS_PORT_HTTP)" \
            --set rbac.create=true \
            --set image.pullPolicy="Always"

cert-manager:
	helm upgrade --install $(NAMESPACE)-cert-manager stable/cert-manager --namespace $(NAMESPACE) \
			--set image.repository="$(IMAGE_REPOSITORY)" \
			--set image.tag="$(IMAGE_TAG)" \
			--set image.pullPolicy="$(IMAGE_POLICY)" \
			--set ingressShim.image.repository="$(INGRESS_SHIM_IMAGE_REPOSITORY)" \
			--set ingressShim.image.pullPolicy="$(INGRESS_SHIM_IMAGE_POLICY)" \
            --set rbac.create=true \
            --set ingressShim.defaultIssuerName="$(INGRESS_DEFAULT_ISSUER)" \
            --set ingressShim.defaultIssuerKind="Issuer"

venafi-issuer:
	helm upgrade --install $(NAMESPACE)-venafi-issuer -f charts/venafi-issuer/values.yaml \
	 --set createTestResources=true \
	 --set tppVenafiIssuer.tppsecret=$(TPPSECRET) \
	 --set cloudVenafiIssuer.cloudsecret=$(CLOUDSECRET) \
	 --namespace=$(NAMESPACE) charts/venafi-issuer

install: namespace credentials ingress cert-manager venafi-issuer

test: test_ingress test_tpp test_cloud test_fake

test_ingress:
	@echo "****Certificate info for ingress generated certificate $(INGRESS_CERT):"
	echo|openssl s_client -servername $(INGRESS_CERT) -connect $(NODE_IP):$(INGRESS_PORT_HTTPS) 2>/dev/null | \
	    openssl x509 -inform pem -noout -issuer -serial -subject -dates
	@echo -e "Site url https://$(INGRESS_CERT):$(INGRESS_PORT_HTTPS) \n\n"
	@curl -s -H "Host: $(INGRESS_CERT)" -k https://$(NODE_IP):$(INGRESS_PORT_HTTPS)
	@echo "\n------------------------------------------\n\n"

test_tpp:
	@echo "****Certificate info for TPP secret $(TPP_CERT)"
	kubectl get secret --namespace=$(NAMESPACE) $(TPP_CERT) -o json | \
	    docker run --rm -i stedolan/jq '.data."tls.crt"' | \
	    docker run --rm -i busybox base64 -d - | \
	    openssl x509 -inform pem -noout -issuer -serial -subject -dates
	@echo "\n------------------------------------------\n\n"

test_cloud:
	@echo "****Certificate info for CLOUD secret $(CLOUD_CERT)"
	kubectl get secret --namespace=$(NAMESPACE) $(CLOUD_CERT) -o json | \
	    docker run --rm -i stedolan/jq '.data."tls.crt"' | \
	    docker run --rm -i busybox base64 -d - | \
	    openssl x509 -inform pem -noout -issuer -serial -subject -dates
	@echo "\n------------------------------------------\n\n"

test_fake:
	@echo "****Certificate info from fake issuer $(FAKE_CERT)"
	kubectl get secret --namespace=$(NAMESPACE) $(FAKE_CERT) -o json | \
	    docker run --rm -i stedolan/jq '.data."tls.crt"' | \
	    docker run --rm -i busybox base64 -d - | \
	    openssl x509 -inform pem -noout -issuer -serial -subject -dates
	@echo "\n------------------------------------------\n\n"

clean:
	helm delete $(NAMESPACE)-cert-manager --purge || echo "Chart cert-manager not found"
	helm delete $(NAMESPACE)-nginx-ingress --purge || echo "Chart nginx-ingress not found"
	helm delete $(NAMESPACE)-venafi-issuer --purge || echo "Chart venafi-issuer not found"
	kubectl delete ns $(NAMESPACE) || echo "Namesapce $(NAMESPACE) not found"
	@echo "Waiting for namespace to terminate..."
	while kubectl get ns $(NAMESPACE); do sleep 1; done

look:
	kubectl --namespace=$(NAMESPACE) logs \
	    $$(kubectl get pods -o go-template \
	        --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' \
	        --namespace=$(NAMESPACE) | grep $(NAMESPACE)-cert-manager \
	      ) cert-manager -f

diag:
	@echo "\nChecking issuer status:\n"
	kubectl --namespace=cert-manager-example get issuer -o=custom-columns=NAME:.metadata.name,STATUS:.status.conditions[*].message

	@echo "Checking certificates status:\n"
	@for cert in $$(kubectl --namespace=$(NAMESPACE) get certificate -o=custom-columns=NAME:.metadata.name|grep -v NAME); \
	do kubectl --namespace=$(NAMESPACE) get secret -o=custom-columns=NAME:.metadata.name|grep -q $$cert || echo Secret for certificate $$cert not found; \
	done

	@for secret in $$(kubectl --namespace=cert-manager-example get secret -o=custom-columns=NAME:.metadata.name,TYPE:.type|grep 'kubernetes.io\/tls'|awk '{print $$1}'); \
	do echo "\nsha256sum should be equal for TLS crt and key in $$secret" && \
	kubectl --namespace=$(NAMESPACE) get secret $$secret -o json |docker run --rm -i stedolan/jq '.data."tls.crt"'|docker run --rm -i busybox base64 -d - > /tmp/$${secret}-diag-tls.crt && \
	kubectl --namespace=$(NAMESPACE) get secret $$secret -o json |docker run --rm -i stedolan/jq '.data."tls.key"'|docker run --rm -i busybox base64 -d - > /tmp/$${secret}-diag-tls.key && \
	openssl pkey -in /tmp/$${secret}-diag-tls.key -pubout -outform pem | sha256sum && \
    openssl x509 -in /tmp/$${secret}-diag-tls.crt -pubkey -noout -outform pem | sha256sum; \
	done

	@echo "\nFor diagnostics run this commands and send output to the support:"
	@echo To show issuers status:
	@echo kubectl --namespace=$(NAMESPACE) get issuer
	@echo To look into issuer inforamtion:
	@echo kubectl --namespace=$(NAMESPACE) describe issuer \<issuer name\>
	@echo To show certificates status:
	@echo kubectl --namespace=$(NAMESPACE) get certificate
	@echo To look into certificate inforamtion:
	@echo kubectl --namespace=$(NAMESPACE) describe certificate \<certificate name\>

cert_list:
	kubectl --namespace=cert-manager-example get certificate -o=custom-columns=NAME:.metadata.name,STATUS:.status.conditions[*].message

doc:
	@pandoc --from markdown --to dokuwiki README.md > README.dokuwiki
	@pandoc --from markdown --to rst README.md > README.rst
