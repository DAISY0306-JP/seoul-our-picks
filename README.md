# SEOUL, OUR PICKS

3人で使うソウル旅行（2026年11月）のしおりアプリです。

このリポジトリにあるのは**ログイン画面だけ**です。旅程・ホテル・お店などの中身は入っていません。中身は Supabase の非公開ストレージ（`trip` バケットの `app.html`）にあります。登録された3人が、自分のIDと合言葉でログインしたときだけ読み込まれます。

## しくみ

```
GitHub Pages（公開）            Supabase（非公開）
index.html ─ ログイン ──▶ Auth（3人だけ・新規登録は止める）
             │
             ├─ app.html を読む ──▶ Storage「trip」（メンバーだけ読める）
             └─ ♡・投票・決定 ───▶ answers / plan テーブル（RLSで3人だけ）
```

- `index.html` に書く Supabase の URL と anon key は、公開しても大丈夫な値です。読み書きできるかどうかは、Supabase の行レベルセキュリティ（RLS）が決めます。
- `members` テーブルに入っている人しか、何も読めません。ログインできるアカウントがあっても同じです。
- 自分の回答は本人しか書き換えられません。決定と旅程の編集は owner だけができます。
- 一度ひらいた旅程は、その端末に保存されます。電波がないときは、保存したものを読み取り専用で開きます。ログアウトすると消えます。

## はじめての設定（1回だけ）

### 1. Supabase（プロジェクト `SEOUL_OUR_PICKS`）

テーブル・RLS・`trip` バケットは作成済みです（`supabase/setup.sql` と同じ内容）。残りはダッシュボードで行います。

1. **Authentication → Sign In / Providers**
   - 「Allow new users to sign up」を **オフ**にします（知らない人がアカウントを作れないようにするため）。
   - Email の「Minimum password length」を **12以上**にします。
2. **Authentication → Users → Add user → Create new user** で3人分作ります。
   - Email：`<ID>@trip.example`（例：`daisy@trip.example`）
   - Password：3人で決めた合言葉（3人とも同じ）
   - 「Auto Confirm User」を **オン**にします。
   - もしメールアドレスが無効と言われたら、本物のメールアドレスで作ってください。その場合は、ログイン画面のIDの欄にメールアドレスをそのまま入れればログインできます。
3. `supabase/members.sql` のメールアドレスと名前を書きかえて、SQL Editor で実行します。いちばん下の確認で3行出れば完了です。
4. **Storage → trip** に `app.html`（別に渡すファイル）をアップロードします。

### 2. GitHub Pages

**Settings → Pages → Build and deployment** で、Source を「Deploy from a branch」、Branch を `main` と `/ (root)` にします。
数分すると `https://<ユーザー名>.github.io/<リポジトリ名>/` で開けるようになります。

## 旅程を更新するとき

Supabase の **Storage → trip** で、`app.html` を新しいものに置きかえます。GitHub 側の変更はいりません。次にアプリを開いたときに反映されます。

## 合言葉を変えたいとき

**Authentication → Users** で3人それぞれのパスワードを変えます。すでにログインしている端末は、そのままログインした状態が続きます。全員を締め出したいときは、ユーザーを削除して作り直してください。

## ファイル

| ファイル | 中身 |
|---|---|
| `index.html` | ログイン画面と、Supabase とのやりとり |
| `supabase/setup.sql` | テーブル・RLS・ストレージの設定 |
| `supabase/members.sql` | 3人をメンバーに登録する SQL のひな形 |

`app.html`（旅程の中身）は `.gitignore` に入れてあり、このリポジトリには入れません。
