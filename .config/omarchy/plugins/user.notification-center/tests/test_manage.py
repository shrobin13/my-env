import json
import os
import subprocess
import sys
import time
from pathlib import Path


PLUGIN_DIR = Path(__file__).resolve().parents[1]
MANAGE = PLUGIN_DIR / "manage.py"


def test_delete_keys_removes_history_and_live_entries():
    import tempfile

    with tempfile.TemporaryDirectory() as directory:
        tmp_path = Path(directory)
        state_dir = tmp_path / ".local/state/omarchy/notifications"
        state_dir.mkdir(parents=True)
        history = state_dir / "history.json"
        live = state_dir / "live.json"
        user_state = state_dir / "user-state.json"
        history.write_text(json.dumps([{"key": "old"}, {"key": "keep"}]))
        live.write_text(json.dumps([{"key": "old"}, {"key": "live"}]))
        user_state.write_text(json.dumps({"deletedKeys": {}}))

        env = os.environ.copy()
        env["HOME"] = str(tmp_path)
        env["OMARCHY_TESTING"] = "1"
        result = subprocess.run(
            [sys.executable, str(MANAGE), "delete-keys", "--", "old"],
            capture_output=True,
            text=True,
            env=env,
            check=True,
        )

        assert "deleted 1 keys" in result.stdout
        assert json.loads(history.read_text()) == [{"key": "keep"}]
        assert json.loads(live.read_text()) == [{"key": "live"}]


def test_clear_removes_history_and_live_entries():
    import tempfile

    with tempfile.TemporaryDirectory() as directory:
        tmp_path = Path(directory)
        state_dir = tmp_path / ".local/state/omarchy/notifications"
        state_dir.mkdir(parents=True)
        history = state_dir / "history.json"
        live = state_dir / "live.json"
        user_state = state_dir / "user-state.json"
        cutoff = int(time.time())
        history.write_text(json.dumps([
            {"key": "old-history", "ts": cutoff - 10},
            {"key": "new-history", "ts": cutoff + 10},
        ]))
        live.write_text(json.dumps([
            {"key": "old-live", "ts": cutoff - 10},
            {"key": "new-live", "ts": cutoff + 10},
        ]))
        user_state.write_text(json.dumps({"deletedKeys": {}}))

        env = os.environ.copy()
        env["HOME"] = str(tmp_path)
        env["OMARCHY_TESTING"] = "1"
        result = subprocess.run(
            [sys.executable, str(MANAGE), "clear"],
            capture_output=True,
            text=True,
            env=env,
            check=True,
        )

        assert "cleared" in result.stdout
        assert json.loads(history.read_text()) == []
        assert json.loads(live.read_text()) == []
        saved_state = json.loads(user_state.read_text())
        assert saved_state["clearedBefore"] >= cutoff


if __name__ == "__main__":
    test_delete_keys_removes_history_and_live_entries()
    test_clear_removes_history_and_live_entries()
    print("ok")
