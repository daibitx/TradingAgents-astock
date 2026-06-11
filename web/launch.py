"""Launch the TradingAgents web UI via `tradingagents-web` command."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

_GUARD_ENV = "_TRADINGAGENTS_WEB_LAUNCHED"


def main() -> None:
    if os.environ.get(_GUARD_ENV):
        return
    os.environ[_GUARD_ENV] = "1"

    app_path = Path(__file__).parent / "app.py"
    cmd = [sys.executable, "-m", "streamlit", "run", str(app_path)]
    if sys.argv[1:]:
        cmd.extend(sys.argv[1:])
    subprocess.run(cmd)


if __name__ == "__main__":
    main()
