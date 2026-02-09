# WhyTheyBuy

<p align="center">
  <img src="docs/logo.png" alt="WhyTheyBuy Logo" width="120" />
</p>

<p align="center">
  <strong>Understand Why Top Investors Make Their Moves</strong>
</p>

<p align="center">
  <a href="https://deepmind.google/technologies/gemini/"><img src="https://img.shields.io/badge/Powered%20by-Gemini%203-4285F4?style=flat&logo=google&logoColor=white" alt="Gemini 3"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.16+-02569B?style=flat&logo=flutter&logoColor=white" alt="Flutter"></a>
  <a href="https://fastapi.tiangolo.com"><img src="https://img.shields.io/badge/FastAPI-0.109+-009688?style=flat&logo=fastapi&logoColor=white" alt="FastAPI"></a>
  <a href="https://www.postgresql.org/"><img src="https://img.shields.io/badge/PostgreSQL-15+-336791?style=flat&logo=postgresql&logoColor=white" alt="PostgreSQL"></a>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#gcp-deployment">GCP Deployment</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#api-documentation">API Docs</a>
</p>

---

**WhyTheyBuy** is a cross-platform application that tracks institutional investor holdings and provides AI-powered analysis explaining *why* top investors buy, sell, or hold specific positions. Built with Flutter (Web + iOS + Android) and FastAPI, powered by **Gemini 3's multimodal AI capabilities**.

## Features

### Core Capabilities

| Feature | Description |
|---------|-------------|
| **Investor Tracking** | Monitor ANY investor type: ETF managers, hedge funds, individuals, pension funds |
| **Holdings Changes** | Automatic detection of NEW, ADDED, REDUCED, and SOLD_OUT positions |
| **6-Pillar AI Reasoning** | Deep analysis across Fundamental, News, Market, Technical, Bull vs Bear, and Risk perspectives |
| **Multi-Agent Analysis** | Sequential AI agents build on each other's insights for comprehensive understanding |
| **Real-Time Data** | Daily ETF holdings, quarterly 13F filings, market prices |
| **Watchlist & Alerts** | Track your favorite investors with customizable notifications |

### Supported Investors

| Investor Type | Data Source | Update Frequency |
|---------------|-------------|------------------|
| ARK ETFs (ARKK, ARKW, ARKG, ARKF, ARKQ) | Public CSV files | Daily |
| Berkshire Hathaway | SEC 13F | Quarterly |
| Bridgewater Associates | SEC 13F | Quarterly |
| Renaissance Technologies | SEC 13F | Quarterly |
| Soros Fund Management | SEC 13F | Quarterly |
| Pershing Square | SEC 13F | Quarterly |
| Duquesne Family Office | SEC 13F | Quarterly |
| CalPERS | SEC 13F | Quarterly |
| Fidelity Contrafund | SEC 13F | Quarterly |

### Internationalization

Fully localized in 8 languages: English, Chinese, Spanish, French, German, Japanese, Korean, Arabic

---

## Quick Start

### Local Development with Docker (Recommended)

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/whytheybuy.git
cd whytheybuy

# 2. Start all backend services
cd backend
docker-compose up -d --build

# 3. Wait for services to start, then run migrations
docker-compose exec api alembic stamp head  # If migrating from existing DB
docker-compose exec api alembic upgrade head

# 4. Seed with REAL data from ARK and SEC EDGAR
docker-compose exec api python -m scripts.setup_real_data

# 5. Verify services are running
docker-compose ps
curl http://localhost:8000/health
```

### Start the Flutter Frontend

```bash
# In a new terminal
cd frontend

# Get dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome
```

### Services Started

| Service | URL | Description |
|---------|-----|-------------|
| API | http://localhost:8000 | FastAPI backend |
| Swagger Docs | http://localhost:8000/docs | Interactive API documentation |
| PostgreSQL | localhost:5432 | Database |
| Redis | localhost:6379 | Cache & job queue |
| Celery Worker | - | Background data ingestion |
| Celery Beat | - | Scheduled tasks |

### Default Credentials

```
Database: postgresql://postgres:postgres@localhost:5432/whytheybuy
```

### Useful Docker Commands

```bash
# View API logs
docker-compose logs -f api

# View Celery worker logs (data ingestion)
docker-compose logs -f celery

# Restart all services
docker-compose restart

# Stop all services
docker-compose down

# Stop and remove all data (fresh start)
docker-compose down -v
```

---

## GCP Deployment

### Prerequisites

- Google Cloud account with billing enabled
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) installed
- Docker installed locally

### Quick Deploy

```bash
cd backend

# 1. Set up GCP infrastructure (Cloud SQL, Redis, VPC, Secrets)
GCP_PROJECT_ID=your-project-id ./scripts/gcp_setup.sh

# 2. Update secrets in Secret Manager
PROJECT_ID=your-project-id

# Gemini API Key (REQUIRED)
echo -n "YOUR_GEMINI_API_KEY" | gcloud secrets versions add gemini-api-key \
    --data-file=- --project=$PROJECT_ID

# 3. Run database migrations via Cloud SQL Proxy
# Download proxy
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.1/cloud-sql-proxy.darwin.amd64
chmod +x cloud-sql-proxy

# Start proxy (in separate terminal)
./cloud-sql-proxy $PROJECT_ID:us-central1:whytheybuy-db

# Run migrations and seed data
export DATABASE_URL="postgresql://postgres:YOUR_DB_PASSWORD@localhost:5432/whytheybuy"
cd backend
alembic upgrade head
python -m scripts.setup_real_data

# 4. Deploy to Cloud Run
GCP_PROJECT_ID=your-project-id ./scripts/deploy.sh

# 5. Get your API URL
gcloud run services describe whytheybuy-api --region=us-central1 --format='value(status.url)'
```

### Deploy Celery Workers

```bash
# Build and push Celery image
docker build -t us-central1-docker.pkg.dev/$PROJECT_ID/whytheybuy/celery:latest \
    -f Dockerfile.celery .
docker push us-central1-docker.pkg.dev/$PROJECT_ID/whytheybuy/celery:latest

# Create Celery worker VM
REDIS_HOST=$(gcloud redis instances describe whytheybuy-redis --region=us-central1 --format='value(host)')

gcloud compute instances create-with-container whytheybuy-celery \
    --zone=us-central1-a \
    --machine-type=e2-small \
    --container-image=us-central1-docker.pkg.dev/$PROJECT_ID/whytheybuy/celery:latest \
    --container-env="GCP_PROJECT_ID=$PROJECT_ID" \
    --container-env="REDIS_HOST=$REDIS_HOST" \
    --container-env="USE_CLOUD_SQL_CONNECTOR=true" \
    --scopes=cloud-platform
```

### Deploy Frontend

```bash
cd frontend

# Get the Cloud Run API URL
API_URL=$(gcloud run services describe whytheybuy-api \
    --region=us-central1 --format='value(status.url)')

# Build for production
flutter build web --release \
    --dart-define=API_BASE_URL=$API_URL \
    --dart-define=ENVIRONMENT=production

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### GCP Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Google Cloud Platform                            │
│                                                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                   Cloud Run (API)                            │   │
│   │              FastAPI + Gunicorn + Uvicorn                    │   │
│   └───────────────────────────┬─────────────────────────────────┘   │
│                               │                                      │
│     ┌─────────────────────────┼─────────────────────────┐           │
│     ▼                         ▼                         ▼           │
│ ┌───────────┐          ┌───────────────┐         ┌────────────┐    │
│ │ Cloud SQL │          │ Memorystore   │         │  Secret    │    │
│ │ (Postgres)│          │   (Redis)     │         │  Manager   │    │
│ └───────────┘          └───────────────┘         └────────────┘    │
│                               ▲                                      │
│                               │                                      │
│   ┌───────────────────────────┴─────────────────────────────────┐   │
│   │              Compute Engine (Celery Workers)                 │   │
│   │         ARK Ingestion • 13F Ingestion • Email Digests       │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                   Firebase Hosting                           │   │
│   │                   (Flutter Web App)                          │   │
│   └─────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

### Estimated Monthly Costs

| Service | Tier | Cost |
|---------|------|------|
| Cloud Run | 1 vCPU, 1GB RAM | $5-20 |
| Cloud SQL | db-f1-micro, 10GB | $15-20 |
| Memorystore | 1GB Basic | $35 |
| Compute Engine (Celery) | e2-small | $15 |
| **Total** | | **~$70-100** |

For detailed deployment instructions, see [INSTRUCTION.md](INSTRUCTION.md).

---

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Flutter App (Web + iOS + Android)                        │
│                                                                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │   Auth   │ │   Home   │ │Watchlist │ │ Investor │ │ Settings │          │
│  │  Module  │ │ Dashboard│ │  Module  │ │  Detail  │ │  Module  │          │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
│                                                                              │
│  State: Riverpod │ Routing: go_router │ HTTP: Dio │ i18n: intl             │
└───────────────────────────────┬─────────────────────────────────────────────┘
                                │ HTTPS / REST API
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            FastAPI Backend                                   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         API Layer (REST)                             │   │
│  │  /auth  /users  /investors  /watchlist  /companies  /ai  /payments  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       Service Layer                                  │   │
│  │  AuthService │ DisclosureAdapters │ DiffEngine │ AIService │ Email  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                     Background Jobs (Celery)                         │   │
│  │  ARK Ingestion │ 13F Ingestion │ Market Data │ Email Digest          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└────────┬──────────────────┬──────────────────┬──────────────────────────────┘
         │                  │                  │
         ▼                  ▼                  ▼
┌────────────────┐  ┌──────────────┐  ┌────────────────────────────────────┐
│   PostgreSQL   │  │    Redis     │  │        External Services           │
│                │  │              │  │                                    │
│  - users       │  │  - sessions  │  │  - Gemini 3 (AI analysis)          │
│  - investors   │  │  - cache     │  │  - Google Search (context)         │
│  - holdings    │  │  - job queue │  │  - SEC EDGAR (13F filings)         │
│  - companies   │  │              │  │  - ARK Invest (holdings CSV)       │
│  - watchlists  │  │              │  │  - Stripe (payments)               │
│  - reports     │  │              │  │  - SendGrid (emails)               │
└────────────────┘  └──────────────┘  └────────────────────────────────────┘
```

### Data Pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│                       DATA SOURCES                                   │
├───────────────────────────────┬─────────────────────────────────────┤
│  ARK Invest CSV Files         │  SEC EDGAR 13F Filings              │
│  (Updated DAILY after close)  │  (Updated QUARTERLY, 45-day delay)  │
└───────────────┬───────────────┴───────────────┬─────────────────────┘
                │                               │
                ▼                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     CELERY BEAT SCHEDULER                            │
├─────────────────────────────────────────────────────────────────────┤
│  ingest_ark_holdings  →  Daily at 23:00 UTC                         │
│  check_13f_filings    →  Daily at 08:00 UTC                         │
│  send_daily_digest    →  Daily at 07:00 UTC                         │
│  send_weekly_digest   →  Sundays at 08:00 UTC                       │
└─────────────────────────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     CELERY WORKERS                                   │
│  • Fetch new holdings data from sources                             │
│  • Compute diffs (NEW, ADDED, REDUCED, SOLD_OUT)                    │
│  • Store snapshots in PostgreSQL                                    │
│  • Trigger email notifications                                      │
└─────────────────────────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     POSTGRESQL DATABASE                              │
│  Holdings snapshots • Changes • AI Reports                          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

### Backend (`backend/`)

```
backend/
├── app/
│   ├── api/                    # REST API endpoints
│   ├── models/                 # SQLAlchemy ORM models
│   ├── schemas/                # Pydantic request/response models
│   ├── services/               # Business logic
│   │   ├── ai.py              # Gemini 3 integration
│   │   ├── multi_agent_reasoning.py  # 6-pillar analysis
│   │   ├── diff.py            # Holdings change detection
│   │   └── entitlements.py    # Subscription access control
│   ├── tasks/                  # Celery background jobs
│   │   ├── ingestion.py       # ARK & 13F data ingestion
│   │   └── notifications.py   # Email digest delivery
│   ├── config.py              # Settings (GCP Secret Manager support)
│   ├── database.py            # SQLAlchemy (Cloud SQL Connector support)
│   └── worker.py              # Celery configuration
├── scripts/
│   ├── setup_real_data.py     # Fetch REAL data from ARK & SEC
│   ├── gcp_setup.sh           # GCP infrastructure setup
│   ├── deploy.sh              # Cloud Run deployment
│   └── run_migrations.py      # Database migrations
├── alembic/                    # Database migrations
├── docker-compose.yml          # Local development stack
├── Dockerfile                  # API container
├── Dockerfile.celery           # Celery worker container
├── cloudbuild.yaml             # CI/CD pipeline
└── requirements.txt            # Python dependencies
```

### Frontend (`frontend/`)

```
frontend/
├── lib/
│   ├── core/                   # Shared infrastructure
│   │   ├── config/app_config.dart  # Production API URL config
│   │   ├── router/            # go_router navigation
│   │   ├── network/           # HTTP client
│   │   └── theme/             # Material Design theming
│   ├── features/               # Feature modules
│   │   ├── auth/              # Login, register
│   │   ├── home/              # Dashboard
│   │   ├── investors/         # Investor detail, AI reasoning
│   │   ├── settings/          # User preferences
│   │   └── landing/           # Landing page
│   └── l10n/                   # Internationalization (8 languages)
└── pubspec.yaml                # Flutter dependencies
```

---

## API Documentation

When the backend is running: http://localhost:8000/docs

### Key Endpoints

```http
# Authentication
POST /api/auth/register
POST /api/auth/login
GET  /api/auth/me

# Investors
GET  /api/investors                    # List all investors
GET  /api/investors/featured           # Featured investors
GET  /api/investors/{id}/holdings      # Current holdings
GET  /api/investors/{id}/changes       # Holdings changes

# AI Analysis
GET  /api/ai/investor-summary/{id}     # AI holdings summary
POST /api/ai/reasoning-demo            # 6-pillar reasoning
POST /api/ai/company-rationale         # Why investor holds stock

# Watchlist
GET  /api/watchlist                    # User's watchlist
POST /api/watchlist/items              # Add to watchlist
```

---

## Environment Variables

### Backend (`.env`)

```bash
# Database
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/whytheybuy
REDIS_URL=redis://localhost:6379/0

# Authentication
JWT_SECRET_KEY=your-secret-key

# AI (Gemini 3)
GEMINI_API_KEY=your-gemini-api-key
AI_PROVIDER=gemini
AI_MODEL=gemini-3-flash-preview

# GCP (for production)
GCP_PROJECT_ID=your-project-id
USE_CLOUD_SQL_CONNECTOR=true
CLOUD_SQL_INSTANCE_CONNECTION_NAME=project:region:instance
```

### Frontend

Build-time configuration via `--dart-define`:

```bash
flutter build web --release \
    --dart-define=API_BASE_URL=https://your-api-url \
    --dart-define=ENVIRONMENT=production
```

---

## Background Tasks Schedule

| Task | Schedule | Description |
|------|----------|-------------|
| ARK Holdings Ingestion | Daily 23:00 UTC | Fetch ARK ETF holdings from CSV |
| 13F Filing Check | Daily 08:00 UTC | Check SEC EDGAR for new filings |
| Daily Digest | Daily 07:00 UTC | Send email digests to PRO users |
| Weekly Digest | Sunday 08:00 UTC | Send email digests to FREE users |

---

## Testing

### Backend

```bash
cd backend
docker-compose exec api pytest tests/ -v --cov=app
```

### Frontend

```bash
cd frontend
flutter test
```

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

MIT License - See [LICENSE](LICENSE) file

---

## Disclaimer

**Not Financial Advice**: WhyTheyBuy provides information about publicly disclosed holdings changes for educational purposes only. This is not investment advice. Past holdings do not indicate future positions. Always do your own research and consult a qualified financial advisor before making investment decisions.

---

<p align="center">
  Built with passion for democratizing institutional investment insights
</p>
