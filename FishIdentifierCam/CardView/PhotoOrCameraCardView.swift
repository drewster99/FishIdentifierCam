//
//  PhotoOrCameraCardView.swift
//  FishIdentifierCam
//
//  Created by Andrew Benson on 5/13/25.
//

import Foundation
import SwiftUI

struct PhotoOrCameraCardView: View {
    let capturedPhoto: CapturedPhoto?

    @EnvironmentObject private var cameraViewModel: CameraViewModel
    @Environment(\.cameraAndPhotoSize) private var cameraAndPhotoSize: CameraAndPhotoSize
    @Namespace private var animation

    var body: some View {
        Group {
            if let capturedPhoto {
                PhotoCardView(image: capturedPhoto.image)
//                    .frame(width: cameraAndPhotoSize.cameraSize.width,
//                           height: cameraAndPhotoSize.cameraSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 23.0, style: .continuous))
//                    .frame(width: cameraAndPhotoSize.photoSize.width,
//                           height: cameraAndPhotoSize.photoSize.height)
                    .transition(.scale)
            } else {
                CameraCardView()
//                    .frame(width: cameraAndPhotoSize.cameraSize.width,
//                           height: cameraAndPhotoSize.cameraSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 23.0, style: .continuous))
                    .transition(.scale)
            }
        }

    }
}

struct CameraAndPhotoSize {
    public let cameraSize: CGSize
    public let photoSize: CGSize
    public let spacing: CGFloat

    public static let `default` = CameraAndPhotoSize(
        cameraSize: CGSize(width: 300,
                           height: 300),
        photoSize: CGSize(width: 250,
                          height: 250),
        spacing: CGFloat(30.0)
    )
}
extension EnvironmentValues {
    @Entry var cameraAndPhotoSize: CameraAndPhotoSize = .default
}


#Preview {
    PhotoOrCameraCardView(capturedPhoto: nil)
}
