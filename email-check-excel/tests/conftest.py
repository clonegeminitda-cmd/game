import pytest
from emailcheck.store import Store


@pytest.fixture
def store(tmp_path):
    return Store(tmp_path / 'data.sqlite3')
