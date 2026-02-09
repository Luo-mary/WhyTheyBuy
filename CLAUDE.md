# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WhyTheyBuy is a cross-platform Flutter app (Web + iOS + Android) that tracks and summarizes portfolio/holdings changes of notable investors and institutions. It uses a FastAPI backend with PostgreSQL, Redis, and Celery for background tasks.

## Common Commands

### Backend Development

```bash
cd backend

# Create and activate virtual environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Database setup (requires PostgreSQL running)
createdb whytheybuy
alembic upgrade head

# Seed initial data
python scripts/seed_data.py

# Start FastAPI server
uvicorn app.main:app --reload --port 8000

# Start Celery worker (separate terminal)
celery -A app.worker worker --loglevel=info

# Start Celery beat scheduler (separate terminal)
celery -A app.worker beat --loglevel=info

# Run tests
pytest tests/ -v

# Run tests with coverage
pytest tests/ -v --cov=app

# Run a single test file
pytest tests/test_diff.py -v
```

### Frontend Development

```bash
cd frontend

# Get dependencies
flutter pub get

# Generate code (Riverpod providers, JSON serialization)
dart run build_runner build --delete-conflicting-outputs

# Run on web
flutter run -d chrome

# Run on iOS
flutter run -d ios

# Run on Android
flutter run -d android

# Run tests
flutter test
```

### Docker (Full Stack)

```bash
cd backend
docker-compose up -d
```

## Architecture

### Backend Structure (`backend/app/`)

- **api/**: REST endpoints organized by domain (auth, users, investors, watchlist, companies, ai, payments, reports)
- **models/**: SQLAlchemy ORM models (user, investor, holdings, company, watchlist, subscription, report)
- **schemas/**: Pydantic request/response schemas
- **services/**: Business logic (auth, diff engine, AI summary generation, market data, email, entitlements)
- **tasks/**: Celery background tasks (ingestion, notifications, market_data)
- **worker.py**: Celery configuration with scheduled tasks (ARK ingestion, 13F checking, digest emails)

### Frontend Structure (`frontend/lib/`)

- **core/**: Shared infrastructure (routing, theming, networking)
- **features/**: Feature modules following feature-based architecture

### Key Patterns

1. **Disclosure Adapter Framework**: Pluggable system for different data sources (ETF holdings, SEC 13F, N-PORT). All adapters normalize to a common `NormalizedDisclosure` schema.

2. **Diff Engine** (`services/diff.py`): Compares holdings snapshots to detect changes (New, Added, Reduced, Sold Out) and calculates share deltas and weight changes.

3. **AI Service** (`services/ai.py`): Generates summaries using OpenAI/Claude, adapting confidence levels based on data source (daily ETF = medium confidence, quarterly 13F = low confidence).

4. **Tiered AI Access** (`services/ai_tier.py`, `services/entitlements.py`): Controls AI feature access based on subscription tier.

### API Documentation

When backend is running: http://localhost:8000/docs (Swagger UI) or http://localhost:8000/redoc

## External Services

- **Database**: PostgreSQL 15+
- **Cache/Queue**: Redis 7+
- **AI**: OpenAI API, Anthropic Claude
- **Payments**: Stripe
- **Email**: SendGrid
- **Market Data**: Alpha Vantage / Polygon
- **Filings**: SEC EDGAR (13F), ARK Invest CSVs
