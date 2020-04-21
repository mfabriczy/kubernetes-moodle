# kubernetes-moodle

A Helm chart to run Moodle on Kubernetes. This chart expects that a Kubernetes cluster has been provisioned and
configured by [kops](https://github.com/kubernetes/kops).

## Setup Helm

Retrieve dependent Helm charts declared in the `requirements.yaml` file:
```
helm dependency update
```

After configuration, install the Helm chart by executing the init script, `./init`.

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

To create the role, use the provided file: `external-dns-role.tf`; set the values for the `ACCOUNT_ID`
([AWS Account ID](https://docs.aws.amazon.com/IAM/latest/UserGuide/console_account-alias.html#FindingYourAWSId)) in the
resource argument `aws_iam_role.ExternalDNS.assume_role_policy`, and replace the `NODE_ROLE_NAME` placeholder with the
name of the role attached to your node(s). When done, use `terraform apply`.

## [cert-manager](https://github.com/jetstack/cert-manager)
cert-manager is used to automate the management and issuance of TLS certificates from
[Let's Encrypt](https://letsencrypt.org/).

cert-manager will ensure certificates are valid and up to date, and will renew certificates before expiry.

Set the value of the `cert-manager.clusterIssuer.email` key to be your email address. Let's Encrypt will use this to
contact you about expiring certificates, and other issues related to your account.

Match via DNS zone to identify the provider in order to do DNS01 challenges. Specify the DNS zone in
`cert-manager-clusterIssuer.dnsZones`.

An IAM role will need to be created. This role would contain the necessary policies to allow cert-mananger to validate
[DNS-01 challenge](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge) requests against Route 53. The role
will be annotated to the cert-manager pod, and the pod will assume that role.

To create the role, use the provided Terraform file: `cert-manager-role.tf`; set the values for the `ACCOUNT_ID`
([AWS Account ID](https://docs.aws.amazon.com/IAM/latest/UserGuide/console_account-alias.html#FindingYourAWSId)) in the
resource argument `aws_iam_role.CertManager.assume_role_policy`, and replace the `NODE_ROLE_NAME` placeholder with the
name of the role attached to your node(s). When done, use `terraform apply`.

Once created, add that role's ARN to the `cert-manager/values.yaml` file.

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

Create an S3 bucket, IAM user, and a IAM policy to allow Spinnaker to access and retrieve objects from the bucket.
[Terraform](https://www.terraform.io) will be needed to create the aforementioned resources defined in the
`spinnaker-artifact.tf` file. In said file, specify a globally unique name for the bucket for the resource argument,
`aws_s3_bucket.s3_spinnaker_moodle_artifacts.name`; ensure that bucket name is inserted into the policy document for the
resource argument, `aws_iam_user_policy.s3_spinnaker_moodle_artifacts.policy`. When done, use `terraform apply`.

Now, to generate an IAM access key for the user account that was just created, see the
[link](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey) for the
instructions.

To have S3 as the artifact provider for Spinnaker, insert the access and secret key of the user from IAM into the
following keys in `values.yaml`: `spinnaker.artifact.s3.accessKey` and `spinnaker.artifact.s3.secretKey`.

Create a deployment pipeline using the `pipeline-s3-moodle-deploy.json` file
([instructions](https://www.spinnaker.io/guides/user/pipeline/managing-pipelines/#edit-a-pipeline-as-json)). The file
can be used as a reference point to build a pipeline to satisfy requirements. After creation, be sure to add the
bucket's name into the
[Expected Artifacts](https://www.spinnaker.io/reference/artifacts/in-pipelines/#expected-artifacts) section.

## [Prometheus](https://prometheus.io/) and [Grafana](https://grafana.com/)
Prometheus is used to collect metrics from the Kubernetes cluster, and more specifically, pods running Moodle. Grafana
will use that data to display those metrics in dashboards. Users will be able to view the state of the cluster, allowing
one to be proactive in identifying and addressing issues.

### Prometheus Setup

Firstly, set the subdomain value for your Prometheus instance. Set the value for the keys
`prometheus-operator.prometheus.ingress.annotations.external-dns.alpha.kubernetes.io/hostname` and
`prometheus-operator.prometheus.ingress.hosts`.

For HTTPS, set that subdomain value for the keys: `prometheus-operator.prometheus.ingress.tls.secretName` and
`prometheus-operator.prometheus.ingress.tls.hosts`.

### Grafana Setup

Firstly, set the subdomain value for your Grafana instance. Set the value for the keys
`prometheus-operator.grafana.ingress.annotations.external-dns.alpha.kubernetes.io/hostname` and
`prometheus-operator.grafana.ingress.hosts`.

For HTTPS, set that subdomain value for the keys: `prometheus-operator.grafana.ingress.tls.secretName` and
`prometheus-operator.grafana.ingress.tls.hosts`.

Lastly, set a password for the admin user by setting a value for the key, `grafana.adminPassword`. Once Grafana is
running, you can login using the username, `admin`.

#### kube-proxy Metrics
The default bind address for `kube-proxy` to collect metrics is `127.0.0.1:10249` - Prometheus instances cannot access.
Add/change `metricsBindAddress` to `0.0.0.0:10249`. If using kops, edit the cluster - `kops edit cluster`, then add the
entry as below:

```
apiVersion: kops.k8s.io/v1alpha2
kind: Cluster
metadata:
  creationTimestamp: "2020-04-21T10:38:47Z"
  name: domain.com
spec:
  kubeProxy:
    metricsBindAddress: 0.0.0.0
  api:
    dns: {}
  authorization:
    rbac: {}
  channel: stable
  cloudProvider: aws
```
