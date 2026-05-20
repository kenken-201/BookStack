# BookStackプロジェクト主要ディレクトリ構成と設計思想キャッチアップガイド

本書は、Laravel 12で構築されたオープンソースのドキュメント管理プラットフォーム「**BookStack**」の全体像を把握し、短時間でタイパよくキャッチアップするための構成・設計思想の解説書です。

Laravelの一般的な規約と対比させながら、BookStackがどのように独自にカスタマイズ・拡張されているのかを、具体的なコード例や処理フロー図を交えて徹底的に紐解きます。

---

## 1. BookStackのアーキテクチャ全体像と設計思想

一般的なLaravelアプリケーションは、MVC（Model-View-Controller）パターンに沿って、すべてのコントローラーを `app/Http/Controllers/` に、モデルを `app/Models/` に集約するフラットな構造をとります。

しかし、BookStackでは規模の拡大に伴う保守性の低下を防ぐため、**「ドメイン（機能・モジュール）単位」でディレクトリを垂直分割するモジュール設計**を採用しています。

### コアコンセプト：ドメイン駆動なディレクトリ構造
BookStackの心臓部である `app/` 配下を見ると、機能ドメインごとにディレクトリが分かれており、その中にControllerやModel、Repositoryなどがカプセル化されています。

```
app/
├── Entities/       # ブック、章、ページ、本棚などのコア概念
│   ├── Controllers/
│   ├── Models/
│   ├── Repos/
│   └── Queries/
├── Access/         # 認証、ソーシャルログイン、MFA、SAML、OIDC
├── Activity/       # アクティビティログ、コメント、タグ、お気に入り
├── Uploads/        # 画像、添付ファイルのアップロード処理
├── Users/          # ユーザー、ロール、プロフィール、権限管理
└── App/            # アプリケーション基盤、サービスプロバイダ
```

この設計により、「本棚（Shelf）に関するコードを修正・調査したい」ときは `app/Entities` だけを見ればよく、コードの凝集度が高まり、依存関係が非常に整理されています。

---

## 2. 処理フロー：リクエストからレスポンスまで

BookStack内でのデータ処理がどのように流れるかを示すテキストベースのフローチャートです。コントローラーは薄く保たれ、ロジックは「リポジトリ（Repos）」や「クエリ（Queries）」に委譲される設計（リポジトリパターン）になっています。

```
[HTTPリクエスト (例: GET /books/my-book)]
       │
       ▼
[routes/web.php] (ルーティング定義)
       │ 解決
       ▼
[BookStack\Entities\Controllers\BookController@show] (ドメイン内コントローラー)
       │
       │ コンストラクタで自動注入 (DI) されたリポジトリを呼び出し
       ▼
[BookStack\Entities\Repos\BookRepo] (データ操作・ビジネスロジックの抽象化)
       │
       │ データベースとのやり取り
       ▼
[BookStack\Entities\Models\Book] (Eloquentモデル)
       │
       ▼ [データベース (MySQL)] 
       │
       │ データ取得後、コントローラーへ返却
       ▼
[BookStack\Entities\Controllers\BookController]
       │
       │ 描画のためにビューを読み込む
       ▼
[resources/views/books/show.blade.php] (Bladeテンプレート)
       │
       ▼
[HTMLレスポンス (ユーザーのブラウザへ)]
```

---

## 3. 主要ディレクトリ構成とLaravelにおける役割

プロジェクトルート配下の主要ディレクトリの役割と、BookStackにおける独自カスタマイズを解説します。

### ① `app/` （アプリケーションの本体・独自拡張）
BookStackの全ビジネスロジックが詰まった最重要ディレクトリです。前述の通りドメインごとに分割されていますが、特に知っておくべきフォルダを解説します。

*   **`app/App/` (アプリケーション基盤)**:
    アプリケーションのブート処理やグローバルヘルパー（`helpers.php`）を管理します。
    特筆すべきは、Laravelの基本クラスを継承した独自の `Application.php` が定義されている点です。
*   **`app/Config/` (設定ファイル群 - ★独自カスタマイズ★)**:
    通常のLaravelではプロジェクトルート直下に `config/` が存在しますが、BookStackでは `app/Config/` に集約されています。
    これは `app/App/Application.php` で以下のようにLaravelのコアメソッドをオーバーライドすることで実現されています。

#### 💡 コード例: `app/App/Application.php`
```php
<?php

namespace BookStack\App;

class Application extends \Illuminate\Foundation\Application
{
    /**
     * 設定ファイルへのパスを「app/Config」にカスタマイズ
     */
    public function configPath($path = '')
    {
        return $this->basePath
            . DIRECTORY_SEPARATOR . 'app'
            . DIRECTORY_SEPARATOR . 'Config'
            . ($path ? DIRECTORY_SEPARATOR . $path : $path);
    }
}
```
このようにフレームワーク自体をスマートに拡張する手法は、Laravelの柔軟性を活かした上級テクニックであり、キャッチアップにおいて最初に押さえるべきポイントです。

*   **`app/App/Providers/` (サービスプロバイダ)**:
    Laravelアプリケーションの「起動（ブート）処理」を行う登録場所です。
    `AppServiceProvider.php` や `RouteServiceProvider.php` などがあり、依存注入（DI）のバインドや、グローバルなイベント登録、カスタムバリデーションルールの設定などを行います。

---

### ② `bootstrap/` （アプリケーションの起動処理）
Laravelフレームワークの起動処理を行う最小限のコードが含まれます。
*   **`bootstrap/app.php`**:
    アプリケーションインスタンス（`BookStack\App\Application`）を生成し、Laravelの重要な契約（KernelやExceptionHandler）をサービスコンテナにバインドするエントリーポイントです。
*   **`bootstrap/cache/`**:
    パフォーマンス向上のために自動生成されるルートキャッシュやサービスキャッシュが保存されます（本番環境での高速化に寄与）。

---

### ③ `database/` （データベース定義とテストデータ）
データベーススキーマの定義とデータ流し込みに関するディレクトリです。
*   **`database/migrations/`**:
    テーブルの作成やカラム追加など、データベースの構成履歴（スキーマ）をプログラムで記述したファイルです。BookStackには多くの機能追加の歴史があるため、100以上のマイグレーションファイルが存在し、データベース構造の変遷を知る手がかりになります。
*   **`database/seeders/`**:
    データベースの初期データや、開発中に使用するデモデータ（ダミーコンテンツ）を挿入するためのスクリプトです。
*   **`database/factories/`**:
    テスト時やデモデータ生成時に、Eloquentモデルのテスト用データを自動生成するための定義書（Factory）です。

---

### ④ `routes/` （ルーティング定義）
すべてのURLと処理（コントローラー）を結びつけるルーティングマップです。
*   **`routes/web.php`**:
    ブラウザからアクセスするウェブ画面用のルート定義です。BookStackでは、認証保護（`Route::middleware('auth')`）の下に、本棚、ブック、章、ページ、ユーザー管理などのルートがドメインコントローラーに整然とマッピングされています。
*   **`routes/api.php`**:
    APIアクセス用のルーティングです。APIトークンによる認証ルートなどが記述されています。

---

### ⑤ `resources/` & `public/` （フロントエンドと公開アセット）
*   **`resources/views/` (Bladeビューテンプレート)**:
    UIを定義するBladeテンプレート（`.blade.php`）群です。
    `app/` ディレクトリとは異なり、こちらは `books`, `chapters`, `pages`, `auth`, `settings` などのフォルダ名でクラシックに整理されており、HTMLの出力と制御を行います。
*   **`resources/js/` & `resources/sass/`**:
    コンパイル前のJavaScriptおよびスタイルシート（SASS）です。BookStackは `esbuild` や `sass` を使ってこれらをコンパイルします。
*   **`public/` (公開ディレクトリ)**:
    Webサーバー（Nginx等）がドキュメントルートとして直接参照する唯一のディレクトリです。
    `index.php`（すべてのリクエストの受け口）や、コンパイル後のJS/CSS、ファビコンなどの静的ファイルが配置されます。

---

### ⑥ `storage/` （実行時の一時ファイル・ログ）
アプリケーションが動的に出力するログや一時ファイルを格納します。書き込み権限が必要な領域です。
*   **`storage/logs/`**: エラーログ（`laravel.log`）が出力されます。開発・デバッグ時の最重要チェックポイントです。
*   **`storage/framework/`**: セッション情報、コンパイルされたBladeビュー、キャッシュデータなど、Laravelのシステムが高速化のために生成するファイルが格納されます。

---

### ⑦ `themes/` （テーマカスタマイズ用 - ★BookStack特有★）
BookStackはテーマカスタマイズ機能を標準で備えています。
この `themes/` ディレクトリ配下に独自のフォルダを作成することで、デフォルトのビューテンプレート（Blade）や動作をオーバーライドして、BookStackの外観や機能をオリジナルのものへと変更できます。
パッケージそのもののコードを改変せずに独自のカスタムを適用できる、BookStack特有の極めて強力な設計です。

---

## 4. BookStackから学ぶLaravelの実践パターン

キャッチアップ時に意識するとソースコードが驚くほど読みやすくなる、BookStackで多用されているLaravelの実践的なデザインパターンを3つ紹介します。

### A. 依存性注入 (DI: Dependency Injection)
BookStackのコントローラーは、データベース処理を直接書くのではなく、データ操作を担当する「リポジトリ（Repository）」をコンストラクタで受け取ります。
Laravelの「サービスコンテナ」機能により、引数にタイプヒント（型指定）を書いておくだけで、自動的に依存インスタンスが注入されます。

### B. Eloquent ORM（ポリモーフィック関係）
BookStackには「ブック」「章」「ページ」など様々な「エンティティ（Entity）」が存在します。これらに対して、共通で「お気に入り（Favourite）」や「タグ（Tag）」、「アクティビティ（Activity）」を紐付けるために、Laravelの**ポリモーフィック関係（Polymorphic Relations）**が使用されています。
どのテーブルのデータであっても柔軟に関係性を持たせられるLaravelの強力な機能を最大限に活用しています。

### C. リポジトリパターン (Repository Pattern)
ControllerとEloquentモデルの間に「`Repos`（リポジトリ）」レイヤーを挟むことで、データの書き込み（`store`）や更新（`update`）ロジックを共通化しています。
これにより、コントローラーが薄く（Thin Controller）なり、テストが容易で、可読性の高い状態が保たれています。

---

## 5. キャッチアップのための推奨ステップ（タイパ重視）

効率よくコードを理解するために、以下のステップでコードリーディングを進めることをおすすめします。

1.  **`routes/web.php` でルートの流れを把握する**:
    興味のある機能（例: ページの作成 `/books/{bookSlug}/create-page`）がどのコントローラーを呼び出しているか調べる。
2.  **呼び出し先コントローラーの処理を見る**:
    `app/Entities/Controllers/PageController.php` を開き、アクションメソッド（例: `create`）を確認する。
3.  **リポジトリとモデルの関連性を追う**:
    コントローラーが呼び出している `PageRepo` などのロジックを見に行き、実際のデータ保存フローを理解する。
4.  **ビューのレンダリングを確認する**:
    `resources/views/pages/` 配下にある対応するBladeファイルを覗き、フロントエンドへのデータの受け渡し方法を確認する。

このステップで各ドメインを1〜2周なぞるだけで、BookStackの作りとLaravelの主要な作法がスピーディに頭に入り、実務での開発へスムーズにキャッチアップできるはずです！
