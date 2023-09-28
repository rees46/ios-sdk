import Foundation
import UIKit

public extension UICollectionViewCell {
    
    func showInCellPromocodeBanner(banner: PromocodeBanner) {
        if PromocodeBanner.OPEN_BANNERS >= PromocodeBanner.MAX_BANNERS {
            return
        } else {
            PromocodeBanner.OPEN_BANNERS += 1
        }
        
        let to: CGRect = banner.frame
        
        switch banner.location {
        case .topLeft:
            banner.frame = CGRect(x: banner.frame.minX, y: banner.frame.minY, width: 0, height: banner.frame.height)
            banner.updateSubviews()
            break
        case .topRight:
            banner.frame = CGRect(x: banner.frame.minX + banner.frame.width, y: banner.frame.minY, width: 0, height: banner.frame.height)
            banner.updateSubviews()
            break
        case .bottomLeft:
            banner.frame = CGRect(x: banner.frame.minX, y: banner.frame.minY, width: 0, height: banner.frame.height)
            banner.updateSubviews()
            break
        case .bottomRight:
            banner.frame = CGRect(x: banner.frame.minX + banner.frame.width, y: banner.frame.minY, width: 0, height: banner.frame.height)
            banner.updateSubviews()
            break
        }
        
        contentView.addSubview(banner)
        contentView.bringSubviewToFront(banner)
        
        UIView.setAnimationCurve(UIView.AnimationCurve.easeOut)
        switch banner.location {
        case .topLeft:
            UIView.animate(withDuration: banner.animationDuration, animations: {
                banner.frame = CGRect(x: banner.frame.minX, y: banner.frame.minY, width: to.width, height: banner.frame.height)
                banner.updateSubviews()
            }, completion: { (b) in
                banner.startTimer()
            })
            break
        case .topRight:
            UIView.animate(withDuration: banner.animationDuration, animations: {
                banner.frame = CGRect(x: to.minX, y: banner.frame.minY, width: to.width, height: banner.frame.height)
                banner.updateSubviews()
            }, completion: { (b) in
                banner.startTimer()
            })
            break
        case .bottomLeft:
            UIView.animate(withDuration: banner.animationDuration, animations: {
                banner.frame = CGRect(x: banner.frame.minX, y: banner.frame.minY, width: to.width, height: banner.frame.height)
                banner.updateSubviews()
            }, completion: { (b) in
                banner.startTimer()
            })
            break
        case .bottomRight:
            UIView.animate(withDuration: banner.animationDuration, animations: {
                banner.frame = CGRect(x: to.minX, y: banner.frame.minY, width: to.width, height: banner.frame.height)
                banner.updateSubviews()
            }, completion: { (b) in
                banner.startTimer()
            })
            break
        }
        
        banner.frame = to
    }
}


public extension UIViewController {
    
    func showInViewPromocodeBanner(banner: PromocodeBanner) {
        if PromocodeBanner.OPEN_BANNERS >= PromocodeBanner.MAX_BANNERS {
            return
        } else {
            PromocodeBanner.OPEN_BANNERS += 1
        }
        
        let to: CGRect = banner.frame
        
        switch banner.location {
        case .topLeft:
            banner.frame = CGRect(x: banner.frame.minX, y: banner.frame.minY, width: 0, height: banner.frame.height)
            banner.updateSubviews()
            break
        case .topRight:
            banner.frame = CGRect(x: banner.frame.minX + banner.frame.width, y: banner.frame.minY, width: 0, height: banner.frame.height)
            banner.updateSubviews()
            break
        case .bottomLeft:
            banner.frame = CGRect(x: banner.frame.minX, y: banner.frame.minY, width: 0, height: banner.frame.height)
            banner.updateSubviews()
            break
        case .bottomRight:
            banner.frame = CGRect(x: banner.frame.minX + banner.frame.width, y: banner.frame.minY, width: 0, height: banner.frame.height)
            banner.updateSubviews()
            break
        }
        
        self.view.addSubview(banner)
        self.view.bringSubviewToFront(banner)
        
        UIView.setAnimationCurve(UIView.AnimationCurve.easeOut)
        switch banner.location {
        case .topLeft:
            UIView.animate(withDuration: banner.animationDuration, animations: {
                banner.frame = CGRect(x: banner.frame.minX, y: banner.frame.minY, width: to.width, height: banner.frame.height)
                banner.updateSubviews()
            }, completion: { (b) in
                banner.startTimer()
            }) 
            break
        case .topRight:
            UIView.animate(withDuration: banner.animationDuration, animations: {
                banner.frame = CGRect(x: to.minX, y: banner.frame.minY, width: to.width, height: banner.frame.height)
                banner.updateSubviews()
            }, completion: { (b) in
                banner.startTimer()
            })
            break
        case .bottomLeft:
            UIView.animate(withDuration: banner.animationDuration, animations: {
                banner.frame = CGRect(x: banner.frame.minX, y: banner.frame.minY, width: to.width, height: banner.frame.height)
                banner.updateSubviews()
            }, completion: { (b) in
                banner.startTimer()
            })
            break
        case .bottomRight:
            UIView.animate(withDuration: banner.animationDuration, animations: {
                banner.frame = CGRect(x: to.minX, y: banner.frame.minY, width: to.width, height: banner.frame.height)
                banner.updateSubviews()
            }, completion: { (b) in
                banner.startTimer()
            }) 
            break
        }
        
        banner.frame = to
    }
}
