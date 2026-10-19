"""Offline functional tests: real scripts, temporary files, synthetic credentials."""
import json
import os
from pathlib import Path
import subprocess
import sys

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]


def apply(tmp, values=None, ok=True):
    env = {'PATH': os.environ['PATH'], 'OPENCODE_CONFIG_DIR': str(tmp / 'config'),
           'OPENCODE_AUTH_DIR': str(tmp / 'state'), **(values or {})}
    result = subprocess.run(['bash', str(ROOT / 'conf/apply-settings.sh')], env=env,
                            text=True, capture_output=True)
    assert (result.returncode == 0) == ok, result.stderr
    return result


def read_config(tmp):
    return json.loads((tmp / 'config/opencode.json').read_text())


@pytest.mark.parametrize('values,model', [
    ({}, 'opencode/big-pickle'),
    ({'OPENCODE_AUTH_MODE': 'existing', 'OPENCODE_MODEL': 'openai/example'}, 'openai/example'),
    *[({'OPENROUTER_PROVIDER': p, 'OPENROUTER_API_KEY': 'fake-"\\$key',
        'OPENCODE_MODEL': 'example'}, p + '/example')
      for p in ['openai', 'anthropic', 'openrouter']],
    *[({'OPENCODE_LOCAL_MODE': 'true', 'OPENCODE_LOCAL_PROVIDER_ID': p,
        'OPENCODE_LOCAL_BASE_URL': 'http://engine:11434/v1',
        'OPENCODE_LOCAL_MODEL': 'model/"\\$special',
        'OPENCODE_LOCAL_PROVIDER_NAME': 'Name "\\',
        'OPENCODE_LOCAL_API_KEY': 'fake-"\\$key'}, p + '/model/"\\$special')
      for p in ['ollama', 'llama.cpp', 'custom']],
    ({'ANTHROPIC_BASE_URL': 'https://example.invalid/v1', 'ANTHROPIC_MODEL': 'example'},
     'anthropic/example'),
])
def test_provider(tmp_path, values, model):
    apply(tmp_path, values)
    config = read_config(tmp_path)
    assert config['model'] == config['small_model'] == model
    assert len(config['agent']) == 51
    assert all(a['model'] == model for a in config['agent'].values())
    assert config['agent']['pentest']['mode'] == 'primary'
    assert config['agent']['aws']['mode'] == 'subagent'
    assert config['agent']['pentest']['prompt'] == '{file:/root/.opencode/agents/pentest.md}'
    assert config['permission'] == {'*': 'ask'}
    if values.get('OPENROUTER_API_KEY'):
        auth = json.loads((tmp_path / 'state/auth.json').read_text())
        assert auth[values['OPENROUTER_PROVIDER']]['key'] == values['OPENROUTER_API_KEY']
        assert (tmp_path / 'state/auth.json').stat().st_mode & 0o777 == 0o600
    before = (tmp_path / 'config/opencode.json').read_bytes()
    apply(tmp_path, values)
    assert (tmp_path / 'config/opencode.json').read_bytes() == before
    assert (tmp_path / 'config/opencode.json').stat().st_mode & 0o777 == 0o600


@pytest.mark.parametrize('values', [
    {'OPENCODE_AUTH_MODE': 'invalid'},
    {'OPENCODE_AUTH_MODE': 'existing'},
    {'OPENCODE_AUTH_MODE': 'existing', 'OPENCODE_MODEL': 'missing-provider'},
    {'OPENCODE_LOCAL_MODE': 'yes'},
    {'OPENCODE_LOCAL_MODE': 'true'},
    {'OPENROUTER_PROVIDER': 'openai', 'OPENCODE_MODEL': 'example'},
    {'OPENROUTER_PROVIDER': 'bad/provider', 'OPENCODE_MODEL': 'example', 'OPENROUTER_API_KEY': 'fake'},
    {'ANTHROPIC_MODEL': 'example', 'ANTHROPIC_BASE_URL': 'file:///secret'},
    {'ANTHROPIC_MODEL': 'example', 'ANTHROPIC_BASE_URL': 'https://user:fake@example.invalid'},
    {'DARKMOON_MCP_PORT': '65536'}, {'DARKMOON_MCP_PORT': 'invalid'},
    {'DARKMOON_MCP_TRANSPORT': 'invalid'},
])
def test_invalid_does_not_write(tmp_path, values):
    config_dir = tmp_path / 'config'
    config_dir.mkdir()
    config = config_dir / 'opencode.json'
    config.write_text('{"user":"original"}')
    state = tmp_path / 'state'
    state.mkdir()
    auth = state / 'auth.json'
    auth.write_text('{"user":"fake-original"}')
    before = (config.read_bytes(), auth.read_bytes())
    output = apply(tmp_path, values, ok=False)
    assert (config.read_bytes(), auth.read_bytes()) == before
    assert 'fake' not in output.stdout + output.stderr


@pytest.mark.parametrize('values', [{}, {'OPENCODE_AUTH_MODE': 'existing', 'OPENCODE_MODEL': 'openai/example'},
    {'OPENCODE_LOCAL_MODE': 'true', 'OPENCODE_LOCAL_PROVIDER_ID': 'ollama',
     'OPENCODE_LOCAL_BASE_URL': 'http://ollama:11434/v1', 'OPENCODE_LOCAL_MODEL': 'example'},
    {'OPENROUTER_PROVIDER': 'openai', 'OPENROUTER_API_KEY': 'fake-new', 'OPENCODE_MODEL': 'example'}])
def test_persistence_and_policy(tmp_path, values):
    apply(tmp_path)
    auth = tmp_path / 'state/auth.json'
    auth.parent.mkdir(exist_ok=True)
    auth.write_bytes(b'{"custom":{"type":"oauth","access":"fake-access","refresh":"fake-refresh"}}')
    original = auth.read_bytes()
    config = read_config(tmp_path)
    config.update(permission={'*': 'deny'}, custom={'data': ['retained']},
                  provider={'custom': {'options': {'baseURL': 'https://example.invalid'}}},
                  plugin=['user-plugin', 'user-plugin', ['configured-plugin', {'setting': True}]],
                  mcp={'user': {'enabled': False}, 'darkmoon': {'enabled': False}})
    config['agent']['pentest']['permission'] = {'bash': 'deny'}
    config['agent']['custom'] = {'model': 'custom/user'}
    (tmp_path / 'config/opencode.json').write_text(json.dumps(config))
    for path in ['state/sessions/one', 'state/reports/one', 'agents/custom.md', 'workflows/custom.json']:
        p = tmp_path / path
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text('user-data')
    apply(tmp_path, values)
    updated = read_config(tmp_path)
    assert updated['permission'] == {'*': 'deny'}
    assert updated['agent']['pentest']['permission'] == {'bash': 'deny'}
    assert updated['agent']['custom']['model'] == 'custom/user'
    assert updated['custom'] == {'data': ['retained']}
    assert updated['provider']['custom'] == config['provider']['custom']
    assert updated['mcp']['user'] == {'enabled': False}
    assert updated['plugin'].count('user-plugin') == 1
    assert ['configured-plugin', {'setting': True}] in updated['plugin']
    assert updated['mcp']['darkmoon']['enabled'] is False
    if not values.get('OPENROUTER_API_KEY'):
        assert auth.read_bytes() == original
    else:
        assert json.loads(auth.read_text())['custom']['access'] == 'fake-access'
    for path in ['state/sessions/one', 'state/reports/one', 'agents/custom.md', 'workflows/custom.json']:
        assert (tmp_path / path).read_text() == 'user-data'


def test_existing_never_parses_auth(tmp_path):
    (tmp_path / 'state').mkdir()
    auth = tmp_path / 'state/auth.json'
    auth.write_bytes(b'opaque file managed externally')
    apply(tmp_path, {'OPENCODE_AUTH_MODE': 'existing', 'OPENCODE_MODEL': 'openai/example'})
    assert auth.read_bytes() == b'opaque file managed externally'


def test_malformed_user_json_preserved(tmp_path):
    (tmp_path / 'config').mkdir()
    config = tmp_path / 'config/opencode.json'
    config.write_text('invalid-user-json')
    apply(tmp_path, ok=False)
    assert config.read_text() == 'invalid-user-json'


def test_stdio(tmp_path):
    apply(tmp_path, {'DARKMOON_MCP_TRANSPORT': 'stdio'})
    assert read_config(tmp_path)['mcp']['darkmoon']['type'] == 'local'


def test_lab_static_policy():
    doc = yaml.safe_load((ROOT / 'docker-compose.lab.yml').read_text())
    svc = doc['services']['opencode']
    assert 'ports' not in svc and 'network_mode' not in svc
    assert svc['cap_drop'] == ['ALL'] and 'cap_add' not in svc
    assert svc['security_opt'] == ['no-new-privileges:true']
    assert svc['environment']['DARKMOON_TOOLBOX_ENABLED'] == 'false'
    assert doc['networks']['lab']['internal'] is True
    assert not any('docker.sock' in v or '.kube' in v for v in svc['volumes'])


def test_toolbox_disabled(monkeypatch):
    sys.path.insert(0, str(ROOT / 'mcp'))
    from src.docker_client import DarkmoonDockerClient
    def forbidden():
        raise AssertionError('Docker Engine must not be contacted')
    monkeypatch.setattr('docker.from_env', forbidden)
    monkeypatch.setenv('DARKMOON_TOOLBOX_ENABLED', 'false')
    client = DarkmoonDockerClient()
    assert client.get_container() is None
    assert not client.execute_command('echo never').success
    assert not client.health_check()['healthy']
    client.cleanup()


def test_local_endpoint_change_does_not_replay_old_key(tmp_path):
    values = {'OPENCODE_LOCAL_MODE': 'true', 'OPENCODE_LOCAL_PROVIDER_ID': 'local',
              'OPENCODE_LOCAL_BASE_URL': 'https://old.invalid/v1',
              'OPENCODE_LOCAL_MODEL': 'example', 'OPENCODE_LOCAL_API_KEY': 'fake-old-key'}
    output = apply(tmp_path, values)
    assert 'fake-old-key' not in output.stdout + output.stderr
    values['OPENCODE_LOCAL_BASE_URL'] = 'http://new.invalid/v1'
    del values['OPENCODE_LOCAL_API_KEY']
    apply(tmp_path, values)
    assert read_config(tmp_path)['provider']['local']['options']['apiKey'] == ''
