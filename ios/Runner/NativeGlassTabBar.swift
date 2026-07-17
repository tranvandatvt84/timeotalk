import Flutter
import UIKit

final class NativeGlassTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    NativeGlassTabBarView(
      frame: frame,
      viewIdentifier: viewId,
      messenger: messenger,
      arguments: args
    )
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

private struct NativeGlassTab {
  let label: String
  let iconName: String
  let selectedIconName: String
}

final class NativeGlassTabBarView: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let rootView: UIView
  private let tabBar: UITabBar
  private let channel: FlutterMethodChannel
  private let tabs: [NativeGlassTab]
  private var selectedIndex: Int

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    messenger: FlutterBinaryMessenger,
    arguments args: Any?
  ) {
    let params = args as? [String: Any]

    self.rootView = UIView(frame: frame)
    self.tabBar = UITabBar(frame: .zero)
    self.channel = FlutterMethodChannel(
      name: "timeotalk/native_glass_tab_bar_\(viewId)",
      binaryMessenger: messenger
    )
    self.tabs = NativeGlassTabBarView.parseTabs(from: params?["tabs"])
    self.selectedIndex = params?["selectedIndex"] as? Int ?? 0

    super.init()

    configureRootView()
    configureTabBar()
    configureChannel()
    selectTab(at: selectedIndex)
  }

  func view() -> UIView {
    rootView
  }

  private func configureRootView() {
    rootView.backgroundColor = .clear
    rootView.isOpaque = false
  }

  private func configureTabBar() {
    tabBar.delegate = self
    tabBar.translatesAutoresizingMaskIntoConstraints = false
    tabBar.isTranslucent = true
    tabBar.tintColor = .label
    tabBar.unselectedItemTintColor = .secondaryLabel
    tabBar.items = tabs.enumerated().map { index, tab in
      makeItem(for: tab, tag: index)
    }

    if Self.usesLegacyMaterialAppearance {
      tabBar.backgroundColor = .clear
      applyLegacyMaterialAppearance()
    }

    rootView.addSubview(tabBar)
    NSLayoutConstraint.activate([
      tabBar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      tabBar.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      tabBar.topAnchor.constraint(equalTo: rootView.topAnchor),
      tabBar.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
    ])
  }

  private func applyLegacyMaterialAppearance() {
    let appearance = UITabBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
    appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
      .foregroundColor: UIColor.secondaryLabel
    ]
    appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
      .foregroundColor: UIColor.label
    ]
    tabBar.standardAppearance = appearance

    if #available(iOS 15.0, *) {
      tabBar.scrollEdgeAppearance = appearance
    }
  }

  private func configureChannel() {
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setSelectedIndex":
        guard let index = call.arguments as? Int else {
          result(FlutterError(code: "invalid_index", message: nil, details: nil))
          return
        }

        self?.selectTab(at: index)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    selectedIndex = item.tag
    channel.invokeMethod("onTabSelected", arguments: item.tag)
  }

  private func selectTab(at index: Int) {
    guard let items = tabBar.items, items.indices.contains(index) else {
      return
    }

    selectedIndex = index
    tabBar.selectedItem = items[index]
  }

  private func makeItem(for tab: NativeGlassTab, tag: Int) -> UITabBarItem {
    let image = UIImage(systemName: tab.iconName)
    let selectedImage = UIImage(systemName: tab.selectedIconName)
    let item = UITabBarItem(title: nil, image: image, selectedImage: selectedImage)
    item.tag = tag
    item.accessibilityLabel = tab.label
    item.imageInsets = UIEdgeInsets(top: 6, left: 0, bottom: -6, right: 0)
    return item
  }

  private static func parseTabs(from value: Any?) -> [NativeGlassTab] {
    guard let rawTabs = value as? [[String: Any]] else {
      return fallbackTabs
    }

    let tabs = rawTabs.compactMap { rawTab -> NativeGlassTab? in
      guard
        let label = rawTab["label"] as? String,
        let iconName = rawTab["iconName"] as? String,
        let selectedIconName = rawTab["selectedIconName"] as? String
      else {
        return nil
      }

      return NativeGlassTab(
        label: label,
        iconName: iconName,
        selectedIconName: selectedIconName
      )
    }

    return tabs.isEmpty ? fallbackTabs : tabs
  }

  private static let fallbackTabs = [
    NativeGlassTab(label: "Inbox", iconName: "message", selectedIconName: "message.fill"),
    NativeGlassTab(label: "Contacts", iconName: "person.2", selectedIconName: "person.2.fill"),
    NativeGlassTab(
      label: "Profile",
      iconName: "person.crop.circle",
      selectedIconName: "person.crop.circle.fill"
    ),
  ]

  private static var usesLegacyMaterialAppearance: Bool {
    ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26
  }
}
