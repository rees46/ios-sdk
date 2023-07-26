import UIKit
import AVKit
import AVFoundation

protocol StoryCollectionViewCellDelegate: AnyObject {
    func didTapUrlButton(url: String, slide: Slide)
    func didTapOpenLinkIosExternalWeb(url: String, slide: Slide)
    func sendProductStructForExternal(product: StoriesElement)
    
    func openProductsCarousel(products: [StoriesProduct])
    func closeProductsCarousel()
}

class StoryCollectionViewCell: UICollectionViewCell {
    
    static let cellId = "StoryCollectionViewCellId"
    
    let videoView = UIView()
    let imageView = UIImageView()
    let storyButton = StoryButton()
    let productsButton = ProductsButton()
    let muteButton = UIButton()
    
    private var selectedElement: StoriesElement?
    private var selectedProductsElement: StoriesElement?
    
    private var currentSlide: Slide?
    var cstHeightAnchor: NSLayoutConstraint!
    var cstBottomAnchor: NSLayoutConstraint!
    
    var pstHeightAnchor: NSLayoutConstraint!
    var pstBottomAnchor: NSLayoutConstraint!
    private var customConstraints = [NSLayoutConstraint]()
    
    public weak var delegate: StoryCollectionViewCellDelegate?
    public weak var mainStoriesDelegate: StoriesViewMainProtocol?
    
    var player = AVPlayer()
    private let timeObserverKeyPath: String = "timeControlStatus"
    fileprivate let kMinVolume = 0.00001
    fileprivate let kMaxVolume = 0.99999
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = .black //.white
        videoView.backgroundColor = .black
        
        NotificationCenter.default.addObserver(self, selector: #selector(pauseVideo(_:)), name: .init(rawValue: "PauseVideoLongTap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playVideo(_:)), name: .init(rawValue: "PlayVideoLongTap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showSpinnner(_:)), name: .init(rawValue: "NeedLongSpinnerShow"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hideSpinnner(_:)), name: .init(rawValue: "NeedLongSpinnerHide"), object: nil)
        
        //player.addObserver(self, forKeyPath: timeObserverKeyPath, options: [.old, .new], context: nil)
        
        // videoView.contentMode = .scaleAspectFill
        videoView.contentMode = .scaleToFill
        
        videoView.isOpaque = true
        videoView.clearsContextBeforeDrawing = true
        videoView.autoresizesSubviews = true
        videoView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(videoView)
        
        //imageView.contentMode = .scaleAspectFill
        imageView.contentMode = .scaleAspectFit
        
        imageView.clipsToBounds = true
        //imageView.layer.cornerRadius = 5
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        storyButton.translatesAutoresizingMaskIntoConstraints = false
        storyButton.setTitle("Continue", for: .normal)
        storyButton.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
        addSubview(storyButton)
        
        productsButton.translatesAutoresizingMaskIntoConstraints = false
        productsButton.setTitle("Continue", for: .normal)
        productsButton.addTarget(self, action: #selector(didTapOnProductsButton), for: .touchUpInside)
        addSubview(productsButton)
        
        self.setMuteButtonToDefault()
        
        makeConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func clearConstraints() {
        customConstraints.forEach { $0.isActive = false }
        customConstraints.removeAll()
    }

   // private func updateViewState() {
//        clearConstraints()
//
//        let constraints = [
//            view.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
//            view.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
//            view.topAnchor.constraint(equalTo: parentView.topAnchor),
//            view.bottomAnchor.constraint(equalTo: parentView.bottomAnchor)
//        ]
//
//        activate(constraints: constraints)
//
//        view.layoutIfNeeded()
//    }
    
    private func activate(constraints: [NSLayoutConstraint]) {
        customConstraints.append(contentsOf: constraints)
        customConstraints.forEach { $0.isActive = true }
    }
    
    func makeConstraints(){
        //self.invalidateIntrinsicContentSize()
        //self.layoutIfNeeded()
        
        videoView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        videoView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        videoView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        videoView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        imageView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        imageView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        imageView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        imageView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        if GlobalHelper.sharedInstance.checkIfHasDynamicIsland() {
            
            clearConstraints()
            
            //            let constraints = [
            //                storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            //                storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            //                //storyButton.topAnchor.constraint(equalTo: topAnchor),
            //                storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            //                storyButton.heightAnchor.constraint(equalToConstant: 56)
            //            ]
            //
            //            let constraintsd = [
            //                productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66),
            //                productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66),
            //                //productsButton.topAnchor.constraint(equalTo: nil),
            //                productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -96 ),
            //                productsButton.heightAnchor.constraint(equalToConstant: 36)
            //            ]
            //
            //            self.activate(constraints: constraints)
            //            self.activate(constraints: constraintsd)
            //layoutIfNeeded()
            
            let ds : Bool = UserDefaults.standard.bool(forKey: "doubleProductsConfig")
            if ds == true {
                let constraints = [
                    storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                    storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                    //storyButton.topAnchor.constraint(equalTo: topAnchor),
                    storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
                    storyButton.heightAnchor.constraint(equalToConstant: 56)
                ]
                
                let constraintsd = [
                    productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66),
                    productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66),
                    //productsButton.topAnchor.constraint(equalTo: topAnchor),
                    productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -89),
                    productsButton.heightAnchor.constraint(equalToConstant: 36)
                ]
                
                self.activate(constraints: constraints)
                self.activate(constraints: constraintsd)
            } else {
                let constraints = [
                    storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                    storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                    //storyButton.topAnchor.constraint(equalTo: topAnchor),
                    storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
                    storyButton.heightAnchor.constraint(equalToConstant: 56)
                ]
                
                let constraintsd = [
                    productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66),
                    productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66),
                    //productsButton.topAnchor.constraint(equalTo: nil),
                    productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
                    productsButton.heightAnchor.constraint(equalToConstant: 36)
                ]
                
                self.activate(constraints: constraints)
                self.activate(constraints: constraintsd)
            }
            
            //self.activate(constraints: constraints)
            //self.activate(constraints: constraintsd)
            layoutIfNeeded()
            
            //            for subview in cell.contentView {
            //                        subview.clearConstraints()
            //                    }
            //                    self.removeConstraints(self.constraints)
            
            //self.invalidateIntrinsicContentSize()
            //self.invalidateIntrinsicContentSize()
            //self.storyButton.topAnchor.constraint(equalTo: topAnchor, constant: 64).isActive = true
            //            self.storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16).isActive = true
            //            self.storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
            //            self.storyButton.heightAnchor.constraint(equalToConstant: 56).isActive = true
            //
            ////            self.cstBottomAnchor = storyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
            ////            self.cstBottomAnchor.isActive = true
            //
            //            //self.productsButton.topAnchor.constraint(equalTo: topAnchor, constant: 64).isActive = true
            //            self.productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66).isActive = true
            //            self.productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66).isActive = true
            //            self.productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
            ////            self.pstBottomAnchor = productsButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -90)
            ////            self.pstBottomAnchor.isActive = true
            //
            //            let ds : Bool = UserDefaults.standard.bool(forKey: "doubleProductsConfig")
            //            if ds == true {
            //
            //                self.cstBottomAnchor = storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -32)
            //                self.cstBottomAnchor.isActive = true
            //
            //                self.pstBottomAnchor = productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -110)
            //                self.pstBottomAnchor.isActive = true
            //
            //                self.cstBottomAnchor.priority = UILayoutPriority(100)
            //                self.pstBottomAnchor.priority = UILayoutPriority(100)
            //
            //                //self.cstBottomAnchor.constant = -24.0
            //                //se//lf.pstBottomAnchor.constant = -90.0
            ////                //storyButton.heightAnchor.constraint(equalToConstant: 14).isActive = false
            ////                storyButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
            ////                productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
            ////
            ////                productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28).isActive = false
            ////                storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -80).isActive = false
            ////
            ////                //storyButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
            ////                storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16).isActive = true
            ////                storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
            ////
            ////                //rstoryButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -80).isActive = false
            ////                storyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32).isActive = true ///
            ////
            ////
            ////                productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66).isActive = true
            ////                productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66).isActive = true
            ////
            ////
            ////                //productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28).isActive = false
            ////                productsButton.bottomAnchor.constraint(equalTo: storyButton.topAnchor, constant: -12).isActive = true
            ////
            //
            //
            //
            //
            //
            //                //storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -22).isActive = true
            //
            //                //productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
            ////                pstBottomAnchor = productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -97)
            ////                pstBottomAnchor.constant = -97
            ////                pstBottomAnchor.isActive = true
            ////                pstHeightAnchor = productsButton.heightAnchor.constraint(equalToConstant: 36)
            ////                pstHeightAnchor.constant = 36
            ////                pstHeightAnchor.isActive = true
            ////                //pstHeightAnchor.isActive = true
            //
            ////                cstHeightAnchor?.priority = UILayoutPriority(rawValue: 100)
            ////                cstBottomAnchor?.priority = UILayoutPriority(rawValue: 100)
            ////                pstHeightAnchor?.priority = UILayoutPriority(rawValue: 100)
            ////                pstBottomAnchor?.priority = UILayoutPriority(rawValue: 100)
            //
            //                UIView.animate(withDuration: 0.4) {
            //                    self.setNeedsUpdateConstraints()
            //                    self.layoutIfNeeded()
            //                }
            //            } else {
            //                //self.storyButton.heightAnchor.constraint(equalToConstant: 1).isActive = true
            //
            //                self.storyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32).isActive = false
            //                self.productsButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = false
            //
            //                self.cstBottomAnchor = storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 60)
            //                self.cstBottomAnchor.isActive = true
            //
            //                self.pstBottomAnchor = productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
            //                self.pstBottomAnchor.isActive = true
            //
            //                self.cstBottomAnchor.priority = UILayoutPriority(100)
            //                self.pstBottomAnchor.priority = UILayoutPriority(100)
            
            //                storyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24).isActive = false
            //                productsButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -90).isActive = false
            //
            //                self.cstBottomAnchor.isActive = false
            //                self.cstBottomAnchor.constant = -1.0
            //                self.cstBottomAnchor.isActive = true
            //
            //                self.pstBottomAnchor.isActive = false
            //                self.pstBottomAnchor.constant = -20.0
            //                self.pstBottomAnchor.isActive = true
            
            //self.myListCVLeftConstraint?.constant = 0.0
            //                storyButton.heightAnchor.constraint(equalToConstant: 60).isActive = false
            //                productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
            //
            //                storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16).isActive = true
            //                storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
            //
            //                productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66).isActive = true
            //                productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66).isActive = true
            //
            //                storyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32).isActive = false
            //                //productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -97).isActive = false
            //
            //                productsButton.bottomAnchor.constraint(equalTo: storyButton.topAnchor, constant: -12).isActive = false
            //
            //                //productsButton.bottomAnchor.constraint(equalTo: storyButton.bottomAnchor, constant: -80).isActive = false
            //                productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -35).isActive = true
            
            
            //fff
            
            //productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
            
            
            //storyButton.heightAnchor.constraint(equalToConstant: 60).isActive = false
            //storyButton.heightAnchor.constraint(equalToConstant: 1).isActive = true
            
            //storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -97).isActive = false
            //s//toryButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5).isActive = true
            
            
            //cstHeightAnchor.bott priority.constant.pri  bottomAnchor.prio = UILayoutPriority(rawValue: 99)
            //storyButton.bottomAnchor.constraint.prio
            ///productsButton.priority = UILayoutPriority(rawValue: 100)
            //pstBottomAnchor?.priority = UILayoutPriority(rawValue: 100)
            
            //                cstHeightAnchor?.priority = UILayoutPriority(rawValue: 100)
            //                cstBottomAnchor?.priority = UILayoutPriority(rawValue: 100)
            //                pstHeightAnchor?.priority = UILayoutPriority(rawValue: 100)
            //                pstBottomAnchor?.priority = UILayoutPriority(rawValue: 100)
            
            //                UIView.animate(withDuration: 0.4) {
            ////
            ////                    self.invalidateIntrinsicContentSize()
            ////                    self.setNeedsLayout()
            ////                    self.layoutIfNeeded()
            //
            //                    //self.setNeedsUpdateConstraints()
            //                    //self.layoutIfNeeded()
            //                }
            
            // }
            
            ////XXXS
            //            storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16).isActive = true
            //            storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
            //            storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18).isActive = true
            //            storyButton.heightAnchor.constraint(equalToConstant: 56).isActive = true
            //
            //            let ds : Bool = UserDefaults.standard.bool(forKey: "doubleProductsConfig")
            //            if ds == true {
            //                productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -90).isActive = true
            //                productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 90).isActive = true
            //                productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -96).isActive = true
            //                productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
            //            } else {
            //                productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -96).isActive = false
            //
            //                productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66).isActive = true
            //                productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66).isActive = true
            //                productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28).isActive = true
            //                productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
            //
            //                //productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28).isActive = true
            // }
        } else {
            
            clearConstraints()
            
            let ds : Bool = UserDefaults.standard.bool(forKey: "doubleProductsConfig")
            if ds == true {
                let constraints = [
                    storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                    storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                    //storyButton.topAnchor.constraint(equalTo: topAnchor),
                    storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
                    storyButton.heightAnchor.constraint(equalToConstant: 56)
                ]
                
                let constraintsd = [
                    productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66),
                    productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66),
                    //productsButton.topAnchor.constraint(equalTo: topAnchor),
                    productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -89),
                    productsButton.heightAnchor.constraint(equalToConstant: 36)
                ]
                
                self.activate(constraints: constraints)
                self.activate(constraints: constraintsd)
            } else {
                let constraints = [
                    storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                    storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                    //storyButton.topAnchor.constraint(equalTo: topAnchor),
                    storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
                    storyButton.heightAnchor.constraint(equalToConstant: 56)
                ]
                
                let constraintsd = [
                    productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66),
                    productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66),
                    //productsButton.topAnchor.constraint(equalTo: nil),
                    productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
                    productsButton.heightAnchor.constraint(equalToConstant: 36)
                ]
                
                self.activate(constraints: constraints)
                self.activate(constraints: constraintsd)
            }
            
            //self.activate(constraints: constraints)
            //self.activate(constraints: constraintsd)
            layoutIfNeeded()
            
        }
   // }
//            //storyButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
//            //productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
//
//            let ds : Bool = UserDefaults.standard.bool(forKey: "doubleProductsConfig")
//            if ds == true {
//                //storyButton.heightAnchor.constraint(equalToConstant: 14).isActive = false
//                storyButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
//                productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
//
//                productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28).isActive = false
//                storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -80).isActive = false
//
//                //storyButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
//                storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16).isActive = true
//                storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
//
//                //rstoryButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -80).isActive = false
//                storyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -27).isActive = true ///
//
//
//                productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66).isActive = true
//                productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66).isActive = true
//
//
//                //productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28).isActive = false
//                productsButton.bottomAnchor.constraint(equalTo: storyButton.topAnchor, constant: -7).isActive = true
//
//                //storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -22).isActive = true
//
//                //productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
////                pstBottomAnchor = productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -97)
////                pstBottomAnchor.constant = -97
////                pstBottomAnchor.isActive = true
////                pstHeightAnchor = productsButton.heightAnchor.constraint(equalToConstant: 36)
////                pstHeightAnchor.constant = 36
////                pstHeightAnchor.isActive = true
////                //pstHeightAnchor.isActive = true
//
//                cstHeightAnchor?.priority = UILayoutPriority(rawValue: 100)
//                cstBottomAnchor?.priority = UILayoutPriority(rawValue: 100)
//                pstHeightAnchor?.priority = UILayoutPriority(rawValue: 100)
//                pstBottomAnchor?.priority = UILayoutPriority(rawValue: 100)
//
//                UIView.animate(withDuration: 0.3) {
//                    //self.setNeedsUpdateConstraints()
//                    //self.layoutIfNeeded()
//                }
//            } else {
//
//                storyButton.heightAnchor.constraint(equalToConstant: 60).isActive = false
//                productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
//
//                storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16).isActive = true
//                storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
//
//                productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66).isActive = true
//                productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66).isActive = true
//
//                storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -27).isActive = false
//                //productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -97).isActive = false
//
//                productsButton.bottomAnchor.constraint(equalTo: storyButton.topAnchor, constant: -7).isActive = false
//
//                //productsButton.bottomAnchor.constraint(equalTo: storyButton.bottomAnchor, constant: -80).isActive = false
//                productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28).isActive = true
//
//                //productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
//
//
//                //storyButton.heightAnchor.constraint(equalToConstant: 60).isActive = false
//                //storyButton.heightAnchor.constraint(equalToConstant: 1).isActive = true
//
//                //storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -97).isActive = false
//                //s//toryButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5).isActive = true
//
//
//                //cstHeightAnchor.bott priority.constant.pri  bottomAnchor.prio = UILayoutPriority(rawValue: 99)
//                //storyButton.bottomAnchor.constraint.prio
//                ///productsButton.priority = UILayoutPriority(rawValue: 100)
//                //pstBottomAnchor?.priority = UILayoutPriority(rawValue: 100)
//
//                cstHeightAnchor?.priority = UILayoutPriority(rawValue: 100)
//                cstBottomAnchor?.priority = UILayoutPriority(rawValue: 100)
//                pstHeightAnchor?.priority = UILayoutPriority(rawValue: 100)
//                pstBottomAnchor?.priority = UILayoutPriority(rawValue: 100)
//
//                UIView.animate(withDuration: 0.3) {
//                    self.setNeedsUpdateConstraints()
//                    self.layoutIfNeeded()
//                }
//
//
        //    }
        
////            cstBottomAnchor.isActive = true
////            cstHeightAnchor.isActive = true
////            pstHeightAnchor.isActive = true
////            pstBottomAnchor.isActive = true
//            layoutIfNeeded()
//            //l/ayoutIfNeeded()
//            layoutSubviews()
//            if GlobalHelper.DeviceType.IS_IPHONE_XS_MAX {
////                storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16).isActive = true
////                storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
////                storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18).isActive = true
////                storyButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
//            }
        //}
        
        muteButton.leadingAnchor.constraint(equalTo: storyButton.leadingAnchor, constant: -7).isActive = true
        muteButton.bottomAnchor.constraint(equalTo: storyButton.bottomAnchor, constant: -70).isActive = true
        muteButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        muteButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
    }
    
    @objc private func didTapOnMute() {
        var mainBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        mainBundle = Bundle.module
#endif
        if player.volume == 1.0 {
            player.volume = 0.0
            muteButton.setImage(UIImage(named: "iconStoryMute", in: mainBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(false, forKey: "soundSetting")
        } else {
            player.volume = 1.0
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            } catch let error {
                print("Error in AVAudio Session\(error.localizedDescription)")
            }
            
            muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: mainBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(true, forKey: "soundSetting")
        }
    }
    
    @objc
    private func pauseVideo(_ notification: NSNotification) {
        if let slideID = notification.userInfo?["slideID"] as? Int {
            if let currentSlide = currentSlide {
                if currentSlide.id == slideID {
                    player.pause()
                }
            }
        }
    }
    
    @objc
    private func playVideo(_ notification: NSNotification) {
        //preloader.stopPreloaderAnimation()
        if let slideID = notification.userInfo?["slideID"] as? Int {
            if let currentSlide = currentSlide {
                if currentSlide.id == slideID {
                    player.play()
                }
            }
        }
    }
    
    private func setMuteButtonToDefault() {
        var mainBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        mainBundle = Bundle.module
#endif
        
        let soundSetting : Bool = UserDefaults.standard.bool(forKey: "soundSetting")
        if soundSetting == true {
            player.volume = 1
            muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: mainBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(true, forKey: "soundSetting")
        } else {
            player.volume = 0
            muteButton.setImage(UIImage(named: "iconStoryMute", in: mainBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(false, forKey: "soundSetting")
        }
        
        muteButton.translatesAutoresizingMaskIntoConstraints = false
        muteButton.isHidden = true
        muteButton.addTarget(self, action: #selector(didTapOnMute), for: .touchUpInside)
        addSubview(muteButton)
    }
    
    public func configure(slide: Slide) {
//        setButtonToDefault()
        
        self.currentSlide = slide
        if slide.type == .video {
//            if let preview = slide.previewImage {
//                DispatchQueue.main.async {
//                    self.imageView.image = preview
//                    self.videoView.isHidden = true
//                    self.imageView.isHidden = false
//                }
//            }

            videoView.isHidden = false
            imageView.isHidden = true

            self.videoView.layer.sublayers?.forEach {
                if $0.name == "VIDEO" {
                    $0.removeFromSuperlayer()
                }
            }
            if let videoURL = slide.videoURL {
                videoView.isHidden = false
                imageView.isHidden = true

                let asset = AVAsset(url: videoURL)
                let volume = AVAudioSession.sharedInstance().outputVolume
                print("output volume: \(volume)")
//                if (volume < Float(kMinVolume)) {
//                    player.volume = 0
//                } else if (volume >= Float(kMinVolume)) {
//                    player.volume = 1
//                }
                
                let playerItem = AVPlayerItem(asset: asset)
                self.player = AVPlayer(playerItem: playerItem)
                let playerLayer = AVPlayerLayer(player: player)
                let screenSize = UIScreen.main.bounds.size
                playerLayer.frame = CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height)
                playerLayer.name = "VIDEO"
                //playerLayer.videoGravity = .resizeAspectFill
                
                if playerItem.asset.tracks.filter({$0.mediaType == .audio}).count != 0 {
                    var mainBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
                    mainBundle = Bundle.module
#endif
                    let soundSetting : Bool = UserDefaults.standard.bool(forKey: "soundSetting")
                    if soundSetting == true {
                        player.volume = 1
                        muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: mainBundle, compatibleWith: nil), for: .normal)
                        UserDefaults.standard.set(true, forKey: "soundSetting")
                        
                        do {
                            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                        } catch let error {
                            print("Error in AVAudio Session\(error.localizedDescription)")
                        }
                    } else {
                        player.volume = 0
                        muteButton.setImage(UIImage(named: "iconStoryMute", in: mainBundle, compatibleWith: nil), for: .normal)
                        UserDefaults.standard.set(false, forKey: "soundSetting")
                    }
                    muteButton.isHidden = false
                } else {
                    muteButton.isHidden = true
                }
                self.videoView.layer.addSublayer(playerLayer)
                player.play()
                UserDefaults.standard.set(Int(currentSlide!.id), forKey: "SlideOpenSetting")
            } else {
                muteButton.isHidden = true
                imageView.isHidden = false
                videoView.isHidden = true
                if let preview = slide.previewImage {
                    self.imageView.image = preview
                }
            }
        } else {
            
            muteButton.isHidden = true
            imageView.isHidden = false
            videoView.isHidden = true
            if let image = slide.downloadedImage {
                self.imageView.image = image
            }
        }
        
        if let element = slide.elements.first(where: {$0.type == .button}) {
            
//            UserDefaults.standard.set(false, forKey: "doubleProductsConfig")
            
            selectedElement = element
            storyButton.configButton(buttonData: element)
            storyButton.isHidden = false
            productsButton.isHidden = true
            
            //TEST
//            productsButton.layer.cornerRadius = layer.frame.size.height / 2
//            productsButton.layer.masksToBounds = true
//
//            productsButton.configProductsButton(buttonData: element)
//            productsButton.isHidden = false
//            makeConstraints()
            //TEST
            makeConstraints()
            
            if let elementProduct = slide.elements.last(where: {$0.type == .products}) {
                UserDefaults.standard.set(true, forKey: "doubleProductsConfig")
                
                selectedProductsElement = elementProduct
                productsButton.layer.cornerRadius = layer.frame.size.height / 2
                productsButton.layer.masksToBounds = true
                
                storyButton.configButton(buttonData: element)
                productsButton.configProductsButton(buttonData: elementProduct)
                
                
                productsButton.isHidden = false
                makeConstraints()
                return
            } else {
                UserDefaults.standard.set(false, forKey: "doubleProductsConfig")
                storyButton.configButton(buttonData: element)
                makeConstraints()
            }
            
        } else if let element = slide.elements.first(where: {$0.type == .products}) {
            UserDefaults.standard.set(false, forKey: "doubleProductsConfig")
            selectedProductsElement = element
            productsButton.layer.cornerRadius = layer.frame.size.height / 2
            productsButton.layer.masksToBounds = true
            
            productsButton.configProductsButton(buttonData: element)
            productsButton.isHidden = false
            
            storyButton.configButton(buttonData: element)
            //storyButton.configButton(buttonData: StoriesElement(json: ["link" : "Any"]))
            storyButton.isHidden = true
            
//            productsButton.configProductsButton(buttonData: element)
//            productsButton.isHidden = false
            
            makeConstraints()
        } else {
            UserDefaults.standard.set(false, forKey: "doubleProductsConfig")
            storyButton.isHidden = true
            productsButton.isHidden = true
            makeConstraints()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

//        if keyPath == "timeControlStatus",
//           let change = change,
//           let newValue = change[NSKeyValueChangeKey.newKey] as? Int,
//           let oldValue = change[NSKeyValueChangeKey.oldKey] as? Int {
//
//            let oldStatus = AVPlayer.TimeControlStatus(rawValue: oldValue)
//            let newStatus = AVPlayer.TimeControlStatus(rawValue: newValue)
//            print(oldStatus?.rawValue)
//            if newStatus != oldStatus {
//                if newStatus == .playing {
//                    player.seek(to: .zero)
//                    player.removeObserver(self, forKeyPath: timeObserverKeyPath)
//                    //delegate?.videoLoaded()
//                } else if newStatus == .waitingToPlayAtSpecifiedRate {
//                    player.seek(to: .zero)
//                    player.removeObserver(self, forKeyPath: timeObserverKeyPath)
//                    player.play()
//                }
//            }
//        }
        
//        if object as AnyObject? === videoView.snapVideo.currentItem && keyPath == "status" {
//            if videoView.status == .readyToPlay  && isViewInFocus && isCompletelyVisible {
//                videoView.play()
//                print("StoryCell: Ready to play video")
//            }
//        }
//
//        if object as AnyObject? === videoView.snapVideo && keyPath == "timeControlStatus" {
//            if videoView.snapVideo.timeControlStatus == .playing && isViewInFocus && isCompletelyVisible {
//                print("StoryCell : timeControlStatus == .playing")
//                var videoDuration: Double = 5
//                if let currentItem = videoView.snapVideo.currentItem {
//                    videoDuration = currentItem.duration.seconds
//                }
//                startAnimatingStory(duration: videoDuration)
//                print("StoryCell: Video started animating")
//            }
//        }
    }
    
    func stopPlayer() {
        player.pause()
    }
    
    @objc
    private func didTapOnProductsButton() {
        if let productsList = selectedProductsElement?.products, productsList.count != 0 {
            UserDefaults.standard.set(Int(currentSlide!.id), forKey: "SlideOpenSetting")
            let products = productsList
            delegate?.openProductsCarousel(products: products)
            return
        }
    }
    
    @objc
    private func didTapButton() {
        
//        if let productsList = selectedProductsElement?.products, productsList.count != 0 {
//            UserDefaults.standard.set(Int(currentSlide!.id), forKey: "SlideOpenSetting")
//            let products = productsList
//            delegate?.openProductsCarousel(products: products)
//            return
//        }
        
        if let linkIos = selectedElement?.linkIos, !linkIos.isEmpty {
            if let currentSlide = currentSlide {
                
                mainStoriesDelegate?.structOfSelectedProduct(product: selectedElement!)
                mainStoriesDelegate?.extendLinkIos(url: linkIos)
                
                delegate?.didTapOpenLinkIosExternalWeb(url: linkIos, slide: currentSlide)
                delegate?.sendProductStructForExternal(product: selectedElement!)
                
                return
            }
        }
        
        if let link = selectedElement?.link, !link.isEmpty {
            if let currentSlide = currentSlide {
                delegate?.didTapUrlButton(url: link, slide: currentSlide)
                return
            }
        }
    }
    
    private func setImage(imagePath: String) {
        guard let url = URL(string: imagePath) else {
            return
        }

        let task = URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
            if error == nil {
                guard let unwrappedData = data, let image = UIImage(data: unwrappedData) else { return }
                DispatchQueue.main.async {
                    self.imageView.image = image
                }
            }
        })
        task.resume()
    }

    @objc
    private func showSpinnner(_ notification: NSNotification) {
        //preloader.startPreloaderAnimation()
    }
    
    @objc
    private func hideSpinnner(_ notification: NSNotification) {
        //preloader.stopPreloaderAnimation()
    }
}

extension AVPlayer {
    var isAudioAvailable: Bool? {
        return self.currentItem?.asset.tracks.filter({$0.mediaType == .audio}).count != 0
    }

    var isVideoAvailable: Bool? {
        return self.currentItem?.asset.tracks.filter({$0.mediaType == .video}).count != 0
    }
}

extension UIView {
    
    var heightConstraint: NSLayoutConstraint? {
        get {
            return constraints.first(where: {
                $0.firstAttribute == .height && $0.relation == .equal
            })
        }
        set { setNeedsLayout() }
    }
}
