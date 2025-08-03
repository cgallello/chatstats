# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ChatStats is a macOS app that analyzes iMessage data and displays message statistics using SwiftUI. The app reads from the local iMessage database (`~/Library/Messages/chat.db`) and provides insights about messaging patterns, group chats, response times, and emoji usage.

## Architecture

### Core Components

- **chatstatsApp.swift**: Main app entry point with SwiftData model container setup
- **ContentView.swift**: Primary UI with comprehensive message analytics and statistics
- **MessageImportService.swift**: Handles SQLite database access and message importing
- **ContactResolver.swift**: Resolves phone numbers/emails to contact names using Contacts framework
- **ChatImageService.swift**: Manages group chat images and profile pictures

### Data Models

- **Message.swift**: Core message model with SwiftData integration
- **Contact.swift**: Contact information model
- **Item.swift**: Legacy model (appears unused)

### UI Components

- **MessagesChartView.swift**: Chart visualizations for message data
- Various inline view components (GroupChatRow, EmojiRow, ConversationRow, MessageRow)

## Development Commands

### Building and Running
```bash
# Open project in Xcode
open chatstats.xcodeproj

# Build from command line
xcodebuild -project chatstats.xcodeproj -scheme chatstats build

# Run tests
xcodebuild -project chatstats.xcodeproj -scheme chatstats test
```

### Key Development Guidelines

1. **Permissions**: App requires Full Disk Access permission to read iMessage database
2. **SwiftData**: Uses SwiftData for local message storage and caching
3. **SQLite Integration**: Direct SQLite access to read from iMessage database
4. **Async/Await**: Uses modern Swift concurrency throughout
5. **MVVM Pattern**: Follows SwiftUI MVVM architecture with ObservableObject services

## Database Schema Understanding

The app reads from Apple's iMessage database with these key tables:
- `message`: Contains message text, timestamps, and metadata
- `handle`: Maps handle IDs to phone numbers/emails
- `chat`: Contains chat identifiers and display names
- `chat_message_join`: Links messages to chats

## Privacy and Security

- All data processing happens locally
- No external network requests
- Requires explicit user permission for disk access
- Only reads from iMessage database, never modifies it

## File Structure Notes

- Main source files are in the root `chatstats/` directory
- Uses standard Xcode project structure
- Assets and entitlements configured for macOS app distribution
- Follows Apple's code signing and sandboxing requirements