#  Venafi issuer for Jetstack cert-manager

Venafi issuer is a cert-manager (https://github.com/jetstack/cert-manager) extension which supports certificate management from Venafi Cloud and Venafi Platform.
Also it has a fakeissuer interface for testing purpose.

Get the code from ssh://git@git.eng.venafi.com/Jetstack.CertManager.git

# Requirements to run:

* macOS or Linux (for Windows support look below)

* Docker

* Kubernetes 1.7+ If you are not familiar with Kubernetes we recommend using minikube - https://github.com/kubernetes/minikube#quickstart  
To view your cluster run: `minikube dashboard`

After the quickstart installation you should be ready to go.

* kubectl - kubernetes command line client - https://kubernetes.io/docs/tasks/tools/install-kubectl/

* helm - kubernetes package manager - https://github.com/kubernetes/helm#install  
Get the binary for your platform and run `helm init`  

* Standard Linux\macOS utilities - make, openssl

# Requirements for Venafi Platform policy

1. Policy should have default template configured

2. Currently vcert (which is used in Venafi issuers) supports only user provided CSR. So it is must be set in the policy.

3. MSCA configuration should have http URI set before the ldap URI in X509 extensions, otherwise NGINX ingress controller can get the certificate chain from URL and OSCP will not work. Example:

```
X509v3 extensions:
    X509v3 Subject Alternative Name:
    DNS:test-cert-manager1.venqa.venafi.com}}
    X509v3 Subject Key Identifier: }}
    61:5B:4D:40:F2:CF:87:D5:75:5E:58:55:EF:E8:9E:02:9D:E1:81:8E}}
    X509v3 Authority Key Identifier: }}
    keyid:3C:AC:9C:A6:0D:A1:30:D4:56:A7:3D:78:BC:23:1B:EC:B4:7B:4D:75}}X509v3 CRL Distribution Points:Full Name:
    URI:http://qavenafica.venqa.venafi.com/CertEnroll/QA%20Venafi%20CA.crl}}
    URI:ldap:///CN=QA%20Venafi%20CA,CN=qavenafica,CN=CDP,CN=Public%20Key%20Services,CN=Services,CN=Configuration,DC=venqa,DC=venafi,DC=com?certificateRevocationList?base?objectClass=cRLDistributionPoint}}{{Authority Information Access: }}
    CA Issuers - URI:http://qavenafica.venqa.venafi.com/CertEnroll/qavenafica.venqa.venafi.com_QA%20Venafi%20CA.crt}}
    CA Issuers - URI:ldap:///CN=QA%20Venafi%20CA,CN=AIA,CN=Public%20Key%20Services,CN=Services,CN=Configuration,DC=venqa,DC=venafi,DC=com?cACertificate?base?objectClass=certificationAuthority}}
```

4. Option in Venafi Platform CA configuration template "Automatically include CN as DNS SAN" should be set to true.

## If you have tried Venafi cert-manager before, please cleanup your previous installation:


1. Run: `make clean`
2. To make sure that all clear run `kubectl get ns` and `helm list`
There should be no namespaces or helm release with cert-manager name in it.

## Notes about Windows 
If you want to try cert-manager on Windows we recommend you run all instructions inside VirtualBox Linux VM. 
You can run minikube inside it using "--vm-driver=none" option:
```bash
minikube start --vm-driver=none
``` 

You still can try to run on pure Windows minikube using bash for Windows, but we can't guarantee that Makefile scripts will work correctly.

# Quickstart:


1. Checkout this repository  

2. Start minikube if it not started yet - `minikube start`  

3. Initialize helm if not yet initialized: `helm init`  

4. Edit /charts/venafi-issuer/values.yaml file and configure your Venafi Platform/Cloud connection parameters there. You also can disable issuers by setting their enable parameter to "false"

5. Create kubernetes secrets with credentials for Venafi Platform or Venafi Cloud
* For Venafi Platform:

```
kubectl create secret generic tppsecret --from-literal=user=YOUR_TPP_USER_HERE --from-literal=password='YOUR_TPP_PASSWORD_HERE' --namespace cert-manager-example
```

* For Venafi Cloud:

```
kubectl create secret generic cloudsecret --from-literal=apikey=YOUR_CLOUD_API_KEY_HERE --namespace cert-manager-example
```

6. If you have tried cert-manager before please cleanup your previous installation: make clean  

7. Run: `make install`

8. To check that all pods were started run: `kubectl --namespace=cert-manager-example get pod`  

Initial start will take about 2-5 minutes, it depends on your network connection, because cert-manager will download its Docker images
Successful start should look like this:

```
$kubectl --namespace=cert-manager-example get pod  
NAME                                                              READY     STATUS    RESTARTS   AGE
cert-manager-cert-manager-example-cert-manager-68b8b744bc-kk4b9   2/2       Running   0          9m
cert-manager-example-nginx-ingress-controller-7575d47ff8-nt5jj    1/1       Running   0          9m
cert-manager-example-nginx-ingress-default-backend-db5d9b85ptwx   1/1       Running   0          9m
echoserver-67589ffcb9-8pppr                                       1/1       Running   0          9m

```

9. If all looks fine run: `make test`  
TIP: `make test` will try to determine node IP to connect to the ingress load balancer. However it may fail to do this if you are testing not on the developement cluster, 
like minikube, but on the real multinode cluster. In this case you can set NODE_IP variable, for example:  
```bash
export NODE_IP=192.168.1.1 && make test -e
```
NODE_IP should be set to the IP address of the one of the kubernetes nodes, because ingress is configured to used NodePort.

10. To look into logs run: `make look`
  
11. For useful diagnostic commands run: `make diag`  

# Credentials
Cloud api key and Venafi Platform password are stored in kubernetes secrets (https://kubernetes.io/docs/concepts/configuration/secret/).
In production you can setup RBAC policies to protect it (https://kubernetes.io/docs/concepts/configuration/secret/#best-practices). 
You can update credentials secrets in 3 ways:  

1. By editing Makefile  
    Edit Makefile and change TPPUSER, TPPPASSWORD and CLOUDAPIKEY parameters.  
    Update secrets by running `make credentials`  

2. Setting them from variables (Escape variable character `$` with `\$` sequense, for example `$Passw` should become `\$$Passw`). Example:
    ```bash
    export TPPUSER='admin' && export TPPPASSWORD='new\$$Password' && export CLOUDAPIKEY='xxxx-xxxx-xxx-xxxxx' && make credentials -e
    ``` 

3. Updating them manually. For example:  
    ```bash
    kubectl delete secret tppsecret --namespace cert-manager-example
    kubectl delete secret cloudsecret --namespace cert-manager-example
    kubectl create secret generic tppsecret --from-literal=user=admin --from-literal=password='tpppassword' --namespace cert-manager-example
    kubectl create secret generic cloudsecret --from-literal=apikey=xxxx-xxxx-xxx-xxxxx --namespace cert-manager-example
    ```

    After it you need to recreate the issuer:
    ```
    helm delete --purge cert-manager-example-venafi-issuer
    helm upgrade --install cert-manager-example-venafi-issuer -f charts/venafi-issuer/values.yaml  --set createTestResources=true  --set tppVenafiIssuer.tppsecret='tppsecret'  --set cloudVenafiIssuer.cloudsecret='cloudsecret'  --namespace=cert-manager-example charts/venafi-issuer
    ```

`make credentials` is included in `make install` scripts, so you can run `make install` if you want setup credentials on new installation.

# Venafi Cloud usage scenarios

## Basic Usage: Requesting a Certificate

Certificates are requested by creating resource files which contain the information to be included in the certificate as well as a pointer to which issuer should be used to request the certificate.

An example yaml file for requesting a certificate from Venafi Cloud is below:

```yaml
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
        name: cert1-venafi-localhost
        namespace: cert-manager-example
spec:
        secretName: cert1-venafi-localhost
        issuerRef:
                name: cloudvenafiissuer
        commonName: cert1.venafi.localhost

```

Create the certificate resource using kubectl (assuming file is named cert2.yaml):

```
$kubectl create -f cert2.yaml
```

Monitor the progress of the certificate issuance by looking at the logs from the cert-manager (in this example default name for the cert-manager namespace 'cert-manager-example' is used):

```
kubectl --namespace=cert-manager-example logs $(kubectl get pods -o go-template --template  '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' --namespace=cert-manager-example | grep cert-manager-cert-manager-example-cert-manager) cert-manager -f
```

## More advanced usage: Creating a custom issuer
Helm commands can be used to create appropriate YAML files, but in these examples the plain YAML files consumed by kubectl create -f will be shown.

Create a secret for the issuer (in this example the issuer will be Venafi Cloud and will use the default namespace)

```
kubectl create secret generic clouddevsecret --namespace=default --from-literal=apikey='XXXXX'
```

Create the issuer (this assumes that cert-manager has been installed on your cluster per the instructions above)

```
apiVersion: certmanager.k8s.io/v1alpha1
kind: Issuer
metadata:
        name: cloud-devops-issuer
        namespace: cert-manager-example
spec:
        venafi:
                cloudsecret: clouddevsecret
                zone: "DevOps"
```


You can create multiple issuers pointing to different Venafi Cloud zones, or even have 1 issuer pointing to the Venafi Platform and another pointing to Venafi Cloud.

Here's an example certificate resource file using the new issuer:

```
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
        name: cert4-venafi-localhost
        namespace: cert-manager-example
spec:
        secretName: cert4-venafi-localhost
        issuerRef:
                name: cloud-devops-issuer
        commonName: cert4.venafi.localhost
```


## Advanced Usage: Creating a simple webservice using HTTPS (no ingress controller)

While in practice pods are deployed behind ingress controllers that will terminate HTTPS, for end-to-end encryption of web traffic to pods it may be useful to deploy a certificate to the containers directly.

This example uses nodejs 6.9.2 as an example webserver (adapted from walkthrough here: https://kubernetes.io/docs/tutorials/hello-minikube/)

Create the node.js app that will be serving content as a HTTPS webserver

server.js:
```javascript
var https = require('https');
var fs = require('fs');

var options = {
  key: fs.readFileSync('/etc/certdata/tls.key'),
  cert: fs.readFileSync('/etc/certdata/tls.crt')
};

var handleRequest = function(request, response) {
  console.log('Received request for URL: ' + request.url);
  response.writeHead(200);
  response.end('Hello World!');
};
var www = https.createServer(options,handleRequest);
www.listen(38080);
```

Create a Dockerfile to build an image (make sure to follow the instructions in the Hello-Minikube example if you are using minikube so that your docker client is configured to point to the docker daemon running in minikube, otherwise you'll end up building your images in your local docker repository and minikube won't have access to them)

Dockerfile:
```
FROM node:6.9.2
EXPOSE 8080
COPY server.js .
CMD node server.js
```

Point your docker client to the minikube docker daemon and build your image

```
eval $(minikube docker-env)
docker build -t hello-node:v1 .
```

Run docker images | grep hello to verify that an image is available with the name/tag used above.

Create a directory that will contain the kubernetes resource files. In this example, there are 3 resources to be created, a Deployment resource, a Certificate resource, and a Server resource.

Certificate resource file:

```
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
        name: cert4-venafi-localhost
        namespace: cert-manager-example
spec:
        secretName: cert4-venafi-localhost
        issuerRef:
                name: cloud-devops-issuer
        commonName: cert4.venafi.localhost
```

Service file:

```
kind: Service
apiVersion: v1
metadata:
  name: hello-node
  namespace: cert-manager-example
spec:
  type: NodePort
  selector:
    app: hello-node
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 38080
```


Deployment file:

```
apiVersion: apps/v1
kind: Deployment
metadata:
    name: hello-node
    namespace: cert-manager-example
spec:
    replicas: 1
    selector:
      matchLabels:
        app: hello-node
    template:
      metadata:
        labels:
          app: hello-node
      spec:
        containers:
        - name: hello-node
          image: hello-node:v3
          imagePullPolicy: Never
          ports:
          - containerPort: 38080
            protocol: TCP
          volumeMounts:
          - name: certdata
            mountPath: "/etc/certdata"
            readOnly: true
        volumes:
        - name: certdata
          secret:
               secretName: cert4-venafi-localhost
```

This deployment will mount the certificate key and certificate in a volume that the node app can access. Once the deployment files are created, run kubectl create -f <dirname> where <dirname> contains the certificate, deployment and service resource files.

Once the deployment has completed successfully, use 'minikube service hello-node' to open up your browser and load the service. You'll note that the service will not load because this command defaults to using http. Simply type 'https://' in front of the URL that minikube loaded. If everything works, you should see your HTTPS connection is established and confirm that the certificate you requested is served by the node app.

## Advanced Usage: End-to-end encryption from client to container app through Ingress

In this example, the default nginx ingress controller that is available as a minikube add-on will be configured with a TLS certificate to terminate traffic HTTPS from the user. It will then forward traffic to the upstream pod via HTTPS, which is also configured with a TLS certificate obtained by cert-manager.

First, enable the ingress controller (note that this is done for you automatically if you use the steps above to deploy cert-manager)

```
minikube addons enable ingress
```

Use the examples in the previous section to create the example hello-node app above. This container will be configured as the upstream for the ingress container.

Next, create the certificate resource file

certingress.yaml
```
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
        name: hellodemo-venafi-localhost
        namespace: cert-manager-example
spec:
        secretName: hellodemo-venafi-localhost
        issuerRef:
                name: cloud-devops-issuer
        commonName: hellodemo.venafi.localhost
```

Since in this example the ingress will forward traffic to the container, the service doesn't need to be configured to expose the app via a NodePort. Use this service.yaml file to expose port 8080 (which will be the port that the ingress controller will forward traffic to):

service.yaml
```
kind: Service
apiVersion: v1
metadata:
  name: hello-node
  namespace: cert-manager-example
spec:
  selector:
    app: hello-node
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 38080
```

Finally, create an ingress.yaml file (note in this example, the target hostname must be resolve to the cluster IP, use dnsmasq or edit your /etc/hosts file so that this hostname resolves to that ip; you can get your cluster IP address with 'minikube ip'):

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: hello-ingress
  annotations:
    nginx.ingress.kubernetes.io/secure-backends: "true"
    nginx.ingress.kubernetes.io/configuration-snippet: error_log  /var/log/nginx/apperror.log debug;
    nginx.ingress.kubernetes.io/configuration-snippet: access_log  /var/log/nginx/appaccess.log upstreaminfo if=$loggable;
spec:
  tls:
  - secretName: hellodemo-venafi-localhost
    hosts:
      - hellodemo.venafi.localhost
  rules:
    - host: hellodemo.venafi.localhost
      http:
        paths:
        - path: /
          backend:
            serviceName: hello-node
            servicePort: 8080
```

This yaml file contains a few annotations:

* the secure-backends flag tells the ingress to use https to talk to the upstream pod.
* the configuration-snippet annotations allow you to setup specific logs for the nginx virtual host on the ingress controller that will be processing your requests.
The TLS spec references the secret that contains the certificate & key resources created by the certingress.yaml file.

Put all the *.yaml files in a directory (appfiles in my case) and run 'kubectl create -f appfiles/'. Assuming the resources were created successfully (and the dns name configured in the ingress resolves to your local cluster IP), open up your browser or use curl and hit the URL 'https://hellodemo.venafi.localhost' and verify that the certificate associated with the ingress controller is shown in your browser.

Obviously, there is no easy way to confirm via the browser if the ingress controller is forwarding traffic to the app over HTTPS. To confirm this, you can get a shell on the application container with 'kubectl exec -it <pod name from kubectl get pod> – /bin/bash. Once you have the shell, you can install tcpdump with 'apt-get update && apt-get install tcpdump'. Then use the following command to capture traffic on the container:

```
tcpdump -i eth0 tcp port 38080 -s0 -w /var/log/nginx/capture.pcap
```

Hit the URL again and observe tcpdump capturing packets.

Copy the capture.pcap file to your local workstation and view it in Wireshark:

```
kubectl cp <pod name>:/var/log/nginx/capture.pcap .
```

If you look at the TLS handshake, you should see the 'cert4.localhost.venafi' certificate in the ServerCertificate message.

## Advanced Usage: Wrapper scripts to create JKS file for use by Spring Boot example container

In this example, a basic Spring boot hello world application will be HTTPS enabled using a certificate acquired by cert-manager. Since spring boot is a Java framework, we need to create a Java keystore file on the container and configure Spring to use the keystore file in the application.properties file.

First, follow the steps here “https://spring.io/guides/gs/spring-boot/” to create the Hello World spring boot app. Use maven to build the app locally on your host. Once the app is built, you will then create a Docker container image that will contain the jar file you built, a customized application.properties file, and a startup script that will execute a pre-startup step.

After the app is built, create your certificate resource file using the examples above and run kubectl create to request the certificate and create a secret.

Next, create an application.properties file in your Java source tree at src/main/resources. Configure the application.properties file as shown below:

```
server.port=38443
server.ssl.key-store=/etc/sbkeystore.jks
server.ssl.key-store-password=[Password for pkcs12 file]
server.ssl.key-password=[Password for pkcs12 file]
```

# Venafi Platform usage scenarios

Determine namespace where cert-manager is installed. By default it is installing into "cert-manager-example" namespace. We will use it in example code.

## Creating custom Venafi Platform issuer

By default one Venafi Platform issuer is already created when you run "make install", it is called tppvenafiissuer. You can create more issuers for different Venafi Platform server or policies.

Create a secret with Venafi Platform credentials:

```
kubectl create secret generic tppsecret --from-literal=user=admin --from-literal=password=tpppassword --namespace cert-manager-example
```

Create Venafi Platform issuer using helm command:

```
helm upgrade --install tpp-venafi-issuer --namespace cert-manager-example \
    --set tppVenafiIssuer.tppsecret=tppsecret \
    --set tppVenafiIssuer.tppurl=https://YOUR_TPP_ADDRESS_HERE/vedsdk \
    --set tppVenafiIssuer.zone=TPP_POLICY_CONFIGURED_FOR_CERT_MANAGER \
    --set tppVenafiIssuer.name=YOUR_TPP_ISSUER_NAME_HERE \
    --set fakeVenafiIssuer.enable=false \
    --set cloudVenafiIssuer.enable=false \
    --set testResources.enable=false \
    ./charts/venafi-issuer
```

## Starting node.js application that gets certificate from Venafi Platform

This is a demo scenario to demonstrate how cert-manager works with certificate resources. Also this scenario may be useful when you don't want to use an ingress controller to terminate SSL traffic.

Create a certificate for the application:

cert.yaml:
```
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
        name: hellodemo-venafi-localhost
        namespace: cert-manager-example
spec:
        secretName: hellodemo-venafi-localhost
        issuerRef:
                name: tppvenafiissuer
        commonName: hellodemo.venafi.localhost
```

Create a deployment file which will run the node application. This deployment will mount the certificate key and certificate in a volume that the node app can access.

node-deployement.yaml:
```
apiVersion: apps/v1
kind: Deployment
metadata:
    name: hello-node
    namespace: cert-manager-example
spec:
    replicas: 1
    selector:
      matchLabels:
        app: hello-node
    template:
      metadata:
        labels:
          app: hello-node
      spec:
        containers:
        - name: hello-node
          image: arykalin/hello-node:v1
          imagePullPolicy: IfNotPresent
          ports:
          - containerPort: 443
            protocol: TCP
          volumeMounts:
          - name: certdata
            mountPath: "/etc/certdata"
            readOnly: true
        volumes:
        - name: certdata
          secret:
               secretName: hellodemo-venafi-localhost
```

Create a service file to expose app
node-service.yaml:
```
kind: Service
apiVersion: v1
metadata:
  name: hello-node
  namespace: cert-manager-example
spec:
  type: NodePort
  selector:
    app: hello-node
  ports:
  - protocol: TCP
    port: 31333
    targetPort: 443
```

After creating files apply them using kubectl:
```
kubectl --namespace=cert-manager-example create -f cert.yaml
kubectl --namespace=cert-manager-example create -f node-deployement.yaml
kubectl --namespace=cert-manager-example create -f node-service.yaml

```

Get the node port by running command:
```
kubectl --namespace=cert-manager-example describe service hello-node
```
Determine you external node IP where NodePort is exposed. If you use minikub you can do it by running:

```
minikube ip
```

Go to the url https://NODE_IP:NODE_PORT to check the certificate


## Starting NGINX ingress enabled site and get a certificate from Venafi Platform

Here we will setup ingress resource for previously configured application.

Setup ingress controller with HELM (by default it is already enabled by "make install" command)

```
helm upgrade --install cert-manager-example-nginx-ingress stable/nginx-ingress --namespace cert-manager-example \
    --set controller.service.type="NodePort" \
    --set controller.service.nodePorts.https="32443" \
    --set controller.service.nodePorts.http="32080" \
    --set rbac.create=true \
    --set image.pullPolicy="Always"
```

Create ingress resource YAML file ingress-res.yaml

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-for-tpp-issuer
  annotations:
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
spec:
  tls:
  - hosts:
    - testing-nginx-ingress1.example.com
    secretName: testing-nginx-ingress1.example.com
  rules:
  - host: testing-nginx-ingress1.example.com
    http:
      paths:
      - path: /
        backend:
          serviceName: hello-node
          servicePort: 8080
```

And apply it:

```
kubect --namespace=cert-manager-example create -f ingress-res.yaml
```

This ingress resource is configured to use hello-node application service which we configured in the previous scenario. When the ingress resource is created cert-manager will automatically create a certificate resource for it.

To test the new ingress site you need to do some manipulations with the hosts file.
Determine your external node IP where ingress is exposed. If you use minikub you can do it by running:

```
minikube ip
```

Add the following record to your hosts file (https://en.wikipedia.org/wiki/Hosts_(file))

```
INGRESS_IP testing-nginx-ingress1.example.com
```

Go to the URL https://testing-nginx-ingress1.example.com:32443

# Monitoring

Prometheus metrics are implemented from pull request https://github.com/jetstack/cert-manager/pull/225      
Since pull this request has not yet been accepted, monitoring is implemented on the separate branch.  

To install monitoring version please switch to the branch VEN-40460  
Then run make with following parameteres:  
```bash
export IMAGE_TAG=monitoring-build && make install -e
```

If you will see error like this:  
```
chmod: cannot access '/data/prometheus': No such file or directory
Makefile:20: recipe for target 'install' failed
```
create directory /data/prometheus with 777 access rights.  


For now only two metrics are implemented:  
Name:      "certificate_expiry_time_seconds"  
Help:      "Number of seconds after January 1, 1970 UTC that the certificate will expire"  				
Name:      "certificate_requests"  
Help:      "Number of certificate requests"  		

Here is example prometheus config:  

```yaml
    scrape_configs:
    - job_name: cert-manager
      scrape_interval: 5s
      scrape_timeout: 5s
      metrics_path: /metrics
      scheme: http
      static_configs:
      - targets:
        - cert-manager-metrics:9402
		
```


This config will be deployed with monitoring template as config map.  

For proper setup you need to setup grafana by adding prometheus as metrics source and importing charts/venafi-issuer/grafana-dashboard.json dashboard.

1. Determine grafana service url. In minikube you can do it by running minikube service list and looking into grafana service URL. Or you can use kuberctl port forward command (you need kubectl 1.10 or higher for this):  
```bash
kubectl --namespace=cert-manager-example port-forward grafana 3000:3000
```
And then go to the url http://localhost:3000  

2. Setup prometheus datasource on grafana using address http://prometheus:9090 (follow this doc if you don't know how to setup grafana datasource https://prometheus.io/docs/visualization/grafana/#creating-a-prometheus-data-source)
 
3. Export grafana dashboard from charts/venafi-issuer/grafana-dashboard.json file:
  a. Go to \<Grafana URL\>/dashboard/import and press "Upload json" button  
  b. Choose charts/venafi-issuer/grafana-dashboard.json file
  c. Choose prometheus datasource  
  Export\import instrucitons on ofiicial wiki: http://docs.grafana.org/reference/export_import/
  
Example graphs:  
![Image of graph0](https://i.imgur.com/HKFGBQK.png)
![Image of graph1](https://i.imgur.com/db5uScF.png)
![Image of graph2](https://i.imgur.com/GJfmbin.png)

# Troubleshooting

Run `make diag` command to get diagnostic information.

Usual problems:

1. Incorrect Venafi Platform policy settings, check "Requirements for Venafi Platform policy"
2. Problems with NGINX controller, run this command to see its logs (change NS variable if you're using another namespace for cert-manager):

```bash
export NS=cert-manager-example;
kubectl --namespace=$NS logs \
	    $(kubectl get pods -o go-template \
	        --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' \
	        --namespace=$NS | grep nginx-ingress-controller \
	      ) -f

```

3. Problems with issuer status. See the issuer message in make diag output. For more information run
 
```bash
export NS=cert-manager-example;
export ISSUER=tppvenafiissuer;
kubectl --namespace=$NS describe issuer $ISSUER

```

# Build instructions for developers:
    

1. Configure Go environment - https://golang.org/doc/install

2. Move modified cert-manager to the $GOPATH/src/github.com/jetstack

3. change dir to $GOPATH/src/github.com/jetstack/cert-manager

4. Follow cert-manager instructions: https://github.com/jetstack/cert-manager/tree/master/docs/devel

5. To install local build image run: `export IMAGE_TAG=build; export IMAGE_POLICY=Never; export INGRESS_SHIM_IMAGE_POLICY=Never && make install -e` 

5. run `make e2e_test` to run integration tests

6. run `make e2e_clean` to cleanup
