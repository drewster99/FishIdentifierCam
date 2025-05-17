import Cocoa
import Foundation
import CryptoKit

let url = URL(string: "file:///Users/andrew/checkouts/fishial-fish-identification-devapi/fishpic.jpg")!

func md5Base64(ofFileAt url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    let digest = Insecure.MD5.hash(data: data)
    let digestData = Data(digest) // raw 16-byte binary
    return digestData.base64EncodedString()
}

do {
    let md5Base64String = try md5Base64(ofFileAt: url)
    print(md5Base64String)
} catch {
    print("Failed - error: \(error)")
}
