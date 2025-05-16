//
//  ContentView.swift
//  FishIdentifierCam
//
//  Created by Andrew Benson on 5/13/25.
//

import Foundation
import SwiftUI
import UIKit
import PhotosUI

struct ContentView: View {
    // State to track captured photos
    @State private var capturedPhotos: [CapturedPhoto] = []
    @State private var selectedPhoto: CapturedPhoto?
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var isPresentingPhotosPicker = false
    @State private var pickedPhotoItems: [PhotosPickerItem] = []

    private func sizesFor() ->  CameraAndPhotoSize {
        let spacing: CGFloat = 30.0
        let width = 318.0
        let height = 424.0

        return CameraAndPhotoSize(
            cameraSize: CGSize(width: width, height: height),
            photoSize: CGSize(width: width * 0.8, height: height * 0.8),
            spacing: spacing
        )
    }

    var body: some View {
        VStack {
            // Settings button
            HStack {
                Button(action: {
                    // Settings action will go here
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 22))
                        .foregroundColor(.primary)
                }

                Spacer()

                Button(action: {
                    // Photo library import action
                }) {
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundColor(.primary)
                }
            }
            .padding()

            Spacer()
            // Main photo scroller with camera view
            HorizontalPhotoScroller(
                photos: capturedPhotos,
                selectedPhoto: $selectedPhoto
            )
            .frame(maxHeight: 400.0)
            .environment(\.cameraAndPhotoSize, sizesFor())

            .onCameraButton {
                print("Camera button tap")
                cameraViewModel.capturePhoto { photo in
                    print("photo captured")
                    let newPhoto = CapturedPhoto(id: UUID(),
                                                 image: photo,
                                                 identificationStatus: .notProcessed,
                                                 fishData: nil)
                    withAnimation {
                        capturedPhotos.append(newPhoto)
                        selectedPhoto = newPhoto
                    }
                }
            }
            Spacer()
        }
        .sheet(isPresented: $isPresentingPhotosPicker, onDismiss: {
            // on dismiss

            for item in pickedPhotoItems {
                item.loadTransferable(type: Image.self) { result in
                    DispatchQueue.main.async {
                        //                        guard imageSelection == self.imageSelection else { return }
                        switch result {
                        case .success(let image?):
                            // Handle the success case with the image.
                            capturedPhotos.append(
                                CapturedPhoto(
                                    id: UUID(),
                                    image: UIImage(),
                                    identificationStatus: .notProcessed,
                                    fishData: nil
                                )
                            )
                        case .success(nil):
                            // Handle the success case with an empty value.
                            fatalError("success but nothing?")
                        case .failure(let error):
                            // Handle the failure case with the provided error.
                            fatalError("really fatal: \(error)")
                        }
                    }
                }
            }
        }, content: {
            PhotosPicker("Pick photos",
                         selection: $pickedPhotoItems,
                         maxSelectionCount: nil,
                         selectionBehavior: .default,
                         matching: .any(of: [.images]),
                         preferredItemEncoding: .automatic)
        })
        .ignoresSafeArea()
        .environmentObject(cameraViewModel)
    }
}

// Model to represent a captured photo with identification status
struct CapturedPhoto: Identifiable {
    var id = UUID()
    var image: UIImage
    var identificationStatus: IdentificationStatus = .notProcessed
    var fishData: FishData? = nil

    enum IdentificationStatus {
        case notProcessed
        case processing
        case identified
        case failed
    }
}

// Simple fish data model (will be expanded based on the API response)
struct FishData {
    var scientificName: String
    var commonName: String
    var confidence: Double
}
//
//// Thumbnail view for the carousel
//struct ThumbnailView: View {
//    let photo: CapturedPhoto
//    let isSelected: Bool
//
//    var body: some View {
//        ZStack(alignment: .topTrailing) {
//            // Display the image as square (center-cropped) in the thumbnail
//            Image(uiImage: photo.image)
//                .resizable()
//                .scaledToFill()
//                .frame(width: 80, height: 80)
//                .clipShape(RoundedRectangle(cornerRadius: 10))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 10)
//                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
//                )
//
//            // Status indicator
//            statusIcon
//                .padding(5)
//        }
//    }
//
//    var statusIcon: some View {
//        Group {
//            switch photo.identificationStatus {
//            case .notProcessed:
//                Image(systemName: "questionmark.circle.fill")
//                    .foregroundColor(.gray)
//            case .processing:
//                Image(systemName: "clock.fill")
//                    .foregroundColor(.yellow)
//            case .identified:
//                Image(systemName: "checkmark.circle.fill")
//                    .foregroundColor(.green)
//            case .failed:
//                Image(systemName: "xmark.circle.fill")
//                    .foregroundColor(.red)
//            }
//        }
//        .font(.system(size: 18))
//        .background(Circle().fill(Color.white).frame(width: 16, height: 16))
//    }
//}
//
//// Simple placeholder for fish information view
//

#Preview {
    ContentView()
}
