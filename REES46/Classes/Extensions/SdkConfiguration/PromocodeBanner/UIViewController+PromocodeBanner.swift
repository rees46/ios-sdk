import Foundation
import UIKit

public extension UICollectionViewCell {
    func showInCellPromocodeBanner(promoBanner: PromocodeBanner) {
        if PromocodeBanner.OPEN_PROMOCODE_BANNERS >= PromocodeBanner.MAX_ALLOWED_BANNERS {
            return
        } else {
            PromocodeBanner.OPEN_PROMOCODE_BANNERS += 1
        }
        
        let needToSetup: CGRect = promoBanner.frame
        
        switch promoBanner.location {
        case .topLeft:
            promoBanner.frame = CGRect(x: promoBanner.frame.minX, y: promoBanner.frame.minY, width: 0, height: promoBanner.frame.height)
            promoBanner.updateSubviews()
            break
        case .topRight:
            promoBanner.frame = CGRect(x: promoBanner.frame.minX + promoBanner.frame.width, y: promoBanner.frame.minY, width: 0, height: promoBanner.frame.height)
            promoBanner.updateSubviews()
            break
        case .bottomLeft:
            promoBanner.frame = CGRect(x: promoBanner.frame.minX, y: promoBanner.frame.minY, width: 0, height: promoBanner.frame.height)
            promoBanner.updateSubviews()
            break
        case .bottomRight:
            promoBanner.frame = CGRect(x: promoBanner.frame.minX + promoBanner.frame.width, y: promoBanner.frame.minY, width: 0, height: promoBanner.frame.height)
            promoBanner.updateSubviews()
            break
        }
        
        contentView.addSubview(promoBanner)
        contentView.bringSubviewToFront(promoBanner)
        
        UIView.setAnimationCurve(UIView.AnimationCurve.easeOut)
        switch promoBanner.location {
        case .topLeft:
            UIView.animate(withDuration: promoBanner.animationDuration, animations: {
                promoBanner.frame = CGRect(x: promoBanner.frame.minX, y: promoBanner.frame.minY, width: needToSetup.width, height: promoBanner.frame.height)
                promoBanner.updateSubviews()
            }, completion: { (isFinished) in
                promoBanner.startTimer()
            })
            break
        case .topRight:
            UIView.animate(withDuration: promoBanner.animationDuration, animations: {
                promoBanner.frame = CGRect(x: needToSetup.minX, y: promoBanner.frame.minY, width: needToSetup.width, height: promoBanner.frame.height)
                promoBanner.updateSubviews()
            }, completion: { (isFinished) in
                promoBanner.startTimer()
            })
            break
        case .bottomLeft:
            UIView.animate(withDuration: promoBanner.animationDuration, animations: {
                promoBanner.frame = CGRect(x: promoBanner.frame.minX, y: promoBanner.frame.minY, width: needToSetup.width, height: promoBanner.frame.height)
                promoBanner.updateSubviews()
            }, completion: { (isFinished) in
                promoBanner.startTimer()
            })
            break
        case .bottomRight:
            UIView.animate(withDuration: promoBanner.animationDuration, animations: {
                promoBanner.frame = CGRect(x: needToSetup.minX, y: promoBanner.frame.minY, width: needToSetup.width, height: promoBanner.frame.height)
                promoBanner.updateSubviews()
            }, completion: { (isFinished) in
                promoBanner.startTimer()
            })
            break
        }
        
        promoBanner.frame = needToSetup
    }
}


public extension UIViewController {
    func showInViewPromocodeBanner(promoBanner: PromocodeBanner) {
        if PromocodeBanner.OPEN_PROMOCODE_BANNERS >= PromocodeBanner.MAX_ALLOWED_BANNERS {
            return
        } else {
            PromocodeBanner.OPEN_PROMOCODE_BANNERS += 1
        }
        
        let needToSetup: CGRect = promoBanner.frame
        
        switch promoBanner.location {
        case .topLeft:
            promoBanner.frame = CGRect(x: promoBanner.frame.minX, y: promoBanner.frame.minY, width: 0, height: promoBanner.frame.height)
            promoBanner.updateSubviews()
            break
        case .topRight:
            promoBanner.frame = CGRect(x: promoBanner.frame.minX + promoBanner.frame.width, y: promoBanner.frame.minY, width: 0, height: promoBanner.frame.height)
            promoBanner.updateSubviews()
            break
        case .bottomLeft:
            promoBanner.frame = CGRect(x: promoBanner.frame.minX, y: promoBanner.frame.minY, width: 0, height: promoBanner.frame.height)
            promoBanner.updateSubviews()
            break
        case .bottomRight:
            promoBanner.frame = CGRect(x: promoBanner.frame.minX + promoBanner.frame.width, y: promoBanner.frame.minY, width: 0, height: promoBanner.frame.height)
            promoBanner.updateSubviews()
            break
        }
        
        self.view.addSubview(promoBanner)
        self.view.bringSubviewToFront(promoBanner)
        
        UIView.setAnimationCurve(UIView.AnimationCurve.easeOut)
        switch promoBanner.location {
        case .topLeft:
            UIView.animate(withDuration: promoBanner.animationDuration, animations: {
                promoBanner.frame = CGRect(x: promoBanner.frame.minX, y: promoBanner.frame.minY, width: needToSetup.width, height: promoBanner.frame.height)
                promoBanner.updateSubviews()
            }, completion: { (isFinished) in
                promoBanner.startTimer()
            }) 
            break
        case .topRight:
            UIView.animate(withDuration: promoBanner.animationDuration, animations: {
                promoBanner.frame = CGRect(x: needToSetup.minX, y: promoBanner.frame.minY, width: needToSetup.width, height: promoBanner.frame.height)
                promoBanner.updateSubviews()
            }, completion: { (isFinished) in
                promoBanner.startTimer()
            })
            break
        case .bottomLeft:
            UIView.animate(withDuration: promoBanner.animationDuration, animations: {
                promoBanner.frame = CGRect(x: promoBanner.frame.minX, y: promoBanner.frame.minY, width: needToSetup.width, height: promoBanner.frame.height)
                promoBanner.updateSubviews()
            }, completion: { (isFinished) in
                promoBanner.startTimer()
            })
            break
        case .bottomRight:
            UIView.animate(withDuration: promoBanner.animationDuration, animations: {
                promoBanner.frame = CGRect(x: needToSetup.minX, y: promoBanner.frame.minY, width: needToSetup.width, height: promoBanner.frame.height)
                promoBanner.updateSubviews()
            }, completion: { (isFinished) in
                promoBanner.startTimer()
            }) 
            break
        }
        
        promoBanner.frame = needToSetup
    }
}
