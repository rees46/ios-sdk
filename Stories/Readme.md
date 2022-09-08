# Stories
## Setup story view
### Step 1 - Add story view to your screen.
#### Xib integration
1 - Create view in xib editor. Change class to 'StoriesView'. 
2 - Connect to your viewController.swift. 

    @IBOutlet private weak var storiesBackView: StoriesView!
    
3 - Initialize with SDK and VC StoryView module
    
    storiesBackView.configure(sdk: SDK, mainVC: self)
    
#### Code integration
0 - Import Library
    
    import REES46

1 - Create view in .swift.

    var storiesView = StoriesView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
    view.addSubview(storiesView)

2 - Initialize with SDK and VC StoryView module
    
    storiesView.configure(sdk: SDK, mainVC: self)
    
Enjoy!
