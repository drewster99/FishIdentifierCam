//
//  AppInfo.swift
//  FishIdentifierCam
//
//  Created by Andrew Benson on 5/16/25.
//

import Foundation
import UIKit

struct AppInfo {
    /// Official name for the app
    static let appName: String = "Fish Identifier Cam"

    /// API login URL for this app
    static let appAPILoginURL: URL = URL(string: "https://us-central1-fish-identifier-cam.cloudfunctions.net/login")!

    /// API app version header - name of header (value will use `appVersionString`, below
    static let appAPIAppVersionHeaderName: String = "FishIdentifierCam-Version"

    public static var userAgentString: String {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "UnknownApp"
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let os = "iOS \(UIDevice.current.systemVersion)"
        let device = UIDevice.current.model
        return "\(appName)/\(appVersion) (\(device); \(os); build \(buildNumber))"
    }

    public static var appVersionString: String {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(appVersion)(\(buildNumber))"
    }
}
