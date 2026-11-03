"""API tests with the storage layer mocked (no AWS access needed). Run from app/: pytest"""
from fastapi.testclient import TestClient

import src.main as main

client = TestClient(main.app)


def test_health():
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_shorten_requires_url():
    assert client.post("/shorten", json={}).status_code == 400


def test_shorten_stores_mapping(monkeypatch):
    stored = {}
    monkeypatch.setattr(main, "put_mapping", lambda k, v: stored.update({k: v}))
    r = client.post("/shorten", json={"url": "https://example.com"})
    assert r.status_code == 200
    assert stored[r.json()["short"]] == "https://example.com"


def test_unknown_id_is_404(monkeypatch):
    monkeypatch.setattr(main, "get_mapping", lambda k: None)
    assert client.get("/stats/nope").status_code == 404


def test_resolve_redirects_and_counts(monkeypatch):
    calls = []
    monkeypatch.setattr(main, "get_mapping", lambda k: {"url": "https://example.com", "clicks": 1})
    monkeypatch.setattr(main, "increment_clicks", lambda k: calls.append(k))
    monkeypatch.setattr(main, "publish_click_event", lambda **kw: None)
    r = client.get("/abc12345", follow_redirects=False)
    assert r.status_code == 307
    assert r.headers["location"] == "https://example.com"
    assert calls == ["abc12345"]
