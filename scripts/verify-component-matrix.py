"""Keep every exported UI/support type discoverable and reviewed; this is not visual QA."""
import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[1]
review = (root / 'docs/MODULE_COMPONENT_REVIEW.md').read_text()
catalog = (root / 'ExampleApp/Sources/Features/Showcase/ComponentCatalog.swift').read_text()
count = 0
for module in ['CYFeedbackStyle', 'CYAppDesignSystem', 'CYAppUI']:
    for source in sorted((root / 'Sources' / module).rglob('*.swift')):
        for name in re.findall(r'^public (?:struct|enum|final class|class) (\w+)', source.read_text(), re.M):
            assert re.search(r'\b' + name + r'\b', review), f'Missing matrix entry: {name}'
            assert re.search(r'\b' + name + r'\b', catalog), f'Missing catalog entry: {name}'
            count += 1
for source in (root / 'ConsumerFixtures').rglob('*.swift'):
    if '.build' in source.parts:
        continue
    text = source.read_text()
    assert '@testable' not in text, source
    assert not re.search(r'^import ExampleApp\b', text, re.M), source
    assert '/Users/' not in text, source
for project in (root / 'ConsumerFixtures/Host').rglob('project.pbxproj'):
    assert '/Users/' not in project.read_text(), project
print(f'PASS {count} public UI/support types in review and searchable catalog; fixtures use public API and relative paths')
