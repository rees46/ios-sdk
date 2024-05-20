import UIKit

extension UIView {
  
  var safeTopAnchor: NSLayoutYAxisAnchor {
      return self.safeAreaLayoutGuide.topAnchor
  }
  
  var safeLeadingAnchor: NSLayoutXAxisAnchor {
      return self.safeAreaLayoutGuide.leadingAnchor
  }
  
  var safeTrailingtAnchor: NSLayoutXAxisAnchor {
      return self.safeAreaLayoutGuide.trailingAnchor
  }
  
  var safeBottomAnchor: NSLayoutYAxisAnchor {
      return self.safeAreaLayoutGuide.bottomAnchor
  }
  
  func bindFrameToSuperviewBounds() {
      guard let superview = self.superview else {
          print("Error! `superview` was nil – call `addSubview(view: UIView)`")
          return
      }
    
    self.translatesAutoresizingMaskIntoConstraints = false
    self.topAnchor.constraint(
        equalTo: superview.topAnchor, constant: 0).isActive = true
    self.bottomAnchor.constraint(
        equalTo: superview.bottomAnchor, constant: 0).isActive = true
    self.leadingAnchor.constraint(
        equalTo: superview.leadingAnchor, constant: 0).isActive = true
    self.trailingAnchor.constraint(
        equalTo: superview.trailingAnchor, constant: 0).isActive = true
  }
}
