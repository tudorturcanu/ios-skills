"""Retain command diagnostics, including timeout output, for disposable probes."""
import os
from pathlib import Path
import signal
import subprocess


def run_recorded(command, records, *, timeout=60, check=True, log_path=None):
    process = subprocess.Popen(command, text=True, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, start_new_session=True)

    def stop_group(signum):
        try:
            os.killpg(process.pid, signum)
        except ProcessLookupError:
            pass

    timed_out = False
    try:
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            stop_group(signal.SIGTERM)
            try:
                stdout, stderr = process.communicate(timeout=2)
            except subprocess.TimeoutExpired:
                stop_group(signal.SIGKILL)
                stdout, stderr = process.communicate()
    except BaseException:
        stop_group(signal.SIGKILL)
        process.communicate()
        raise

    record = {'argv': list(command), 'returncode': 124 if timed_out else process.returncode,
              'process_returncode': process.returncode, 'timed_out': timed_out,
              'stdout': stdout, 'stderr': stderr}
    records.append(record)
    if log_path is not None:
        Path(log_path).write_text(stdout + stderr)
    if check and record['returncode']:
        reason = f'Command timed out after {timeout} seconds' if timed_out else f'Command exited {process.returncode}'
        raise RuntimeError(f'{reason}: {command[0]}\n{stderr or stdout[-3000:]}')
    return stdout.strip()
