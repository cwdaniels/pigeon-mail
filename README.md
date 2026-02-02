# SendOnly

A lightweight macOS menu bar app for writing and sending emails without the distraction of an inbox. Integrates with Gmail for sending, contacts, and draft syncing.

## Features

- **Menu bar app** - Lives in macOS menu bar, click to open compose window
- **Keyboard shortcuts** - Global hotkey (⌘⇧M) to open compose from any app
- **Send emails** - Via Gmail API (no inbox access)
- **Contact autocomplete** - Pull from Gmail contacts via People API
- **Undo send** - Configurable delay (5-30 seconds) before actually sending
- **Schedule send** - Pick date/time, stores locally, sends automatically
- **Draft sync** - Sync drafts to Gmail so they're accessible elsewhere

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Google Cloud project with Gmail API and People API enabled

## Setup

### 1. Create Xcode Project

1. Open Xcode
2. File → New → Project
3. Select **macOS** → **App**
4. Configure:
   - Product Name: `SendOnly`
   - Team: Your Apple Developer account
   - Organization Identifier: `com.sendonly`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **SwiftData**
5. Save in this folder (it's OK to replace files)

### 2. Add Source Files

After creating the project:

1. Delete the auto-generated `ContentView.swift`
2. In Xcode, right-click the `SendOnly` group
3. Select "Add Files to 'SendOnly'..."
4. Add these folders (create groups):
   - `Views/`
   - `Models/`
   - `Services/`
   - `Managers/`
5. Add `Resources/Assets.xcassets`
6. Replace the auto-generated `SendOnlyApp.swift` with the one in this folder

### 3. Configure Build Settings

1. Select the project in the navigator
2. Select the `SendOnly` target
3. **General** tab:
   - Deployment Target: macOS 13.0
4. **Signing & Capabilities** tab:
   - Enable "Keychain Sharing"
   - Add keychain group: `com.sendonly.oauth`
5. **Info** tab (or edit Info.plist):
   - Add `LSUIElement` = `YES` (makes it a menu bar app)
   - Add URL Types:
     - Identifier: `OAuth Callback`
     - URL Schemes: `com.sendonly.app`

### 4. Set Up Google Cloud

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project named "SendOnly"
3. Enable these APIs:
   - Gmail API
   - People API
4. Configure OAuth consent screen:
   - User Type: External (or Internal for Workspace)
   - App name: SendOnly
   - Add scopes:
     - `https://www.googleapis.com/auth/gmail.send`
     - `https://www.googleapis.com/auth/gmail.compose`
     - `https://www.googleapis.com/auth/contacts.readonly`
5. Create OAuth 2.0 credentials:
   - Application type: **Desktop app**
   - Name: SendOnly Desktop
6. Download the credentials JSON

### 5. Add Credentials

**Option A:** Add `credentials.json` to app bundle:
1. Copy the downloaded JSON to `SendOnly/Resources/`
2. Rename to `credentials.json`
3. Add to Xcode project

**Option B:** Enter manually in app:
1. Run the app
2. Go to Settings → Account
3. Enter the Client ID from the downloaded JSON

### 6. Build and Run

1. Build: ⌘B
2. Run: ⌘R
3. Look for the envelope icon in the menu bar
4. Click and sign in with Google

## Usage

### Compose Email
- Click the menu bar icon → "New Message"
- Or press ⌘⇧M from any app (global hotkey)

### Send Email
- Click "Send" or press ⌘Return
- Watch the undo countdown (10 seconds by default)
- Press Escape or click "Undo" to cancel

### Schedule Email
- Click the clock icon in the compose window
- Choose a preset or custom date/time
- Email will send automatically at the scheduled time

### Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open Compose | ⌘⇧M (global) |
| Send Email | ⌘Return |
| Discard | Escape |
| Settings | ⌘, |
| Quit | ⌘Q |

## Privacy

SendOnly only requests the minimum permissions needed:
- `gmail.send` - Send emails on your behalf
- `gmail.compose` - Create and save drafts
- `contacts.readonly` - Read contacts for autocomplete

**We do NOT request:**
- `gmail.readonly` - Cannot read your inbox
- `gmail.modify` - Cannot modify existing emails

## Troubleshooting

### "OAuth not configured"
Add your Google OAuth credentials in Settings → Account, or add `credentials.json` to the app bundle.

### Global hotkey doesn't work
The app needs accessibility permissions:
1. Open System Settings → Privacy & Security → Accessibility
2. Enable SendOnly

### Contacts not loading
Make sure you've authorized the People API scope when signing in. Try signing out and signing back in.

## License

MIT License - see LICENSE file for details.
