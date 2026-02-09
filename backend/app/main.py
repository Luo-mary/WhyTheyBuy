"""FastAPI main application entry point."""
import os
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings
from app.database import engine, Base
from app.api import auth, users, investors, watchlist, companies, ai, payments, reports
from app.api.websocket import router as websocket_router

# Configure logging for GCP Cloud Logging
logging.basicConfig(
    level=logging.INFO if not settings.debug else logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events."""
    logger.info("Starting WhyTheyBuy API...")
    # Startup
    if settings.debug:
        # Only auto-create tables in development
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        logger.info("Development mode: tables auto-created")
    yield
    # Shutdown
    logger.info("Shutting down WhyTheyBuy API...")
    await engine.dispose()


app = FastAPI(
    title="WhyTheyBuy API",
    description="Track and summarize portfolio/holdings changes of well-known investors",
    version="1.0.0",
    lifespan=lifespan,
    # Disable docs in production for security (optional)
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
)

# CORS middleware configuration
cors_origins = settings.get_cors_origins()

if cors_origins:
    # Production: use explicit origins list
    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    logger.info(f"CORS configured for origins: {cors_origins}")
else:
    # Development: allow localhost on any port
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    logger.info("CORS configured for localhost development")

# Include routers
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(users.router, prefix="/api/users", tags=["Users"])
app.include_router(investors.router, prefix="/api/investors", tags=["Investors"])
app.include_router(watchlist.router, prefix="/api/watchlist", tags=["Watchlist"])
app.include_router(companies.router, prefix="/api/companies", tags=["Companies"])
app.include_router(ai.router, prefix="/api/ai", tags=["AI"])
app.include_router(payments.router, prefix="/api/payments", tags=["Payments"])
app.include_router(reports.router, prefix="/api/reports", tags=["Reports"])
app.include_router(websocket_router, tags=["WebSocket"])
from app.api.reasoning import router as reasoning_router
app.include_router(reasoning_router)



@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "name": settings.app_name,
        "version": "1.0.0",
        "status": "running",
    }


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy"}


@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler."""
    return JSONResponse(
        status_code=500,
        content={
            "detail": "An unexpected error occurred",
            "error": str(exc) if settings.debug else None,
        },
    )
