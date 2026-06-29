from pathlib import Path
from sqlalchemy import text
from scripts.db import get_engine

SQL_DIR = Path(__file__).parent.parent / "sql"


def run_sql(filename: str, params: dict = None):
    sql = (SQL_DIR / filename).read_text()

    # Remove comment lines
    lines = [
        line for line in sql.split("\n")
        if line.strip() and not line.strip().startswith("--")
    ]
    sql = "\n".join(lines)

    # Split by semicolon and execute
    statements = [s.strip() for s in sql.split(";") if s.strip()]

    with get_engine().begin() as conn:
        for stmt in statements:
            conn.execute(text(stmt), params or {})

    print(f"Executed {filename}")
