import Foundation
import CYAppCore

extension String {
    private static var exampleBundle: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }

    /// 宿主文案来自宿主自己的 SPM 资源包。
    var exampleLocalized: String {
        CYLocalizationManager.shared.localized(self, tableName: "Localizable", bundle: Self.exampleBundle)
    }
}
