# 08 - テーブル定義とマイグレーション (Table Definitions & Migrations)

Laravelでは、データベースのテーブル定義やスキーマの変更履歴を **「マイグレーション (Migration)」** という仕組みを用いてプログラムコード（PHP）として記述・管理します。

本稿では、`01-Bookshelf.md` から `07-SearchRunner.md` までのDB操作で登場した主要テーブルが、実際にどのようなLaravelのマイグレーションコードによって定義されているかを整理・解説します。

---

## 1. Laravelにおけるテーブル定義の基本構造

Laravelのマイグレーションファイルは、`database/migrations/` ディレクトリに配置され、クラス内に `up()` と `down()` の2つのメソッドを持ちます。

- **`up()`**: マイグレーション実行時（テーブル作成、カラム追加、インデックス作成など）に呼ばれる処理。
- **`down()`**: マイグレーションのロールバック（テーブル削除、追加したカラムの削除など）に呼ばれる逆処理。

### 基本的な記述パターン

```php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Schema::create で新規テーブルを作成
        Schema::create('table_name', function (Blueprint $table) {
            $table->bigIncrements('id');            // BIGINT AUTO_INCREMENT PRIMARY KEY
            $table->string('name', 100)->index();   // VARCHAR(100) + INDEX
            $table->unsignedInteger('user_id');     // INT UNSIGNED
            $table->timestamps();                   // created_at と updated_at (TIMESTAMP)
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('table_name');
    }
};
```

### 🔑 よく使う Blueprint メソッド早見表

マイグレーションのコードを読む上で、`$table->xxx()` の部分は **Blueprint（設計図）メソッド** と呼ばれます。
主要なものを「生成されるSQL型」と合わせて整理します。

| Blueprint メソッド | 生成される SQL 型 | 説明 |
| :--- | :--- | :--- |
| `increments('id')` | `INT UNSIGNED AUTO_INCREMENT PRIMARY KEY` | 自動増分の主キー |
| `bigIncrements('id')` | `BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY` | 大きな自動増分の主キー |
| `integer('col')` | `INT` | 整数 |
| `unsignedInteger('col')` | `INT UNSIGNED` | 符号なし整数（0以上） |
| `unsignedBigInteger('col')` | `BIGINT UNSIGNED` | 符号なし大整数 |
| `unsignedTinyInteger('col')` | `TINYINT UNSIGNED` | 符号なし小整数（0〜255） |
| `string('col')` | `VARCHAR(255)` | 文字列（デフォルト255文字） |
| `string('col', 100)` | `VARCHAR(100)` | 文字列（長さ指定） |
| `text('col')` | `TEXT` | 長いテキスト（約64KB） |
| `longText('col')` | `LONGTEXT` | 非常に長いテキスト（約4GB） |
| `boolean('col')` | `TINYINT(1)` | 真偽値 |
| `timestamp('col')` | `TIMESTAMP` | 日時 |
| `timestamps()` | `created_at TIMESTAMP, updated_at TIMESTAMP` | 作成日時・更新日時の2カラムを一括追加 |

### 🔗 チェーンメソッド（修飾子）早見表

Blueprint メソッドの後ろに `->nullable()` や `->index()` をつなげて、カラムの制約や振る舞いを追加します。
Kotlinの拡張関数チェーン (`val name = varchar("name", 255).nullable().index()`) と同じ発想です。

| チェーンメソッド | 意味 | 生成される SQL |
| :--- | :--- | :--- |
| `->nullable()` | NULL を許容する | `DEFAULT NULL` |
| `->default(値)` | デフォルト値を設定 | `DEFAULT 値` |
| `->index()` | カラムにインデックスを追加 | `INDEX (col)` |
| `->primary()` | カラムを主キーに指定 | `PRIMARY KEY (col)` |
| `->unsigned()` | 符号なしに変更 | `UNSIGNED` |
| `->change()` | 既存カラムの型変更（ALTER） | `ALTER TABLE ... MODIFY COLUMN ...` |

> [!TIP]
> **Kotlin との対比**: Kotlinで `val name: String?` と書くとNULL許容になるのと同様に、Laravel では `->nullable()` をチェーンすることでNULL許容にします。逆に、チェーンしなければデフォルトでNOT NULL制約がかかります。

---

## 2. 主要テーブルの定義とマイグレーション解説

各SQL学習ファイルで扱った主要なテーブルのマイグレーション定義を見ていきましょう。

> [!IMPORTANT]
> **「初期定義」と「最終形」について**:
> Laravelのマイグレーションは **時系列順** に実行されます。つまり、あるテーブルが最初に `integer` 型で作られた後、後続のマイグレーションで `unsignedBigInteger` に変更されるケースがあります。
> 以下では、各テーブルの **初期定義のコード** を示しつつ、後続マイグレーションで変更された部分は **⚠️ マーク** で注記しています。
> 特に、`2025_09_15_134751_update_entity_relation_columns.php` により、多くのテーブルで `entity_id` 系カラムが `integer` → `unsignedBigInteger` に一括変更されています。

### 🔹 ポリモーフィックリレーションとは？

以下のテーブル定義を読み進める前に、BookStackで頻出する設計パターン **「ポリモーフィックリレーション」** を簡単に理解しておきましょう。

通常のリレーションでは「`book_id` で `books` テーブルを参照する」のように、参照先テーブルが1つに固定されます。
しかし、BookStackでは **1つのタグが、本にも・章にも・ページにも・本棚にも** つけられます。

これを実現するために、「参照先のID」と「参照先のテーブル種別」の **2カラムをセット** で持ちます：

```
tags テーブルの例:
┌────┬───────────┬─────────────┬────────┐
│ id │ entity_id │ entity_type │ name   │
├────┼───────────┼─────────────┼────────┤
│  1 │        10 │ book        │ status │  ← 本 (id=10) のタグ
│  2 │         5 │ page        │ status │  ← ページ (id=5) のタグ
│  3 │        10 │ chapter     │ status │  ← 章 (id=10) のタグ
└────┴───────────┴─────────────┴────────┘
```

Kotlinで言えば、sealed class を使った型安全なUnion型に近い考え方ですが、RDBでは文字列カラムで型を区別するのが一般的です。

---

### ① `entities` / `entity_container_data` / `entity_page_data`
* **対象ファイル**: `01-Bookshelf.md`, `02-Favourite.md`, `03-BaseRepo.md`, `05-migrate_entity_data.md`, `06-TagRepo.md`, `07-SearchRunner.md`
* **マイグレーションファイル**: [`2025_09_15_132850_create_entities_table.php`](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/database/migrations/2025_09_15_132850_create_entities_table.php)

BookStackは、本棚（Shelf）、本（Book）、章（Chapter）、ページ（Page）を総称して「エンティティ (Entity)」と呼びます。かつては `books`, `chapters`, `pages`, `bookshelves` と個別テーブルに分かれていましたが、権限・タグ・検索などの共通処理を効率化するため、2025年のリファクタリングで **`entities`** テーブルにメタデータが集約されました。

#### スキーマ定義コード (PHP)
```php
// --- entities テーブル（全エンティティ共通のメタデータ）---
Schema::create('entities', function (Blueprint $table) {
    $table->bigIncrements('id');                          // 主キーの一部（BIGINT AUTO_INCREMENT）
    $table->string('type', 10)->index();                  // エンティティ種別: 'bookshelf', 'book', 'chapter', 'page'
    $table->string('name');                               // 表示名
    $table->string('slug')->index();                      // URLスラッグ（例: my-first-book）

    // 階層構造を表現するリレーションカラム（page, chapterのみ使用）
    $table->unsignedBigInteger('book_id')->nullable()->index();     // 所属する本のID（章・ページ用）
    $table->unsignedBigInteger('chapter_id')->nullable()->index();  // 所属する章のID（ページ用）
    $table->unsignedInteger('priority')->nullable();                // 並び順

    // タイムスタンプ
    $table->timestamp('created_at')->nullable();
    $table->timestamp('updated_at')->nullable()->index();
    $table->timestamp('deleted_at')->nullable()->index();   // ソフトデリート用（NULLなら未削除）

    // ユーザーリレーション
    $table->unsignedInteger('created_by')->nullable();     // 作成者のユーザーID
    $table->unsignedInteger('updated_by')->nullable();     // 最終更新者のユーザーID
    $table->unsignedInteger('owned_by')->nullable()->index(); // 所有者のユーザーID

    // ★ id と type の複合プライマリキー（通常の単一カラムPKとは異なる）
    $table->primary(['id', 'type'], 'entities_pk');
});

// --- entity_container_data テーブル（本棚・本・章の説明文などのデータ）---
Schema::create('entity_container_data', function (Blueprint $table) {
    $table->unsignedBigInteger('entity_id');                    // entities.id への参照
    $table->string('entity_type', 10);                         // entities.type への参照
    $table->text('description');                                // 説明文（プレーンテキスト）
    $table->text('description_html');                           // 説明文（HTML）

    $table->unsignedBigInteger('default_template_id')->nullable(); // デフォルトページテンプレート
    $table->unsignedInteger('image_id')->nullable();               // カバー画像のID
    $table->unsignedInteger('sort_rule_id')->nullable();           // 並び替えルールのID

    $table->primary(['entity_id', 'entity_type'], 'entity_container_data_pk');
});

// --- entity_page_data テーブル（ページ固有のデータ：本文やエディタ情報）---
Schema::create('entity_page_data', function (Blueprint $table) {
    $table->unsignedBigInteger('page_id')->primary();  // entities.id を参照（1対1）

    $table->boolean('draft')->index();             // 下書きフラグ
    $table->boolean('template')->index();          // テンプレートフラグ
    $table->unsignedInteger('revision_count');      // リビジョン数
    $table->string('editor', 50);                  // 使用エディタ（'wysiwyg', 'markdown' 等）

    $table->longText('html');                      // HTML形式の本文
    $table->longText('text');                      // プレーンテキスト形式の本文（検索用）
    $table->longText('markdown');                   // Markdown形式の本文
});
```

> [!NOTE]
> **設計のポイント: なぜ複合プライマリキー？**
> `entities` テーブルは `id` と `type` の複合プライマリキー (`entities_pk`) を持っています。
> `bigIncrements('id')` は AUTO_INCREMENT を定義しますが、`$table->primary(...)` で複合PKを明示的に上書きしています。
> これにより `WHERE type = 'book' AND id = 42` のようなクエリが高速に解決されます。

> [!NOTE]
> **設計のポイント: テーブルを3つに分けた理由**
> 「全部 `entities` に入れればいいのでは？」と思うかもしれませんが、ページの本文（`longText`）のような巨大なデータと、メタデータ（名前やスラッグ）は **アクセスパターンが異なります**。メタデータの一覧取得時に本文まで読み込む無駄を避けるため、データ種別ごとにテーブルを分離しています。

---

### ② `bookshelves_books` (中間テーブル)
* **対象ファイル**: `01-Bookshelf.md`, `04-DatabaseTransaction.md`
* **マイグレーションファイル**: [`2018_08_04_115700_create_bookshelves_table.php`](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/database/migrations/2018_08_04_115700_create_bookshelves_table.php)

本棚 (Bookshelf) と本 (Book) の「多対多」のリレーションを紐付ける中間（ピボット）テーブルです。

> [!TIP]
> **Kotlinとの対比**: Kotlinの Exposed で多対多リレーションを定義する際も、同じように中間テーブルを作成します。
> ```kotlin
> object BookshelvesBooks : Table("bookshelves_books") {
>     val bookshelfId = reference("bookshelf_id", Entities.id)
>     val bookId = reference("book_id", Entities.id)
>     val order = integer("order")
>     override val primaryKey = PrimaryKey(bookshelfId, bookId)
> }
> ```

#### スキーマ定義コード (PHP) — 初期定義
```php
Schema::create('bookshelves_books', function (Blueprint $table) {
    $table->integer('bookshelf_id')->unsigned();  // ⚠️ 後に unsignedBigInteger に変更
    $table->integer('book_id')->unsigned();       // ⚠️ 後に unsignedBigInteger に変更
    $table->integer('order')->unsigned();          // 本棚の中での並び順

    // 複合プライマリキー（1つの本棚に同じ本は1冊だけ）
    $table->primary(['bookshelf_id', 'book_id']);

    // 外部キー制約（CASCADE: 親が削除されたら中間レコードも削除）
    $table->foreign('bookshelf_id')->references('id')->on('bookshelves')
        ->onUpdate('cascade')->onDelete('cascade');
    $table->foreign('book_id')->references('id')->on('books')
        ->onUpdate('cascade')->onDelete('cascade');
});
```

> ⚠️ `2025_09_15_134751_update_entity_relation_columns.php` により、`bookshelf_id` と `book_id` は `unsignedBigInteger` に変更され、外部キー制約は削除されています（`entities` テーブルへの統合に伴うため）。

---

### ③ `favourites` (お気に入りテーブル)
* **対象ファイル**: `02-Favourite.md`
* **マイグレーションファイル**: [`2021_05_15_173110_create_favourites_table.php`](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/database/migrations/2021_05_15_173110_create_favourites_table.php)

ユーザーがどのエンティティをお気に入りに登録したかを管理するテーブルです。
`favouritable_id` + `favouritable_type` の組み合わせが **ポリモーフィックリレーション** です。

#### スキーマ定義コード (PHP) — 初期定義
```php
Schema::create('favourites', function (Blueprint $table) {
    $table->increments('id');                             // 主キー（INT AUTO_INCREMENT）
    $table->integer('user_id')->index();                  // お気に入りしたユーザーのID
    $table->integer('favouritable_id');                    // ⚠️ 後に unsignedBigInteger に変更
    $table->string('favouritable_type', 100);             // 対象エンティティの種別
    $table->timestamps();                                 // created_at, updated_at

    // 複合インデックスにより「このエンティティはお気に入り済み？」を高速に判定
    $table->index(['favouritable_id', 'favouritable_type'], 'favouritable_index');
});
```

> ⚠️ `2025_09_15_134751_update_entity_relation_columns.php` により、`favouritable_id` は `integer` → `unsignedBigInteger` に変更されています。

---

### ④ `joint_permissions` (権限キャッシュテーブル)
* **対象ファイル**: `02-Favourite.md`
* **マイグレーション履歴**:
  1. [`2016_04_20_... (初期作成)`](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/database/migrations/2016_04_20_192649_create_joint_permissions_table.php) — `id`, `role_id`, `entity_type`, `entity_id`, `action`, `has_permission`, `has_permission_own`, `created_by`
  2. `2020_08_04_... (id カラム削除)` — 複合PKに切り替え
  3. `2022_07_16_... (action カラム削除)` — view権限のみに限定
  4. `2023_01_24_... (リファクタリング)` — `has_permission`/`has_permission_own`/`owned_by` → `status`/`owner_id` に置き換え
  5. `2025_09_15_... (型拡張)` — `entity_id` を `unsignedBigInteger` に変更

BookStackの権限は「ロールごと」「エンティティごと」「自身の所有か否か」など非常に柔軟かつ複雑です。これを実行時に毎回計算するとSQLの結合が膨大になり低速になるため、**計算済みの閲覧権限を高速に引くための専用キャッシュテーブル**として機能します。

#### スキーマ定義コード (PHP) — 最終形（全マイグレーション適用後）
```php
// ★ これは初期定義ではなく、全マイグレーション適用後の「最終的なテーブル構造」を示しています
Schema::create('joint_permissions', function (Blueprint $table) {
    $table->unsignedInteger('role_id');                     // ロールのID
    $table->string('entity_type', 10);                     // エンティティ種別
    $table->unsignedBigInteger('entity_id');                // エンティティのID
    $table->unsignedTinyInteger('status')->index();        // 閲覧許可ステータス (0=不許可, 1=許可 など)
    $table->unsignedInteger('owner_id')->nullable()->index(); // 所有者ID（自分の所有物か判定用）

    // 複合プライマリキーにより高速な権限チェックを実現
    // → WHERE role_id = ? AND entity_type = ? AND entity_id = ? が高速になる
    $table->primary(['role_id', 'entity_type', 'entity_id'], 'joint_primary');
});
```

> [!NOTE]
> **設計のポイント**: このテーブルは「キャッシュ」なので、権限ルールが変わるたびに TRUNCATE → 再構築 (`JointPermissionBuilder::rebuildForAll()`) されます。`02-Favourite.md` ではこのテーブルを JOIN することで「ユーザーが閲覧権限を持つお気に入りだけ」を取得しています。

---

### ⑤ `tags` (タグテーブル)
* **対象ファイル**: `03-BaseRepo.md`, `06-TagRepo.md`
* **マイグレーションファイル**: [`2016_05_06_185215_create_tags_table.php`](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/database/migrations/2016_05_06_185215_create_tags_table.php)

あらゆるエンティティに対して動的にキー・バリュー形式のタグを付与するためのポリモーフィックなテーブルです。

#### スキーマ定義コード (PHP) — 初期定義
```php
Schema::create('tags', function (Blueprint $table) {
    $table->increments('id');                      // 主キー
    $table->integer('entity_id');                   // ⚠️ 後に unsignedBigInteger に変更
    $table->string('entity_type', 100);            // 対象エンティティの種別
    $table->string('name');                         // タグのキー (例: "status", "genre")
    $table->string('value');                        // タグの値 (例: "completed", "sci-fi")
    $table->integer('order');                       // 表示順
    $table->timestamps();                           // created_at, updated_at

    // インデックス：name や value で検索・フィルタリングするため
    $table->index('name');
    $table->index('value');
    $table->index('order');
    // 複合インデックス：特定のエンティティに紐づくタグを高速に取得
    $table->index(['entity_id', 'entity_type']);
});
```

> ⚠️ `2025_09_15_134751_update_entity_relation_columns.php` により、`entity_id` は `integer` → `unsignedBigInteger` に変更されています。

---

### ⑥ `search_terms` (検索用インデックステーブル)
* **対象ファイル**: `03-BaseRepo.md`, `07-SearchRunner.md`
* **マイグレーションファイル**: [`2017_03_19_091553_create_search_index_table.php`](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/database/migrations/2017_03_19_091553_create_search_index_table.php)

RDBMSの種類（MySQL, PostgreSQL, SQLiteなど）に依存せず、安定して高速な全文検索・スコアリング検索を実現するために、単語（Term）単位に分解してスコアをキャッシュしておくインデックステーブルです。

#### スキーマ定義コード (PHP) — 初期定義
```php
Schema::create('search_terms', function (Blueprint $table) {
    $table->increments('id');                      // 主キー
    $table->string('term', 180);                   // 分割された単語 (例: "laravel", "bookstack")
    $table->string('entity_type', 100);            // 対象エンティティの種別
    $table->integer('entity_id');                   // ⚠️ 後に unsignedBigInteger に変更
    $table->integer('score');                       // 出現頻度や重み付けによる算出スコア

    // インデックス定義（カラム定義とは別行で定義するスタイル）
    $table->index('term');
    $table->index('entity_type');
    $table->index(['entity_type', 'entity_id']);
    $table->index('score');
});
```

> [!TIP]
> **`->index()` の2つの書き方**:
> - **インライン**: `$table->string('term', 180)->index()` — カラム定義と同じ行で書く
> - **別行**: `$table->index('term')` — カラム定義の後にまとめて書く
>
> どちらも結果は同じです。このマイグレーションでは別行スタイルが使われています。

> ⚠️ `2025_09_15_134751_update_entity_relation_columns.php` により、`entity_id` は `integer` → `unsignedBigInteger` に変更されています。

---

### ⑦ `comments` (コメントテーブル)
* **対象ファイル**: `07-SearchRunner.md`
* **マイグレーションファイル**: [`2017_08_01_130541_create_comments_table.php`](file:///Users/sasaki/Desktop/progDoc/%E3%83%90%E3%83%83%E3%82%AF%E3%82%A8%E3%83%B3%E3%83%89/BookStack/database/migrations/2017_08_01_130541_create_comments_table.php) (後に `2025_04_18_...` や `2025_10_22_...` で拡張)

ページなどに書き込まれるコメントを格納するテーブルです。`parent_id` による親子関係（返信ツリー）を表現できます。

#### スキーマ定義コード (PHP) — 初期定義
```php
Schema::create('comments', function (Blueprint $table) {
    $table->increments('id')->unsigned();                          // 主キー
    $table->integer('entity_id')->unsigned();                      // ⚠️ 後に unsignedBigInteger に変更
    $table->string('entity_type');                                 // 対象エンティティの種別
    $table->longText('text')->nullable();                          // マークダウン等のプレーンテキスト
    $table->longText('html')->nullable();                          // レンダリングされたHTML
    $table->integer('parent_id')->unsigned()->nullable();          // 返信先コメントのID（NULLならトップレベル）
    $table->integer('local_id')->unsigned()->nullable()->index();  // ページ内での連番ID（#comment-3 のような用途）
    $table->integer('created_by')->unsigned();                     // コメント投稿者のユーザーID
    $table->integer('updated_by')->unsigned()->nullable();         // 最終編集者のユーザーID
    $table->timestamps();                                          // created_at, updated_at

    // 複合インデックス：特定エンティティのコメント一覧を高速に取得
    $table->index(['entity_id', 'entity_type']);
});
```

> ⚠️ `2025_09_15_134751_update_entity_relation_columns.php` により、`entity_id` は `integer` → `unsignedBigInteger` に変更されています。

---

## 3. Kotlin開発者のための対比と解説

Kotlinでバックエンドを開発する場合、データベースの定義方法には大きく分けて2つのアプローチがあります。
1. **コードファースト (Exposed などの ORM による DSL 定義)**
2. **スキーマファースト (Flyway や Liquibase による SQL 定義)**

Laravelのマイグレーションは、記述方法としては **「コードファースト (DSL) 的な記述で、スキーマ移行履歴を管理する」** という、両方の良いとこ取りをした性質を持っています。

### Exposed (Kotlin) とのスキーマ定義比較

Kotlinの人気SQLライブラリである **Exposed** のテーブル定義 DSL と、Laravelの `Blueprint` の書き方を比較してみましょう。

#### 例: `tags` テーブルの定義

| 定義項目 | Laravel (PHP) | JetBrains Exposed (Kotlin) |
| :--- | :--- | :--- |
| **テーブル宣言** | `Schema::create('tags', function (...) { ... })` | `object Tags : Table("tags") { ... }` |
| **自動増分主キー** | `$table->increments('id')` | `val id = integer("id").autoIncrement()` |
| **整数** | `$table->integer('entity_id')` | `val entityId = integer("entity_id")` |
| **文字列 (VARCHAR)** | `$table->string('name')` | `val name = varchar("name", 255)` |
| **インデックス追加** | `$table->index('name')` | `val name = varchar("name", 255).index()` |
| **複合インデックス** | `$table->index(['entity_id', 'entity_type'])` | `init { index(false, entityId, entityType) }` |
| **タイムスタンプ** | `$table->timestamps()` | `val createdAt = datetime("created_at").nullable()` |

#### Exposedでの実際の定義コード例 (Kotlin)
```kotlin
import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.javatime.datetime

object Tags : Table("tags") {
    val id = integer("id").autoIncrement()
    val entityId = integer("entity_id")
    val entityType = varchar("entity_type", 100)
    val name = varchar("name", 255).index()
    val value = varchar("value", 255).index()
    val order = integer("order").index()
    val createdAt = datetime("created_at").nullable()
    val updatedAt = datetime("updated_at").nullable()

    override val primaryKey = PrimaryKey(id)

    init {
        // entity_id と entity_type の複合インデックス
        index(customIndexName = "tags_entity_index", isUnique = false, entityId, entityType)
    }
}
```

### Kotlinにおけるマイグレーションツールとの関係性
Kotlin (Spring Boot / Ktor) で開発する場合、Laravelの `Migration` に最も近い運用ツールは **Flyway** です。

| 比較項目 | Laravel Migration | Flyway (Kotlin) |
| :--- | :--- | :--- |
| **定義方法** | PHP の DSL (`Blueprint`) | 生の SQL ファイル |
| **ファイル名** | `2021_05_15_173110_create_favourites_table.php` | `V1__create_favourites_table.sql` |
| **管理テーブル** | `migrations` テーブル | `flyway_schema_history` テーブル |
| **DB差異の吸収** | Blueprint が自動で SQL 方言を変換 | 自分で SQL を書くため、方言は自己管理 |

Laravelはスキーマ定義自体をDSL（`Blueprint`）で行うため、**DBエンジンごとのSQL構文の違い（MySQLとPostgreSQLでの型名の違いなど）をフレームワークが隠蔽してくれる** というメリットがあり、これがKotlinにおけるExposed等のDSLによる定義手法と非常によく似ています。

---

## 4. テーブル定義を理解してSQLを読み解くメリット

スキーマ定義（マイグレーション）を頭に入れた上で、もう一度 `01-Bookshelf.md` 〜 `07-SearchRunner.md` のSQLを眺めてみてください。

- **なぜインデックスを気にするのか？**
  - マイグレーションで `->index()` や `$table->index(...)` と明示されているカラムが、SQLの `WHERE` や `JOIN` の結合条件 (`ON`) で使われていることが分かります。インデックスがないカラムでの検索は「全レコード総当たり（フルテーブルスキャン）」になるため、パフォーマンスに大きく影響します。
- **なぜ `type` カラムが頻繁に登場するのか？**
  - `entities`, `tags`, `comments`, `favourites` などの多くのテーブルで `entity_type` や `favouritable_type` が定義されています。これは、複数のデータ種別（本、章、ページ）を柔軟に紐付ける **ポリモーフィックリレーション**（冒頭で解説）を実現するための根幹の設計だからです。
- **なぜカラム型が途中で変わるのか？**
  - BookStack は長い歴史を持つプロジェクトです。初期は `integer` で十分だった ID カラムも、データ量の増大や `entities` テーブルへの統合に合わせて `unsignedBigInteger` に変更されました。このように、マイグレーションは **スキーマの進化の記録** でもあります。

テーブル定義という「設計図」を理解することで、生のSQLがなぜそのように組み立てられているのかの「意図」が、より深く・立体的に見えてくるはずです！
