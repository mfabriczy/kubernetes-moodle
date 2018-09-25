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
