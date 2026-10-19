"""Type-check Swift fences explicitly marked compile-check against built package modules."""
import pathlib
import platform
import re
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
architecture = platform.machine()
modules = root / f'.build/{architecture}-apple-macosx/debug/Modules'
if not modules.exists():
    raise SystemExit('Run swift build first on this macOS host.')
count = 0
with tempfile.TemporaryDirectory(prefix='cy-doc-examples-') as temporary:
    for path in [root / 'README.md', root / 'ConsumerFixtures/README.md', *sorted((root / 'docs').glob('*.md'))]:
        for match in re.finditer(r'```swift\n// compile-check: ([\w-]+)\n(.*?)```', path.read_text(), re.S):
            name, source = match.groups()
            output = pathlib.Path(temporary) / (name + '.swift')
            output.write_text(source)
            subprocess.run([
                'xcrun', 'swiftc', '-typecheck', '-parse-as-library', '-swift-version', '6',
                '-target', f'{architecture}-apple-macos15.0', '-module-cache-path', '/tmp/cy-doc-modules',
                '-I', str(modules), str(output),
            ], check=True, cwd=root)
            print(f'PASS {path.name}: {name}')
            count += 1
print(f'{count} documentation examples passed')
