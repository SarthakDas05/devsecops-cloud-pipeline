from fastapi.testclient import TestClient


def test_root_endpoint(client: TestClient):
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "operational"
    assert "health" in data


def test_health_check_healthy(client: TestClient):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "uptime_seconds" in data
    assert "timestamp" in data
    assert "version" in data


def test_readiness_probe(client: TestClient):
    response = client.get("/ready")
    assert response.status_code == 200
    data = response.json()
    assert data["ready"] is True
    assert data["checks"]["database"] == "connected"


def test_service_info(client: TestClient):
    response = client.get("/info")
    assert response.status_code == 200
    data = response.json()
    assert "app_name" in data
    assert "version" in data
    assert "commit_sha" in data
    assert "runtime_python" in data


def test_metrics_endpoint(client: TestClient):
    response = client.get("/metrics")
    assert response.status_code == 200
    data = response.json()
    assert "http_requests_total" in data
    assert data["http_requests_total"] >= 1
    assert "service_healthy" in data


def test_process_transaction_success(client: TestClient):
    payload = {
        "transaction_id": "tx-12345-prod",
        "payload": {
            "amount": 499.99,
            "currency": "USD",
            "account_id": "acc-9988",
        },
        "tags": ["cloud", "devsecops"],
    }
    response = client.post("/process", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["transaction_id"] == "tx-12345-prod"
    assert data["status"] == "processed"
    assert "checksum" in data
    assert data["items_count"] == 3


def test_process_transaction_invalid_schema(client: TestClient):
    # Missing required 'payload' field
    payload = {
        "transaction_id": "tx-fail",
    }
    response = client.post("/process", json=payload)
    assert response.status_code == 422  # Unprocessable Entity


def test_chaos_toggle_health(client: TestClient):
    # Toggle to unhealthy
    toggle_resp = client.post("/chaos/toggle-health")
    assert toggle_resp.status_code == 200
    assert toggle_resp.json()["service_healthy"] is False

    # Health probe should now return 503
    health_resp = client.get("/health")
    assert health_resp.status_code == 503

    # Toggle back to healthy
    toggle_back = client.post("/chaos/toggle-health")
    assert toggle_back.status_code == 200
    assert toggle_back.json()["service_healthy"] is True

    # Health probe returns 200 again
    assert client.get("/health").status_code == 200


def test_chaos_error_simulation(client: TestClient):
    response = client.post("/chaos/error")
    assert response.status_code == 500
