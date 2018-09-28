#!/usr/bin/env bash

# This script will create the role and policies required to allow the ExternalDNS pod(s) to create/remove its records
# in Route53.

ACCOUNT_ID=
NEW_ROLE_NAME="ExternalDnsRoleForRoute53"
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
}' --description 'The role the pod will assume to allow External DNS to perform actions against Route 53.'

aws iam put-role-policy --role-name $NEW_ROLE_NAME --policy-name ExternalDnsRoute53 --policy-document '{
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
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}'