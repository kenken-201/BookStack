# BookStackキャッチアップ実践ToDoリスト（タイパ重視版）

このToDoリストは、`catch-up/directory-structure-guide.md` の解説をベースに、**「どこから読み始めれば、最も効率よくBookStackとLaravelの設計を理解できるか」**に特化して作成したアクションプランです。

チェックボックス（`[ ]`）を活用して、進捗を管理しながらキャッチアップを進めてみてください！

---

## 📅 フェーズ1：環境と全体構造の把握（目標時間：30分）
まずはシステム全体の構成と、BookStack特有の設定変更について理解します。

- [ ] **1. 全体像の把握**
  - [directory-structure-guide.md](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/catch-up/directory-structure-guide.md) を一通り読み、モジュール（ドメイン）分割の思想を理解する。
- [ ] **2. 独自拡張コードの確認**
  - [app/App/Application.php](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/app/App/Application.php) を開き、設定ファイルのパスを変更している `configPath` メソッドのオーバーライドを確認する。
- [ ] **3. アプリケーション設定の確認**
  - [app/Config/app.php](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/app/Config/app.php) を開き、サービスプロバイダ（`providers`）やタイムゾーン、ロケールの設定を確認する。

---

## 📅 フェーズ2：ルーティングとミドルウェアの把握（目標時間：45分）
リクエストが最初にどこに到達し、どのようなセキュリティフィルタを通過するのかを把握します。

- [ ] **1. ウェブルートの全体像把握**
  - [routes/web.php](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/routes/web.php) を開く。
  - `Route::middleware('auth')->group(...)` で囲まれた「ログイン必須のルート」と、その外にある「ゲスト向けルート」の切り分けを確認する。
- [ ] **2. 主要機能のルートの特定**
  - `web.php` 内で以下のルート定義を探し、呼び出されているコントローラー名を確認する。
    - [ ] ブックの一覧・表示: `/books/`
    - [ ] ページの作成・表示: `/books/{bookSlug}/page/{pageSlug}`
- [ ] **3. ミドルウェアの確認**
  - [app/Http/Kernel.php](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/app/Http/Kernel.php) を開き、`middlewareGroups`（`web` や `api`）にどのミドルウェアが設定されているか確認する（CSRF保護、セッション、MFAなど）。

---

## 📅 フェーズ3：コア機能「ブック（Book）」のソースリーディング（目標時間：90分） ★最重要★
BookStackの最も中心となるドメイン「Entities」のコードを、1本のストーリーに沿って読み解きます。

- [ ] **1. コントローラー層の解読**
  - [app/Entities/Controllers/BookController.php](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/app/Entities/Controllers/BookController.php) を開く。
  - ブック詳細表示メソッドである `show(...)` を見つけ、どのように引数を受け取り、リジトリからデータを取得し、ビューを返しているかを解読する。
- [ ] **2. リポジトリ層（ビジネスロジック）の解読**
  - [app/Entities/Repos/BookRepo.php](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/app/Entities/Repos/BookRepo.php) を開く。
  - `BookController` から呼び出されるメソッド（例: `create`, `update` 等）を探し、バリデーションや関連付け処理がどう共通化されているかを確認する。
- [ ] **3. Eloquentモデルとリレーションの解読**
  - [app/Entities/Models/Book.php](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/app/Entities/Models/Book.php) を開く。
  - ブック（Book）が、章（`chapters`）、ページ（`pages`）、本棚（`shelves`）とどのようにリレーションシップ（`hasMany` や `belongsToMany` 等）を定義しているかを確認する。
- [ ] **4. ビュー（Bladeテンプレート）のレンダリングの確認**
  - [resources/views/books/show.blade.php](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/resources/views/books/show.blade.php) を開く。
  - `BookController` から渡された変数（例: `$book`）が、Blade上でどのようにHTMLとして出力されているか、共通レイアウトがどう使われているかを確認する。

---

## 📅 フェーズ4：認証とセキュリティ（目標時間：60分）
システム開発で避けては通れない「ログイン」「権限」の設計を読み解きます。

- [ ] **1. ログイン・セッション処理の確認**
  - [app/Access/Controllers/LoginController.php](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/app/Access/Controllers/LoginController.php) を開き、ログインフォームの表示 (`getLogin`) と送信 (`login`) の処理の流れを確認する。
- [ ] **2. 権限（パーミッション）チェックの仕組みの把握**
  - `app/Permissions/` ディレクトリを軽く眺め、BookStackがどのようにロールやユーザーに権限を割り当てているかを大枠で理解する。
  - ビュー（Blade）の中でどのように `@can` ディレクティブなどを用いて表示制御をしているか、既存のBladeファイルを検索して確認する。

---

## 📅 フェーズ5：開発の裏方（便利関数とログデバッグ）（目標時間：30分）
実務での実装に入った際に、開発生産性を上げるためのツール・デバッグ手段を整理します。

- [ ] **1. 便利ヘルパー関数の確認**
  - [app/App/helpers.php](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/app/App/helpers.php) を開き、グローバルに使える便利な独自関数（例: 設定取得や権限チェックのショートカットなど）が定義されていないか確認する。
- [ ] **2. デバッグとエラーログの出力場所**
  - `storage/logs/laravel.log` の存在を確認する。
  - コード内で `logger("デバッグ用のメッセージ");` や `Log::info(...)` を記述した際に、ここにどう出力されるかをイメージしておく。

---

## 🚀 キャッチアップを爆速にするコツ（アドバイス）
*   **深追いしすぎない**: 最初のうちは、各処理の細かいバリデーションの正規表現やエスケープ処理などは読み飛ばしてOKです。「**どのクラスがどのクラスを呼び出して、最終的にDBや画面にどう届くか**」という**データの導線（フロー）**を掴むことに集中しましょう。
*   **エディタの「定義元へ移動」を駆使する**: VS CodeやPHPStormなどのエディタを使用している場合、メソッド名の上で `Cmd + クリック`（Mac）をすることで、コントローラーからリポジトリ、モデルへと一瞬でジャンプできます。このToDoに沿ってジャンプしながら読むと、圧倒的にタイパが上がります！


yt-dlp -f 135+140 "https://www.youtube.com/watch?v=vju0ljpNwKA"