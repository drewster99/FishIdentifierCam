import Foundation

// Serializable metadata for CapturedPhoto
struct PhotoMetadata: Codable {
    let identificationStatus: CapturedPhoto.IdentificationStatus
    let fishData: FishData?
    let captureDate: Date
    
    // Create metadata from a CapturedPhoto
    static func from(_ photo: CapturedPhoto) -> PhotoMetadata {
        return PhotoMetadata(
            identificationStatus: photo.identificationStatus,
            fishData: photo.fishData,
            captureDate: photo.captureDate
        )
    }
}

// Add a computed property to CapturedPhoto for metadata
extension CapturedPhoto {
    var metadata: PhotoMetadata {
        return PhotoMetadata.from(self)
    }
} 