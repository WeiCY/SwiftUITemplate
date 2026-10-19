"""Keep every exported UI/support type discoverable and reviewed; this is not visual QA."""
import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[1]
review = (root / 'docs/MODULE_COMPONENT_REVIEW.md').read_text().split('## 历史记录', 1)[0]
catalog = (root / 'ExampleApp/Sources/Features/Showcase/ComponentCatalog.swift').read_text()
count = 0
for module in ['CYFeedbackStyle', 'CYAppDesignSystem', 'CYAppUI']:
    for source in sorted((root / 'Sources' / module).rglob('*.swift')):
        for name in re.findall(r'^public (?:struct|enum|final class|class) (\w+)', source.read_text(), re.M):
            assert re.search(r'\b' + name + r'\b', review), f'Missing matrix entry: {name}'
            assert re.search(r'\b' + name + r'\b', catalog), f'Missing catalog entry: {name}'
            count += 1
# This round deliberately removed these interfaces: no compatibility shells or current examples.
removed_types = [
    'CYStickyBottomBar', 'CYBottomSafeAreaInset', 'CYPageNavigationChrome',
    'CYSplitViewContainer', 'CYKeyboardObserver', 'CYAppStorage',
]
removed_calls = [
    'cyBottomSafeAreaInset', 'cyPageNavigationChrome', 'keyboardAwarePadding', 'showsNavigationBar',
    'navigationBarAppearance', 'navigationBarHidden', 'scrollEdgeAppearance',
]
for directory in ['Sources', 'ExampleApp', 'ConsumerFixtures']:
    for source in (root / directory).rglob('*.swift'):
        if '.build' in source.parts:
            continue
        text = source.read_text()
        for name in removed_types + removed_calls:
            assert not re.search(r'\b' + name + r'\b', text), f'Removed API restored or still consumed: {source}: {name}'
# Check only our declarations: native methods and unrelated Result-like models can share names.
for file, pattern in {
    'Collection+Extensions.swift': r'public var length\b',
    'Dictionary+Extensions.swift': r'public (?:var (?:isNotEmpty|keysArray|valuesArray)|func (?:hasKey|value|merge|merged))\b',
    'Optional+Extensions.swift': r'public (?:var (?:isNil|isNotNil|countOrZero|orZero)|func (?:or|then))\b',
    'String+Extensions.swift': r'public var (?:asURL|asData|toInt|toDouble)\b',
    'Task+Extensions.swift': r'func sleep\((?:seconds|milliseconds):',
    'UIImage+Extensions.swift': r'func (?:withTintColor|toPNG|toJPEG)\b',
}.items():
    source = root / 'Sources/CYAppCore/Extensions' / file
    assert not re.search(pattern, source.read_text()), f'Removed synonym restored: {source}'
assert not (root / 'Sources/CYAppCore/Extensions/Result+Extensions.swift').exists()
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
