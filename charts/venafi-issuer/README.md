# Venafi issuer for cert-manager

cert-manager is a Kubernetes addon to automate the management and issuance of
TLS certificates from various issuing sources.

Venafi issuer is allowing to request certificates from Venfi Trust Protection Platform and Venafi Cloud.

## Prerequisites

- Kubernetes 1.7+

## Installing the Chart

Full installation instructions, including details on how to configure extra
functionality in cert-manager can be found in the [official deploying docs](https://github.com/jetstack/cert-manager/blob/master/docs/user-guides/deploying.md#addendum).

To install the chart with the release name `my-release`:

```console
$ helm install --name my-release venafi-issuer
```


## Configuration
The following tables lists the configurable parameters of the cert-manager chart and their default values.

| Parameter | Description | Default |
| --------- | ----------- | ------- |
|`testResources.enable`|Set to true to create test resources from template|`true`|
|`testResources.tppdomain`|Domain used in Venafi Platform issuer resources|`venqa.venafi.com`|
|`testResources.clouddomain`|Domain used in Venafi Cloud resources|`venafi.example.com`|
|`testResources.fakedomain`|Domain used in fake resources|`fake.venafi.com`|
|`fakeVenafiIssuer.name`|Name of the issuer|`fakevenafiissuer`|
|`fakeVenafiIssuer.enable`|You can disable issuer by setting this parameter to false|`true`|
|`tppVenafiIssuer.enable`|ou can disable issuer by setting this parameter to false |`true`|
|`tppVenafiIssuer.name`|Name of the issuer|`tppvenafiissuer`|
|`tppVenafiIssuer.tppsecret`|Venafi Platform secret for storing credentials|`tppsecret`|
|`tppVenafiIssuer.tppurl`|URL of Venafi Platform WebSDK|`https://tpp.venafi.example/vedsd`|
|`tppVenafiIssuer.zone`|Venafi Platform policy name|`devops\\cert-manager`|
|`cloudVenafiIssuer.enable`|You can disable issuer by setting this parameter to false|`true`|
|`cloudVenafiIssuer.name`|Name of the issuer|`cloudvenafiissuer`|
|`cloudVenafiIssuer.cloudsecret`|Cloud secret for storing credentials|`cloudsecret`|
|`cloudVenafiIssuer.zone`|Cloud zone|`Default`|
|`cloudVenafiIssuer.cloudurl`|Cloud URL, you can comment it to use production cloud.|`https://ui.dev12.qa.venafi.io/v1`|


Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`.

If connector.apikey is set cloud issuer will be used. If connector.tppuser is sett Venafi Venafi Platform will be used.

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

```console
$ helm install --name my-release -f values.yaml .
```
> **Tip**: You can use the default [values.yaml](values.yaml)
