"""Generation contract tests: isolation, validation and reproducibility without Xcode."""
import json
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/create-app.py'


class CreateAppTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)

    def generate(self, name='SampleApp', bundle='com.example.sample', output='app', source=None):
        return subprocess.run([
            sys.executable, str(SCRIPT), '--name', name, '--bundle-id', bundle,
            '--output', str(self.root / output),
            *(source or ['--template-revision', 'a' * 40]),
        ], text=True, capture_output=True)

    def test_remote_app_is_minimal_and_pinned(self):
        result = self.generate()
        self.assertEqual(result.returncode, 0, result.stderr)
        app = self.root / 'app'
        spec = json.loads((app / 'project.json').read_text())
        self.assertEqual(spec['packages']['Template']['revision'], 'a' * 40)
        products = spec['targets']['SampleApp']['dependencies']
        self.assertEqual(len(products), 4)
        for optional in ['CYAppNetwork', 'CYAppImage', 'CYAppPersistence']:
            self.assertNotIn(optional, str(products))
        self.assertIn('com.example.sample.dev', (app / 'Config/Debug.xcconfig').read_text())
        self.assertNotIn('.dev', (app / 'Config/Release.xcconfig').read_text())
        self.assertEqual(len(list(app.rglob('*.swift'))), 6)
        swift = '\n'.join(p.read_text() for p in app.rglob('*.swift'))
        self.assertEqual(swift.count('@main'), 1)
        self.assertNotIn('@@', swift)
        self.assertNotIn('ExampleApp', swift)
        privacy = plistlib.loads((app / 'Resources/PrivacyInfo.xcprivacy').read_bytes())
        self.assertFalse(privacy['NSPrivacyTracking'])
        self.assertEqual(subprocess.run(['bash', '-n', str(app / 'ci.sh')]).returncode, 0)

    def test_reproducible_output(self):
        for output in ['first', 'second']:
            self.assertEqual(self.generate(output=output).returncode, 0)
        def snapshot(folder):
            return {str(p.relative_to(folder)): p.read_bytes() for p in folder.rglob('*') if p.is_file()}
        self.assertEqual(snapshot(self.root / 'first'), snapshot(self.root / 'second'))

    def test_existing_directory_is_untouched(self):
        app = self.root / 'app'
        app.mkdir()
        marker = app / 'user.txt'
        marker.write_text('keep')
        self.assertNotEqual(self.generate().returncode, 0)
        self.assertEqual(list(app.iterdir()), [marker])
        self.assertEqual(marker.read_text(), 'keep')

    def test_invalid_input_leaves_no_output(self):
        for options in [dict(name='../Escape'), dict(name='class'), dict(name='App;echo'),
                        dict(bundle='example'), dict(bundle='com.example/escape'),
                        dict(source=['--template-revision', 'main']),
                        dict(source=['--template-path', str(self.root / 'missing')])]:
            with self.subTest(options=options):
                self.assertNotEqual(self.generate(**options).returncode, 0)
                self.assertFalse((self.root / 'app').exists())

    def test_local_package_and_path_with_spaces(self):
        result = self.generate(output='App With Spaces', source=['--template-path', str(ROOT)])
        self.assertEqual(result.returncode, 0, result.stderr)
        spec = json.loads((self.root / 'App With Spaces/project.json').read_text())
        self.assertEqual(spec['packages']['Template']['path'], str(ROOT))

    def test_dangling_symlink_is_not_replaced(self):
        app = self.root / 'app'
        app.symlink_to(self.root / 'missing', target_is_directory=True)
        self.assertNotEqual(self.generate().returncode, 0)
        self.assertTrue(app.is_symlink())


if __name__ == '__main__':
    unittest.main()
