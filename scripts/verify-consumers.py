"""Build each external product in a fresh scratch; inspect actual link inputs, then behavior tests.
Reuse only downloaded sources with --cache-from .build. No existing cache is removed.
"""
import argparse
import datetime
import platform
import json
import os
import pathlib
import re
import shutil
import subprocess
import tempfile
import time

root = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--cache-from', type=pathlib.Path)
parser.add_argument('--output', type=pathlib.Path)
args = parser.parse_args()
scratch = pathlib.Path(tempfile.mkdtemp(prefix='cy-consumer-proof-'))
if args.cache_from:
    for name in ['repositories', 'checkouts']:
        source = args.cache_from / name
        if source.exists():
            shutil.copytree(source, scratch / name)
env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(scratch/'modules'), SWIFTPM_MODULECACHE_OVERRIDE=str(scratch/'modules'))
base = ['swift', 'build', '--package-path', str(root/'ConsumerFixtures'), '--scratch-path', str(scratch), '--disable-sandbox', '--skip-update']
report = {'measured_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'machine': platform.machine(), 'host_os': platform.mac_ver()[0], 'configuration': 'debug', 'first_build_scope': 'One fresh scratch shared sequentially across products; later first builds reuse earlier compiled dependencies', 'downloaded_sources_reused': bool(args.cache_from), 'fresh_compiled_artifacts': True, 'products': {}}
for product in ['CoreOnly', 'OfflinePersistence', 'NetworkOnly', 'DesignSystemConsumer', 'CustomComposition']:
    timings = []
    for label in ['first', 'incremental']:
        start = time.monotonic()
        log = scratch / (product+'-'+label+'.log')
        with log.open('w') as output:
            subprocess.run(base+['--product', product+'Proof'], cwd=root, env=env, stdout=output, stderr=subprocess.STDOUT, check=True)
        timings.append(round(time.monotonic()-start, 3))
    link = next(scratch.glob('*/debug/'+product+'Proof.product/Objects.LinkFileList'))
    modules = sorted(set(re.findall(r'/([^/]+)\.build/', link.read_text())))
    compiled = sorted(set(re.findall(r'Emitting module ([A-Za-z0-9_]+)', (scratch/(product+'-first.log')).read_text())))
    executable = link.parent.parent / (product+'Proof')
    subprocess.run([str(executable)], cwd=root, env=env, check=True)
    forbidden = {'CYAppImage', 'Kingfisher', 'ExampleApp', 'CYTestSupport'}
    if product not in ['NetworkOnly']:
        forbidden |= {'CYAppNetwork', 'Alamofire'}
    if product not in ['OfflinePersistence']:
        forbidden |= {'CYAppPersistence'}
    if product in ['CoreOnly', 'OfflinePersistence', 'NetworkOnly']:
        forbidden |= {'CYAppUI', 'CYAppDesignSystem', 'CYFeedbackStyle'}
    if product == 'DesignSystemConsumer':
        forbidden |= {'CYAppUI'}
    assert not forbidden.intersection(compiled), (product, compiled)
    assert not forbidden.intersection(modules), (product, modules)
    report['products'][product] = {'first_seconds': timings[0], 'incremental_seconds': timings[1], 'linked_modules': modules, 'compiled_modules': compiled, 'binary_bytes': executable.stat().st_size}
    print(product, report['products'][product], flush=True)
with (scratch/'tests.log').open('w') as output:
    subprocess.run(['swift', 'test']+base[2:], cwd=root, env=env, stdout=output, stderr=subprocess.STDOUT, check=True)
test_counts = re.findall(r'Executed (\d+) tests?, with 0 failures', (scratch/'tests.log').read_text())
assert test_counts and max(map(int, test_counts)) > 0, 'No XCTest behavior tests ran'
report['behavior_test_count'] = max(map(int, test_counts))
report['behavior_tests_passed'] = True
for source in (root/'ConsumerFixtures').rglob('*.swift'):
    if '.build' not in source.parts:
        assert '@testable' not in source.read_text(), source
report['public_api_only'] = True
output = args.output or scratch/'report.json'
output.write_text(json.dumps(report, indent=2)+'\n')
print('Evidence:', output, 'Logs:', scratch, flush=True)
