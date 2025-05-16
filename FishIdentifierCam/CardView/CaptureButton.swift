//
//  CaptureButton.swift
//  FishIdentifierCam
//
//  Created by Andrew Benson on 5/13/25.
//

import Foundation
import SwiftUI
import OSLog

/// Camera capture shutter button
///
/// The button's action runs the closure from the environment value `.cameraButtonAction`
struct CaptureButton: View {
    @Environment(\.cameraButtonAction) private var action: () -> Void

    public var body: some View {
        ZStack {
            Circle()
                .fill(Color.red)
                .frame(width: 70, height: 70)
                .opacity(0.85)

            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 80, height: 80)
                .opacity(0.75)
        }
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: 0.00,
                            maximumDistance: 0.00) {
            // do nothing
        } onPressingChanged: { isPressing in
            if isPressing {
                action()
            }
        }
    }
}

extension EnvironmentValues {
    /// The action to take when the camera's shutter button is activated
    @Entry var cameraButtonAction: () -> Void = {
        Logger(subsystem: "Camera", category: "cameraButtonAction").fault("cameraButtonAction environment value is not set")
#if DEBUG
        fatalError("cameraButtonAction environment value not set")
#endif
    }
}

extension View {
    public func onCameraButton(_ action: @escaping () -> Void) -> some View {
        self
            .environment(\.cameraButtonAction, action)
    }
}
