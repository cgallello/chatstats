# ChatStats

A macOS app for analyzing your iMessage data and viewing message statistics.

## Features

- Import iMessage data from your local database
- View message history with sender information
- Track sent vs received messages
- Clean, modern interface

## Setup Instructions

### 1. Grant Full Disk Access

To import your iMessage data, you need to grant Full Disk Access to the app:

1. Open **System Preferences** (or **System Settings** on newer macOS versions)
2. Go to **Security & Privacy** > **Privacy**
3. Select **Full Disk Access** from the left sidebar
4. Click the lock icon to make changes (enter your password)
5. Click the **+** button and add the ChatStats app
6. Make sure the checkbox next to ChatStats is checked

### 2. Build and Run

1. Open the project in Xcode
2. Build and run the app (⌘+R)
3. Click the "Import Messages" button to import your iMessage data

## How It Works

The app locates your iMessage database at `~/Library/Messages/chat.db` and imports the most recent 1000 messages. The data includes:

- Message text
- Timestamp
- Sender information
- Whether the message was sent or received
- Chat identifier

## Privacy

- All data is stored locally on your device
- No data is transmitted to external servers
- The app only reads your iMessage database, it doesn't modify it

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- Full Disk Access permission

## Troubleshooting

If you encounter issues:

1. **"Could not locate iMessage database"**: Make sure you've granted Full Disk Access as described above
2. **"Import failed"**: Try restarting the app and ensuring Messages app is not actively running
3. **No messages appear**: Check that you have iMessage data in your Messages app

## Development

This app is built with:
- SwiftUI for the user interface
- SwiftData for local data storage
- SQLite for reading the iMessage database 