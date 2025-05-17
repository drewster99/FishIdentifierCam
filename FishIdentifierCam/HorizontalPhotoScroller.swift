import Foundation
import SwiftUI

struct HorizontalPhotoScroller: View {
    let photos: [CapturedPhoto]
    @Binding var selectedPhoto: CapturedPhoto?
    @Environment(\.cameraAndPhotoSize) private var cameraAndPhotoSize: CameraAndPhotoSize
    @State var idAtCurrentScrollPosition: CapturedPhoto.ID?
    let cameraViewID = CapturedPhoto.cameraViewID

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { scrollProxy in
                LazyHStack(alignment: .center, spacing: cameraAndPhotoSize.spacing) {
                    // Display all captured photos
                    ForEach(photos) { photo in
                        PhotoCardView(image: photo.image)
                            .containerRelativeFrame(.horizontal)
                            .aspectRatio(1.0, contentMode: .fill)
                            .clipped()
                    }

                    // Camera view at the far right
                    CameraCardView()
                        .containerRelativeFrame(.horizontal)
                        .aspectRatio(1.0, contentMode: .fill)
                        .clipped()
                        .overlay(alignment: .bottom, content: {
                                CaptureButton()
                                .padding(.bottom, 15)

                        })
                        .id(cameraViewID)
                }

                .scrollTargetLayout()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
                        // If no photo is selected, ensure camera view is centered
                        if selectedPhoto == nil {
                            print("*** appear - selected = nil")
                            scrollProxy.scrollTo(cameraViewID, anchor: .center)
                        } else if let photo = selectedPhoto {
                            // Ensure the selected photo is centered
                            print("*** appear - selected is photo \(photo.id)")
                            scrollProxy.scrollTo(photo.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .onChange(of: idAtCurrentScrollPosition, initial: true) { old, new in
            guard let id = idAtCurrentScrollPosition else {
                selectedPhoto = nil
                return
            }
            guard id != CapturedPhoto.cameraViewID else {
                selectedPhoto = nil
                return
            }
            selectedPhoto = photos.first(where: { $0.id == id })
        }
        .scrollPosition(id: $idAtCurrentScrollPosition)
        .scrollTargetBehavior(.viewAligned) // Makes the scroll view snap to each item
        .overlay(alignment: .top) {
            Text("\(idAtCurrentScrollPosition ?? "n/a")")
        }
    }
}

// Extension to pass through environment values
extension HorizontalPhotoScroller {
    func onCameraButton(action: @escaping () -> Void) -> some View {
        self.environment(\.cameraButtonAction, action)
    }
}
