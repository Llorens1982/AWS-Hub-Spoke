#!/usr/bin/env bash
# bootstrap.sh — Crea el bucket S3 y tabla DynamoDB para el estado remoto de Terraform.
# Uso: ./scripts/bootstrap.sh <bucket-name> <dynamodb-table> <region>

set -euo pipefail

BUCKET_NAME="${1:?Debes indicar el nombre del bucket S3}"
TABLE_NAME="${2:?Debes indicar el nombre de la tabla DynamoDB}"
REGION="${3:-eu-west-1}"

echo "🪣  Creando bucket S3: $BUCKET_NAME en $REGION"
if [[ "$REGION" == "us-east-1" ]]; then
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION"
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
fi

echo "🔒  Habilitando versionado en el bucket..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

echo "🔐  Habilitando cifrado SSE-S3..."
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "🚫  Bloqueando acceso público al bucket..."
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "🗄️   Creando tabla DynamoDB para locks: $TABLE_NAME"
aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"

echo ""
echo "✅  Bootstrap completado."
echo ""
echo "Añade estas variables a los Secrets de GitHub Actions:"
echo "  TF_STATE_BUCKET  = $BUCKET_NAME"
echo "  TF_LOCK_TABLE    = $TABLE_NAME"
echo "  AWS_REGION       = $REGION"
echo ""
echo "A continuación ejecuta:"
echo "  terraform init \\"
echo "    -backend-config=\"bucket=$BUCKET_NAME\" \\"
echo "    -backend-config=\"dynamodb_table=$TABLE_NAME\" \\"
echo "    -backend-config=\"region=$REGION\""
