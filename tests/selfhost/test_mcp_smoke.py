"""Real MCP protocol request with Docker disabled, no provider or campaign."""
import asyncio
import os
from pathlib import Path
import sys

from fastmcp import Client
from fastmcp.client.transports import StdioTransport

ROOT = Path(__file__).resolve().parents[2]


def test_mcp_protocol(tmp_path):
    async def check():
        transport = StdioTransport(
            command=sys.executable,
            # Run the real registered server, without the upstream CLI's stdout banner.
            args=['-c', 'from src.server import mcp; mcp.run(show_banner=False)'],
            cwd=str(ROOT / 'mcp'),
            env={**os.environ, 'DARKMOON_TOOLBOX_ENABLED': 'false',
                 'DARKMOON_NO_TELEMETRY': '1', 'DARKMOON_GROWTH_DIR': str(tmp_path / 'growth'),
                 'DARKMOON_PRIVACY_SOCK': str(tmp_path / 'privacy.sock')},
            log_file=tmp_path / 'mcp.log',
        )
        async with Client(transport, timeout=15) as client:
            tools = await client.list_tools()
            assert {'health_check', 'execute_command', 'get_session'} <= {t.name for t in tools}
            result = await client.call_tool('health_check', {})
            assert not result.is_error
            assert result.data['healthy'] is False
            session = await client.call_tool('get_session', {})
            assert session.data['session_id']
    asyncio.run(check())


def test_http_startup_readiness(tmp_path):
    import socket
    import subprocess
    import json
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    config = tmp_path / 'config'
    config.mkdir()
    (config / 'opencode.json').write_text(json.dumps({'model': 'opencode/big-pickle'}))
    env = {**os.environ, 'PYTHONPATH': str(ROOT / 'mcp'), 'DARKMOON_TOOLBOX_ENABLED': 'false',
           'DARKMOON_PRIVACY': '0', 'DARKMOON_NO_TELEMETRY': '1',
           'DARKMOON_GROWTH_DIR': str(tmp_path / 'growth'),
           'OPENCODE_CONFIG_DIR': str(config),
           'DARKMOON_READINESS_URL': f'http://127.0.0.1:{port}/mcp'}
    with (tmp_path / 'server.log').open('w') as log:
        process = subprocess.Popen([sys.executable, '-c',
            f'from src.server import mcp; mcp.run(transport="http", host="127.0.0.1", port={port}, show_banner=False)'],
            cwd=tmp_path, env=env, stdout=log, stderr=log)
        try:
            result = subprocess.run([sys.executable, str(ROOT / 'conf/lab-ready.py')],
                                    env=env, capture_output=True, text=True, timeout=30)
            assert result.returncode == 0, result.stderr
            assert 'MCP protocol ready' in result.stdout
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
