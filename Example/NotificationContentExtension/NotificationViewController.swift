//
//  NotificationViewController.swift
//  NotificationContentExtension
//
//  Created by Арсений Дорогин on 03.01.2021.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import CoreData
import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var subTitleLabel: UILabel!

    var bestAttemptContent: UNMutableNotificationContent?

    var carouselImages: [Product] = [Product]()
    var currentIndex: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.contentInset = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
        collectionView.register(UINib(nibName: "ImagesCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "ImagesCollectionViewCell")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    func didReceive(_ notification: UNNotification) {
        bestAttemptContent = (notification.request.content.mutableCopy() as? UNMutableNotificationContent)

        if let bestAttemptContent = bestAttemptContent {
            titleLabel.isHidden = true
            subTitleLabel.isHidden = true
            if let aps = bestAttemptContent.userInfo["aps"] as? [String: Any] {
                if let alert = aps["alert"] as? [String: Any] {
                    if let title = alert["title"] as? String {
                        titleLabel.text = title
                        titleLabel.isHidden = false
                    }
                    if let subtitle = alert["subtitle"] as? String {
                        subTitleLabel.text = subtitle
                        subTitleLabel.isHidden = false
                    }
                }
            }
            if let event = bestAttemptContent.userInfo["event"] as? [String: Any] {
                if let products = event["products"] as? [[String: Any]] {
                    var productArr = [Product]()
                    for item in products {
                        let product = Product(json: item)
                        productArr.append(product)
                    }
                    carouselImages = productArr
                    DispatchQueue.main.async {
                        self.collectionView.reloadData()
                    }
                }
            }
        }
    }

    func didReceive(_ response: UNNotificationResponse, completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void) {
        if response.actionIdentifier == "carousel.next" {
            scrollNextItem()
            completion(UNNotificationContentExtensionResponseOption.doNotDismiss)
        } else if response.actionIdentifier == "carousel.previous" {
            scrollPreviousItem()
            completion(UNNotificationContentExtensionResponseOption.doNotDismiss)
        } else {
            completion(UNNotificationContentExtensionResponseOption.dismissAndForwardAction)
        }
    }

    private func scrollNextItem() {
        collectionView.isPagingEnabled = false
        currentIndex == (carouselImages.count - 1) ? (currentIndex = 0) : (currentIndex += 1)
        let indexPath = IndexPath(row: currentIndex, section: 0)
        collectionView.contentInset.right = (indexPath.row == 0 || indexPath.row == carouselImages.count - 1) ? 10.0 : 20.0
        collectionView.contentInset.left = (indexPath.row == 0 || indexPath.row == carouselImages.count - 1) ? 10.0 : 20.0
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        collectionView.isPagingEnabled = true
    }

    private func scrollPreviousItem() {
        collectionView.isPagingEnabled = false
        currentIndex == 0 ? (currentIndex = carouselImages.count - 1) : (currentIndex -= 1)
        let indexPath = IndexPath(row: currentIndex, section: 0)
        collectionView.contentInset.right = (indexPath.row == 0 || indexPath.row == carouselImages.count - 1) ? 10.0 : 20.0
        collectionView.contentInset.left = (indexPath.row == 0 || indexPath.row == carouselImages.count - 1) ? 10.0 : 20.0
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
    }
}

extension NotificationViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedItem = carouselImages[indexPath.row]
        if let url = URL(string: selectedItem.deepUrl) {
            extensionContext?.open(url, completionHandler: nil)
        }
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return carouselImages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImagesCollectionViewCell", for: indexPath) as! ImagesCollectionViewCell
        let curProd = carouselImages[indexPath.row]
        cell.configure(product: curProd)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = self.collectionView.frame.width
        let cellWidth = (indexPath.row == 0 || indexPath.row == carouselImages.count - 1) ? (width - 30) : (width - 40)
        return CGSize(width: cellWidth, height: width - 20.0)
    }
}
