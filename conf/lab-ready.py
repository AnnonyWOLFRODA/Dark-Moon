#!/usr/bin/env python3
"""Readiness for the configuration-only lab; never run a tool/campaign."""
import asyncio
import json
import os
from pathlib import Path

from fastmcp import Client


async def ready():
    url = os.getenv('DARKMOON_READINESS_URL', 'http://127.0.0.1:8181/mcp')
    async with asyncio.timeout(20):
        while True:
            try:
                async with Client(url, timeout=2) as client:
                    tools = await client.list_tools()
                    if 'health_check' not in {tool.name for tool in tools}:
                        raise RuntimeError('Missing health tool')
                    result = await client.call_tool('health_check', {})
                    if result.is_error or result.data['healthy']:
                        raise RuntimeError('Expected disabled toolbox')
                    print('MCP protocol ready; toolbox unavailable as configured')
                    return
            except (OSError, RuntimeError, TimeoutError):
                await asyncio.sleep(0.5)


if __name__ == '__main__':
    config = Path(os.getenv('OPENCODE_CONFIG_DIR', '/root/.config/opencode')) / 'opencode.json'
    json.loads(config.read_text())
    if os.getenv('DARKMOON_TOOLBOX_ENABLED') != 'false':
        raise SystemExit('This readiness check is only for the configuration-only lab')
    asyncio.run(ready())
