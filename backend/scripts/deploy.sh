#!/bin/bash
# Deployment script for WhyTheyBuy to GCP Cloud Run
# Usage: ./scripts/deploy.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration - Update these or set via environment
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-whytheybuy-api}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

if [ -z "$PROJECT_ID" ]; then
    echo "Error: GCP_PROJECT_ID is not set"
    echo "Usage: GCP_PROJECT_ID=your-project ./scripts/deploy.sh"
    exit 1
fi

# Get infrastructure info
CLOUD_SQL_CONNECTION=$(gcloud sql instances describe whytheybuy-db \
    --format='value(connectionName)' \
    --project=$PROJECT_ID 2>/dev/null || echo "")

REDIS_HOST=$(gcloud redis instances describe whytheybuy-redis \
    --region=$REGION \
    --format='value(host)' \
    --project=$PROJECT_ID 2>/dev/null || echo "")

if [ -z "$CLOUD_SQL_CONNECTION" ]; then
    echo "Warning: Cloud SQL instance not found. Make sure to run gcp_setup.sh first."
fi

if [ -z "$REDIS_HOST" ]; then
    echo "Warning: Memorystore instance not found. Make sure to run gcp_setup.sh first."
fi

echo -e "${GREEN}Deploying WhyTheyBuy API to Cloud Run${NC}"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Service: $SERVICE_NAME"
echo ""

# Build and push Docker image
echo -e "${GREEN}Building Docker image...${NC}"
docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/whytheybuy/api:$IMAGE_TAG .

echo -e "${GREEN}Pushing to Artifact Registry...${NC}"
docker push $REGION-docker.pkg.dev/$PROJECT_ID/whytheybuy/api:$IMAGE_TAG

# Deploy to Cloud Run
echo -e "${GREEN}Deploying to Cloud Run...${NC}"

gcloud run deploy $SERVICE_NAME \
    --image=$REGION-docker.pkg.dev/$PROJECT_ID/whytheybuy/api:$IMAGE_TAG \
    --region=$REGION \
    --platform=managed \
    --allow-unauthenticated \
    --memory=1Gi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=10 \
    --timeout=300 \
    --concurrency=80 \
    --vpc-connector=whytheybuy-connector \
    --add-cloudsql-instances=$CLOUD_SQL_CONNECTION \
    --set-env-vars="GCP_PROJECT_ID=$PROJECT_ID" \
    --set-env-vars="GCP_REGION=$REGION" \
    --set-env-vars="USE_CLOUD_SQL_CONNECTOR=true" \
    --set-env-vars="CLOUD_SQL_INSTANCE_CONNECTION_NAME=$CLOUD_SQL_CONNECTION" \
    --set-env-vars="DB_USER=postgres" \
    --set-env-vars="DB_NAME=whytheybuy" \
    --set-env-vars="REDIS_HOST=$REDIS_HOST" \
    --set-env-vars="REDIS_PORT=6379" \
    --set-env-vars="AI_PROVIDER=gemini" \
    --set-env-vars="AI_MODEL=gemini-3-flash-preview" \
    --set-env-vars="GEMINI_MODEL=gemini-3-flash-preview" \
    --set-env-vars="DEBUG=false" \
    --set-secrets="JWT_SECRET_KEY=jwt-secret-key:latest" \
    --set-secrets="DB_PASS=db-password:latest" \
    --set-secrets="GEMINI_API_KEY=gemini-api-key:latest" \
    --project=$PROJECT_ID

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
    --region=$REGION \
    --format='value(status.url)' \
    --project=$PROJECT_ID)

echo ""
echo -e "${GREEN}Deployment complete!${NC}"
echo "Service URL: $SERVICE_URL"
echo ""
echo "Test the health endpoint:"
echo "  curl $SERVICE_URL/health"
