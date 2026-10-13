import Foundation
import CYAppCore

extension String {
    /// 宿主文案来自宿主自己的 SPM 资源包。
    var exampleLocalized: String {
        CYLocalizationManager.shared.localized(self, tableName: "Localizable", bundle: .module)
    }
}
