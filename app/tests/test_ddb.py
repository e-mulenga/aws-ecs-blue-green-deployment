"""DynamoDB backend selection tests (no AWS calls)."""
import pytest

import src.db as db


def test_requires_a_backend(monkeypatch):
    monkeypatch.delenv("TABLE_NAME", raising=False)
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.setattr(db, "_backend", None)
    with pytest.raises(RuntimeError):
        db._get_backend()
