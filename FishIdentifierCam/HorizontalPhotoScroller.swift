import Foundation
import SwiftUI

struct HorizontalPhotoScroller: View {
    let photos: [CapturedPhoto]
    @Binding var selectedPhoto: CapturedPhoto?
    @Environment(\.cameraAndPhotoSize) private var cameraAndPhotoSize: CameraAndPhotoSize
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { scrollProxy in
                LazyHStack(alignment: .center, spacing: cameraAndPhotoSize.spacing) {
                    // Display all captured photos
                    ForEach(photos) { photo in
                        PhotoCardView(image: photo.image)
                            .aspectRatio(1.0, contentMode: .fill)
                            .containerRelativeFrame(.horizontal)
//                            .containerRelativeFrame(.horizontal, alignment: .center) { width, _ in
//                                width - (cameraAndPhotoSize.spacing / 2.0)
//                            }
//                            .containerRelativeFrame([.vertical], alignment: .top) { height, _ in height * 0.60 }
//                            .containerRelativeFrame([.horizontal], alignment: .top) { width, _ in
//                                width - (cameraAndPhotoSize.spacing / 2.0)
//                            }
//                            .containerRelativeFrame(.horizontal, count: 5, span: 4)
                            .clipped()
                            .id(photo.id)
                    }

                    // Camera view at the far right
                    CameraCardView()
                        .aspectRatio(1.0, contentMode: .fill)
                        .containerRelativeFrame(.horizontal)
//                        .containerRelativeFrame(.horizontal, alignment: .center) { width, _ in
//                            width - (cameraAndPhotoSize.spacing / 2.0)
//                        }
//                        .containerRelativeFrame([.vertical], alignment: .top) { height, _ in height * 0.60 }
//                        .containerRelativeFrame([.horizontal], alignment: .top) { width, _ in
//                            width - (cameraAndPhotoSize.spacing / 2.0)
//                        }
                        .clipped()
                        .id("camera")
                }
                .scrollTargetLayout()
                .onAppear {
                    // If no photo is selected, ensure camera view is centered
                    if selectedPhoto == nil {
                        scrollProxy.scrollTo("camera", anchor: .center)
                    } else if let photo = selectedPhoto {
                        // Ensure the selected photo is centered
                        scrollProxy.scrollTo(photo.id, anchor: .center)
                    }
                }
            }
        }
//        .safeAreaPadding(cameraAndPhotoSize.spacing)
        .scrollTargetBehavior(.viewAligned) // Makes the scroll view snap to each item
//        .contentMargins(.horizontal, cameraAndPhotoSize.spacing*3)
    }
}

// Extension to pass through environment values
extension HorizontalPhotoScroller {
    func onCameraButton(action: @escaping () -> Void) -> some View {
        self.environment(\.cameraButtonAction, action)
    }
} 
