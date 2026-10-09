import SwiftUI
import CYAppCore
import CYAppDesignSystem
import CYAppUI

// MARK: - Settings Feature
//
// 演示宿主如何把模板的全局状态（主题 / 语言）暴露给用户。

struct SettingsView: View {
    @Environment(CYAppState.self) private var appState

    private let languages: [(code: String, name: String)] = [
        ("zh-Hans", "简体中文"),
        ("en", "English")
    ]

    var body: some View {
        @Bindable var appState = appState

        CYPageContainer(title: "设置", showsNavigationBar: true) {
            VStack(alignment: .leading, spacing: CYAppDimens.marginL) {
                themeSection(appState: appState)
                languageSection
            }
        }
    }

    private func themeSection(appState: CYAppState) -> some View {
        VStack(alignment: .leading, spacing: CYAppDimens.marginS) {
            CYSectionHeader(title: "外观")

            CardView {
                Picker("主题", selection: Binding(
                    get: { appState.theme },
                    set: { appState.theme = $0 }
                )) {
                    ForEach(CYAppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: CYAppDimens.marginS) {
            CYSectionHeader(title: "语言")

            CardView {
                VStack(spacing: 0) {
                    ForEach(languages, id: \.code) { language in
                        CYListRow(
                            title: language.name,
                            trailing: {
                                if appState.language == language.code {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(CYAppColor.primary)
                                }
                            },
                            action: {
                                appState.setLanguage(language.code)
                                CYToastManager.shared.show("已切换语言", type: .success)
                            }
                        )
                    }
                }
            }
        }
    }
}
