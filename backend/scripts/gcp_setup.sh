#!/bin/bash
# GCP Setup Script for WhyTheyBuy
# This script automates the initial GCP infrastructure setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration - Update these values
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"
ZONE="${GCP_ZONE:-us-central1-a}"

# Service names
API_SERVICE_NAME="whytheybuy-api"
DB_INSTANCE_NAME="whytheybuy-db"
REDIS_INSTANCE_NAME="whytheybuy-redis"
VPC_CONNECTOR_NAME="whytheybuy-connector"

print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

check_prerequisites() {
    print_step "Checking prerequisites..."

    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed. Please install it first."
        exit 1
    fi

    if [ -z "$PROJECT_ID" ]; then
        print_error "GCP_PROJECT_ID environment variable is not set."
        echo "Usage: GCP_PROJECT_ID=your-project-id ./scripts/gcp_setup.sh"
        exit 1
    fi

    # Check if authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 > /dev/null 2>&1; then
        print_error "Not authenticated with gcloud. Run 'gcloud auth login' first."
        exit 1
    fi

    echo "Project ID: $PROJECT_ID"
    echo "Region: $REGION"
    echo "Zone: $ZONE"
}

enable_apis() {
    print_step "Enabling required APIs..."

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
        vpcaccess.googleapis.com \
        --project=$PROJECT_ID

    echo "APIs enabled successfully."
}

create_artifact_registry() {
    print_step "Creating Artifact Registry repository..."

    if gcloud artifacts repositories describe whytheybuy --location=$REGION --project=$PROJECT_ID &> /dev/null; then
        print_warning "Artifact Registry repository already exists. Skipping."
    else
        gcloud artifacts repositories create whytheybuy \
            --repository-format=docker \
            --location=$REGION \
            --description="WhyTheyBuy Docker images" \
            --project=$PROJECT_ID
        echo "Artifact Registry created."
    fi
}

create_cloud_sql() {
    print_step "Creating Cloud SQL instance..."

    if gcloud sql instances describe $DB_INSTANCE_NAME --project=$PROJECT_ID &> /dev/null; then
        print_warning "Cloud SQL instance already exists. Skipping."
    else
        gcloud sql instances create $DB_INSTANCE_NAME \
            --database-version=POSTGRES_15 \
            --tier=db-f1-micro \
            --region=$REGION \
            --storage-type=SSD \
            --storage-size=10GB \
            --availability-type=zonal \
            --backup-start-time=03:00 \
            --project=$PROJECT_ID

        echo "Cloud SQL instance created. This may take 5-10 minutes..."

        # Wait for instance to be ready
        while [ "$(gcloud sql instances describe $DB_INSTANCE_NAME --format='value(state)' --project=$PROJECT_ID)" != "RUNNABLE" ]; do
            echo "Waiting for Cloud SQL instance to be ready..."
            sleep 10
        done

        # Generate and set password
        DB_PASSWORD=$(openssl rand -base64 32)
        gcloud sql users set-password postgres \
            --instance=$DB_INSTANCE_NAME \
            --password="$DB_PASSWORD" \
            --project=$PROJECT_ID

        # Create database
        gcloud sql databases create whytheybuy \
            --instance=$DB_INSTANCE_NAME \
            --project=$PROJECT_ID

        # Store password in Secret Manager
        echo -n "$DB_PASSWORD" | gcloud secrets create db-password --data-file=- --project=$PROJECT_ID

        echo "Cloud SQL created. Password stored in Secret Manager as 'db-password'."
    fi
}

create_vpc_connector() {
    print_step "Creating VPC connector..."

    if gcloud compute networks vpc-access connectors describe $VPC_CONNECTOR_NAME --region=$REGION --project=$PROJECT_ID &> /dev/null; then
        print_warning "VPC connector already exists. Skipping."
    else
        gcloud compute networks vpc-access connectors create $VPC_CONNECTOR_NAME \
            --region=$REGION \
            --range=10.8.0.0/28 \
            --project=$PROJECT_ID
        echo "VPC connector created."
    fi
}

create_memorystore() {
    print_step "Creating Cloud Memorystore Redis instance..."

    if gcloud redis instances describe $REDIS_INSTANCE_NAME --region=$REGION --project=$PROJECT_ID &> /dev/null; then
        print_warning "Memorystore instance already exists. Skipping."
    else
        gcloud redis instances create $REDIS_INSTANCE_NAME \
            --size=1 \
            --region=$REGION \
            --tier=basic \
            --redis-version=redis_7_0 \
            --project=$PROJECT_ID

        echo "Memorystore created. This may take 5-10 minutes..."
    fi
}

create_secrets() {
    print_step "Creating secrets in Secret Manager..."

    # JWT Secret
    if ! gcloud secrets describe jwt-secret-key --project=$PROJECT_ID &> /dev/null; then
        JWT_SECRET=$(openssl rand -base64 64)
        echo -n "$JWT_SECRET" | gcloud secrets create jwt-secret-key --data-file=- --project=$PROJECT_ID
        echo "Created jwt-secret-key secret."
    else
        print_warning "jwt-secret-key already exists. Skipping."
    fi

    # Placeholder secrets (user must update these)
    for SECRET in gemini-api-key stripe-secret-key stripe-webhook-secret sendgrid-api-key; do
        if ! gcloud secrets describe $SECRET --project=$PROJECT_ID &> /dev/null; then
            echo -n "PLACEHOLDER_UPDATE_ME" | gcloud secrets create $SECRET --data-file=- --project=$PROJECT_ID
            print_warning "Created $SECRET with placeholder. Update with real value!"
        else
            print_warning "$SECRET already exists. Skipping."
        fi
    done
}

print_summary() {
    print_step "Setup Complete!"
    echo ""
    echo "Next steps:"
    echo "1. Update secrets in Secret Manager with real values:"
    echo "   - gemini-api-key"
    echo "   - stripe-secret-key"
    echo "   - stripe-webhook-secret"
    echo "   - sendgrid-api-key"
    echo ""
    echo "2. Get Cloud SQL connection name:"
    echo "   gcloud sql instances describe $DB_INSTANCE_NAME --format='value(connectionName)' --project=$PROJECT_ID"
    echo ""
    echo "3. Get Memorystore IP:"
    echo "   gcloud redis instances describe $REDIS_INSTANCE_NAME --region=$REGION --format='value(host)' --project=$PROJECT_ID"
    echo ""
    echo "4. Run database migrations (see INSTRUCTION.md)"
    echo ""
    echo "5. Deploy to Cloud Run (see INSTRUCTION.md)"
}

# Main execution
main() {
    echo "WhyTheyBuy GCP Setup Script"
    echo "=============================="
    echo ""

    check_prerequisites

    gcloud config set project $PROJECT_ID

    enable_apis
    create_artifact_registry
    create_vpc_connector
    create_cloud_sql
    create_memorystore
    create_secrets

    print_summary
}

main "$@"
