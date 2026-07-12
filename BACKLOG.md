# Pigeon Mail — Backlog / To-Do

Working checklist of things to tackle later. Newest priorities from 2026-07-12 at top.
See `PROGRESS.md` for current project state and `FEATURES.md` for what already exists.

---

## Priority items

### 1. iOS app — unblock build & run
- [ ] **Reboot / finish the pending macOS update** to clear the
      `CoreSimulator is out of date` error.
- [ ] Build & run the **SendOnly** target for an iOS simulator/device.
- [ ] Verify the **Lock Screen widget** (`SendOnlyWidget`) and **Share extension**
      (`SendOnlyShare`) work on iOS.
- [ ] Fill in `DEVELOPMENT_TEAM` in `project.yml` (needed for a real device).
- _Note:_ Widget & Share are **iOS-only** extensions; they don't build on macOS.

### 2. Templating system
Let users save and reuse email templates (subject + body, maybe recipients/signature).
- [ ] Decide storage: SwiftData (like `ScheduledEmail`) vs. a JSON file in App Support.
- [ ] Data model: name, subject, markdown body, optional default To/CC/BCC, timestamps.
- [ ] Template picker in the compose window (e.g., a menu/drawer like the Drafts drawer).
- [ ] "Save current message as template" action.
- [ ] Manage templates (rename / edit / delete) — likely a Settings tab.
- [ ] Consider simple placeholders (e.g., `{{name}}`) for later, out of scope for v1.

### 3. Esc-to-close compose with save-draft prompt
- [ ] Bind **Esc** in the compose window to a close action.
- [ ] If there's an in-progress draft (non-empty subject/body/recipients/attachments),
      show a confirmation dialog: **Save Draft / Discard / Cancel**.
- [ ] "Save Draft" uses the existing Gmail draft auto-save path (`DraftManager`).
- [ ] If the message is empty, close immediately with no prompt.
- _Note:_ current behavior — Esc discards the draft (per v1 shortcuts). This changes it
  to a safer save-first flow. Confirm no conflict with the existing Escape binding.

### 4. Make it feel more natively macOS
Audit pass — find where the app diverges from macOS conventions. Candidates to check:
- [ ] Standard **menu bar menus** (App / File / Edit / Window / Help) with proper roles,
      not just the status-item dropdown.
- [ ] Native **window chrome, sizing, and restoration**; proper title bar behavior.
- [ ] System-standard **keyboard shortcuts** and menu-item key equivalents.
- [ ] **Appearance**: respect Light/Dark mode, system accent color, vibrancy/materials.
- [ ] **Text editing niceties**: standard Edit menu (undo/redo, cut/copy/paste, spelling,
      substitutions), services.
- [ ] **Settings** window using the standard Settings scene/style.
- [ ] Notifications, sounds, and Dock/menu-bar behavior consistent with system norms.
- [ ] Accessibility (VoiceOver labels, Full Keyboard Access, Dynamic Type where relevant).
- [ ] Deliver findings as a prioritized list before implementing.

---

## Known smaller items (carried over)
- [ ] **OAuth → production** to stop the 7-day re-login (free; see `PROGRESS.md` §5).
- [ ] Clean up the lone `EmailManager.swift:283` "result of 'try?' is unused" warning.
- [ ] `git rm --cached` the tracked-but-ignored `.DS_Store` / `*.xcuserstate` noise.
- [ ] Distribution: code signing + notarization, DMG, Sparkle auto-updates.

---

_Last updated: 2026-07-12_
