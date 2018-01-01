#!/bin/bash

set -e
set -o pipefail

if [ -z "$AWS_REGION" ]; then
  echo >&2 'Error: missing AWS_REGION environment variable.'
  exit 1
fi

if [ -z "$AWS_S3_CONFIGURATION_OBJECT" ]; then
  echo >&2 'Error: missing AWS_S3_CONFIGURATION_OBJECT environment variable.'
  exit 1
fi

echo "Fetching and sourcing configuration."
eval $(aws s3 cp --sse AES256 --region ${AWS_REGION} \
    ${AWS_S3_CONFIGURATION_OBJECT} - | sed 's/^/export /')

echo "Fetching certificate..."
certbot certonly \
    --non-interactive \
    --manual \
    --manual-public-ip-logging-ok \
    --manual-auth-hook /opt/cert-manager/scripts/route53-auth-hook.sh \
    --manual-cleanup-hook /opt/cert-manager/scripts/route53-cleanup-hook.sh \
    --config-dir /opt/cert-manager/certs/ \
    --logs-dir /opt/cert-manager/logs/ \
    --work-dir /opt/cert-manager/work/ \
    --agree-tos \
    --preferred-challenges dns \
    --domain ${CERT_MANAGER_DOMAIN} \
    --email ${CERT_MANAGER_EMAIL}

echo "Converting to PKCS12 keystore..."
openssl pkcs12 \
    -export \
    -inkey /opt/cert-manager/certs/live/${CERT_MANAGER_DOMAIN}/privkey.pem \
    -in /opt/cert-manager/certs/live/${CERT_MANAGER_DOMAIN}/fullchain.pem \
    -out /opt/cert-manager/certs/live/${CERT_MANAGER_DOMAIN}/keystore.pkcs12 \
    -password pass:${CERT_MANAGER_KEY_STORE_PASSWORD}

echo "Done."
