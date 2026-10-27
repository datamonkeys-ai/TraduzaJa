# TraduzaJa

Select text anywhere on your Mac, press **⌃⇧T**, and it is replaced by the translation. No copy, no paste, no switching windows.

A native macOS menu bar app (SwiftUI). It talks to Claude through [Claude Code](https://claude.com/claude-code) with the login you already have, so there is **no API key** to manage.

## Shortcuts

| Shortcut | What it does |
|---|---|
| **⌃⇧T** | Translate English ↔ your language |
| **⌃⇧G** | Fix grammar and spelling |
| **⌃⇧F** | Make it more formal |
| **⌃⇧C** | Make it more casual |
| **⌃⇧E** | Explain the sentence |

With nothing selected, **G / F / C** act on the line under the cursor.

## It also teaches you

- Every correction shows what was wrong, in a small card at the top of the screen.
- Your mistakes go into a history with a **flashcard review** so you stop repeating them.
- Pick your language and the model (Haiku for speed, Sonnet, Opus) from the menu.
- Translate the clipboard, see the last translation, open at login.
- Private by default: the windows are hidden from screen sharing and screenshots.

## Install

Requirements: macOS 14+, Xcode, [xcodegen](https://github.com/yonaskolb/XcodeGen) and [Claude Code](https://claude.com/claude-code) logged in (`claude` on your PATH).

```sh
git clone https://github.com/datamonkeys/TraduzaJa.git
cd TraduzaJa
make run
```

`make run` builds, installs to `/Applications` and opens the app. The first time, allow TraduzaJa in **System Settings › Privacy & Security › Accessibility** so it can read the selection and paste the result.

## Develop

```sh
make test                      # core tests
TRADUZA_LIVE=1 swift test      # also calls Claude for real
make xcodeproj                 # regenerate the Xcode project from project.yml
```

`Sources/TraduzaCore` holds the translator and history (plain Swift, testable). `Sources/TraduzaJa` holds the menu bar app, hotkeys, selection handling and windows.

## Why

We write in English and Portuguese all day and were tired of the copy, paste, translate, paste back loop. We built this between client projects at [datamonkeys](https://datamonkeys.ai), and it stuck.

## License

MIT
