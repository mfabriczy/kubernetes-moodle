# kubernetes-moodle

A Helm chart to run Moodle on Kubernetes. This chart expects that a Kubernetes cluster has been provisioned and
configured by [kops](https://github.com/kubernetes/kops).

## Setup Helm

RBAC permissions for Tiller will need to be set. For the sake of expediency, the example provided: `tiller-rbac.yaml`
will create a service account which will bind to the super-user - `cluster-admin`.

```
kubectl create -f tiller-rbac.yaml
```

Start Tiller and add the service account to it:

```
helm init --service-account tiller
```

Install this Helm chart by using command, `helm install`.

Retrieve dependent Helm charts declared in the `requirements.yaml` file:
```
helm dependency update
```

After following the steps below, install this Helm chart by using command, `helm install`.

## [NGINX Ingress Controller](https://github.com/kubernetes/ingress-nginx)
Creates and configures a load balancer. The Ingress Controller is deployed as a
DaemonSet. Configured with an [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) to route
traffic to services within a cluster.

Set the value of the `moodleIngress.host` key to be the subdomain of your Moodle site, e.g., moodle.yourdomain.com.

## [ExternalDNS](https://github.com/kubernetes-incubator/external-dns)
Control DNS records dynamically by configuring your DNS provider - in this case, Route53.

In the `values.yaml` file, set the value of the `external-dns.domainFilters` key to be the domain e.g., "yourdomain.com".
