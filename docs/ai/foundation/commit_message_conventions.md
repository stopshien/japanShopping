# Commit Message Conventions

Use these rules whenever writing or proposing a git commit message in this repository.

## Format

```text
<emoji> <描述>
```

- Write the summary (`<描述>`) in Traditional Chinese, concise and outcome-focused.
- One line. Add a body only when the reason for the change is not obvious from the summary.
- Describe the behavior change, not the list of touched files.

## Emoji Table

| Emoji | Type |
|-------|------|
| ✨ | New feature |
| 🐛 | Bug fix |
| ♻️ | Refactor |
| 💄 | UI / layout adjustment |
| 🔧 | Configuration or Xcode project change |
| 📝 | Documentation |
| 🗑️ | Removal |
| ⬆️ | Dependency or toolchain upgrade |

## Quality Bar

- Keep each commit focused on one reviewable goal.
- Avoid vague summaries such as `修正問題`, `調整邏輯`, or `更新程式碼`.
- Name the screen or model the change affects when it makes the summary clearer.
- Never silently bundle unrelated changes under one message; split the commit instead.

## History Note

Commits before this convention was adopted use a plain Traditional Chinese summary with no emoji (for example `完成即時匯率ＡＰＩ下載，並顯示匯率更新時間`). Do not rewrite that history; apply the emoji prefix from the adopting commit onward.

## Examples

```text
✨ 新增信用卡回饋上限提醒
```

```text
🐛 修正清單為空時計算總金額會崩潰的問題
```

```text
♻️ 將匯率下載邏輯抽離 ComputeViewController
```
