# Pigeon Mail - Project Status

## Overview
Pigeon Mail is a macOS menu bar email client for sending emails via Gmail. It's a SwiftUI app using SwiftData for persistence.

## Project Structure

```
SendOnly/
├── SendOnly/
│   ├── SendOnlyApp.swift          # Main app entry point, timer for scheduled emails
│   ├── Info.plist
│   ├── SendOnly.entitlements
│   ├── Views/
│   │   ├── ComposeView.swift      # Email composition UI
│   │   ├── MenuBarView.swift      # Menu bar dropdown UI
│   │   ├── SchedulePickerView.swift
│   │   ├── SettingsView.swift
│   │   ├── UndoSendView.swift
│   │   ├── DraftsDrawerView.swift # Slide-out drafts panel
│   │   └── FavoritesBarView.swift # Quick-access favorites bar
│   ├── Models/
│   │   ├── Email.swift            # Email model + EmailSendState enum
│   │   ├── Contact.swift          # Contact model with matchScore()
│   │   ├── ScheduledEmail.swift   # SwiftData model for scheduled emails
│   │   └── QueuedEmail.swift      # SwiftData model for offline queue
│   ├── Services/
│   │   ├── AuthService.swift      # Google OAuth 2.0 with PKCE
│   │   ├── GmailService.swift     # Gmail API for sending
│   │   ├── PeopleService.swift    # Google People API for contacts
│   │   ├── KeychainService.swift  # Secure token storage
│   │   ├── NetworkRetry.swift     # Retry wrapper with exponential backoff
│   │   └── NetworkMonitor.swift   # NWPathMonitor connectivity tracking
│   ├── Managers/
│   │   ├── EmailManager.swift     # Send state, scheduling, offline queue integration
│   │   ├── DraftManager.swift     # Gmail draft management
│   │   ├── HotkeyManager.swift    # Global hotkey registration + system sounds
│   │   ├── OfflineQueueManager.swift  # Offline email queue processing
│   │   ├── FavoritesManager.swift # Favorite contacts with pin/usage tracking
│   │   └── AppModeManager.swift   # Dock/menu bar mode switching
│   └── Resources/
│       └── Assets.xcassets
│           └── AppIcon.appiconset # Custom pigeon app icon
├── SendOnlyTests/
│   ├── SendOnlyTests.swift        # Original tests
│   ├── NetworkRetryTests.swift    # Retry logic tests
│   ├── ContactMatchingTests.swift # Contact scoring tests
│   ├── ScheduledEmailTests.swift  # Scheduled email tests
│   └── QueuedEmailTests.swift     # Queued email tests
├── SendOnly.xcodeproj/
├── FEATURES.md                    # Feature documentation
├── README.md                      # Setup instructions
└── CLAUDE.md                      # This file
```

## Key Technical Details

### SwiftData Models
- `ScheduledEmail` - Emails scheduled for future sending
- `QueuedEmail` - Emails queued due to network failure

### Network Resilience
- `NetworkRetry.swift` defines `RetryableError` protocol and `withRetry()` function
- `GmailError` and `PeopleError` conform to `RetryableError`
- Retry on: network errors, 5xx server errors
- No retry on: auth errors, 4xx client errors
- Exponential backoff: 1s, 2s, 4s (max 3 attempts)

### Offline Queue Flow
1. `EmailManager.actuallySendEmail()` checks `NetworkMonitor.shared.isConnected`
2. If offline, calls `OfflineQueueManager.shared.queueEmail()`
3. Sets `sendState = .queued`
4. `NetworkMonitor` posts `.networkBecameAvailable` notification
5. `OfflineQueueManager` observes notification and calls `processAllPending()`

### Scheduled Email Flow
1. `SendOnlyApp` has 60-second `Timer.publish`
2. Timer triggers `EmailManager.processScheduledEmails()`
3. Fetches due emails where `scheduledDate <= now && status == .pending`
4. Sends via `GmailService.sendEmail()`
5. Posts user notification on success/failure

### Contact Search Scoring
- 4 = exact match
- 3 = prefix match
- 2 = word boundary match
- 1 = substring match
- 0 = no match
- Recent contacts get +10 boost
- Directory results get +5 boost

### Contact Sources
1. Recent contacts (emails you've sent to)
2. Google Workspace Directory (coworkers, requires `directory.readonly` scope)
3. Personal Google Contacts (`/people/me/connections`)
4. Other Contacts (frequently emailed addresses)

### UserDefaults Storage Keys
- `recentEmails` - Recent contacts array (PeopleService)
- `favoriteEmails` - Favorite contacts with pin/usage data (FavoritesManager)
- `showFavoritesBar` - Boolean toggle for favorites bar visibility
- `appMode` - App mode: "menuBar", "dock", or "both"

### AppModeManager
- Uses `NSApp.setActivationPolicy()` for dynamic switching
- `.accessory` = menu bar only (hidden from dock)
- `.regular` = shows in dock (used for "dock" and "both" modes)
- Changes take effect immediately without restart

### System Sound Playback
- Uses `AudioToolbox` framework with `AudioServicesPlaySystemSound`
- Works properly in sandboxed macOS apps
- Sound plays immediately when user clicks send (before undo countdown)
- Selectable from 13 built-in system sounds in Settings
- Sound IDs are cached for performance

### Global Hotkey
- Default: Cmd+Option+Shift+M opens compose window
- Uses Carbon `RegisterEventHotKey` API
- Posts `.openComposeWindow` notification
- MenuBarView observes notification and calls `openWindow(id: "compose")`

## Bundle Identifiers
- App: `com.sendonly.app`
- Tests: `com.sendonly.app.tests`

## Requirements
- macOS 14.0+
- Xcode 15+
- Google Cloud OAuth credentials

## Recent Changes (Jan 2026)
- Added network retry logic with exponential backoff
- Added offline email queuing with auto-retry
- Added scheduled email processing timer (60s interval)
- Added smart contact search with scoring
- Added Google Workspace directory search (finds coworkers by name)
- Added comprehensive test coverage
- Renamed user-facing text from "SendOnly" to "Pigeon Mail"
- Fixed send sound to use AudioToolbox (works in sandbox)
- Added selectable system sounds in Settings
- Sound plays when user clicks send, not after undo countdown
- Added custom pigeon app icon
- Fixed hotkey compose window flashing issue
- Created FEATURES.md documentation
