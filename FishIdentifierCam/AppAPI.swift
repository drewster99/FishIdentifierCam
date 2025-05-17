//
//  AppAPI.swift
//  FishIdentifierCam
//
//  Created by Andrew Benson on 5/16/25.
//  Copyright (C) 2025 Nuclear Cyborg Corp
//
//  Proprietary and Confidental.
//  All rights reserved.
//

import Foundation
import SwiftUI
import OSLog
import DeviceCheck
import CryptoKit
import Firebase
import FirebaseCore
import FirebaseAppCheck
import FirebaseAuth

final class AppAPI: ObservableObject {
    private static let logger = Logger(subsystem: "AppAPI", category: "AppAPI")

    @Published public var isLoggedIn: Bool = false
    @Published public var loginResult: Result<LoginResponse, Error>?

    /// Firebase `User` object
    @Published public var user: User?

    private lazy var urlSessionOperationQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        return operationQueue
    }()

    private lazy var urlSession: URLSession = {
        var configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300.0
        configuration.timeoutIntervalForResource = 300.0
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: urlSessionOperationQueue)
        return session
    }()

    /// Fetches Firebase user's ID token - used for validating anonymous users with Firebase
    public func getUserBearerToken(forcingRefresh: Bool = false) async -> String? {
        guard let user else { return nil }
        do {
            return try await user.getIDToken(forcingRefresh: forcingRefresh)
        } catch {
            Self.logger.error("Error getting user bearer token: \(error)")
            return nil
        }
    }

    /// App check token
    public func getAppCheckToken(forcingRefresh: Bool = false) async -> String? {
        do {
            return try await AppCheck.appCheck().token(forcingRefresh: forcingRefresh).token
        } catch {
            Self.logger.error("Error getting app check token: \(error)")
            return nil
        }
    }

    private func getLoginURLRequest() async -> URLRequest {
        var request = await getURLRequest(url: AppInfo.appAPILoginURL)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        return request
    }

    public func getURLRequest(url: URL) async -> URLRequest {
        var req = URLRequest(url: url)
        req.timeoutInterval = 120
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpMethod = "POST"
        req.setValue(AppInfo.userAgentString, forHTTPHeaderField: "User-Agent")
        req.setValue(AppInfo.appVersionString, forHTTPHeaderField: AppInfo.appAPIAppVersionHeaderName)
        if let bearerToken = await getUserBearerToken() {
            req.addValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        if let appCheckToken = await getAppCheckToken( ) {
            req.addValue("\(appCheckToken)", forHTTPHeaderField: "X-Firebase-AppCheck")
        }
        return req
    }


    public init() {

    }

    public func doFirebaseUserLogin() {
        let completion: (Result<LoginResponse, Error>) -> Void = { result in
            DispatchQueue.main.async {
                self.loginResult = result
                switch result {
                case .success(let response):
                    if response.loginResult == "success" {
                        self.isLoggedIn = true
                        return
                    }
                default: break
                }
                self.isLoggedIn = false
            }
        }

        Self.logger.debug("\(#function): AppCheck.appCheck().isTokenAutoRefreshEnabled = \(AppCheck.appCheck().isTokenAutoRefreshEnabled)")

        do {
            let signposter = OSSignposter(subsystem: "AppAPI", category: "Login")
            let signpostID = signposter.makeSignpostID()
            let name: StaticString = "AppAPI Firebase Sign In"
            let state = signposter.beginInterval(name, id: signpostID)

            // Authenticate user (e.g., anonymously)
            Auth.auth().signInAnonymously { [weak self] authResult, error in
                signposter.endInterval(name, state)

                if let error {
                    Self.logger.error("Error: auth().signInAnonymously() failed: \(error)")
                    completion(.failure(error))
                    return
                }
                guard let authResult else {
                    Self.logger.error("Error: auth.signInAnonymously(): authResult is unexpectedly nil, but no error was reported")
                    completion(.failure(LoginResponse.Error.authResultUnexpectedlyNil))
                    return
                }

                let idTokenRefreshName: StaticString = "Init Firebase ID Token Refresh"
                let state = signposter.beginInterval(idTokenRefreshName, id: signpostID)

                let user = authResult.user
                Self.logger.log("Firebase anonymous user login succeeded.")
                DispatchQueue.main.async {
                    self?.user = user
                }
                Self.logger.debug("Requesting user's ID token...")
                user.getIDTokenForcingRefresh(true, completion: { idToken, error in
                    signposter.endInterval(idTokenRefreshName, state)

                    if let error {
                        Self.logger.error("Error: getIDToken() failed: \(error)")
                        completion(.failure(error))
                        return
                    }
                    guard let idToken else {
                        Self.logger.error("Error: getIDToken() idToken is unexpectedly nil, but no error was reported")
                        completion(.failure(LoginResponse.Error.idTokenUnexpectedlyNil))
                        return
                    }

                    Self.logger.log("Firebase user's ID token receieved successfully: \(idToken)")

                    let appCheckTokenName: StaticString = "Init Firebase AppCheck Token Refresh"
                    let state = signposter.beginInterval(appCheckTokenName, id: signpostID)

                    Self.logger.debug("Requesting Firebase App Check token...")
                    AppCheck.appCheck().token(forcingRefresh: false) { [weak self] appCheckToken, error in
                        signposter.endInterval(appCheckTokenName, state)
                        guard let self else {
                            return
                        }

                        if let error {
                            Self.logger.error("Error: appCheck().token() failed: \(error)")
                            completion(.failure(error))
                            return
                        }

                        // we just nil-check this token because every place else fetches it
                        // from the `getAppCheckToken` function above
                        guard appCheckToken?.token != nil else {
                            Self.logger.error("Error: appCheck().token() appCheckToken unexpectedly nil, but no error was reported")
                            completion(.failure(LoginResponse.Error.appCheckTokenUnexpectedlyNil))
                            return
                        }

                        Self.logger.debug("Received App Check token: \(appCheckToken?.token ?? "<nil>")")
                        Task { [weak self] in
                            Self.logger.log("Doing API login...")
                            guard let self else { return }
                            // Includes both the user's ID token and App Check token in the request
                            let request = await getLoginURLRequest()

                            // Send the request
                            urlSession.dataTask(with: request) { data, response, error in
                                if let error {
                                    Self.logger.error("LOGIN URL request error: \(error)")
                                    completion(.failure(error))
                                    return
                                }
                                if let response {
                                    Self.logger.error("LOGIN URL response: \(response)")
                                    if let httpURLResponse = response as? HTTPURLResponse {
                                        Self.logger.log("LOGIN HTTP URL Response status code: \(httpURLResponse.statusCode)")
                                    }
                                }
                                if let data {
                                    Self.logger.debug("LOGIN URL response data (\(data.count) bytes): \(String(data: data, encoding: .utf8) ?? "(no data)")")
                                    let decoder = JSONDecoder()
                                    decoder.dateDecodingStrategy = .iso8601
                                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                                    do {
                                        let loginResponse = try decoder.decode(LoginResponse.self, from: data)
                                        Self.logger.log("LOGIN succeeded")
                                        completion(.success(loginResponse))
                                    } catch {
                                        Self.logger.error("Error decoding login response: \(error)")
                                        completion(.failure(error))
                                    }
                                } else {
                                    completion(.failure(LoginResponse.Error.noDataInResponse))
                                }
                            }.resume()
                        }
                    }
                }) // getIDToken
            }
        }
    }
}

extension Data {
    /// Returns a base64-encoded version of the binary data
    /// of the md5 hash for the given data
    public func md5Base64() throws -> String {
        let digest = Insecure.MD5.hash(data: self)
        let digestData = Data(digest) // raw 16-byte binary
        return digestData.base64EncodedString()
    }
}

extension AppAPI {
    public struct FishIdentificationRequest: Identifiable {
        public init(id: ID, image: UIImage, uploadRequest: AppAPI.UploadRequest) {
            self.id = id
            self.image = image
            self.uploadRequest = uploadRequest
        }
        

        /// Errors related to fish identification
        public enum Error: Swift.Error, LocalizedError {
            case unrecognizedImageFormat

            public var errorDescription: String? {
                switch self {
                case .unrecognizedImageFormat:
                    return "We don't recognize the image format of this photo. Please try as JPEG or PNG"
                }
            }
        }

        typealias ID = String
        let id: ID
        let image: UIImage
        var uploadRequest: UploadRequest

        public static func create(with image: UIImage) throws -> Self {
            var filename = UUID().uuidString
            let data: Data
            let contentType: String

            if let pngData = image.pngData() {
                data = pngData
                contentType = "image/png"
                filename += ".png"
            } else if let jpegData = image.jpegData(compressionQuality: 1) {
                data = jpegData
                contentType = "image/jpeg"
                filename += ".jpg"
            } else {
                throw FishIdentificationRequest.Error.unrecognizedImageFormat
            }
            let byteSize = data.count
            let checksum = try data.md5Base64()

            let uploadRequest = try UploadRequest(
                filename: filename,
                contentType: contentType,
                byteSize: byteSize,
                checksum: checksum
            )

            let fishIdentificationRequest = FishIdentificationRequest(
                id: UUID().uuidString,
                image: image,
                uploadRequest: uploadRequest
            )

            return fishIdentificationRequest
        }
    }

    public struct UploadRequest: Encodable {
        public init(filename: String, contentType: String, byteSize: Int, checksum: String) throws {
            self.filename = filename
            self.contentType = contentType
            self.byteSize = byteSize
            self.checksum = checksum
        }
        
        //      "filename": "fishpic.jpg",                     <-- filename
        //      "content_type": "image/jpeg",                  <-- we identified what kind of image this is - important!
        //      "byte_size": 2204455,                          <-- data size, in bytes
        //      "checksum": "EA5w4bPQDfzBgEbes8ZmuQ=="         <-- md5 base64 encoded
        let filename: String
        let contentType: String
        let byteSize: Int
        let checksum: String

        public struct Response: Decodable {
            let signedID: String                        // <-- signed_id
            let uploadURL: URL                          // <-- upload_url
            let uploadHeaders: [ String : String ]      // <-- upload_headers

            //        {
            //            "byte-size" : 2204455,                             <-- size of the file - same size we declared above
            //            "checksum" : "EA5w4bPQDfzBgEbes8ZmuQ==",           <-- this is your base64 encoded md5 hash
            //            "content-type" : "image/jpeg",
            //            "created-at" : "2025-05-13T18:46:16.806Z",
            //            "direct-upload" : {                                <-- details of how to uplaod
            //                "headers" : {
            //                    "Content-Disposition" : "inline; filename=\"fishpic.jpg\"; filename*=UTF-8''fishpic.jpg",
            //                    "Content-MD5" : "EA5w4bPQDfzBgEbes8ZmuQ=="
            //                },
            //                "url" : "https://storage.googleapis.com/backend-fishes-st<redact>]36JNc4%2BRg%3D%3D"
            //            },
            //            "filename" : "fishpic.jpg",
            //            "id" : 9436493,
            //            "key" : "qrh7v80ud6ptxp06j96mb9u6q1jp",
            //            "metadata" : {},
            //            "service-name" : "google",
            //            "signed-id" : "<your-signed-id>"
            //        }
        }
    }



    public func requestUpload(_ request: FishIdentificationRequest) async throws -> UploadRequest.Response {
        Self.logger.log("\(#function)")
        let url = URL(string: "https://us-central1-fish-identifier-cam.cloudfunctions.net/upload_request")!

        var apiRequest = await getURLRequest(url: url)
        apiRequest.httpMethod = "POST"

        Self.logger.log("\(#function) - encoding request")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request.uploadRequest)
        apiRequest.httpBody = data

        Self.logger.log("\(#function) - sending request")
        let (responseData, response) = try await urlSession.data(from: url)
        Self.logger.log("\(#function) - response received")

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse {
                Self.logger.error("HTTP status code: \(httpResponse.statusCode)")
            }
            Self.logger.error("Bad server response")
            throw URLError(.badServerResponse)
        }

        Self.logger.log("\(#function) - decoding response")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let uploadRequestResponse = try decoder.decode(UploadRequest.Response.self, from: responseData)

        Self.logger.log("Response decoded: ID=\(uploadRequestResponse.signedID), URL=\(uploadRequestResponse.uploadURL), headers=\(uploadRequestResponse.uploadHeaders)")
        return uploadRequestResponse
    }
}

public struct LoginResponse: Decodable, Equatable, Hashable {
    let loginResult: String
    let messages: [Message]?

    public enum Error: Swift.Error {
        case noDataInResponse
        case appCheckTokenUnexpectedlyNil
        case idTokenUnexpectedlyNil
        case authResultUnexpectedlyNil

    }
    public struct Message: Decodable, Identifiable, Equatable, Hashable {
        public let id: String
        let type: String
        let isOneTime: Bool
        let appVersion: String
        let title: String
        let message: String
        let buttons: [ButtonDescription]

        public struct ButtonDescription: Decodable, Equatable, Hashable {
            let title: String
            let actionType: String
            let actionData: String
        }

        static let empty: Message = {
            Message(id: "0x0000000000001EMPTY", type: "empty", isOneTime: false, appVersion: "n/a", title: "n/a", message: "n/a", buttons: [])
        }()
        public var shouldShow: Bool {
            let loginMessageIDsPreviouslyShownKey = "loginMessageIDsPreviouslyShown"
            var loginMessageIDsPreviouslyShown: Set<String> {
                get {

                    let items = UserDefaults.standard.string(forKey: loginMessageIDsPreviouslyShownKey) ?? ""
                    let array = items.split(separator: ",")
                    let set = Set(array.map({ String($0) }))
                    return set
                }
                set {
                    let items = newValue.joined(separator: ",")
                    UserDefaults.standard.setValue(items, forKey: loginMessageIDsPreviouslyShownKey)
                }

            }

            // If type is 'debug', it only shows for debug builds
            switch type.lowercased() {
            case "debug":
#if DEBUG
                break
#else
                print("Message \(id) is marked as debug only, not showing in release build")
                return false
#endif
            default:
                break
            }

            func passesVersionCheck() -> Bool {
                // Check app version string
                let actual = AppInfo.appVersionString
                let compare = appVersion
                func comparableVersionString(_ appVersionText: any StringProtocol) -> String {
                    let result: String = appVersionText
                        .replacingOccurrences(of: ")", with: "")
                        .replacingOccurrences(of: "(", with: ".")
                        .split(separator: ".")
                        .map({
                            if let intValue = Int($0) {
                                return String(format: "%04d", intValue)
                            } else {
                                return String($0)
                            }
                        })
                        .joined(separator: ".")
                    return result
                }

                let comparableActual = comparableVersionString(actual)
                guard compare.count >= 2 else {
                    print("Message \(id) `app_version` too short:: \(compare) - skipping")
                    return false
                }
                let comparisonType = compare.first ?? "="
                let versionToCompare = compare.dropFirst()
                let comparableMessageVersion = comparableVersionString(versionToCompare)
                print("actual version: \(comparableActual) message version: \(comparableMessageVersion) comparable")
                switch comparisonType {
                case "=":
                    return comparableActual == comparableMessageVersion
                case "<":
                    return comparableActual < comparableMessageVersion
                case ">":
                    return comparableActual > comparableMessageVersion
                default:
                    print("Message \(id) unkonwn version comparison type: \(comparisonType) - skipping")
                    return false
                }
            }

            guard passesVersionCheck() else {
                print("Message \(id) - version check failed - skipping")
                if !loginMessageIDsPreviouslyShown.contains(id) {
                    loginMessageIDsPreviouslyShown.insert(id)
                }
                return false
            }

            guard isOneTime else {
                print("Message \(id) is not `isOneTime` - ok to show")
                return true
            }

            // It's a 1-time message. Check to see if we showed it before
            if loginMessageIDsPreviouslyShown.contains(id) {
                print("Message \(id) previously shown - ignoring")
                return false
            } else {
                print("Message \(id) has not been shown - ok to show")
                loginMessageIDsPreviouslyShown.insert(id)
                return true
            }
        }
    }
}


//
//  NCCAppCheckProviderFactory.swift
//
//  Created by Andrew Benson on 3/14/25.
//

import Foundation
import Firebase
import FirebaseCore
import FirebaseAppCheck

/// Creates App Check providers - Required for Firebase App Check
final class NCCAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if #available(iOS 14.0, *), !ProcessInfo.processInfo.isiOSAppOnMac {
            return AppAttestProvider(app: app)
        } else {
            // iOS/iPad running on mac, or native macOS
            return DeviceCheckProvider(app: app)
        }
    }
}
