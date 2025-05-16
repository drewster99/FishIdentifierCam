//
//  FishInfoView.swift
//  FishIdentifierCam
//
//  Created by Andrew Benson on 5/15/25.
//


import Foundation
import SwiftUI
import UIKit

struct FishInfoView: View {
    let photo: CapturedPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let fishData = photo.fishData {
                Text(fishData.commonName)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(fishData.scientificName)
                    .font(.subheadline)
                    .italic()

                Text("Confidence: \(Int(fishData.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("View Details") {
                    // Detail view action
                }
                .buttonStyle(.bordered)
            } else {
                switch photo.identificationStatus {
                case .notProcessed:
                    Text("Tap to identify")
                case .processing:
                    HStack {
                        ProgressView()
                        Text("Identifying fish...")
                            .padding(.leading, 8)
                    }
                case .failed:
                    Text("Identification failed")
                        .foregroundColor(.red)
                case .identified:
                    Text("No fish identified")
                }
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
}