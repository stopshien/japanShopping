---
description: 依照專案規則建立 commit
allowed-tools: Bash(git status), Bash(git diff*), Bash(git log*), Bash(git add*), Bash(git commit*), Bash(git branch*)
---

## Task

依照 canonical 規範 `docs/ai/foundation/commit_message_conventions.md`，將當前 staged 檔案建立 commit。

## 步驟

1. 先完整閱讀 `docs/ai/foundation/commit_message_conventions.md`（格式與 emoji 對照表以該檔為準）
2. 執行 `git status` 查看 staged 檔案（若無 staged 檔案，提醒使用者先 `git add`，不要自行 `git add .`）
3. 執行 `git diff --staged` 查看變更內容
4. 依變更內容判斷 emoji 類型
5. 用繁體中文寫出以行為結果為主的描述，指明受影響的畫面或 model
6. 若 staged 內容包含多個不相關的變更，先向使用者說明並建議拆成多個 commit
7. 組出完整訊息並 commit

## 注意事項

- 若變更包含敏感檔案（.env、credentials、憑證、API key），先警告使用者再繼續
- 若 staged 內容包含 `xcuserdata/` 等個人 Xcode 設定，提醒使用者這通常不該進版控
- 描述只包含變更內容，不加任何額外標記
