"""Minimal unit tests run by the CI pipeline (Étape 3 du sujet)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest  # noqa: E402

from app import app as flask_app  # noqa: E402


@pytest.fixture
def client():
    flask_app.config.update(TESTING=True)
    with flask_app.test_client() as client:
        yield client


def test_index_returns_200(client):
    response = client.get('/')
    assert response.status_code == 200


def test_unknown_route_returns_404(client):
    response = client.get('/this-route-does-not-exist')
    assert response.status_code == 404
