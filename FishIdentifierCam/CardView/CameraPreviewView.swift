//
//  CameraPreviewView.swift
//  FishIdentifierCam
//
//  Created by Andrew Benson on 5/13/25.
//


import Foundation
import SwiftUI
import Capturer
import UIKit
import AVFoundation
import OSLog

/// Shows a live camera preview
struct CameraPreviewView: View {
    @EnvironmentObject var viewModel: CameraViewModel

    var body: some View {
        #if targetEnvironment(simulator)
        Text("No camera access in Simulator")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.green.opacity(0.5))
        #else
        CameraPreviewWrapperView(previewOutput: viewModel.previewOutput)
            .onAppear {
                viewModel.startCamera()
            }
            .onDisappear {
                viewModel.stopCamera()
            }
        #endif
    }
}

/// Wraps a `PixelBufferView` to render the camera preview
///
/// Parameters:
/// - `previewOutput`:     The output receiiving camera preview data stream
///
fileprivate struct CameraPreviewWrapperView: UIViewRepresentable {
    public let previewOutput: PreviewOutput

    func makeUIView(context: Context) -> PixelBufferView {
        let view = PixelBufferView()
        view.attach(output: previewOutput)
        view.contentMode = .scaleAspectFill // Fill the available space
        return view
    }
    
    func updateUIView(_ uiView: PixelBufferView, context: Context) {
        // Nothing to update
    }
}
