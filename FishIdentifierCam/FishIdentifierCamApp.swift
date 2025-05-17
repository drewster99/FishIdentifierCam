//
//  FishIdentifierCamApp.swift
//  FishIdentifierCam
//
//  Created by Andrew Benson on 5/13/25.
//

import Foundation
import SwiftUI
import Firebase
import DeviceCheck
import OSLog

@main
struct FishIdentifierCamApp: App {
    @StateObject private var appAPI: AppAPI

    private static let logger = Logger(subsystem: "FishIdentifierCamApp", category: "App")
    init() {
        let appAPI = AppAPI()
        _appAPI = .init(wrappedValue: appAPI)

        if CommandLine.arguments.contains("--testAPILogin") {
            // MARK: - FIREBASE - APP CHECK (DEVICE CHECK / APP ATTEST)
            Self.logger.debug("DeviceCheck API: \(DCDevice.current.isSupported ? "SUPPORTED" : "NOT SUPPORTED")")
#if targetEnvironment(simulator)
            Self.logger.debug("Setting firebase AppCheck provider factory (simulator)")
            let providerFactory = AppCheckDebugProviderFactory()
#else
            Self.logger.debug("Setting firebase AppCheck provider factory (device)")
            let providerFactory = NCCAppCheckProviderFactory()
#endif
            AppCheck.setAppCheckProviderFactory(providerFactory)

            FirebaseApp.configure()
            Task.detached {
                appAPI.doFirebaseUserLogin()
            }
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .colorScheme(.dark)
        }
    }
}
