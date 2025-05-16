//
//  PhotoCardView.swift
//  FishIdentifierCam
//
//  Created by Andrew Benson on 5/13/25.
//

import Foundation
import UIKit
import SwiftUI

struct PhotoCardView: View {
    let image: UIImage
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)

    }
}
