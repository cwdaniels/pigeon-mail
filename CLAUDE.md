# Pigeon Mail - Project Status

**Version 3.1** | Last Updated: February 16, 2026

## Overview
Pigeon Mail is a multi-platform (macOS + iOS) email client for sending emails via Gmail. It's a SwiftUI app using SwiftData for persistence. Built with Claude Opus 4.5/4.6. The macOS version runs as a menu bar app; the iOS version is a standard NavigationStack-based app.

## Project Structure

```
SendOnly/
├── SendOnly/
│   ├── SendOnlyApp.swift              # Main app entry point (#if os conditional scenes)
│   ├── Info.plist                     # macOS Info.plist
│   ├── Info-iOS.plist                 # iOS Info.plist (no LSUIElement/NSPrincipalClass)
│   ├── SendOnly.entitlements          # macOS entitlements (includes network.server)
│   ├── SendOnly-iOS.entitlements      # iOS entitlements (no network.server)
│   ├── Views/
│   │   ├── PlatformHelpers.swift      # Cross-platform Color extensions
│   │   ├── SharedComponents.swift     # EmailChip, AttachmentChip, FlowLayout, InsertLinkView
│   │   ├── ComposeView.swift          # macOS email composition UI (#if os(macOS))
│   │   ├── MenuBarView.swift          # macOS menu bar dropdown (#if os(macOS))
│   │   ├── SettingsView.swift         # macOS settings (#if os(macOS))
│   │   ├── iOSMainView.swift          # iOS main navigation view (#if os(iOS))
│   │   ├── iOSComposeView.swift       # iOS Form-based compose (#if os(iOS))
│   │   ├── iOSSettingsView.swift      # iOS settings (#if os(iOS))
│   │   ├── SchedulePickerView.swift   # Shared (cross-platform)
│   │   ├── UndoSendView.swift         # Shared (cross-platform)
│   │   ├── DraftsDrawerView.swift     # Shared (cross-platform)
│   │   └── FavoritesBarView.swift     # Shared (cross-platform)
│   ├── Models/                        # All models are platform-agnostic
│   │   ├── Email.swift
│   │   ├── Contact.swift
│   │   ├── ScheduledEmail.swift
│   │   └── QueuedEmail.swift
│   ├── Services/
│   │   ├── AuthService.swift          # OAuth: macOS=CallbackServer, iOS=ASWebAuthenticationSession
│   │   ├── GmailService.swift         # Platform-agnostic
│   │   ├── PeopleService.swift        # Platform-agnostic
│   │   ├── KeychainService.swift      # macOS=appSupport, iOS=documents dir
│   │   ├── NetworkRetry.swift         # Platform-agnostic
│   │   └── NetworkMonitor.swift       # Platform-agnostic
│   ├── Managers/
│   │   ├── EmailManager.swift         # Shared (uses SoundManager instead of HotkeyManager)
│   │   ├── DraftManager.swift         # Platform-agnostic
│   │   ├── SoundManager.swift         # Cross-platform sound: macOS=system sounds, iOS=haptic
│   │   ├── HotkeyManager.swift        # macOS only (#if os(macOS)) + shared Notification.Name
│   │   ├── OfflineQueueManager.swift  # Platform-agnostic
│   │   ├── FavoritesManager.swift     # Platform-agnostic
│   │   └── AppModeManager.swift       # macOS only (#if os(macOS))
│   └── Resources/
│       ├── Assets.xcassets
│       │   └── AppIcon.appiconset     # Blue bird.fill icon, macOS + iOS universal 1024x1024
│       └── credentials.json
├── SendOnlyWidget/                    # iOS Lock Screen Widget Extension
│   ├── SendOnlyWidget.swift           # Static widget: accessoryCircular + accessoryInline
│   └── Info.plist                     # Widget extension plist
├── SendOnlyShare/                     # iOS Share Extension
│   └── ShareViewController.swift      # Simple compose form for sharing
├── SendOnlyTests/                     # Platform-agnostic tests
│   ├── SendOnlyTests.swift
│   ├── NetworkRetryTests.swift
│   ├── ContactMatchingTests.swift
│   ├── ScheduledEmailTests.swift
│   └── QueuedEmailTests.swift
├── SendOnly.xcodeproj/
├── FEATURES.md
├── README.md
└── CLAUDE.md
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

### AppModeManager (macOS only)
- Uses `NSApp.setActivationPolicy()` for dynamic switching
- `.accessory` = menu bar only (hidden from dock)
- `.regular` = shows in dock (used for "dock" and "both" modes)
- Changes take effect immediately without restart

### System Sound Playback (SoundManager)
- Cross-platform singleton extracted from HotkeyManager
- macOS: loads from `/System/Library/Sounds/`, uses `AudioServicesPlaySystemSound`, sound IDs cached
- iOS: uses system sound ID 1001 + `UINotificationFeedbackGenerator` haptic
- Sound plays immediately when user clicks send (before undo countdown)
- EmailManager now calls `SoundManager.shared.playSendSound()` instead of `HotkeyManager`

### Global Hotkey (macOS only)
- Default: Cmd+Option+Shift+M opens compose window
- Uses Carbon `RegisterEventHotKey` API
- Posts `.openComposeWindow` notification (defined outside `#if os(macOS)` for shared use)
- MenuBarView observes notification and calls `openWindow(id: "compose")`

### iOS Architecture
- **iOSMainView**: NavigationStack with List showing undo status, queued emails, drafts, scheduled emails
- **iOSComposeView**: Form-based layout with inline contact suggestions, keyboard toolbar for formatting
- **iOSSettingsView**: Form with Account, Send Settings, Signature, Favorites, OAuth config, About
- **OAuth on iOS**: Uses `ASWebAuthenticationSession` with custom URL scheme `com.sendonly.app:/oauth2callback`
- **Token storage on iOS**: Uses `documentDirectory` instead of `applicationSupportDirectory`
- **Attachments on iOS**: Uses `.fileImporter` (same as macOS, no NSOpenPanel)
- **Share Extension**: `SendOnlyShare` target with simple compose form, reads tokens from shared keychain
- **Lock Screen Widget**: `SendOnlyWidget` target with `accessoryCircular` (bird icon) and `accessoryInline` families
  - Static widget (no dynamic data), `.never` refresh policy
  - Deep-links to compose via `sendonly://compose` URL scheme
  - Requires `.containerBackground(for: .widget) {}` — iOS 17+ crashes without it
- **Deep Link Handling**: `.onOpenURL` in `SendOnlyApp.swift` posts `.openComposeFromWidget` notification
  - `iOSMainView` receives notification and opens compose sheet

### Platform Compilation Strategy
- `#if os(macOS)` wraps: ComposeView, MenuBarView, SettingsView, HotkeyManager, AppModeManager, CallbackServer
- `#if os(iOS)` wraps: iOSMainView, iOSComposeView, iOSSettingsView, ASWebAuthPresentationContext, ShareViewController
- Shared (no guard): Models, GmailService, PeopleService, NetworkMonitor, NetworkRetry, DraftManager, OfflineQueueManager, FavoritesManager, EmailManager, SoundManager, PlatformHelpers, SharedComponents, SchedulePickerView, UndoSendView, DraftsDrawerView, FavoritesBarView

### Notification Names
- `.openComposeWindow` — macOS global hotkey triggers compose window (HotkeyManager)
- `.openComposeFromWidget` — `sendonly://compose` deep link triggers iOS compose sheet (SendOnlyApp)
- `.networkBecameAvailable` / `.networkBecameUnavailable` — network status changes (NetworkMonitor)
- `.emailQueued` — email added to offline queue (OfflineQueueManager)

### Extension Build Flags
- Both `SendOnlyShare` and `SendOnlyWidget` targets define `SWIFT_ACTIVE_COMPILATION_CONDITIONS: EXTENSION`
- Code guarded with `#if !EXTENSION` (e.g., `UIApplication.shared` in `AuthService.swift`)

## Bundle Identifiers
- App: `com.sendonly.app`
- Tests: `com.sendonly.app.tests`
- Share Extension: `com.sendonly.app.share-extension`
- Widget Extension: `com.sendonly.app.widget`

## Requirements
- macOS 14.0+ / iOS 17.0+
- Xcode 15+
- Google Cloud OAuth credentials

## Recent Changes (Feb 16, 2026) - Version 3.1 (Widget + Icon)
- **Lock Screen Widget**: New `SendOnlyWidget` extension target
  - `accessoryCircular`: bird icon on `AccessoryWidgetBackground`, `.widgetAccentable()`
  - `accessoryInline`: "Compose" label with bird icon
  - Deep-links to compose via `sendonly://compose` URL scheme
  - Static configuration with `.never` refresh policy
- **Deep Link Handling**: `sendonly://` URL scheme (already registered in `Info-iOS.plist`) now handled
  - `.onOpenURL` in `SendOnlyApp.swift` posts `.openComposeFromWidget` notification
  - `iOSMainView` receives notification and opens compose sheet
- **New App Icon**: Replaced cartoon pigeon with blue `bird.fill` SF Symbol
  - AccentColor blue `rgb(0.275, 0.459, 0.898)` on white background
  - Bird sized at 55% of icon dimensions, centered
  - All 10 macOS sizes + iOS 1024x1024 universal regenerated
- **XcodeGen Fixes**:
  - `platform: [macOS, iOS]` updated to `supportedDestinations: [macOS, iOS]` for XcodeGen 2.44 compatibility
  - Merged duplicate `settings:` blocks in `SendOnly` target (YAML was silently discarding the first)
  - Added `PRODUCT_NAME` to extension targets to prevent output path conflicts
  - Added `SWIFT_ACTIVE_COMPILATION_CONDITIONS: EXTENSION` to both extension targets

## Changes (Feb 11, 2026) - Version 3.0 (iOS Port)
- **iOS Support**: Added iPhone destination to the SendOnly target
  - `iOSMainView` with NavigationStack, list of drafts/scheduled/queued emails
  - `iOSComposeView` with Form-based layout, keyboard toolbar, file importer
  - `iOSSettingsView` with Account, Send Settings, Signature, Favorites, OAuth, About
  - `ASWebAuthenticationSession` for OAuth on iOS (replaces local callback server)
  - `SoundManager` cross-platform singleton for send sounds
  - `PlatformHelpers` for cross-platform Color extensions
  - `SharedComponents` for EmailChip, AttachmentChip, FlowLayout, InsertLinkView
  - Share Extension (`SendOnlyShare`) for composing from other apps
- **Platform Guards**: macOS-only views wrapped in `#if os(macOS)`, iOS views in `#if os(iOS)`
- **NSColor removal**: All shared views now use `Color.platformWindowBackground` etc.
- **KeychainService**: iOS uses `documentDirectory` for token file storage
- **AppIcon**: Added iOS universal 1024x1024 entry reusing existing icon
- New files: `Info-iOS.plist`, `SendOnly-iOS.entitlements`

## Changes (Feb 9, 2026) - Version 2.1
- **Bundled OAuth credentials**: `credentials.json` added to app bundle Resources and Xcode project
  - OAuth config now survives app re-signing and sandbox container resets
  - Previously relied on UserDefaults which was lost when code signing identity changed
  - AuthService loads from bundle first, falls back to UserDefaults for manual entry
- **Build/export fix**: App was previously exported as a Debug build with `__preview.dylib` and `SendOnly.debug.dylib` in the bundle, causing Gatekeeper rejection. Future builds should use Product > Archive for proper Release export.

## Changes (Feb 2, 2026) - Version 2.0
- **Favorites Bar**: Quick-access bar in compose window showing top 5 contacts
  - Pin/unpin via context menu, pinned contacts appear first
  - Usage tracked automatically after successful sends
  - Toggle visibility in Settings > General
- **Drafts Drawer**: Slide-out panel to browse Gmail drafts
  - Click document icon in compose header to toggle
  - Select draft to load into compose window
  - Caches drafts, refresh button available
- **App Mode Toggle**: Switch between menu bar, dock, or both
  - Uses `NSApp.setActivationPolicy()` for instant switching
  - No restart required
- **About Tab**: Version info and Claude credits in Settings
- App renamed to "Pigeon 2" in Applications folder

## Security Hardening (Feb 2, 2026)
- Added `.gitignore` to exclude credentials, tokens, xcuserdata, build artifacts
- Removed debug `print()` statements that exposed token paths
- Added `escapeHTML()` function to prevent XSS in markdown-to-HTML conversion
- Note: Internal identifiers remain "SendOnly" for compatibility; user-facing text is "Pigeon Mail"

## GitHub
- **Repo**: https://github.com/cwdaniels/pigeon-mail
- **Website**: https://cwdaniels.github.io/pigeon-mail/ (separate project)
- **Branch**: `feature/v2-enhancements` (default)

## Previous Changes (Jan 2026)
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
