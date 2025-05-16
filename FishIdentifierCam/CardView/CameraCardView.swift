//
//  CameraCardView.swift
//  FishIdentifierCam
//
//  Created by Andrew Benson on 5/13/25.
//

import Foundation
import UIKit
import SwiftUI
import Capturer

/// Shows a live camera preview in a card format, including a camera
/// shutter bottom centered near the bottom of the view.
///
/// The camera shutter button's action is set by the `.cameraButtonAction`
/// environment value.
struct CameraCardView: View {
    @EnvironmentObject var viewModel: CameraViewModel

    var body: some View {
        CameraPreviewView()
            .aspectRatio(contentMode: .fill)
            .overlay(
                VStack(alignment: .center) {
                    Spacer()
                    CaptureButton()
                        .padding()
                }
            )
    }
}
