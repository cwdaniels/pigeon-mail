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

### 5. Priority "peek" inbox (research / feasibility first)
Idea: a lightweight, read-only view of the **most recent important messages** — a
quick peek, not a full inbox — that surfaces what matters and hides
newsletters/promotions.

- [ ] **Design decision first:** this reverses Pigeon's founding "send-only, no
      inbox, no distraction" premise. Decide how far to go — a tiny "recent &
      important" glance vs. a real reading surface — before building.
- [ ] **Gmail is the realistic data source.** Gmail already does the sorting for us
      via the API:
  - Filter by the built-in category labels — `CATEGORY_PROMOTIONS`,
    `CATEGORY_SOCIAL`, `CATEGORY_UPDATES`, `CATEGORY_FORUMS`, `CATEGORY_PERSONAL`.
  - Lean on Gmail's own priority guess: the `IMPORTANT` label + `is:important` /
    `in:inbox category:primary` search queries via `messages.list`.
  - So "important inbox" ≈ *Primary + IMPORTANT, minus Promotions/Social*. No custom
    ML needed — reuse Gmail's smart mailboxes.
- [ ] **⚠️ Cost/scope implication (important):** reading messages needs a Gmail
      **read** scope (`gmail.readonly` or `gmail.modify`). Google classifies these as
      **restricted**, a stricter tier than Pigeon's current *sensitive* scopes. In
      production that path can require the **paid annual CASA security assessment** —
      the cost we specifically avoided (see `PROGRESS.md` §5). Confirm this before
      committing; it may be the deciding factor.
- [ ] **Apple Mail is not a good source.** No clean public API for third-party apps to
      read its smart mailboxes; would mean fragile AppleScript or poking at local Mail
      data. Skip in favor of the Gmail API.
- [ ] Open questions: read-only or allow archive/mark-read (changes scope + risk)?
      How many messages / how far back? Refresh cadence & caching? Where does it live
      (menu-bar dropdown section vs. separate window vs. iOS tab)? Does an inbox dilute
      the product's identity?
- [ ] Suggested next step: a small spike — list Primary+Important, excluding
      Promotions/Social — to see how good Gmail's own sorting feels in practice before
      any real UI work.

---

## Known smaller items (carried over)
- [ ] **OAuth → production** to stop the 7-day re-login (free; see `PROGRESS.md` §5).
- [ ] Clean up the lone `EmailManager.swift:283` "result of 'try?' is unused" warning.
- [ ] `git rm --cached` the tracked-but-ignored `.DS_Store` / `*.xcuserstate` noise.
- [ ] Distribution: code signing + notarization, DMG, Sparkle auto-updates.

---

_Last updated: 2026-07-12_
