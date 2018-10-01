#!/usr/bin/env bash

# This script will create the role and policies to allow the cert-manager pod(s) to perform DNS validation against
# Let's Encrypt, allowing it to issue TLS certificates.

ACCOUNT_ID=
NEW_ROLE_NAME="CertManagerDNSValidate"
NODE_ROLE_NAME=

aws iam create-role --role-name $NEW_ROLE_NAME --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::'"$ACCOUNT_ID"':role/'"$NODE_ROLE_NAME"'"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}' --description "The role the cert-manager pod assumes (via kube2iam) to perform DNS validation against Let's Encrypt."

aws iam put-role-policy --role-name $NEW_ROLE_NAME --policy-name CertManagerRoute53 --policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZonesByName"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}'