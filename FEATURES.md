# Pigeon Mail

A fast, lightweight macOS menu bar email client for sending emails via Gmail. Pigeon Mail lives in your menu bar and lets you compose and send emails quickly without the overhead of a full email client.

## Core Features

### Menu Bar App
- Lives in your macOS menu bar for quick access
- Minimal footprint - no dock icon, no full window needed
- Custom menu bar icon (pigeon or envelope)

### Email Composition
- Clean, distraction-free compose window
- Support for To, CC, and BCC recipients
- Contact autocomplete from Google Contacts
- Markdown support for rich text formatting
- File attachments
- Custom email signatures

### Undo Send
- Configurable delay (5-30 seconds) before emails are actually sent
- Cancel sending during the countdown to edit or discard
- Visual countdown in menu bar

### Scheduled Emails
- Schedule emails to be sent at a future date/time
- Preset options: Later Today, Tomorrow Morning, Tomorrow Afternoon, Next Week
- Custom date/time picker
- View and cancel pending scheduled emails from menu bar
- Automatic processing every 60 seconds
- Notifications when scheduled emails are sent or fail

### Global Hotkey
- System-wide keyboard shortcut (Cmd+Option+Shift+M) to open compose window
- Works from any application
- Configurable in settings

## Network Resilience

### Automatic Retry
- Failed network requests automatically retry up to 3 times
- Exponential backoff (1s, 2s, 4s delays)
- Retries on network errors and server errors (5xx)
- No retry on authentication or client errors (4xx)

### Offline Queue
- Emails are automatically queued when offline
- Visual indicator in menu bar when emails are queued
- Automatic retry when network connection is restored
- Manual retry and delete options for queued emails
- Tracks attempt count and last error for failed sends

### Network Monitoring
- Real-time network connectivity monitoring
- Automatic detection of WiFi, cellular, and ethernet connections
- Notifications posted when network becomes available

## Smart Contact Search

### Intelligent Matching
- Contacts scored by match quality:
  - Exact match (highest priority)
  - Prefix match (name/email starts with query)
  - Word boundary match ("Jo" matches "John" but not "banjo")
  - Substring match (contains query)

### Recent Contacts
- Recently emailed contacts get priority (+10 score boost)
- Up to 50 recent contacts stored
- Shown first when opening compose window

### Google Contacts Integration
- Fetches contacts from Google People API
- Includes "Other Contacts" (frequently emailed addresses)
- 5-minute cache for performance
- Deduplication by email address

### Google Workspace Directory
- Search coworkers by name in your organization
- Works with Google Workspace/G Suite accounts (e.g., work or school emails)
- Directory results automatically included in contact search
- Requires `directory.readonly` OAuth scope

## Security & Privacy

### OAuth 2.0 Authentication
- Secure Google sign-in with PKCE flow
- Tokens stored in macOS Keychain
- Automatic token refresh
- No passwords stored

### App Sandbox
- Runs in macOS App Sandbox
- Only requests necessary permissions
- Hardened runtime enabled

## Settings

### General
- Menu bar icon style (pigeon/envelope)
- Undo send delay duration
- Send sound toggle with 13 selectable system sounds
- Preview sounds before selecting
- Default email signature
- Launch at login

### Account
- Google account sign-in/sign-out
- OAuth credential configuration

### Shortcuts
- View all keyboard shortcuts
- Re-register global hotkey
- Open accessibility settings

## Technical Details

- Built with SwiftUI and SwiftData
- macOS 14.0+ required
- Uses Gmail API for sending
- Uses Google People API for contacts
- Persistent storage for scheduled and queued emails
