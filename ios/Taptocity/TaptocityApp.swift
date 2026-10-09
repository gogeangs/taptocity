import SwiftUI
import WebKit

// 탭투시티 iOS 앱 — 웹 게임(gogeangs.github.io/taptocity)을 전체 화면 WKWebView로 띄운다.
// - gogeangs.github.io 는 App-Bound Domain 으로 지정되어 서비스 워커(오프라인 캐시)가 동작한다.
// - 사용자 에이전트에 "TaptocityiOS" 를 붙여 웹 쪽에서 iOS 앱임을 알 수 있게 한다(구글 로그인 버튼 숨김).
// - 게임 밖 링크(예: 개인정보처리방침의 외부 링크)는 Safari로 연다.

let gameURL = URL(string: "https://gogeangs.github.io/taptocity/")!
let gameHost = "gogeangs.github.io"

@main
struct TaptocityApp: App {
    var body: some Scene {
        WindowGroup {
            GameScreen()
                .ignoresSafeArea()
                .background(Color("LaunchBg"))
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}

struct GameScreen: View {
    @StateObject private var model = GameModel()

    var body: some View {
        ZStack {
            Color("LaunchBg").ignoresSafeArea()
            GameWebView(model: model).ignoresSafeArea()
            if model.failed {
                VStack(spacing: 16) {
                    Text("연결할 수 없어요")
                        .font(.title3.bold())
                    Text("처음 실행할 때는 인터넷 연결이 필요해요.\n한 번 열고 나면 오프라인에서도 이어서 할 수 있어요.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("다시 시도") { model.reload() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.95, green: 0.63, blue: 0.24))
                }
                .padding(32)
                .foregroundStyle(.white)
            }
        }
    }
}

final class GameModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published var failed = false
    weak var webView: WKWebView?

    func reload() {
        failed = false
        if let wv = webView {
            if wv.url == nil { wv.load(URLRequest(url: gameURL)) } else { wv.reload() }
        }
    }

    // 게임 도메인 밖으로 나가는 링크는 Safari로 연다.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.allow) }
        let isMain = action.targetFrame?.isMainFrame ?? true
        if isMain, let host = url.host, host != gameHost, url.scheme?.hasPrefix("http") == true {
            UIApplication.shared.open(url)
            return decisionHandler(.cancel)
        }
        if let scheme = url.scheme, ["mailto", "tel", "sms"].contains(scheme) {
            UIApplication.shared.open(url)
            return decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }

    // target="_blank" 링크
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url {
            if url.host == gameHost { webView.load(action.request) } else { UIApplication.shared.open(url) }
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { failed = false }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { failed = true }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { failed = true }
    }

    // 웹 프로세스가 메모리 부족 등으로 종료되면 다시 띄운다.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reload() }

    // confirm()/alert() 지원
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        present(UIAlertController(title: nil, message: message, preferredStyle: .alert), actions: [("확인", true)]) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        present(UIAlertController(title: nil, message: message, preferredStyle: .alert),
                actions: [("취소", false), ("확인", true)], done: completionHandler)
    }

    private func present(_ alert: UIAlertController, actions: [(String, Bool)], done: @escaping (Bool) -> Void) {
        for (title, value) in actions {
            alert.addAction(UIAlertAction(title: title, style: value ? .default : .cancel) { _ in done(value) })
        }
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let next = top?.presentedViewController { top = next }
        if let top { top.present(alert, animated: true) } else { done(false) }
    }
}

struct GameWebView: UIViewRepresentable {
    let model: GameModel

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.limitsNavigationsToAppBoundDomains = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()
        config.applicationNameForUserAgent = "TaptocityiOS/1.0 Mobile/15E148 Safari/604.1"
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = UIColor(red: 0.027, green: 0.039, blue: 0.071, alpha: 1)
        wv.scrollView.backgroundColor = wv.backgroundColor
        wv.scrollView.bounces = false
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.allowsBackForwardNavigationGestures = false
        wv.allowsLinkPreview = false
        wv.navigationDelegate = model
        wv.uiDelegate = model
        if #available(iOS 16.4, *) { wv.isInspectable = false }
        model.webView = wv
        wv.load(URLRequest(url: gameURL))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
