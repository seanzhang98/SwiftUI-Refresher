import Foundation
import SwiftUI

extension ScrollView {
    public func refresher<RefreshView>(style: Style = .default,
                                       config: Config = Config(),
                                       refreshView: @escaping (Binding<RefresherState>) -> RefreshView,
                                       action: @escaping RefreshAction) -> RefreshableScrollView<Content, RefreshView> {
        RefreshableScrollView(axes: axes,
                              showsIndicators: showsIndicators,
                              refreshAction: action,
                              style: style,
                              config: config,
                              refreshView: refreshView,
                              content: content)
    }
}

extension ScrollView {
    public func refresher(style: Style = .default,
                          config: Config = Config(),
                          action: @escaping RefreshAction) -> some View {
        RefreshableScrollView(axes: axes,
                              showsIndicators: showsIndicators,
                              refreshAction: action,
                              style: style,
                              config: config,
                              refreshView: DefaultRefreshView.init,
                              content: content)
    }
}

extension ScrollView {
    public func refresher<RefreshView>(style: Style = .default,
                                       config: Config = Config(),
                                       refreshView: @escaping (Binding<RefresherState>) -> RefreshView,
                                       action: @escaping AsyncRefreshAction) -> RefreshableScrollView<Content, RefreshView> {
        RefreshableScrollView(axes: axes,
                              showsIndicators: showsIndicators,
                              refreshAction: { done in
                                  Task { @MainActor in
                                      await action()
                                      done()
                                  }
                              },
                              style: style,
                              config: config,
                              refreshView: refreshView,
                              content: content)
    }
}

extension ScrollView {
    public func refresher(style: Style = .default,
                          config: Config = Config(),
                          action: @escaping AsyncRefreshAction) -> some View {
        RefreshableScrollView(axes: axes,
                              showsIndicators: showsIndicators,
                              refreshAction: { done in
                                  Task { @MainActor in
                                      await action()
                                      done()
                                  }
                              },
                              style: style,
                              config: config,
                              refreshView: DefaultRefreshView.init,
                              content: content)
    }
}

// MARK: - 新增：直接设置刷新距离的便利方法

extension ScrollView {
    /// 设置自定义刷新触发距离的便利方法
    /// - Parameters:
    ///   - refreshDistance: 触发刷新需要拖拽的距离（默认 90）
    ///   - style: 刷新样式
    ///   - action: 刷新动作
    public func refresher(refreshDistance: CGFloat,
                          style: Style = .default,
                          action: @escaping RefreshAction) -> some View {
        let customConfig = Config(refreshAt: refreshDistance)
        return RefreshableScrollView(axes: axes,
                                   showsIndicators: showsIndicators,
                                   refreshAction: action,
                                   style: style,
                                   config: customConfig,
                                   refreshView: DefaultRefreshView.init,
                                   content: content)
    }
}

extension ScrollView {
    /// 设置自定义刷新触发距离的便利方法（异步版本）
    /// - Parameters:
    ///   - refreshDistance: 触发刷新需要拖拽的距离（默认 90）
    ///   - style: 刷新样式
    ///   - action: 异步刷新动作
    public func refresher(refreshDistance: CGFloat,
                          style: Style = .default,
                          action: @escaping AsyncRefreshAction) -> some View {
        let customConfig = Config(refreshAt: refreshDistance)
        return RefreshableScrollView(axes: axes,
                                   showsIndicators: showsIndicators,
                                   refreshAction: { done in
                                       Task { @MainActor in
                                           await action()
                                           done()
                                       }
                                   },
                                   style: style,
                                   config: customConfig,
                                   refreshView: DefaultRefreshView.init,
                                   content: content)
    }
}

extension ScrollView {
    /// 设置自定义刷新触发距离的便利方法（带自定义刷新视图）
    /// - Parameters:
    ///   - refreshDistance: 触发刷新需要拖拽的距离（默认 90）
    ///   - style: 刷新样式
    ///   - refreshView: 自定义刷新视图
    ///   - action: 刷新动作
    public func refresher<RefreshView>(refreshDistance: CGFloat,
                                       style: Style = .default,
                                       refreshView: @escaping (Binding<RefresherState>) -> RefreshView,
                                       action: @escaping RefreshAction) -> RefreshableScrollView<Content, RefreshView> {
        let customConfig = Config(refreshAt: refreshDistance)
        return RefreshableScrollView(axes: axes,
                                   showsIndicators: showsIndicators,
                                   refreshAction: action,
                                   style: style,
                                   config: customConfig,
                                   refreshView: refreshView,
                                   content: content)
    }
}

extension ScrollView {
    /// 设置自定义刷新触发距离的便利方法（带自定义刷新视图，异步版本）
    /// - Parameters:
    ///   - refreshDistance: 触发刷新需要拖拽的距离（默认 90）
    ///   - style: 刷新样式
    ///   - refreshView: 自定义刷新视图
    ///   - action: 异步刷新动作
    public func refresher<RefreshView>(refreshDistance: CGFloat,
                                       style: Style = .default,
                                       refreshView: @escaping (Binding<RefresherState>) -> RefreshView,
                                       action: @escaping AsyncRefreshAction) -> RefreshableScrollView<Content, RefreshView> {
        let customConfig = Config(refreshAt: refreshDistance)
        return RefreshableScrollView(axes: axes,
                                   showsIndicators: showsIndicators,
                                   refreshAction: { done in
                                       Task { @MainActor in
                                           await action()
                                           done()
                                       }
                                   },
                                   style: style,
                                   config: customConfig,
                                   refreshView: refreshView,
                                   content: content)
    }
}
