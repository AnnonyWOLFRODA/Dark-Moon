import os
from pathlib import Path
import shutil
import subprocess

import pytest

ROOT = Path(__file__).resolve().parents[2]

@pytest.fixture
def machine(tmp_path):
    for name in ['install.sh', 'docker-compose.lab.yml', 'conf/apply-settings.sh',
                 'tools/selfhost/validate-env.py']:
        target = tmp_path / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, target)
    (tmp_path / '.opencode.env').write_text('OPENCODE_AUTH_MODE=existing\nOPENCODE_MODEL=openai/fake\n')
    bindir = tmp_path / 'bin'
    bindir.mkdir()
    docker = bindir / 'docker'
    docker.write_text('''#!/bin/bash
printf '%s\\n' "$*" >> "$DOCKER_TEST_LOG"
if [[ "$*" == *"$FAIL_OPERATION"* && -n "$FAIL_OPERATION" ]]; then exit 9; fi
exit 0
''')
    docker.chmod(0o700)
    env = {'PATH': str(bindir) + ':' + os.environ['PATH'],
           'DARKMOON_OPENCODE_IMAGE': 'sha256:' + '0' * 64,
           'DOCKER_TEST_LOG': str(tmp_path / 'commands'), 'FAIL_OPERATION': ''}
    return tmp_path, env


def run(machine, command, response='', ok=True):
    path, env = machine
    result = subprocess.run(['bash', str(path / 'install.sh'), command], env=env,
                            input=response, text=True, capture_output=True)
    assert (result.returncode == 0) == ok, result.stderr
    return result


def test_lifecycle_preserves_files(machine):
    path, env = machine
    preserved = ['data/auth.json', 'sessions/one', 'reports/one', 'workflows/one',
                 'darkmoon-settings/agents/custom.md']
    for name in preserved:
        file = path / name
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text('user-original')
    for command in ['install', 'install', 'reconfigure', 'update', 'diagnose', 'stop']:
        run(machine, command)
    assert 'pull' not in (path / 'commands').read_text()  # local immutable image
    env['DARKMOON_OPENCODE_IMAGE'] = 'example.invalid/opencode@sha256:' + '0' * 64
    run(machine, 'update')
    for name in preserved:
        assert (path / name).read_text() == 'user-original'
    assert (path / '.opencode.env').stat().st_mode & 0o777 == 0o600
    commands = (path / 'commands').read_text()
    assert 'pull' in commands and 'up -d' in commands
    for forbidden in ['prune', '--volumes', '--rmi', '--no-cache', '--force-recreate', 'run --rm', 'down']:
        assert forbidden not in commands


def test_reset_requires_exact_confirmation(machine):
    path, _ = machine
    run(machine, 'reset', 'yes\n', ok=False)
    assert 'down' not in (path / 'commands').read_text()
    run(machine, 'reset', 'RESET darkmoon-lab\n')
    assert (path / 'commands').read_text().splitlines()[-1].endswith(' down')


@pytest.mark.parametrize('operation', ['compose version', 'config --quiet', 'info', 'up -d', 'exec -T'])
def test_external_error_stops_install(machine, operation):
    path, env = machine
    env['FAIL_OPERATION'] = operation
    run(machine, 'install', ok=False)
    commands = (path / 'commands').read_text()
    if operation in ['compose version', 'config --quiet', 'info']:
        assert 'up -d' not in commands


def test_invalid_config_never_starts(machine):
    path, _ = machine
    (path / '.opencode.env').write_text('OPENCODE_AUTH_MODE=existing\n')
    run(machine, 'install', ok=False)
    assert 'up -d' not in (path / 'commands').read_text()


def test_no_shell_execution(machine):
    path, _ = machine
    marker = path / 'executed'
    (path / '.opencode.env').write_text(
        f'OPENROUTER_PROVIDER=openai\nOPENCODE_MODEL=fake\nOPENROUTER_API_KEY=$(touch {marker})\n')
    run(machine, 'install')
    assert not marker.exists()


def test_missing_docker(machine):
    path, env = machine
    (path / 'bin/docker').unlink()
    env['PATH'] = str(path / 'bin')
    result = subprocess.run(['/bin/bash', 'install.sh', 'install'], cwd=path, env=env,
                            text=True, capture_output=True)
    assert result.returncode != 0
    assert not (path / 'commands').exists()


def test_mutable_image_rejected(machine):
    path, env = machine
    env['DARKMOON_OPENCODE_IMAGE'] = 'example:latest'
    run(machine, 'install', ok=False)
    assert 'up -d' not in (path / 'commands').read_text()
