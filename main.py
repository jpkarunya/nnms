from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from loguru import logger

from db.models import init_db
from ml.threat_classifier import ThreatClassifier
from ml.anomaly_detector import AnomalyDetector
from ml.preprocessor import FeatureEngineer
from ml.threat_scorer import ThreatScoringEngine, ThreatPredictionEngine

from api.routes_scan import router as scan_router
from api.routes_detect import router as detect_router
from api.routes_predict import router as predict_router
from api.routes_logs import router as logs_router
from api.routes_dashboard import router as dashboard_router
from api.routes_shap import router as shap_router
from api.routes_pcap import router as pcap_router
from api.routes_report import router as report_router


class AppState:
    classifier: ThreatClassifier
    anomaly_detector: AnomalyDetector
    feature_engineer: FeatureEngineer
    scoring_engine: ThreatScoringEngine
    prediction_engine: ThreatPredictionEngine
    db_session_factory = None


app_state = AppState()
MODELS_DIR = Path(__file__).parent / "models"
SCALER_PATH = MODELS_DIR / "scaler.joblib"


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("NetGuard backend starting up...")

    app_state.db_session_factory = init_db()
    logger.info("Database initialized")

    app_state.feature_engineer = FeatureEngineer()
    if SCALER_PATH.exists():
        app_state.feature_engineer.load_scaler(str(SCALER_PATH))

    app_state.classifier = ThreatClassifier()
    loaded_cls = app_state.classifier.load()
    if not loaded_cls:
        logger.warning("Classifier model not found — using heuristic fallback")

    app_state.anomaly_detector = AnomalyDetector()
    loaded_ano = app_state.anomaly_detector.load()
    if not loaded_ano:
        logger.warning("Anomaly model not found — scores will be zero")

    app_state.scoring_engine = ThreatScoringEngine()
    app_state.prediction_engine = ThreatPredictionEngine()

    logger.info("ML models loaded")
    logger.info("NetGuard is ready — http://0.0.0.0:8000")

    yield

    logger.info("NetGuard shutting down...")
    from ml.packet_capture import capture_engine
    if capture_engine.is_running():
        capture_engine.stop()


app = FastAPI(
    title="NetGuard — AI Threat Detection API",
    description="Predictive AI-based network threat detection backend",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def attach_state(request, call_next):
    request.state.app = app_state
    response = await call_next(request)
    return response

app.include_router(scan_router,      prefix="/scan",  tags=["Scanning"])
app.include_router(detect_router,    prefix="",       tags=["Detection"])
app.include_router(predict_router,   prefix="",       tags=["Prediction"])
app.include_router(logs_router,      prefix="",       tags=["Logs"])
app.include_router(dashboard_router, prefix="",       tags=["Dashboard"])
app.include_router(shap_router,      prefix="",       tags=["SHAP"])
app.include_router(pcap_router,      prefix="",       tags=["PCAP"])
app.include_router(report_router,    prefix="",       tags=["Report"])


@app.get("/health")
async def health():
    return {"status": "ok", "version": "2.0.0"}
