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

After following the steps below, install this Helm chart by using command, `helm install --timeout 600 --wait`.
Spinnaker takes awhile to install, so use the `--timeout` and `--wait` flags.

## [NGINX Ingress Controller](https://github.com/kubernetes/ingress-nginx)
Creates and configures a load balancer. The Ingress Controller is deployed as a
DaemonSet. Configured with an [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) to route
traffic to services within a cluster.

Set the value of the `moodleIngress.host` key to be the subdomain of your Moodle site, e.g., moodle.yourdomain.com.

## [ExternalDNS](https://github.com/kubernetes-incubator/external-dns)
Control DNS records dynamically by configuring your DNS provider - in this case, Route53.

In the `values.yaml` file, set the value of the `external-dns.domainFilters` key to be the domain e.g., "yourdomain.com".

## [kube2iam](https://github.com/jtblin/kube2iam)
Allows a pod to assume an IAM role. Deployed as a
[DaemonSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)

Multiple containers with different purposes usually share the same node (unless using
[nodeSelector](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#nodeselector)) and thus a single IAM
role (an EC2 instance can only have one IAM role). Previously one would create an IAM role with all the necessary IAM
policies attached; this is not advisable from a security standpoint.

An IAM role will need to be created. This role would contain the necessary policies to allow ExternalDNS to configure
Route 53. The role will be annotated to the ExternalDNS pod, and the pod will assume that role.

To create the role, use the provided shell script: `iam-create-externaldns-role.sh`; set the values for the `ACCOUNT_ID`
([AWS Account ID](https://docs.aws.amazon.com/IAM/latest/UserGuide/console_account-alias.html#FindingYourAWSId)), and
`NODE_ROLE_NAME` with the name of the role attached to your node(s).

## [cert-manager](https://github.com/jetstack/cert-manager)
cert-manager is used to automate the management and issuance of TLS certificates from
[Let's Encrypt](https://letsencrypt.org/).

cert-manager will ensure certificates are valid and up to date, and will renew certificates before expiry.

Set the value of the `cert-manager.clusterIssuer.email` key to be your email address. Let's Encrypt will use this to
contact you about expiring certificates, and other issues related to your account.

An IAM role will need to be created. This role would contain the necessary policies to allow cert-manager to validate
[DNS-01 challenge](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge) requests against Route 53. The role
will be annotated to the cert-manager pod, and the pod will assume that role.

To create the role, use the provided shell script: `iam-create-cert-manager-role.sh`; set the values for the `ACCOUNT_ID`
([AWS Account ID](https://docs.aws.amazon.com/IAM/latest/UserGuide/console_account-alias.html#FindingYourAWSId)), and
`NODE_ROLE_NAME` with the name of the role attached to your node(s).

## [Spinnaker](https://www.spinnaker.io/)
A continuous delivery platform. Create deployment pipelines that run integration and system tests, spin up and down
server groups, and monitor your rollouts. Trigger pipelines via Git events, Jenkins, or other Spinnaker pipelines. This
will be used to deploy Moodle patches and releases.

[Halyard](https://github.com/spinnaker/halyard) is used to configure Spinnaker.

### Authentication and Authorisation
By default, Spinnaker is configured without any authentication and authorisation.

This Helm chart can configure Spinnaker to use OAuth 2.0 - GitHub as the provider, if enabled.

Create an OAuth app on GitHub
([link](https://developer.github.com/apps/building-oauth-apps/creating-an-oauth-app/)).

In the Homepage URL field, set the subdomain value that users will access Spinnaker from
([Deck](https://github.com/spinnaker/deck)), e.g., `https://spinnaker.yourdomain.com`. Set the
`spinnaker.oauth.uiBaseURL`, `spinnaker.ingress.host` (without HTTPS), `spinnaker.ingress.tls.secretName` (without HTTPS),
`spinnaker.ingress.tls.hosts` (without HTTPS) and `spinnaker.ingress.annotations.external-dns.alpha.kubernetes.io/hostname`
(without HTTPS) keys to the same subdomain value.

Set a value in the
[Authorization callback URL](https://developer.github.com/apps/building-oauth-apps/authorizing-oauth-apps/#redirect-urls)
field: GitHub will redirect a user to that address ([Spinnaker API Gateway](https://github.com/spinnaker/gate))
after authentication has been completed. For example, `https://api.spinnaker.yourdomain.com/login` - note that `/login`
at the end of the value is needed; afterwards, set the API subdomain value you had just inserted in GitHub to the
following keys: `spinnaker.ingressGate.host` (without HTTPS), `spinnaker.ingressGate.tls.secretName` (without HTTPS),
`spinnaker.ingressGate.tls.hosts` (without HTTPS) and
`spinnaker.ingressGate.annotations.external-dns.alpha.kubernetes.io/hostname` (without HTTPS).

When logging into Spinnaker for the first time, as part of the OAuth authorisation process, you will be prompted to enter
your GitHub credentials to proceed.

### Pipelines
Pipelines will be used deploy Moodle releases and patches into a cluster. An artifact is generated from the Moodle chart
by using the command, `helm package`. The artifact is then stored into S3, to be consumed by Spinnaker; afterwards, it's
deployed into a cluster. In the future, Jenkins will be used to help automate the deployment process which includes the
packaging of the Moodle Helm chart.

To have S3 as the artifact provider, insert the access and secret key of a user from IAM into the following keys in
`values.yaml`: `spinnaker.artifact.s3.accessKey` and `spinnaker.artifact.s3.secretKey`. The IAM user will need a policy
attached to get objects from an S3 bucket. You can use the `AdministratorAccess` policy for testing only; it is not
recommended for use in production.

Create an S3 bucket to contain the artifacts. In the future, [Terraform](https://www.terraform.io) will be used to
create the bucket.

Create a deployment pipeline using the `pipeline-s3-moodle-deploy.json` file
([instructions](https://www.spinnaker.io/guides/user/pipeline/managing-pipelines/#edit-a-pipeline-as-json)). The file
can be used as a reference point to build a pipeline to satisfy requirements. After creation, be sure to add the
bucket's name into the
[Expected Artifacts](https://www.spinnaker.io/reference/artifacts/in-pipelines/#expected-artifacts) section.
