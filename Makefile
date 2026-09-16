.PHONY: help install-dev test lint format scan docker-build docker-run monitor devsecops-check clean

help:
	@echo "Available commands:"
	@echo "  make install-dev    - Install development and testing dependencies"
	@echo "  make test           - Run pytest unit and integration tests with coverage"
	@echo "  make lint           - Run Ruff and Bandit static analysis"
	@echo "  make format         - Auto-format Python code with Ruff"
	@echo "  make docker-build   - Build hardened non-root container image"
	@echo "  make docker-run     - Run containerized microservice locally on port 8080"
	@echo "  make monitor        - Run single-check health monitor against localhost"
	@echo "  make devsecops-check- Run all tests, linters, and container scans locally"
	@echo "  make clean          - Remove Python bytecode and build artifacts"

install-dev:
	pip install --upgrade pip
	pip install -r app/requirements-dev.txt

test:
	pytest -v --cov=app --cov-report=term-missing app/tests/

lint:
	ruff check app/
	bandit -r app/ -ll -ii

format:
	ruff format app/

docker-build:
	docker build -t devsecops-microservice:latest ./app

docker-run:
	docker run --rm -p 8080:8080 --name devsecops-service devsecops-microservice:latest

monitor:
	bash scripts/health_monitor.sh "http://localhost:8080/health" --once

devsecops-check:
	bash scripts/local_devsecops_check.sh

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	rm -rf .pytest_cache .coverage htmlcov
