<p align="center">
  <img src="docs/icon.png" width="128" alt="SageBar icon">
</p>

<h1 align="center">SageBar</h1>

<p align="center">
  Zhuge Liang, Socrates, Nietzsche and King Sejong take turns reading your Claude Code<br>
  conversations and writing you a morning letter of advice. A macOS menu bar app.
</p>

<p align="center">
  <a href="https://github.com/ReentaKim/SageBar/releases/latest"><img src="https://img.shields.io/github/v/release/ReentaKim/SageBar?label=release" alt="Release"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift 6">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT"></a>
</p>

<p align="center">
  <b>English</b> · <a href="README.ko.md">한국어</a>
</p>

---

> **Note:** The letters are written in Korean. The app UI is Korean-first for now; an English letter option is on the roadmap.

## What it does

Every morning at a time you choose, one of four sages reads **what you actually typed into Claude Code** over the past two weeks and writes two pieces:

| | Part one | Part two |
|---|---|---|
| **Topic** | How to use your AI coding tool better | Direction for your work and life |
| **Grounded in** | Your real prompts and recurring habits | Projects, worries and relationships that surface in your conversations |
| **Length** | ~2,000 chars | ~3,000 chars |

No generic advice. The sage quotes you back to yourself: "you asked the same config question three times this week", "your work is scattered across 26 folders".

## The four sages

<table>
<tr>
<td width="25%" align="center"><b>Zhuge Liang</b><br><sub>Memorial to the throne</sub></td>
<td width="25%" align="center"><b>Socrates</b><br><sub>Dialogue</sub></td>
<td width="25%" align="center"><b>Nietzsche</b><br><sub>Aphorisms</sub></td>
<td width="25%" align="center"><b>King Sejong</b><br><sub>Royal edict</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/zhuge.png" alt="Zhuge Liang"></td>
<td><img src="docs/screenshots/socrates.png" alt="Socrates"></td>
<td><img src="docs/screenshots/nietzsche.png" alt="Nietzsche"></td>
<td><img src="docs/screenshots/sejong.png" alt="King Sejong"></td>
</tr>
<tr>
<td valign="top">Hanji scroll and vermilion seal. A chancellor's <b>blunt counsel</b> to his lord: criticism first, one line of encouragement at the very end.</td>
<td valign="top">Marble and olive. He doesn't answer, he <b>asks</b>. "Do you truly know that?" Midwifery of the mind until you see your own contradiction.</td>
<td valign="top">Black paper, gold leaf. Numbered <b>short aphorisms</b> hammering at complacency. The last one always turns to "then what will you build?"</td>
<td valign="top">Royal teal silk. A wise king who is kind but <b>scolds laziness</b>, writes in plain words, and always checks on your sleep and your family.</td>
</tr>
</table>

By default they **rotate daily**. In Settings you can pin one, randomize, or exclude any of them.

## How it works

1. **Profile (once)** — Reads `~/.claude/projects`, keeps only the text *you* typed, and asks Claude to write a profile of who you are and what you're working on. Refreshed weekly.
2. **Every morning** — 20 minutes before your chosen time (default 07:00) today's letter is pre-generated; at the time, the window opens. If your Mac was asleep, it opens right after you log in. Once a day.
3. **Generation** — profile + last 14 days of your prompts + recently covered topics (to avoid repetition) go into one call to the installed **Claude Code CLI** (`claude -p`). No API key; it uses the session you're already logged into.
4. **No Chinese characters** — all four sages write in pure Hangul. If any slip through, it's logged.

## Install

**Requirements**
- macOS 14 Sonoma or later, Apple Silicon or Intel
- [Claude Code](https://claude.com/claude-code) CLI installed and logged in once from a terminal

**Homebrew (recommended)**
```sh
brew install --cask reentakim/tap/sagebar
```

**Manual**
1. Download `SageBar-x.y.z.dmg` from the [latest release](https://github.com/ReentaKim/SageBar/releases/latest).
2. Drag `SageBar.app` into `Applications`.
3. On first launch macOS may warn about an unidentified developer. **Right-click → Open** once, or run:
   ```sh
   xattr -d com.apple.quarantine /Applications/SageBar.app
   ```
   (The app is ad-hoc signed and not notarized — no paid Apple Developer account. The source is here; build it yourself if you prefer.)

**From source**
```sh
git clone https://github.com/ReentaKim/SageBar.git
cd SageBar
scripts/build-app.sh --single-arch   # → dist/SageBar.app
open dist/SageBar.app
```

## First run

A scroll icon appears in the menu bar and a setup window opens. It checks for the Claude Code CLI and your conversation history; press **Start** to build your profile (2–5 min) and receive the first letter.

## Menu & settings

| Item | What it does |
|---|---|
| Show today's letter | Opens today's letter, generating it first if needed |
| Write anew | Regenerate today with the next sage, or pick one |
| All past letters | Archive with date, sage and subtitle |
| Settings › General | Show time, pre-build lead, length (short/normal/long), model (Opus/Sonnet), launch at login |
| Settings › Sages | Rotate / pin one / random, which sages to include |
| Settings › Advanced | `claude` path override, days of history to use, refresh profile now, open log |

Headless test from a terminal:
```sh
/Applications/SageBar.app/Contents/MacOS/SageBar --generate --persona nietzsche --model sonnet --length short
```

## Data & privacy

| Path | Content | Notes |
|---|---|---|
| `~/.claude/projects/**/*.jsonl` | Claude Code conversation logs | **Read only.** Only `type == "user"` messages you typed yourself; tool-injected content and sidechains are skipped. |
| `~/.claude/plans/*.md` | Plan titles and first paragraphs | Read only |
| `~/Library/Application Support/SageBar/` | Profile, recent excerpts, letters (HTML), raw output, history, logs | All local. Delete with the app if you like. |

- The app itself makes **no network requests**. The only outbound traffic is the single `claude` CLI call to Anthropic, whose prompt contains your profile and recent prompt excerpts — the same kind of content that already goes there when you use Claude Code.
- The profile prompt forbids recording phone numbers, addresses, account numbers and the like, but anything you typed into a conversation may appear in the excerpts. You can open and edit the profile from Settings › Advanced.
- No telemetry, analytics or update checks.

## FAQ

**Can I use it without Claude Code?** Not yet — both the history and the generation come from it. An API-key mode is being considered.

**Letters are too long / short.** Settings › General › Length. Short is ~3,000 chars, long ~7,500.

**The window didn't show this morning.** Check the status line in the menu and the log under Settings › Advanced. If the Mac was asleep at show time, it opens shortly after wake.

**I want another sage.** Add one to `Sources/SageBar/Model/Persona.swift`, plus `Resources/styles/persona-<id>.css` and `Resources/seals/<id>.svg`. PRs welcome.

## License

MIT. The voices of Zhuge Liang, Socrates, Nietzsche and King Sejong are imitations; the content is AI-generated from your own conversations and should not be mistaken for the historical figures' views.
