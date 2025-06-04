import Foundation
import SwiftUI
import SwiftUIIntrospect
import RenderLock

public typealias RefreshAction = (_ completion: @escaping () -> ()) -> ()
public typealias AsyncRefreshAction = () async -> ()

public struct Config {
    /// Drag distance needed to trigger a refresh
    public var refreshAt: CGFloat
    
    /// Max height of the spacer for the refresh spinner to sit while refreshing
    public var headerShimMaxHeight: CGFloat
    
    /// Offset where the spinner stops moving after draging
    public var defaultSpinnerSpinnerStopPoint: CGFloat
    
    /// Off screen start point for the spinner (relative to the top of the screen)
    /// TIP: set this to the max height of your spinner view if using a custom spinner.
    public var defaultSpinnerOffScreenPoint: CGFloat
    
    /// How far you have to pull (from 0 - 1) for the spinner to start moving
    public var defaultSpinnerPullClipPoint: CGFloat
    
    /// How far you have to pull (from 0 - 1) for the spinner to start becoming visible
    public var systemSpinnerOpacityClipPoint: CGFloat
    
    /// How long to hold the spinner before dismissing (a small delay is a nice UX if the refresh is VERY fast)
    public var holdTime: DispatchTimeInterval
    
    /// How long to wait before allowing the next refresh
    public var cooldown: DispatchTimeInterval
    
    /// How close to resting position the scrollview has to move in order to allow the next refresh (finger must also be released from screen)
    public var resetPoint: CGFloat
    
    public init(
        refreshAt: CGFloat = 90,
        headerShimMaxHeight: CGFloat = 75,
        defaultSpinnerSpinnerStopPoint: CGFloat = -50,
        defaultSpinnerOffScreenPoint: CGFloat = -50,
        defaultSpinnerPullClipPoint: CGFloat = 0.1,
        systemSpinnerOpacityClipPoint: CGFloat = 0.2,
        holdTime: DispatchTimeInterval = .milliseconds(300),
        cooldown: DispatchTimeInterval = .milliseconds(500),
        resetPoint: CGFloat = 5
    ) {
        self.refreshAt = refreshAt
        self.defaultSpinnerSpinnerStopPoint = defaultSpinnerSpinnerStopPoint
        self.headerShimMaxHeight = headerShimMaxHeight
        self.defaultSpinnerOffScreenPoint = defaultSpinnerOffScreenPoint
        self.defaultSpinnerPullClipPoint = defaultSpinnerPullClipPoint
        self.systemSpinnerOpacityClipPoint = systemSpinnerOpacityClipPoint
        self.holdTime = holdTime
        self.cooldown = cooldown
        self.resetPoint = resetPoint
    }
}

public enum Style {
    /// Spinner pulls down and centers on a padding view above the scrollview
    case `default`
    
    /// Mimic the system refresh controller as close as possible
    case system
    case system2
    
    /// Overlay the spinner onto the cotained view - good for static images
    case overlay
}

public enum RefreshMode {
    case notRefreshing
    case pulling
    case refreshing
}

public struct RefresherState {
    /// Updated without animation - NOTE: Both modes are always updated in sequence (this one is first)
    public var mode: RefreshMode = .notRefreshing
    
    /// Updated with animation (this one is second)
    public var modeAnimated: RefreshMode = .notRefreshing
    
    /// Value from 0 - 1. 0 is resting state, 1 is refresh trigger point - use this value for custom translations
    public var dragPosition: CGFloat = 0
    
    /// the configuration style - useful if you want your custom spinner to change behavior based on the style
    public let style: Style
}


public struct RefreshableScrollView<Content: View, RefreshView: View>: View {
    let axes: Axis.Set
    let showsIndicators: Bool
    let content: Content
    let refreshAction: RefreshAction
    var refreshView: (Binding<RefresherState>) -> RefreshView
    
    @State private var headerInset: CGFloat = 1000000 // Somewhere far off screen
    @State var state: RefresherState
    @State var distance: CGFloat = 0
    @State var rawDistance: CGFloat = 0
    @State var renderLock = false
    private let style: Style
    private let config: Config

    @State private var uiScrollView: UIScrollView?
    @State private var isRefresherVisible = true
    @State private var isFingerDown = false
    @State private var canRefresh = true
    
    // MARK: - 温和的SwiftUIIntrospect保护机制
    @State private var introspectErrorCount = 0
    @State private var lastSuccessfulIntrospect: Date = Date()
    
    init(
        axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        refreshAction: @escaping RefreshAction,
        style: Style,
        config: Config,
        refreshView: @escaping (Binding<RefresherState>) -> RefreshView,
        content: Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.refreshAction = refreshAction
        self.refreshView = refreshView
        self.content = content
        self.style = style
        self.config = config
        self._state = .init(wrappedValue: RefresherState(style: style))
    }
    
    private var refreshHeaderOffset: CGFloat {
        switch state.style {
        case .default, .system:
            if case .refreshing = state.modeAnimated {
                return config.headerShimMaxHeight * (1 - state.dragPosition)
            }
        case .system2:
            switch state.modeAnimated {
            case .pulling:
                return config.headerShimMaxHeight * (state.dragPosition)
            case .refreshing:
                return config.headerShimMaxHeight
            default: break
            }
        default: break
        }
        
        return 0
    }
    
    private var isTracking: Bool {
        guard let scrollView = uiScrollView else { return false }
        return scrollView.isTracking
    }
    
    private var showRefreshControls: Bool {
        return isFingerDown || isRefresherVisible
    }
    
    @ViewBuilder
    private var refreshSpinner: some View {
        if style == .default || style == .overlay {
            RefreshSpinnerView(offScreenPoint: config.defaultSpinnerOffScreenPoint,
                                pullClipPoint: config.defaultSpinnerPullClipPoint,
                                mode: state.modeAnimated,
                                stopPoint: config.defaultSpinnerSpinnerStopPoint,
                                refreshHoldPoint: config.headerShimMaxHeight / 2,
                                refreshView: refreshView($state),
                                headerInset: $headerInset,
                                refreshAt: config.refreshAt)
                .opacity(showRefreshControls ? 1 : 0)
        }
    }
    
    @ViewBuilder
    private var systemStyleRefreshSpinner: some View {
        if style == .system {
            SystemStyleRefreshSpinner(opacityClipPoint: config.systemSpinnerOpacityClipPoint,
                                      state: state,
                                      position: distance,
                                      refreshHoldPoint: config.headerShimMaxHeight / 2,
                                      refreshView: refreshView($state))
                .opacity(showRefreshControls ? 1 : 0)
        }
    }
    
    @ViewBuilder
    private var system2StyleRefreshSpinner: some View {
        if style == .system2 {
            System2StyleRefreshSpinner(opacityClipPoint: config.systemSpinnerOpacityClipPoint,
                                       state: state,
                                       refreshHoldPoint: config.headerShimMaxHeight / 2,
                                       refreshView: refreshView($state))
                .opacity(showRefreshControls ? 1 : 0)
        }
    }
    
    public var body: some View {
        // The ordering of views and operations here is very important - things break
        // in very strange ways between iOS 14 and iOS 15.
        GeometryReader { globalGeometry in
            ScrollView(axes, showsIndicators: showsIndicators) {
                ZStack(alignment: .top) {
                    OffsetReader { val in
                        offsetChanged(val)
                    }
                    systemStyleRefreshSpinner
                    system2StyleRefreshSpinner
                    
                    // Content wrapper with refresh banner
                    VStack(spacing: 0) {
                        content
                            .renderLocked(with: $renderLock)
                            .offset(y: refreshHeaderOffset)
                    }
                    // renders over content
                    refreshSpinner
                }
            }
            // MARK: - 保护性的SwiftUIIntrospect调用
            .modifier(ProtectedIntrospectModifier(
                onScrollViewFound: { scrollView in
                    // 使用异步调度避免在视图更新期间修改状态
                    DispatchQueue.main.async {
                        self.lastSuccessfulIntrospect = Date()
                        self.introspectErrorCount = 0
                        self.uiScrollView = scrollView
                    }
                },
                onError: {
                    // 使用异步调度避免在视图更新期间修改状态
                    DispatchQueue.main.async {
                        self.introspectErrorCount += 1
                        
                        // 如果错误太多，尝试fallback方案
                        if self.introspectErrorCount > 5 {
                            print("⚠️ SwiftUIIntrospect errors detected, using fallback scroll detection")
                        }
                    }
                }
            ))
            .onChange(of: globalGeometry.frame(in: .global)) { val in
                // 使用异步调度避免在视图更新期间修改状态
                DispatchQueue.main.async {
                    headerInset = val.minY
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    headerInset = globalGeometry.frame(in: .global).minY
                }
            }
        }
    }
    
    private func offsetChanged(_ val: CGFloat) {
        // 将状态更新包装在异步调度中以避免在视图更新期间修改状态
        DispatchQueue.main.async {
            let newIsFingerDown = isTracking
            let newDistance = val - headerInset
            let newDragPosition = normalize(from: 0, to: config.refreshAt, by: newDistance)
            
            // 批量更新状态以提高性能
            isFingerDown = newIsFingerDown
            distance = newDistance
            state.dragPosition = newDragPosition
            
            // If the refresh state has settled, we are not touching the screen, and the offset has settled, we can signal the view to update itself.
            if canRefresh, !isFingerDown, distance <= 0 {
                renderLock = false
            }
            
            guard canRefresh else {
                canRefresh = distance <= config.resetPoint && !isFingerDown && state.mode != .refreshing
                return
            }
            guard distance > 0, showRefreshControls else {
                isRefresherVisible = false
                return
            }
            
            isRefresherVisible = true

            if distance >= config.refreshAt, !renderLock {
                #if !os(visionOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                renderLock = true
                canRefresh = false
                set(mode: .refreshing)
                
                refreshAction {
                    // The ordering here is important - calling `set` on the main queue after `refreshAction` prevents
                    // strange animaton behaviors on some complex views
                    DispatchQueue.main.asyncAfter(deadline: .now() + config.holdTime) {
                        set(mode: .notRefreshing)
                        self.renderLock = false
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + config.cooldown) {
                            self.canRefresh = !isFingerDown
                            self.isRefresherVisible = false
                        }
                    }
                }

            } else if distance > 0, state.mode != .refreshing {
                set(mode: .pulling)
            }
        }
    }
    
    func set(mode: RefreshMode) {
        state.mode = mode
        withAnimation {
            state.modeAnimated = mode
        }
    }
}

// MARK: - 保护性的SwiftUIIntrospect修饰器（温和版本）

struct ProtectedIntrospectModifier: ViewModifier {
    let onScrollViewFound: (UIScrollView) -> Void
    let onError: () -> Void
    
    @State private var hasAttemptedIntrospect = false
    
    func body(content: Content) -> some View {
        content
            .introspect(.scrollView, on: .iOS(.v14, .v15, .v16, .v17, .v18)) { scrollView in
                // 添加基本的验证，但不阻止正常功能
                guard scrollView.superview != nil else {
                    // 使用异步调度避免在视图更新期间修改状态
                    if !hasAttemptedIntrospect {
                        DispatchQueue.main.async {
                            hasAttemptedIntrospect = true
                            onError()
                        }
                    }
                    return
                }
                
                // 使用异步调度记录成功尝试
                DispatchQueue.main.async {
                    hasAttemptedIntrospect = true
                    onScrollViewFound(scrollView)
                }
            }
            .background(
                // Fallback: 如果introspect完全失败，提供手动检测
                FallbackScrollDetector(onScrollViewFound: onScrollViewFound)
                    .opacity(0)
                    .allowsHitTesting(false)
            )
    }
}

// MARK: - Fallback滚动检测器

struct FallbackScrollDetector: UIViewRepresentable {
    let onScrollViewFound: (UIScrollView) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        
        // 延迟查找父级ScrollView作为fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let scrollView = view.findParentScrollView() {
                onScrollViewFound(scrollView)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension UIView {
    func findParentScrollView() -> UIScrollView? {
        var current: UIView? = self
        var attempts = 0
        
        while let parent = current?.superview, attempts < 10 {
            if let scrollView = parent as? UIScrollView {
                return scrollView
            }
            current = parent
            attempts += 1
        }
        return nil
    }
}
