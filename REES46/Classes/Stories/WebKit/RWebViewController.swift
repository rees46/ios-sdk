import UIKit
import WebKit

public class RWebViewController:UIViewController, WKUIDelegate {
  
  enum WebViewKeyPath:String {
      case estimatedProgress
      case title
  }
  
  private lazy var container = UIView(frame: CGRect.zero)
  private lazy var progressView = UIProgressView(progressViewStyle: .bar)
  public private(set) lazy var rWebView:WKWebView = WKWebView(frame: CGRect.zero)
  
  private lazy var toolbar:UIView = {
      let v = UIView(frame: CGRect.zero)
      v.isUserInteractionEnabled = true
      v.heightAnchor.constraint(equalToConstant: 44.0).isActive = true
      v.translatesAutoresizingMaskIntoConstraints = false
        
      let blurEffect = UIBlurEffect(style: .light)
      let blurEffectView = UIVisualEffectView(effect: blurEffect)
      v.addSubview(blurEffectView)
      blurEffectView.bindFrameToSuperviewBounds()
      return v
  }()

    private lazy var titleLabel:UILabel = {
      let lbl = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: 250.0, height: 16.0))
      lbl.adjustsFontSizeToFitWidth = true
      lbl.minimumScaleFactor = 0.9
      lbl.textAlignment = .center
      lbl.font = UIFont.boldSystemFont(ofSize: 16)
      return lbl
  }()
  
  private lazy var urlLabel:UILabel = {
      let lbl = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: 250.0, height: 10.0))
      lbl.adjustsFontSizeToFitWidth = true
      lbl.minimumScaleFactor = 0.9
      lbl.textAlignment = .center
      lbl.font = UIFont.systemFont(ofSize: 10)
      return lbl
  }()

  private let topMargin:CGFloat = 10.0
  private var lastLocation:CGPoint = .zero
  public var request:URLRequest!
 
  public override var title: String? {
      didSet {
          titleLabel.text = title
      }
  }
  
  var detail:String? {
      didSet {
          urlLabel.text = detail
      }
  }
  
  public var titleHidden:Bool = false
  
  override public func loadView() {
      super.loadView()
      setupMainLayout()
      setupToolbar()
  }
  
  override public func viewDidLoad() {
      super.viewDidLoad()
      addPanGestureRecognizer()
      titleLabel.text = titleHidden ? "" : NSLocalizedString("Loading...", comment: "Loading...")
      rWebView.navigationDelegate = self
      rWebView.uiDelegate = self
      rWebView.load(request)
  }
  
  public override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      addWebViewObservers()
  }
  
  public override func viewDidDisappear(_ animated: Bool) {
      super.viewDidDisappear(animated)
      removeWebViewObservers()
  }
  
  private func setupToolbar() {
      let closeButton = createImageButton(imageName: "iconWebKitClose")
      closeButton.addTarget(self, action: #selector(dismissMe(_:)), for: .touchUpInside)
      closeButton.tintColor = .gray
      closeButton.widthAnchor.constraint(equalTo: closeButton.heightAnchor).isActive = true

      let titleStackView = UIStackView(arrangedSubviews: [titleLabel, urlLabel])
      titleStackView.axis = .vertical

      let toolbarStackView = UIStackView(arrangedSubviews: [closeButton, titleStackView])
      toolbarStackView.spacing = 2.0
      toolbarStackView.axis = .horizontal
      toolbar.addSubview(toolbarStackView)

      toolbarStackView.translatesAutoresizingMaskIntoConstraints = false
      toolbarStackView.topAnchor.constraint(equalTo: toolbar.topAnchor, constant: 5).isActive = true
      toolbarStackView.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 5).isActive = true
      toolbarStackView.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: -5).isActive = true
      toolbarStackView.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant:  -49).isActive = true
  }
    
  private func createImageButton(imageName: String) -> UIButton {
      var mainBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
      mainBundle = Bundle.module
#endif
      let image = UIImage(named: "iconWebKitClose", in: mainBundle, compatibleWith: nil)
      
      let closeButton = UIButton(type: .custom)
      closeButton.setImage(image, for: .normal)
      return closeButton
  }
  
  private func setupMainLayout() {
      view = UIView()
      view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
      view.backgroundColor = .clear
      view.addSubview(container)
      container.translatesAutoresizingMaskIntoConstraints = false
      container.topAnchor.constraint(
        equalTo: view.safeTopAnchor, constant: topMargin).isActive = true
      container.bottomAnchor.constraint(
        equalTo: view.bottomAnchor).isActive = true
      container.leadingAnchor.constraint(
        equalTo: view.safeLeadingAnchor, constant: 0).isActive = true
      container.trailingAnchor.constraint(
        equalTo: view.safeTrailingtAnchor, constant: 0).isActive = true
      container.layer.cornerRadius = 16.0
      container.clipsToBounds = true
    
      let progressViewContainer = UIView()
      progressViewContainer.backgroundColor = UIColor.white
      progressViewContainer.addSubview(progressView)
      progressView.bindFrameToSuperviewBounds()
      progressViewContainer.heightAnchor.constraint(equalToConstant: 1)
          .isActive = true
    
      let mainStackView = UIStackView(arrangedSubviews: [
        toolbar,
        progressViewContainer,
        rWebView])
    
      mainStackView.axis = .vertical
      container.addSubview(mainStackView)
      mainStackView.bindFrameToSuperviewBounds()
  }
  
  private func addWebViewObservers() {
      rWebView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
      rWebView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
      rWebView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
      rWebView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)
  }
  
  private func removeWebViewObservers() {
      rWebView.removeObserver(self, forKeyPath:  #keyPath(WKWebView.estimatedProgress))
      rWebView.removeObserver(self, forKeyPath:  #keyPath(WKWebView.title))
      rWebView.removeObserver(self, forKeyPath:  #keyPath(WKWebView.canGoBack))
      rWebView.removeObserver(self, forKeyPath:  #keyPath(WKWebView.canGoForward))
  }
  
  @objc private func dismissMe(_ sender: UIButton) {
      dismiss(completion: nil)
  }
  
  public func dismiss(completion: (() -> Void)? = nil) {
      dismiss(animated: true, completion: {
          NotificationCenter.default.post(name: NSNotification.Name(rawValue: "WebKitClosedContinueTimerSetting"), object: nil)
          
          let carouselOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "CarouselTimerStopMemorySetting")
          if !carouselOpenedBoolKey {
              let sIdDetect : Int = UserDefaults.standard.integer(forKey: "LastViewedSlideMemorySetting")
              NotificationCenter.default.post(name: .init(rawValue: "PlayVideoLongTap"), object: nil, userInfo: ["slideID": sIdDetect])
          }
      })
  }
  
  override public func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                    change: [NSKeyValueChangeKey : Any]?,
                                    context: UnsafeMutableRawPointer?) {
    
      switch keyPath {
      case WebViewKeyPath.estimatedProgress.rawValue:
          progressView.progress = Float(rWebView.estimatedProgress)
          if progressView.progress == 1.0 {
              progressView.alpha = 0.0
              
          } else if progressView.alpha != 1.0 {
              progressView.alpha = 1.0
              
          }
      case WebViewKeyPath.title.rawValue:
          title = titleHidden ? "" : rWebView.title
          if !titleHidden, let scheme = rWebView.url?.scheme,
             let host = rWebView.url?.host {
              detail = "\(scheme)://\(host)"
              
          } else {
              detail = ""
          }
      default:
          break
      }
  }
}

extension RWebViewController:UIGestureRecognizerDelegate {
  
    fileprivate func addPanGestureRecognizer() {
        let panRecognizer = UIPanGestureRecognizer(
            target: self,
            action: #selector(self.handlePanning(_:)))
        panRecognizer.delegate = self
        panRecognizer.maximumNumberOfTouches = 1
        panRecognizer.minimumNumberOfTouches = 1
        panRecognizer.cancelsTouchesInView = true
        toolbar.gestureRecognizers?.forEach {
            $0.require(toFail: panRecognizer)
        }
        toolbar.gestureRecognizers = [panRecognizer]
    }
    
    @objc private func handlePanning(_ gestureRecognizer: UIPanGestureRecognizer?) {
    
    if gestureRecognizer?.state == .began {
        lastLocation = container.center
    }
    
    if gestureRecognizer?.state != .cancelled {
        guard let translation: CGPoint = gestureRecognizer?
            .translation(in: view) else { return }
        container.center = CGPoint(
            x: container.center.x,
            y: lastLocation.y + translation.y)
    }
    
    if gestureRecognizer?.state == .ended {
        if container.frame.origin.y > view.frame.size.height/2.0 {
            dismiss()
            return
        }
        
        UIView.animate(
            withDuration: 0.7,
            delay: 0.0,
            usingSpringWithDamping: 0.5,
            initialSpringVelocity: 0.5,
            options: .allowUserInteraction,
            animations: {
              self.container.center = self.lastLocation
                
            }) { finished in
                
            }
        }
    }
}

extension RWebViewController:WKNavigationDelegate {

public func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        switch navigationAction.navigationType {
        case .linkActivated:
            webView.load(navigationAction.request)
        default:
            break
        }
        decisionHandler(.allow)
    }
}
