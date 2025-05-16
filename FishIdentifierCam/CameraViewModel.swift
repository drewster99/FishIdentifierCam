//
//  CameraViewModel.swift
//  FishIdentifierCam
//
//  Created by Andrew Benson on 5/13/25.
//

import Foundation
import SwiftUI
import Capturer

@MainActor
final class CameraViewModel: ObservableObject {
    @Published public var isCapturing: Bool = false

    /// Data steam that receives camera preview data
    let previewOutput: PreviewOutput

    /// Data stream that receives photo capture data
    let photoOutput = PhotoOutput()

    /// Session manager for the camera
    let sessionManager = CaptureBody(
        configuration: .init {
            $0.sessionPreset = .photo
        }
    )

    /// `AnyCVPixelBufferOutput` that receives preview output from
    /// the upstream `previewOutput`.
    let output: AnyCVPixelBufferOutput

    /// Initializes a new `CameraViewModel` whch holds state and manages
    /// camera live preview video and photo capture
    public init() {
        let previewOutput = PreviewOutput()
        self.previewOutput = previewOutput
        let output = AnyCVPixelBufferOutput(
            upstream: previewOutput,
            filter: CoreImageFilter(filters: [])
        )
        self.output = output

#if !targetEnvironment(simulator)
        Task {
            let input = CameraInput.wideAngleCamera(position: .back)
            await sessionManager.attach(input: input)
            await sessionManager.attach(output: output)
            await sessionManager.attach(output: photoOutput)
            await sessionManager.start()
        }
#endif
    }

    /// Starts the camera data streams and live preview
    public func startCamera() {
#if !targetEnvironment(simulator)
        Task { await sessionManager.start() }
#endif
    }

    /// Stps the camera data streams and live preview
    public func stopCamera() {
#if !targetEnvironment(simulator)
        Task { await sessionManager.stop() }
#endif
    }


    /// Closre thta'll be called after photo is captured
    private var onPhotoCaptured: ((UIImage) -> Void)?

    /// Captures a photo, calling the given closure when a photo has been captured
    public func capturePhoto(_ onPhotoCaptured: @escaping (_ photo: UIImage) -> Void) {
        isCapturing = true
        self.onPhotoCaptured = onPhotoCaptured
#if targetEnvironment(simulator)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let path = Bundle.main.path(forResource: "imageForSimulator", ofType: "jpg"),
               let imageForSimulator = UIImage(contentsOfFile: path) {
                // use image
                self.onPhotoCaptured?(imageForSimulator)
            } else {
                fatalError("no image for simulator")
            }
            self.isCapturing = false
        }
#else
        let start = Date()
        let captureSettings = AVCapturePhotoSettings()
        //        captureSettings.photoQualityPrioritization = .speed
        captureSettings.isAutoRedEyeReductionEnabled = true
        captureSettings.isAutoVirtualDeviceFusionEnabled = true
        captureSettings.isShutterSoundSuppressionEnabled = true

        photoOutput.capture(with: captureSettings) { [self] result in
            print("Closure return after \(Date().timeIntervalSince(start))")
            switch result {
            case .success(let capturedPhoto):
                guard let imageData = capturedPhoto.photo.fileDataRepresentation(),
                      let image = UIImage(data: imageData) else {
                    fatalError("failed at life")
                }

//                let squareImage = processToSquare(image)
                DispatchQueue.main.async { [self] in
                    self.onPhotoCaptured?(image)
                }
            case .failure(let error):
                fatalError("\(error)")
            }
            self.isCapturing = false
        }
#endif
    }
//
//    /// Returns the given `image` cropped, if needed, to a square `UIImage`
//    private func processToSquare(_ image: UIImage) -> UIImage {
//        let originalSize = image.size
//        let minSize = min(originalSize.width, originalSize.height)
//        let xOffset = (originalSize.width - minSize) / 2
//        let yOffset = (originalSize.height - minSize) / 2
//
//        let cropRect = CGRect(x: xOffset, y: yOffset, width: minSize, height: minSize)
//
//        if let cgImage = image.cgImage?.cropping(to: cropRect) {
//            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
//        }
//
//        return image // Return original if cropping fails
//    }
}
