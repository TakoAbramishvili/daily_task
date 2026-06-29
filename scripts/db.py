import os
from sqlalchemy import create_engine

_engine = None


def get_engine():
    global _engine
    if _engine is None:
        _engine = create_engine(os.environ["SALES_DB_CONN"])
    return _engine
