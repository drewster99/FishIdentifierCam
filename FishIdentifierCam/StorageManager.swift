import Foundation
import UIKit

// Class to manage photo storage and retrieval
class StorageManager {
    static let shared = StorageManager()
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let photoDirectory: URL
    
    private init() {
        // Get documents directory
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Create a dedicated directory for storing photos
        photoDirectory = documentsDirectory.appendingPathComponent("SavedPhotos", isDirectory: true)
        
        // Ensure the photo directory exists
        try? fileManager.createDirectory(at: photoDirectory, withIntermediateDirectories: true)
    }
    
    // Save a CapturedPhoto to disk
    func savePhoto(_ photo: CapturedPhoto) throws {
        let photoData = try JSONEncoder().encode(photo.metadata)
        let photoFilePath = photoDirectory.appendingPathComponent("\(photo.id).json")
        try photoData.write(to: photoFilePath)
        
        // Save the image separately
        if let imageData = photo.image.jpegData(compressionQuality: 0.8) {
            let imageFilePath = photoDirectory.appendingPathComponent("\(photo.id).jpg")
            try imageData.write(to: imageFilePath)
        } else {
            throw StorageError.imageConversionFailed
        }
    }
    
    // Save an array of CapturedPhotos
    func savePhotos(_ photos: [CapturedPhoto]) {
        for photo in photos {
            do {
                try savePhoto(photo)
            } catch {
                print("Failed to save photo \(photo.id): \(error.localizedDescription)")
            }
        }
    }
    
    // Load all saved photos
    func loadSavedPhotos() -> [CapturedPhoto] {
        var savedPhotos: [CapturedPhoto] = []
        
        do {
            // Get all json files in the photo directory
            let fileURLs = try fileManager.contentsOfDirectory(at: photoDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
            
            for fileURL in fileURLs {
                let photoID = fileURL.deletingPathExtension().lastPathComponent
                
                // Get the corresponding image file
                let imageFileURL = photoDirectory.appendingPathComponent("\(photoID).jpg")
                
                // Check if both metadata and image exist
                if fileManager.fileExists(atPath: imageFileURL.path) {
                    // Load metadata
                    let data = try Data(contentsOf: fileURL)
                    let metadata = try JSONDecoder().decode(PhotoMetadata.self, from: data)
                    
                    // Load image
                    if let imageData = try? Data(contentsOf: imageFileURL),
                       let image = UIImage(data: imageData) {
                        
                        // Create CapturedPhoto from components
                        let photo = CapturedPhoto(
                            image: image,
                            identificationStatus: metadata.identificationStatus,
                            fishData: metadata.fishData,
                            captureDate: metadata.captureDate
                        )
                        
                        savedPhotos.append(photo)
                    }
                }
            }
            
            // Sort photos by capture date, newest first
            savedPhotos.sort { $0.captureDate > $1.captureDate }
            
        } catch {
            print("Error loading saved photos: \(error.localizedDescription)")
        }
        
        return savedPhotos
    }
    
    // Delete a photo
    func deletePhoto(_ photo: CapturedPhoto) throws {
        let photoFilePath = photoDirectory.appendingPathComponent("\(photo.id).json")
        let imageFilePath = photoDirectory.appendingPathComponent("\(photo.id).jpg")
        
        // Remove metadata file
        if fileManager.fileExists(atPath: photoFilePath.path) {
            try fileManager.removeItem(at: photoFilePath)
        }
        
        // Remove image file
        if fileManager.fileExists(atPath: imageFilePath.path) {
            try fileManager.removeItem(at: imageFilePath)
        }
    }
    
    // Storage-related errors
    enum StorageError: Error {
        case imageConversionFailed
    }
} 
