import Foundation
import GoogleMobileAds
import UIKit
import google_mobile_ads

class NativeAdFactoryExample: NSObject, FLTNativeAdFactory {

  func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable : Any]? = nil
  ) -> NativeAdView {

    let nativeAdView = NativeAdView()

    let background = UIView()
    background.backgroundColor = UIColor(
      red: 1.0,
      green: 0.95,
      blue: 0.97,
      alpha: 1.0
    )

    background.layer.cornerRadius = 16
    background.translatesAutoresizingMaskIntoConstraints = false

    nativeAdView.addSubview(background)

    NSLayoutConstraint.activate([
      background.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
      background.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
      background.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
      background.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
    ])

    let headlineLabel = UILabel()
    headlineLabel.translatesAutoresizingMaskIntoConstraints = false
    headlineLabel.font = UIFont.boldSystemFont(ofSize: 18)
    headlineLabel.textColor = .black
    headlineLabel.numberOfLines = 2

    background.addSubview(headlineLabel)

    NSLayoutConstraint.activate([
      headlineLabel.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
      headlineLabel.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 16),
      headlineLabel.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16),
    ])

    headlineLabel.text = nativeAd.headline

    nativeAdView.headlineView = headlineLabel
    nativeAdView.nativeAd = nativeAd

    return nativeAdView
  }
}