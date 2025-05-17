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
//        GeometryReader { pr in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
            //            .aspectRatio(contentMode: .fill)
//                .overlay(Text("\(pr.size.width)x\(pr.size.height)"))
//
//        }
    }
}
