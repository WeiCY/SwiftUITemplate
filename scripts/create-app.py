#!/usr/bin/env python3
"""Generate an independent iOS host. Python stdlib only; no network or shell execution."""
import argparse
import json
import pathlib
import plistlib
import re
import shutil
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
PRODUCTS = ['CYAppCore', 'CYFeedbackStyle', 'CYAppDesignSystem', 'CYAppUI']
PACKAGE_URL = 'https://github.com/WeiCY/SwiftUITemplate'


def render(args):
    if not re.fullmatch(r'[A-Z][A-Za-z0-9]{0,49}', args.name):
        raise ValueError('name must start with A-Z and contain only ASCII letters/digits (max 50).')
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z][A-Za-z0-9-]*)+', args.bundle_id):
        raise ValueError('bundle-id must be a reverse-DNS identifier, e.g. com.example.MyApp.')
    if len(args.bundle_id) > 200:
        raise ValueError('bundle-id is too long.')
    if args.template_revision:
        if not re.fullmatch(r'[a-fA-F0-9]{40}', args.template_revision):
            raise ValueError('template-revision must be a full 40-character commit SHA.')
        package = {'url': PACKAGE_URL, 'revision': args.template_revision.lower()}
    else:
        local = pathlib.Path(args.template_path).expanduser().resolve()
        if not (local / 'Package.swift').is_file():
            raise ValueError('template-path must contain Package.swift.')
        package = {'path': str(local)}
    name = args.name
    spec = {
        'name': name,
        'options': {'minimumXcodeGenVersion': '2.44.1', 'deploymentTarget': {'iOS': '18.0'}},
        'configs': {'Debug': 'debug', 'Release': 'release'},
        'packages': {'Template': package},
        'settings': {'base': {'SWIFT_VERSION': '6.0', 'IPHONEOS_DEPLOYMENT_TARGET': '18.0'}},
        'targets': {
            name: {
                'type': 'application', 'platform': 'iOS',
                'sources': ['App', 'Features', 'Resources'],
                'configFiles': {'Debug': 'Config/Debug.xcconfig', 'Release': 'Config/Release.xcconfig'},
                'settings': {'base': {'GENERATE_INFOPLIST_FILE': 'YES',
                                     'INFOPLIST_KEY_UILaunchScreen_Generation': 'YES',
                                     'INFOPLIST_KEY_UIApplicationSceneManifest_Generation': 'YES',
                                     'TARGETED_DEVICE_FAMILY': '1,2',
                                     'MARKETING_VERSION': '1.0.0', 'CURRENT_PROJECT_VERSION': '1'}},
                'dependencies': [{'package': 'Template', 'product': p} for p in PRODUCTS],
            },
            name + 'UITests': {
                'type': 'bundle.ui-testing', 'platform': 'iOS', 'sources': ['Tests'],
                'dependencies': [{'target': name}],
                'settings': {'base': {'GENERATE_INFOPLIST_FILE': 'YES',
                                     'PRODUCT_BUNDLE_IDENTIFIER': args.bundle_id + '.uitests'}},
            },
        },
        'schemes': {name: {'build': {'targets': {name: 'all'}},
                           'run': {'config': 'Debug'},
                           'test': {'config': 'Debug', 'targets': [name + 'UITests']},
                           'archive': {'config': 'Release'}}},
    }
    files = {}
    for source in sorted((ROOT / 'templates/minimal').rglob('*.template')):
        target = str(source.relative_to(ROOT / 'templates/minimal'))[:-len('.template')]
        files[target] = source.read_text().replace('@@APP_NAME@@', name)
    files['project.json'] = json.dumps(spec, indent=2) + '\n'
    files['template-manifest.json'] = json.dumps({
        'schemaVersion': 1, 'profile': 'minimal', 'name': name, 'bundleID': args.bundle_id,
        'template': package, 'products': PRODUCTS,
        'generatorVersion': 1,
    }, indent=2) + '\n'
    for config, suffix in [('Debug', '.dev'), ('Release', '')]:
        files[f'Config/{config}.xcconfig'] = (
            f'PRODUCT_BUNDLE_IDENTIFIER = {args.bundle_id}{suffix}\n'
            f'INFOPLIST_KEY_CFBundleDisplayName = {name}{" Dev" if suffix else ""}\n'
        )
    files['.gitignore'] = '.DS_Store\n.build/\nDerivedData/\nxcuserdata/\n*.xcodeproj/\n'
    files['.swiftlint.yml'] = 'included:\n  - App\n  - Features\n  - Tests\n'
    # Host uses preferences via CYAppState; no tracking or collected data in this starter.
    files['Resources/PrivacyInfo.xcprivacy'] = plistlib.dumps({
        'NSPrivacyTracking': False, 'NSPrivacyTrackingDomains': [],
        'NSPrivacyCollectedDataTypes': [],
        'NSPrivacyAccessedAPITypes': [{
            'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategoryUserDefaults',
            'NSPrivacyAccessedAPITypeReasons': ['CA92.1'],
        }],
    }).decode()
    files['ci.sh'] = f'''#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
xcodegen generate --spec project.json
swiftlint lint --strict --quiet
for configuration in Debug Release; do
  xcodebuild -project {name}.xcodeproj -scheme {name} -configuration "$configuration" \\
    -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData \\
    CODE_SIGNING_ALLOWED=NO build
done
DEVICE_ID=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(v["udid"] for a in d["devices"].values() for v in a if v["name"].startswith("iPhone")))')
xcodebuild -project {name}.xcodeproj -scheme {name} \\
  -destination "platform=iOS Simulator,id=$DEVICE_ID" -derivedDataPath DerivedData \\
  CODE_SIGNING_ALLOWED=NO test
'''
    files['.github/workflows/ci.yml'] = '''name: App CI
on: [push, pull_request]
permissions:
  contents: read
jobs:
  validate:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - run: brew install xcodegen swiftlint
      - run: bash ci.sh
'''
    files['README.md'] = f'''# {name}

独立 iOS 18+ / Swift 6 App。业务代码归此仓库，公共能力由 Swift Package 提供。

## 首次运行（macOS / Xcode 16+）

```bash
brew install xcodegen swiftlint
xcodegen generate --spec project.json
open {name}.xcodeproj
# 构建 Debug/Release 并运行启动与反馈 UI 测试
bash ci.sh
```

目录：App 为组合根，Features 按业务划分，Resources 放品牌与本地化，
Config 放构建配置，Tests 放宿主测试。工程以 project.json 为唯一配置来源。
Debug Bundle ID 为 `{args.bundle_id}.dev`，Release 为 `{args.bundle_id}`，可并存安装。
默认无后端、无演示业务、无网络/图片/数据库可选 Product、无开发者签名身份。

## 依赖与更新

模板来源记在 template-manifest.json。正式项目使用远端完整 commit SHA；
本地 path 仅适合开发验证，跨机器前换为可访问远端 revision。
首次运行 bash ci.sh 会把解析结果保存到仓库根目录 Package.resolved，请提交该文件。
后续 CI 会恢复并严格使用已锁定版本；升级时先删除旧 lockfile 再运行 CI 重新解析。
升级时在分支更新 project.json 与 manifest 中的 revision，重新解析并提交 lockfile，运行 CI。
生成器只创建新目录，不用于覆盖升级已有项目。

## 发布前宿主工作

补充 App Icon、品牌与本地化、签名 Team、版本号、实际功能与测试。
隐私清单仅声明初始偏好存储，不是完整发布认证；按实际 API、SDK 和数据收集更新并检查归档报告。
引入 Network/Image/Persistence 时在 project.json 添加对应 Product，并在 AppBootstrap 装配；
Endpoint、登录、SwiftData Schema、业务 Route 留在宿主。
CI 使用 runner 自带 Xcode 和 Homebrew 工具；团队稳定后应统一固定工具链版本。
'''
    # Persist transitive resolution outside the ignored generated project.
    files['ci.sh'] = files['ci.sh'].replace('swiftlint lint', f'''LOCK_DIR="{name}.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
mkdir -p "$LOCK_DIR"
if [ -f Package.resolved ]; then cp Package.resolved "$LOCK_DIR/Package.resolved"; fi
swiftlint lint''')
    files['ci.sh'] = files['ci.sh'].replace('swiftlint lint --strict --quiet', f'''swiftlint lint --strict --quiet
RESOLUTION_FLAGS=(-project {name}.xcodeproj -scheme {name})
if [ -f Package.resolved ]; then RESOLUTION_FLAGS+=(-onlyUsePackageVersionsFromResolvedFile); fi
xcodebuild -resolvePackageDependencies "${{RESOLUTION_FLAGS[@]}}"
if [ -f "$LOCK_DIR/Package.resolved" ]; then cp "$LOCK_DIR/Package.resolved" Package.resolved; fi''')
    files['ci.sh'] = files['ci.sh'].replace('CODE_SIGNING_ALLOWED=NO', '-disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO')
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--name', required=True)
    parser.add_argument('--bundle-id', required=True)
    parser.add_argument('--output', required=True, help='New directory; existing paths are never overwritten')
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--template-revision', help='Published full commit SHA in WeiCY/SwiftUITemplate')
    source.add_argument('--template-path', help='Local Package directory for development/CI only')
    args = parser.parse_args()
    try:
        files = render(args)
        output = pathlib.Path(args.output).expanduser().absolute()
        if output.exists() or output.is_symlink():
            raise ValueError(f'Output already exists: {output}')
        output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='.cy-app-', dir=output.parent) as temporary:
            staging = pathlib.Path(temporary)
            for relative, content in files.items():
                path = staging / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding='utf-8')
            # mkdir is exclusive: do not overwrite even if another process wins the race.
            output.mkdir()
            try:
                shutil.copytree(staging, output, dirs_exist_ok=True)
            except OSError:
                shutil.rmtree(output)
                raise
        print(f'Created {output}\nNext: cd {output} && xcodegen generate --spec project.json')
    except (ValueError, OSError) as error:
        parser.exit(2, f'error: {error}\n')


if __name__ == '__main__':
    main()
