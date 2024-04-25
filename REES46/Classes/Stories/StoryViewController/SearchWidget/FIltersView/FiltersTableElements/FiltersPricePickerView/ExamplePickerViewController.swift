import UIKit

class ExamplePickerCoreViewController: UIViewController, PickerCoreViewDataSource {
    @objc func pickerCoreViewNumberOfRows(_ pickerCoreView: PickerCoreView) -> Int {
        return 1
    }
    
    @objc func pickerCoreView(_ pickerCoreView: PickerCoreView, titleForRow row: Int) -> String {
        return "1"
    }
    

    enum PresentationType {
        case numbers(Int, Int), names(Int, Int)
    }


    @IBOutlet weak var examplePicker: PickerCoreView!
    
    let numbers: [String] = {
        var numbers = [String]()
        
        for index in 34...47 {
            numbers.append(String(index))
        }

        return numbers
    }()

    let osxNames = ["0", "50", "100", "500", "1000", "2000", "5000", "10 000", "100 000", "1 000 000", "10 000 000"]
    
    var presentationType = PresentationType.numbers(0, 0)
    
    var currentSelectedValue: String?
    var updateSelectedValue: ((_ newSelectedValue: String) -> Void)?
    
    //var itemsType: PickerExamplesTableViewController.ItemsType = .label
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureNavigationBar()
        configureExamplePicker()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    
    fileprivate func configureNavigationBar() {
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
    }
    
    
    
    fileprivate func configureExamplePicker() {
        examplePicker.dataSource = self
        //examplePicker.delegate = self
        
        let scrollingStyle: PickerCoreView.ScrollingStyle
        let selectionStyle: PickerCoreView.SelectionStyle
        
        switch presentationType {
        case let .numbers(scrollingStyleRaw, selectionStyleRaw):
            scrollingStyle = PickerCoreView.ScrollingStyle(rawValue: scrollingStyleRaw)!
            selectionStyle = PickerCoreView.SelectionStyle(rawValue: selectionStyleRaw)!
            
            examplePicker.scrollingStyle = scrollingStyle
            examplePicker.selectionStyle = selectionStyle
            
            if let currentSelected = currentSelectedValue, let indexOfCurrentSelectedValue = numbers.firstIndex(of: currentSelected) {
                examplePicker.currentSelectedRow = indexOfCurrentSelectedValue
            }
        case let .names(scrollingStyleRaw, selectionStyleRaw):
            scrollingStyle = PickerCoreView.ScrollingStyle(rawValue: scrollingStyleRaw)!
            selectionStyle = PickerCoreView.SelectionStyle(rawValue: selectionStyleRaw)!
            
            examplePicker.scrollingStyle = scrollingStyle
            examplePicker.selectionStyle = selectionStyle
            
            if let currentSelected = currentSelectedValue, let indexOfCurrentSelectedValue = osxNames.firstIndex(of: currentSelected) {
                examplePicker.currentSelectedRow = indexOfCurrentSelectedValue
            }
        }
        
        if selectionStyle == .image {
            examplePicker.selectionImageView.image = UIImage(named: "SelectionImage")!
        }
    }
    
    
    @IBAction func close(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func setNewPickerValue(_ sender: UIBarButtonItem) {
        if let updateValue = updateSelectedValue, let currentSelected = currentSelectedValue {
            updateValue(currentSelected)
        }
        
        dismiss(animated: true, completion: nil)
    }
}

extension ExamplePickerCoreViewController {
    func pickerCoreViewHeightForRows(_ pickerCoreView: PickerCoreView) -> CGFloat {
        return 50.0
    }

    func pickerCoreView(_ pickerCoreView: PickerCoreView, didSelectRow row: Int) {
        switch presentationType {
        case .numbers(_, _):
            currentSelectedValue = numbers[row]
        case .names(_, _):
            currentSelectedValue = osxNames[row]
        }

        print(currentSelectedValue ?? "")
    }
    
    func pickerCoreView(_ pickerCoreView: PickerCoreView, styleForLabel label: UILabel, highlighted: Bool) {
        label.textAlignment = .center
        if #available(iOS 8.2, *) {
            if (highlighted) {
                label.font = UIFont.systemFont(ofSize: 26.0, weight: UIFont.Weight.light)
            } else {
                label.font = UIFont.systemFont(ofSize: 16.0, weight: UIFont.Weight.light)
            }
        } else {
            if (highlighted) {
                label.font = UIFont(name: "HelveticaNeue-Light", size: 16.0)
            } else {
                label.font = UIFont(name: "HelveticaNeue-Light", size: 26.0)
            }
        }
        
        if (highlighted) {
            label.textColor = view.tintColor
        } else {
            label.textColor = UIColor(red: 161.0/255.0, green: 161.0/255.0, blue: 161.0/255.0, alpha: 1.0)
        }
    }
    
    func pickerCoreView(_ pickerCoreView: PickerCoreView, viewForRow row: Int, highlighted: Bool, reusingView view: UIView?) -> UIView? {
//        if (itemsType != .customView) {
//            return nil
//        }
        
        var customView = view
        
        let imageTag = 100
        let labelTag = 101
        
        if (customView == nil) {
            var frame = pickerCoreView.frame
            frame.origin = CGPoint.zero
            frame.size.height = 50
            customView = UIView(frame: frame)
            
            let imageView = UIImageView(frame: frame)
            imageView.tag = imageTag
            imageView.contentMode = .scaleAspectFill
            imageView.image = UIImage(named: "AbstractImage")
            imageView.clipsToBounds = true
            
            customView?.addSubview(imageView)
            
            let label = UILabel(frame: frame)
            label.tag = labelTag
            label.textColor = UIColor.white
            label.shadowColor = UIColor.black
            label.shadowOffset = CGSize(width: 1.0, height: 1.0)
            label.textAlignment = .center
            
            if #available(iOS 8.2, *) {
                label.font = UIFont.systemFont(ofSize: 26.0, weight: UIFont.Weight.light)
            } else {
                label.font = UIFont(name: "HelveticaNeue-Light", size: 26.0)
            }
            
            customView?.addSubview(label)
        }
        
        let imageView = customView?.viewWithTag(imageTag) as? UIImageView
        let label = customView?.viewWithTag(labelTag) as? UILabel
        
        switch presentationType {
        case .numbers(_, _):
            label?.text = numbers[row]
        case .names(_, _):
            label?.text = osxNames[row]
        }
        
        let alpha: CGFloat = highlighted ? 1.0 : 0.5
        
        imageView?.alpha = alpha
        label?.alpha = alpha
        
        return customView
    }
}
