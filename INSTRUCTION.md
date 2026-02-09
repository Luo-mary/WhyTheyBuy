# GCP Deployment Guide for WhyTheyBuy

This guide walks you through deploying the WhyTheyBuy application on Google Cloud Platform (GCP).

─                                   
  File:                               
  backend/scripts/run_migrations.py   
  Purpose: Migration runner for Cloud 
    Run Jobs                          
  Quick Start                         
                                      
  1. Set up GCP infrastructure:       
  cd backend                          
  GCP_PROJECT_ID=gen-lang-client-0407120714 ./scripts/gcp_setup.sh              
  2. Update secrets in Secret Manager:
    - gemini-api-key - Your Gemini API key                                
    - stripe-secret-key - Stripe secret key                          
    - Others as needed  

  # Update Gemini API key (read from your .env or paste directly)
  echo -n "YOUR_GEMINI_API_KEY" | gcloud secrets versions add gemini-api-key --data-file=- --project=$PROJECT_ID                                                                      
                                                                                             
  # Update Stripe secret key (if using payments)                                             
  echo -n "YOUR_STRIPE_SECRET_KEY" | gcloud secrets versions add stripe-secret-key           
  --data-file=- --project=$PROJECT_ID                                                        
                                                                                             
  # Update Stripe webhook secret (if using payments)                                         
  echo -n "YOUR_STRIPE_WEBHOOK_SECRET" | gcloud secrets versions add stripe-webhook-secret   
  --data-file=- --project=$PROJECT_ID                                                        
                                                                                             
  # Update SendGrid API key (if using email)                                                 
  echo -n "YOUR_SENDGRID_API_KEY" | gcloud secrets versions add sendgrid-api-key             
  --data-file=- --project=$PROJECT_ID  


  3. Deploy to Cloud Run:             
  GCP_PROJECT_ID=gen-lang-client-0407120714 ./scripts/deploy.sh                 
  4. Build and deploy frontend:       
  cd frontend flutter build web --release \       
    --dart-define=API_BASE_URL=https:/
  /your-cloud-run-url \               
                                      
  --dart-define=ENVIRONMENT=production
                                      
  See INSTRUCTION.md for the complete 
  deployment guide with detailed steps
   for each component.    

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [GCP Project Setup](#2-gcp-project-setup)
3. [Enable Required APIs](#3-enable-required-apis)
4. [Cloud SQL Setup (PostgreSQL)](#4-cloud-sql-setup-postgresql)
5. [Cloud Memorystore Setup (Redis)](#5-cloud-memorystore-setup-redis)
6. [Secret Manager Setup](#6-secret-manager-setup)
7. [Artifact Registry Setup](#7-artifact-registry-setup)
8. [Deploy Backend to Cloud Run](#8-deploy-backend-to-cloud-run)
9. [Deploy Celery Workers](#9-deploy-celery-workers)
10. [Deploy Frontend](#10-deploy-frontend)
11. [Configure Domain & SSL](#11-configure-domain--ssl)
12. [Set Up CI/CD with Cloud Build](#12-set-up-cicd-with-cloud-build)
13. [Monitoring & Logging](#13-monitoring--logging)
14. [Cost Optimization](#14-cost-optimization)
15. [Troubleshooting](#15-troubleshooting)

---

## 1. Prerequisites

Before starting, ensure you have:

- [ ] A Google Cloud account with billing enabled
- [ ] [Google Cloud SDK (gcloud CLI)](https://cloud.google.com/sdk/docs/install) installed
- [ ] Docker installed locally (for testing)
- [ ] Flutter SDK installed (for frontend)
- [ ] A domain name (optional, but recommended for production)

### Install and Configure gcloud CLI

```bash
# Install gcloud (macOS)
brew install google-cloud-sdk

# Initialize gcloud
gcloud init

# Login to your Google account
gcloud auth login

# Set your project
gcloud config set project YOUR_PROJECT_ID
```

---

## 2. GCP Project Setup

### Create a New Project

```bash
# Create a new project
gcloud projects create whytheybuy-prod --name="WhyTheyBuy Production"

# Set as default project
gcloud config set project whytheybuy-prod

# Link to billing account (required for paid services)
gcloud beta billing projects link whytheybuy-prod \
    --billing-account=YOUR_BILLING_ACCOUNT_ID
```

### Set Environment Variables

```bash
# Set these for the rest of the guide
export PROJECT_ID=whytheybuy-prod
export REGION=us-central1
export ZONE=us-central1-a
```

---

## 3. Enable Required APIs

```bash
# Enable all required APIs
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    sqladmin.googleapis.com \
    secretmanager.googleapis.com \
    redis.googleapis.com \
    compute.googleapis.com \
    artifactregistry.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iam.googleapis.com \
    vpcaccess.googleapis.com
```

---

## 4. Cloud SQL Setup (PostgreSQL)

### Create Cloud SQL Instance

```bash
# Create a PostgreSQL 15 instance
gcloud sql instances create whytheybuy-db \
    --database-version=POSTGRES_15 \
    --tier=db-f1-micro \
    --region=$REGION \
    --storage-type=SSD \
    --storage-size=10GB \
    --availability-type=zonal \
    --backup-start-time=03:00

# Wait for instance to be ready (this takes 5-10 minutes)
gcloud sql instances describe whytheybuy-db
```

### Set Database Password

```bash
# Generate a secure password
DB_PASSWORD=$(openssl rand -base64 32)
echo "Save this password securely: $DB_PASSWORD"

# Set the postgres user password
gcloud sql users set-password postgres \
    --instance=whytheybuy-db \
    --password="$DB_PASSWORD"
```

### Create the Database

```bash
# Create the whytheybuy database
gcloud sql databases create whytheybuy \
    --instance=whytheybuy-db
```

### Get Connection Information

```bash
# Get the instance connection name (you'll need this later)
gcloud sql instances describe whytheybuy-db \
    --format="value(connectionName)"

# Example output: whytheybuy-prod:us-central1:whytheybuy-db
```

### Run Database Migrations

You can run migrations using Cloud SQL Auth Proxy locally:

```bash
# Download Cloud SQL Auth Proxy
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.1/cloud-sql-proxy.darwin.amd64
chmod +x cloud-sql-proxy

# Start the proxy in another terminal
./cloud-sql-proxy $PROJECT_ID:$REGION:whytheybuy-db

# In your backend directory, run migrations
cd backend
export DATABASE_URL="postgresql://postgres:$DB_PASSWORD@localhost:5432/whytheybuy"
alembic upgrade head
```

---

## 5. Cloud Memorystore Setup (Redis)

### Create VPC Connector (Required for Memorystore)

```bash
# Create a VPC connector for Cloud Run to access Memorystore
gcloud compute networks vpc-access connectors create whytheybuy-connector \
    --region=$REGION \
    --range=10.8.0.0/28
```

### Create Memorystore Redis Instance

```bash
# Create a basic Redis instance (1GB)
gcloud redis instances create whytheybuy-redis \
    --size=1 \
    --region=$REGION \
    --tier=basic \
    --redis-version=redis_7_0

# Wait for instance to be ready (this takes 5-10 minutes)
gcloud redis instances describe whytheybuy-redis --region=$REGION
```

### Get Redis IP Address

```bash
# Get the Redis host IP
REDIS_HOST=$(gcloud redis instances describe whytheybuy-redis \
    --region=$REGION \
    --format="value(host)")
echo "Redis Host: $REDIS_HOST"
```

---

## 6. Secret Manager Setup

Store all sensitive values in Secret Manager:

```bash
# JWT Secret Key
JWT_SECRET=$(openssl rand -base64 64)
echo -n "$JWT_SECRET" | gcloud secrets create jwt-secret-key --data-file=-

# Database Password
echo -n "$DB_PASSWORD" | gcloud secrets create db-password --data-file=-

# Gemini API Key
echo -n "YOUR_GEMINI_API_KEY" | gcloud secrets create gemini-api-key --data-file=-

# Stripe Secret Key (if using payments)
echo -n "sk_live_xxxxx" | gcloud secrets create stripe-secret-key --data-file=-

# Stripe Webhook Secret
echo -n "whsec_xxxxx" | gcloud secrets create stripe-webhook-secret --data-file=-

# SendGrid API Key (if using email)
echo -n "SG.xxxxx" | gcloud secrets create sendgrid-api-key --data-file=-
```

### Grant Cloud Run Access to Secrets

```bash
# Get the Cloud Run service account
SERVICE_ACCOUNT="$PROJECT_ID@$PROJECT_ID.iam.gserviceaccount.com"

# Grant access to secrets
for SECRET in jwt-secret-key db-password gemini-api-key stripe-secret-key stripe-webhook-secret sendgrid-api-key; do
    gcloud secrets add-iam-policy-binding $SECRET \
        --member="serviceAccount:$SERVICE_ACCOUNT" \
        --role="roles/secretmanager.secretAccessor"
done
```

---

## 7. Artifact Registry Setup

```bash
# Create a Docker repository
gcloud artifacts repositories create whytheybuy \
    --repository-format=docker \
    --location=$REGION \
    --description="WhyTheyBuy Docker images"

# Configure Docker to use Artifact Registry
gcloud auth configure-docker $REGION-docker.pkg.dev
```

---

## 8. Deploy Backend to Cloud Run

### Build and Push Docker Image

```bash
cd backend

# Build the image
docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/whytheybuy/api:latest .

# Push to Artifact Registry
docker push $REGION-docker.pkg.dev/$PROJECT_ID/whytheybuy/api:latest
```

### Deploy to Cloud Run

```bash
# Get Cloud SQL instance connection name
CLOUD_SQL_CONNECTION=$(gcloud sql instances describe whytheybuy-db \
    --format="value(connectionName)")

# Deploy the service
gcloud run deploy whytheybuy-api \
    --image=$REGION-docker.pkg.dev/$PROJECT_ID/whytheybuy/api:latest \
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
    --set-secrets="GEMINI_API_KEY=gemini-api-key:latest"
```

### Get the API URL

```bash
API_URL=$(gcloud run services describe whytheybuy-api \
    --region=$REGION \
    --format="value(status.url)")
echo "API URL: $API_URL"

# Test the health endpoint
curl $API_URL/health
```

### Update CORS for Production

Once you have your frontend domain, update the CORS configuration:

```bash
gcloud run services update whytheybuy-api \
    --region=$REGION \
    --set-env-vars="CORS_ORIGINS=https://yourdomain.com,https://www.yourdomain.com"
```

---

## 9. Deploy Celery Workers

Celery workers need to run as long-lived processes. We'll use Compute Engine for this.

### Create Compute Engine VM for Celery

```bash
# Build and push Celery worker image
docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/whytheybuy/celery:latest \
    -f Dockerfile.celery .
docker push $REGION-docker.pkg.dev/$PROJECT_ID/whytheybuy/celery:latest

# Create a VM instance
gcloud compute instances create-with-container whytheybuy-celery \
    --zone=$ZONE \
    --machine-type=e2-small \
    --container-image=$REGION-docker.pkg.dev/$PROJECT_ID/whytheybuy/celery:latest \
    --container-env="GCP_PROJECT_ID=$PROJECT_ID" \
    --container-env="REDIS_HOST=$REDIS_HOST" \
    --container-env="USE_CLOUD_SQL_CONNECTOR=true" \
    --container-env="CLOUD_SQL_INSTANCE_CONNECTION_NAME=$CLOUD_SQL_CONNECTION" \
    --container-env="DB_USER=postgres" \
    --container-env="DB_NAME=whytheybuy" \
    --scopes=cloud-platform
```

### Create Celery Beat Scheduler

```bash
# Create a separate VM for Celery Beat
gcloud compute instances create-with-container whytheybuy-celery-beat \
    --zone=$ZONE \
    --machine-type=e2-micro \
    --container-image=$REGION-docker.pkg.dev/$PROJECT_ID/whytheybuy/celery:latest \
    --container-command="celery" \
    --container-arg="-A" \
    --container-arg="app.worker" \
    --container-arg="beat" \
    --container-arg="--loglevel=info" \
    --container-env="GCP_PROJECT_ID=$PROJECT_ID" \
    --container-env="REDIS_HOST=$REDIS_HOST" \
    --container-env="USE_CLOUD_SQL_CONNECTOR=true" \
    --container-env="CLOUD_SQL_INSTANCE_CONNECTION_NAME=$CLOUD_SQL_CONNECTION" \
    --container-env="DB_USER=postgres" \
    --container-env="DB_NAME=whytheybuy" \
    --scopes=cloud-platform
```

---

## 10. Deploy Frontend

### Option A: Firebase Hosting (Recommended)

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project
cd frontend
firebase init hosting

# Build Flutter web
flutter build web --release \
    --dart-define=API_BASE_URL=$API_URL \
    --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_xxxxx

# Deploy to Firebase
firebase deploy --only hosting
```

### Option B: Cloud Storage + Cloud CDN

```bash
# Create a Cloud Storage bucket
gsutil mb -l $REGION gs://$PROJECT_ID-frontend

# Enable website hosting
gsutil web set -m index.html -e index.html gs://$PROJECT_ID-frontend

# Build Flutter web
cd frontend
flutter build web --release \
    --dart-define=API_BASE_URL=$API_URL \
    --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_xxxxx

# Upload to Cloud Storage
gsutil -m cp -r build/web/* gs://$PROJECT_ID-frontend/

# Make public
gsutil iam ch allUsers:objectViewer gs://$PROJECT_ID-frontend
```

### Mobile App Distribution

For iOS and Android builds:

```bash
# Build Android APK/Bundle
flutter build appbundle --release \
    --dart-define=API_BASE_URL=$API_URL

# Build iOS
flutter build ios --release \
    --dart-define=API_BASE_URL=$API_URL
```

---

## 11. Configure Domain & SSL

### Set Up Cloud Load Balancer with Custom Domain

```bash
# Reserve a static IP
gcloud compute addresses create whytheybuy-ip --global

# Get the IP address
gcloud compute addresses describe whytheybuy-ip --global

# Create SSL certificate (managed by Google)
gcloud compute ssl-certificates create whytheybuy-cert \
    --domains=api.yourdomain.com \
    --global

# Create backend service for Cloud Run
gcloud compute backend-services create whytheybuy-backend \
    --global \
    --load-balancing-scheme=EXTERNAL_MANAGED

# Create URL map
gcloud compute url-maps create whytheybuy-map \
    --default-service=whytheybuy-backend

# Create HTTPS proxy
gcloud compute target-https-proxies create whytheybuy-proxy \
    --url-map=whytheybuy-map \
    --ssl-certificates=whytheybuy-cert

# Create forwarding rule
gcloud compute forwarding-rules create whytheybuy-forwarding \
    --global \
    --target-https-proxy=whytheybuy-proxy \
    --ports=443 \
    --address=whytheybuy-ip
```

### Update DNS Records

Add the following DNS records at your domain registrar:

| Type | Name | Value |
|------|------|-------|
| A | api | (your static IP from above) |
| A | @ | (Firebase Hosting IPs) |
| CNAME | www | yourdomain.com |

---

## 12. Set Up CI/CD with Cloud Build

### Connect Repository

```bash
# Connect to GitHub (follow the prompts)
gcloud builds triggers create github \
    --repo-name=YOUR_REPO_NAME \
    --repo-owner=YOUR_GITHUB_USERNAME \
    --branch-pattern="^main$" \
    --build-config=backend/cloudbuild.yaml \
    --name=whytheybuy-deploy
```

### Grant Cloud Build Permissions

```bash
# Get Cloud Build service account
CLOUDBUILD_SA="$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')@cloudbuild.gserviceaccount.com"

# Grant required roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CLOUDBUILD_SA" \
    --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CLOUDBUILD_SA" \
    --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CLOUDBUILD_SA" \
    --role="roles/secretmanager.secretAccessor"
```

---

## 13. Monitoring & Logging

### Enable Cloud Monitoring

```bash
# View logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=whytheybuy-api" \
    --limit=50

# Create an uptime check
gcloud monitoring uptime-check-configs create \
    --display-name="WhyTheyBuy API Health" \
    --protocol=https \
    --host=api.yourdomain.com \
    --path=/health \
    --period=60 \
    --timeout=10
```

### Set Up Alerts

```bash
# Create a notification channel (email)
gcloud alpha monitoring channels create \
    --display-name="Admin Email" \
    --type=email \
    --channel-labels=email_address=admin@yourdomain.com

# Create an alerting policy for high error rate
# (This is easier done in the Cloud Console)
```

---

## 14. Cost Optimization

### Estimated Monthly Costs (USD)

| Service | Tier | Estimated Cost |
|---------|------|----------------|
| Cloud Run | 1 vCPU, 1GB RAM, ~100k requests | $5-20 |
| Cloud SQL | db-f1-micro, 10GB SSD | $15-20 |
| Cloud Memorystore | 1GB Basic | $35 |
| Compute Engine (Celery) | 2x e2-small | $15 |
| Cloud Storage | 1GB | $0.02 |
| Secret Manager | 6 secrets | $0.06 |
| **Total** | | **$70-100** |

### Cost-Saving Tips

1. **Cloud SQL**: Use the smallest tier that works, scale up as needed
2. **Cloud Run**: Set min-instances to 0 if you can tolerate cold starts
3. **Memorystore**: Consider using Cloud Run's built-in caching if Redis isn't critical
4. **Compute Engine**: Use preemptible VMs for Celery workers (with restart logic)

---

## 15. Troubleshooting

### Common Issues

#### 1. Cloud Run Can't Connect to Cloud SQL

```bash
# Check if Cloud SQL Admin API is enabled
gcloud services list --enabled | grep sqladmin

# Verify the connection name
gcloud sql instances describe whytheybuy-db --format="value(connectionName)"

# Check Cloud Run service account has Cloud SQL Client role
gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.role:roles/cloudsql.client"
```

#### 2. Cloud Run Can't Reach Memorystore

```bash
# Verify VPC connector is attached
gcloud run services describe whytheybuy-api --region=$REGION \
    --format="value(spec.template.metadata.annotations['run.googleapis.com/vpc-access-connector'])"

# Check if VPC connector is ready
gcloud compute networks vpc-access connectors describe whytheybuy-connector \
    --region=$REGION
```

#### 3. Secrets Not Loading

```bash
# Verify secret exists
gcloud secrets describe gemini-api-key

# Check IAM permissions
gcloud secrets get-iam-policy gemini-api-key

# Test accessing a secret
gcloud secrets versions access latest --secret=gemini-api-key
```

#### 4. Database Migrations Fail

```bash
# Connect via Cloud SQL Proxy locally
./cloud-sql-proxy $PROJECT_ID:$REGION:whytheybuy-db &

# Test connection
psql "postgresql://postgres:$DB_PASSWORD@localhost:5432/whytheybuy"

# Run migrations manually
cd backend
alembic upgrade head
```

### Viewing Logs

```bash
# Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision" --limit=100

# Celery worker logs
gcloud compute ssh whytheybuy-celery --zone=$ZONE -- docker logs -f $(docker ps -q)

# Cloud SQL logs
gcloud sql operations list --instance=whytheybuy-db
```

---

## Quick Reference Commands

```bash
# Redeploy Cloud Run after code changes
gcloud run deploy whytheybuy-api \
    --image=$REGION-docker.pkg.dev/$PROJECT_ID/whytheybuy/api:latest \
    --region=$REGION

# Update environment variable
gcloud run services update whytheybuy-api \
    --region=$REGION \
    --set-env-vars="NEW_VAR=value"

# Scale Cloud Run
gcloud run services update whytheybuy-api \
    --region=$REGION \
    --min-instances=1 \
    --max-instances=20

# View Cloud Run service
gcloud run services describe whytheybuy-api --region=$REGION

# Restart Celery workers
gcloud compute instances reset whytheybuy-celery --zone=$ZONE
```

---

## Architecture Diagram

```
                                ┌─────────────────────────────────────────┐
                                │         Google Cloud Platform            │
                                │                                          │
   Users                        │   ┌─────────────────────────────────┐   │
     │                          │   │      Cloud Load Balancer        │   │
     │                          │   │     (Global HTTPS + SSL)        │   │
     ▼                          │   └───────────────┬─────────────────┘   │
┌─────────┐                     │                   │                      │
│ Browser │◄───────────────────►│   ┌───────────────▼─────────────────┐   │
│ or App  │                     │   │         Cloud Run               │   │
└─────────┘                     │   │     (FastAPI + Gunicorn)        │   │
                                │   │     ─ Auto-scaling              │   │
     │ Flutter Web              │   │     ─ Serverless                │   │
     │ (Firebase Hosting)       │   └───────────────┬─────────────────┘   │
     ▼                          │                   │                      │
┌─────────────────┐             │     ┌─────────────┼─────────────┐       │
│ Firebase Hosting│             │     ▼             ▼             ▼       │
│ (Static Assets) │             │ ┌───────┐   ┌───────────┐  ┌────────┐   │
└─────────────────┘             │ │Cloud  │   │ Cloud     │  │Secret  │   │
                                │ │SQL    │   │ Memorystore  │Manager │   │
                                │ │(Postgres)  │ (Redis)   │  │        │   │
                                │ └───────┘   └───────────┘  └────────┘   │
                                │     ▲             ▲                      │
                                │     │             │                      │
                                │     └─────────────┼──────────────────┐  │
                                │                   │                  │  │
                                │   ┌───────────────▼──────────────┐   │  │
                                │   │      Compute Engine          │   │  │
                                │   │   (Celery Worker + Beat)     │   │  │
                                │   └──────────────────────────────┘   │  │
                                │                                      │  │
                                │   ┌──────────────────────────────┐   │  │
                                │   │        Cloud Storage         │◄──┘  │
                                │   │     (File uploads, backups)  │      │
                                │   └──────────────────────────────┘      │
                                │                                          │
                                └──────────────────────────────────────────┘
```

---

## Next Steps

After deployment:

1. [ ] Set up proper domain and SSL certificates
2. [ ] Configure Stripe webhooks with production endpoint
3. [ ] Set up email templates in SendGrid
4. [ ] Configure alerting and monitoring dashboards
5. [ ] Set up regular database backups
6. [ ] Implement log-based metrics for business KPIs
7. [ ] Load test the application
8. [ ] Set up staging environment for testing

---

## Support

For issues specific to:
- **GCP Services**: [Google Cloud Support](https://cloud.google.com/support)
- **Flutter**: [Flutter Documentation](https://docs.flutter.dev)
- **FastAPI**: [FastAPI Documentation](https://fastapi.tiangolo.com)
- **Gemini API**: [Google AI Documentation](https://ai.google.dev/docs)
