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

# Build from command line (REQUIRED AFTER EVERY CHANGE)
xcodebuild -project chatstats.xcodeproj -scheme chatstats build

# Run tests (REQUIRED AFTER EVERY CHANGE)
xcodebuild -project chatstats.xcodeproj -scheme chatstats test
```

### 🚨 MANDATORY: Run After Every Code Change
**Claude MUST run these commands after ANY code modification:**
```bash
# 1. ALWAYS build first
xcodebuild -project chatstats.xcodeproj -scheme chatstats build

# 2. ALWAYS run tests
xcodebuild -project chatstats.xcodeproj -scheme chatstats test
```
**If either command fails, the task is NOT complete.**

### Key Development Guidelines

1. **Permissions**: App requires Full Disk Access permission to read iMessage database
2. **SwiftData**: Uses SwiftData for local message storage and caching
3. **SQLite Integration**: Direct SQLite access to read from iMessage database
4. **Async/Await**: Uses modern Swift concurrency throughout
5. **MVVM Pattern**: Follows SwiftUI MVVM architecture with ObservableObject services

## CRITICAL: Build Verification and Feature Validation

### MANDATORY Build Verification Process

**EVERY code change MUST be verified with these steps:**

1. **Build Verification**: Always run the build command after making changes:
   ```bash
   xcodebuild -project chatstats.xcodeproj -scheme chatstats build
   ```
   - The build MUST succeed without errors or warnings
   - If build fails, fix ALL issues before considering the task complete
   - Never commit or push code that fails to build

2. **Syntax and Compilation Check**: Ensure all Swift files compile cleanly:
   ```bash
   # Check for compilation errors across all files
   xcodebuild -project chatstats.xcodeproj -scheme chatstats build -quiet
   ```

3. **Test Execution**: Run all tests to ensure no regressions:
   ```bash
   xcodebuild -project chatstats.xcodeproj -scheme chatstats test
   ```

### Feature Validation Requirements

**For ANY new feature or modification:**

1. **Functional Testing**: Manually verify the feature works as expected
   - Open the app in Xcode and run it
   - Test the specific functionality that was implemented
   - Verify edge cases and error conditions
   - Ensure UI elements respond correctly

2. **Integration Testing**: Verify the feature integrates properly
   - Test with existing features to ensure no conflicts
   - Verify data flow between components
   - Check that SwiftData models work correctly
   - Ensure proper async/await usage

3. **UI/UX Validation**: For UI changes
   - Verify layouts render correctly on different screen sizes
   - Test accessibility features
   - Ensure consistent visual design with existing app
   - Check dark/light mode compatibility

4. **Performance Verification**: Ensure no performance regressions
   - Monitor memory usage during feature operation
   - Check for smooth UI animations and transitions
   - Verify database operations are efficient

### Issue Implementation Checklist

**When implementing GitHub issues:**

- [ ] Read and understand the complete issue requirements
- [ ] Plan implementation approach with TodoWrite tool
- [ ] Implement the feature following existing code patterns
- [ ] Build verification: `xcodebuild -project chatstats.xcodeproj -scheme chatstats build`
- [ ] Manual testing of the implemented feature
- [ ] Verify integration with existing functionality
- [ ] Test edge cases and error scenarios
- [ ] Run full test suite: `xcodebuild -project chatstats.xcodeproj -scheme chatstats test`
- [ ] Document any new functionality or changes
- [ ] Verify the solution meets ALL requirements in the original issue

### Common Build Issues and Solutions

1. **Missing Imports**: Ensure all required frameworks are imported
2. **Type Mismatches**: Check SwiftData model compatibility
3. **Async/Await Issues**: Verify proper Task and async context usage
4. **UI Thread Issues**: Ensure UI updates happen on MainActor
5. **Entitlements**: Verify app entitlements for database access

**CRITICAL: TASK COMPLETION REQUIREMENTS**

🚨 **NO TASK IS COMPLETE UNTIL:**
1. Build passes: `xcodebuild -project chatstats.xcodeproj -scheme chatstats build`
2. Tests pass: `xcodebuild -project chatstats.xcodeproj -scheme chatstats test`
3. Manual verification of implemented functionality

**IF ANY OF THESE FAIL, THE TASK IS NOT DONE. PERIOD.**

### Automated Enforcement

This repository includes:
- **Pre-commit hooks**: Install with `pre-commit install` to automatically run build/test checks
- **GitHub Actions**: Claude Code Review workflow will verify all changes
- **CI Validation**: All PRs must pass build and test checks

```bash
# Install pre-commit hooks (run once)
# Option 1: Using Homebrew (recommended)
brew install pre-commit
pre-commit install

# Option 2: Using Python3 (if available)
python3 -m pip install pre-commit
pre-commit install

# Option 3: Manual validation script (fallback)
# See validate-build.sh in repository root
```

**FAILURE TO FOLLOW THESE GUIDELINES RESULTS IN INCOMPLETE WORK**

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