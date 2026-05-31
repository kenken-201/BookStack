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

---

## 2. 主要テーブル의 定義とマイグレーション解説

各SQL学習ファイルで扱った主要なテーブルのマイグレーション定義を見ていきましょう。

### ① `entities` / `entity_container_data` / `entity_page_data`
* **対象ファイル**: `01-Bookshelf.md`, `02-Favourite.md`, `03-BaseRepo.md`, `05-migrate_entity_data.md`, `06-TagRepo.md`, `07-SearchRunner.md`
* **マイグレーションファイル**: `2025_09_15_132850_create_entities_table.php`

BookStackは、本棚（Shelf）、本（Book）、章（Chapter）、ページ（Page）を総称して「エンティティ (Entity)」と呼びます。かつては個別のテーブルに分かれていましたが、共通のカラムやポリモーフィックな権限・タグ管理を高速化するため、**`entities`** テーブルにメタデータが集約されました。

#### スキーマ定義コード (PHP)
```php
Schema::create('entities', function (Blueprint $table) {
    $table->bigIncrements('id');
    $table->string('type', 10)->index(); // 'bookshelf', 'book', 'chapter', 'page'
    $table->string('name');
    $table->string('slug')->index();

    $table->unsignedBigInteger('book_id')->nullable()->index();
    $table->unsignedBigInteger('chapter_id')->nullable()->index();
    $table->unsignedInteger('priority')->nullable();

    $table->timestamp('created_at')->nullable();
    $table->timestamp('updated_at')->nullable()->index();
    $table->timestamp('deleted_at')->nullable()->index();

    $table->unsignedInteger('created_by')->nullable();
    $table->unsignedInteger('updated_by')->nullable();
    $table->unsignedInteger('owned_by')->nullable()->index();

    // id と type の複合プライマリキー
    $table->primary(['id', 'type'], 'entities_pk');
});

// 本棚や本、章のテキスト説明などのデータ用
Schema::create('entity_container_data', function (Blueprint $table) {
    $table->unsignedBigInteger('entity_id');
    $table->string('entity_type', 10);
    $table->text('description');
    $table->text('description_html');

    $table->unsignedBigInteger('default_template_id')->nullable();
    $table->unsignedInteger('image_id')->nullable();
    $table->unsignedInteger('sort_rule_id')->nullable();

    $table->primary(['entity_id', 'entity_type'], 'entity_container_data_pk');
});

// ページの本文やエディタ情報など、ページ特有のデータ用
Schema::create('entity_page_data', function (Blueprint $table) {
    $table->unsignedBigInteger('page_id')->primary();

    $table->boolean('draft')->index();
    $table->boolean('template')->index();
    $table->unsignedInteger('revision_count');
    $table->string('editor', 50);

    $table->longText('html');
    $table->longText('text');
    $table->longText('markdown');
});
```

> [!NOTE]
> **設計のポイント**: `entities` テーブルは `id` と `type` の複合プライマリキー (`entities_pk`) を持っています。これにより、異なるエンティティ（例: `id = 1` の本と `id = 1` のページ）が同じ `entities` テーブル内で共存でき、かつポリモーフィックなリレーションが高速に引けるよう設計されています。

---

### ② `bookshelves_books` (中間テーブル)
* **対象ファイル**: `01-Bookshelf.md`, `04-DatabaseTransaction.md`
* **マイグレーションファイル**: `2018_08_04_115700_create_bookshelves_table.php` (後に `2025_09_15_134751_update_entity_relation_columns.php` で拡張)

本棚 (Bookshelf) と本 (Book) の「多対多」のリレーションを紐付ける中間（ピボット）テーブルです。

#### スキーマ定義コード (PHP)
```php
Schema::create('bookshelves_books', function (Blueprint $table) {
    // 2025_09_15のマイグレーションにより、両カラムは unsignedBigInteger に拡張されています
    $table->unsignedBigInteger('bookshelf_id');
    $table->unsignedBigInteger('book_id');
    $table->unsignedInteger('order'); // 本棚の中での並び順

    // 複合プライマリキー
    $table->primary(['bookshelf_id', 'book_id']);
});
```

---

### ③ `favourites` (お気に入りテーブル)
* **対象ファイル**: `02-Favourite.md`
* **マイグレーションファイル**: `2021_05_15_173110_create_favourites_table.php`

ユーザーがどのエンティティをお気に入りに登録したかを管理するテーブルです。

#### スキーマ定義コード (PHP)
```php
Schema::create('favourites', function (Blueprint $table) {
    $table->increments('id');
    $table->integer('user_id')->index();
    $table->unsignedBigInteger('favouritable_id');     // 対象エンティティのID
    $table->string('favouritable_type', 100);          // 対象エンティティのモデルクラス名
    $table->timestamps();

    // 複合インデックスを貼ることで、特定モデルのお気に入り判定を高速化
    $table->index(['favouritable_id', 'favouritable_type'], 'favouritable_index');
});
```

---

### ④ `joint_permissions` (権限キャッシュテーブル)
* **対象ファイル**: `02-Favourite.md`
* **マイグレーションファイル**: `2016_04_20_192649_create_joint_permissions_table.php` (累次のスキーマ変更を経て、`2023_01_24_104625_refactor_joint_permissions_storage.php` および `2025_09_15_134751_update_entity_relation_columns.php` にて最終形へ)

BookStackの権限は「ロールごと」「エンティティごと（本・章・ページ・本棚）」「自身の所有か否か」など非常に柔軟かつ複雑です。これを実行時に毎回計算するとSQLの結合が極大化し低速になるため、**計算済みの閲覧権限を高速に引くための専用キャッシュテーブル**として機能します。

#### スキーマ定義コード (PHP) - 最終形
```php
Schema::create('joint_permissions', function (Blueprint $table) {
    $table->unsignedInteger('role_id');
    $table->string('entity_type', 10);
    $table->unsignedBigInteger('entity_id');
    $table->unsignedTinyInteger('status')->index();     // 閲覧許可ステータス
    $table->unsignedInteger('owner_id')->nullable()->index(); // 所有者ID

    // 複合プライマリキーによる高速シーク
    $table->primary(['role_id', 'entity_type', 'entity_id'], 'joint_primary');
});
```

---

### ⑤ `tags` (タグテーブル)
* **対象ファイル**: `03-BaseRepo.md`, `06-TagRepo.md`
* **マイグレーションファイル**: `2016_05_06_185215_create_tags_table.php`

あらゆるエンティティに対して動的にキー・バリュー形式のタグを付与するためのポリモーフィックなテーブルです。

#### スキーマ定義コード (PHP)
```php
Schema::create('tags', function (Blueprint $table) {
    $table->increments('id');
    $table->unsignedBigInteger('entity_id');    // 対象エンティティのID
    $table->string('entity_type', 100);         // 対象エンティティのタイプ
    $table->string('name')->index();            // タグのキー (例: "status")
    $table->string('value')->index();           // タグの値 (例: "completed")
    $table->integer('order')->index();          // 表示順
    $table->timestamps();

    // 複合インデックスにより特定のエンティティに紐づくタグを高速に取得
    $table->index(['entity_id', 'entity_type']);
});
```

---

### ⑥ `search_terms` (検索用インデックステーブル)
* **対象ファイル**: `03-BaseRepo.md`, `07-SearchRunner.md`
* **マイグレーションファイル**: `2017_03_19_091553_create_search_index_table.php`

RDBMSの種類（MySQL, PostgreSQL, SQLiteなど）に依存せず、安定して高速な全文検索・スコアリング検索を実現するために、単語（Term）単位に分解してスコアをキャッシュしておくインデックステーブルです。

#### スキーマ定義コード (PHP)
```php
Schema::create('search_terms', function (Blueprint $table) {
    $table->increments('id');
    $table->string('term', 180)->index();       // 分割された単語
    $table->string('entity_type', 100);
    $table->unsignedBigInteger('entity_id');
    $table->integer('score')->index();          // 出現頻度や重み付けによる算出スコア

    $table->index('entity_type');
    $table->index(['entity_type', 'entity_id']);
});
```

---

### ⑦ `comments` (コメントテーブル)
* **対象ファイル**: `07-SearchRunner.md`
* **マイグレーションファイル**: `2017_08_01_130541_create_comments_table.php` (後に `2025_10_22_134507_update_comments_relation_field_names.php` などで拡張)

ページなどに書き込まれるコメントを格納するテーブルです。親子関係（返信）やリビジョンとの紐付けなども考慮されています。

#### スキーマ定義コード (PHP)
```php
Schema::create('comments', function (Blueprint $table) {
    $table->increments('id')->unsigned();
    $table->unsignedBigInteger('entity_id');    // 対象エンティティ(基本はページ)のID
    $table->string('entity_type');              // 対象エンティティのモデルクラス名
    $table->longText('text')->nullable();       // マークダウン等のプレーンテキスト
    $table->longText('html')->nullable();       // レンダリングされたHTML
    $table->integer('parent_id')->unsigned()->nullable(); // 返信先コメントのID
    $table->integer('local_id')->unsigned()->nullable()->index(); // ページ内での連番ID
    $table->integer('created_by')->unsigned();
    $table->integer('updated_by')->unsigned()->nullable();
    $table->timestamps();

    $table->index(['entity_id', 'entity_type']);
});
```

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
| **テーブル宣言** | `Schema::create('tags', ...)` | `object Tags : Table("tags") { ... }` |
| **自動増分主キー** | `$table->increments('id')` | `val id = integer("id").autoIncrement()` |
| **符号なし大整数** | `$table->unsignedBigInteger('entity_id')` | `val entityId = uLong("entity_id")` |
| **文字列 (VARCHAR)** | `$table->string('name')->index()` | `val name = varchar("name", 255).index()` |
| **インデックス追加** | `$table->index(['entity_id', 'entity_type'])` | `init { index(false, entityId, entityType) }` |
| **タイムスタンプ** | `$table->timestamps()` | `val createdAt = datetime("created_at")`<br>`val updatedAt = datetime("updated_at")` |

#### Exposedでの実際の定義コード例 (Kotlin)
```kotlin
import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.javatime.datetime

object Tags : Table("tags") {
    val id = integer("id").autoIncrement()
    val entityId = uLong("entity_id")
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

- **Flyway**: `V1__create_tags_table.sql` のように生のSQLファイルを作成し、バージョン管理テーブル (`flyway_schema_history`) で実行済みバージョンを追跡します。
- **Laravel Migration**: PHP of file name でバージョンを追跡し、`migrations` テーブルで実行状態を管理します。

Laravelはスキーマ定義自体をDSL（`Blueprint`）で行うため、**DBエンジンごとのSQL構文の違い（MySQLとPostgreSQLでの型名の違いなど）をフレームワークが隠蔽してくれる** というメリットがあり、これがKotlinにおけるExposed等のDSLによる定義手法と非常によく似ています。

---

## 4. テーブル定義を理解してSQLを読み解くメリット

スキーマ定義（マイグレーション）を頭に入れた上で、もう一度 `01-Bookshelf.md` 〜 `07-SearchRunner.md` のSQLを眺めてみてください。

- **なぜインデックスを気にするのか？**
  - マイグレーションで `->index()` や `$table->index(...)` と明示されているカラムが、SQLの `WHERE` や `JOIN` の結合条件 (`ON`) で使われていることが分かります。
- **なぜ `type` カラムが頻繁に登場するのか？**
  - `entities`, `tags`, `comments`, `favourites` などの多くのテーブルで `entity_type` や `favouritable_type` が定義されています。これは、複数のデータ型（本、章、ページ）を柔軟に紐付ける **ポリモーフィックリレーション** を実現するための根幹の設計だからです。

テーブル定義という「設計図」を理解することで、生のSQLがなぜそのように組み立てられているのかの「意図」が、より深く・立体的に見えてくるはずです！
