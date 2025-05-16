# FishIdentifierCam Project Specification

## Project Overview
FishIdentifierCam is an iOS app that uses AI to identify fish in photos and provides users with interesting information about the identified species. The app targets primarily iPhones with iPads as a secondary focus, supporting both portrait and landscape orientations.

## Core Features

### Photo Capture & Import
- **Default Format**: Square photos for camera capture
- **Import Support**: Any aspect ratio from user's photo library
- **Display**: Center-cropped in carousel, full photo accessible on tap
- **Storage**: Always store original photos regardless of display format
- **Metadata**: Save date, time, and location (if permissions granted)

### User Interface
- **Main Screen**:
  - Live camera preview (card-style, prominent but not full-screen)
  - Horizontal scrolling carousel of previous photos
  - Camera capture button
  - Photo library import button
  - Settings access (gear icon in top left)

### Fish Identification
- **Process**:
  - Take/select photo → show loading animation → display results
  - Results appear below the selected photo when scrolling stops
  - Return to camera via back gesture/button
- **Results Display**:
  - Scientific and common names
  - Basic species information
  - Option to view detailed information
- **Status Indicators**:
  - Visual indicator on photos showing identification status

### Settings
- Toggle to save/not save photos to user's photo library
- Additional settings to be determined

## Data Model
- Fish identification results based on the provided JSON format
- Photo storage with metadata (date, time, location if available)
- Crop position data for non-square imported photos

## Future Enhancements (Post v1.0)
- Social sharing with customizable text overlay
  - Custom messages
  - Font/color selection
  - Export to photo library or social media
- Crop adjustment for imported photos
- Multi-photo selection from library
- Background processing for multiple photos
- Gallery view for easier browsing of many photos
- Onboarding experience
- Advanced search/filtering of identified fish
- Aspect ratio options for camera capture

## Technical Constraints
- Swift and SwiftUI implementation
- Xcode project format
- iOS target platform
- Portrait mode primary, landscape supported
- Time-to-market priority over feature completeness

## API Integration
- Integration with fish identification API that returns JSON in the format shown in output-final.json
- Species information including:
  - Taxonomy
  - Habitat
  - Physical characteristics
  - Conservation status
  - IGFA records
  - Similar species

## Phase 1 Focus
- Deliver core camera and photo import functionality
- Implement basic fish identification flow
- Create simple, intuitive UI with horizontal photo scrolling
- Focus on quality over quantity of features 