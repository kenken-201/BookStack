# 05-migrate_entity_data.md (バルクインサートによる高速データ移行)

元のマイグレーションファイル: [2025_09_15_134701_migrate_entity_data.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/database/migrations/2025_09_15_134701_migrate_entity_data.php)

## 5. 【上級】バルクインサートによる高速データ移行
### 📂 ファイル: [2025_09_15_134701_migrate_entity_data.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/database/migrations/2025_09_15_134701_migrate_entity_data.php)
*   **主なテーマ**: クエリビルダを使用した超高速なETL処理（データ移行）。
*   **ここから学べること**:
    *   `DB::beginTransaction()` と `DB::commit()` を明示的に使う手動トランザクション制御。
    *   `DB::table('...')->insertUsing(...)` を用いた、PHPのメモリを消費しない「他テーブルからのサブクエリ付き高速バルクインサート（SELECT INSERT）」。
    *   `whereNotIn` の条件に別のクエリビルダインスタンス（サブクエリ）を引き渡して、整合性の取れないデータを一瞬でUPDATEでクリーンアップする実戦テクニック。
*   **キャッチアップのポイント**:
    本番環境のデータベース構造を大規模アップデートする際に、数秒〜数ミリ秒で数万件のデータを一気に移行するためのクエリビルダの真の実力が学べます。

---

## 1. 他テーブルからのサブクエリ付きバルクインサート (SELECT INSERT)

### 💡 ORMソースコード (PHP)
```php
public function up(): void
{
    DB::beginTransaction();

    // booksテーブルのデータを entitiesテーブルへ超高速バルク挿入
    DB::table('entities')->insertUsing([
        'id', 'type', 'name', 'slug', 'created_at', 'updated_at', 'deleted_at', 'created_by', 'updated_by', 'owned_by',
    ], DB::table('books')->select([
        'id', DB::raw("'book'"), 'name', 'slug', 'created_at', 'updated_at', 'deleted_at', 'created_by', 'updated_by', 'owned_by',
    ]));

    // ... その他のテーブル移行
    
    DB::commit();
}
```

### 🔍 変換後の生SQL
```sql
START TRANSACTION;

-- SELECT INSERT文による超高速一括データコピー
INSERT INTO entities (
    id, `type`, `name`, slug, created_at, updated_at, deleted_at, created_by, updated_by, owned_by
)
SELECT 
    id, 
    'book', -- 固定文字列 'book' を type カラムとして挿入
    `name`, 
    slug, 
    created_at, 
    updated_at, 
    deleted_at, 
    created_by, 
    updated_by, 
    owned_by 
FROM 
    books;
```

### 📝 解説・対比のポイント
*   **insertUsing()**:
    Laravelの `insertUsing()` は、メモリ上でループ処理を行う代わりに、データベースエンジン側で直接 `INSERT INTO ... SELECT ...` を実行するクエリを生成します。
    これにより、PHP側に数万件のデータをロードしてコレクション化する必要がなくなり、メモリ消費量ほぼゼロで超高速にデータ移行（秒間数十万件規模）を行えます。

---

## 2. データのクリーニング（整合性チェックとNULL化）

マイグレーション時、旧テーブルのデータには不正な値（存在しないユーザーID等）が含まれている可能性があります。  
外部キー制約を張る前に、これらのゴミデータを2段階で一斉クリーンアップします。

### 💡 ORMソースコード (PHP)
```php
// --- Step A: ID = 0 を NULL に変換（古いデータの無効値をクリーンアップ） ---
DB::table('entities')->where('created_by', '=', 0)->update(['created_by' => null]);
DB::table('entities')->where('updated_by', '=', 0)->update(['updated_by' => null]);
DB::table('entities')->where('owned_by', '=', 0)->update(['owned_by' => null]);
DB::table('entities')->where('chapter_id', '=', 0)->update(['chapter_id' => null]);

// --- Step B: users テーブルに存在しないIDを持つレコードを NULL に変換 ---
$userIdQuery = DB::table('users')->select('id');
DB::table('entities')->whereNotIn('created_by', $userIdQuery)->update(['created_by' => null]);
DB::table('entities')->whereNotIn('updated_by', $userIdQuery)->update(['updated_by' => null]);
DB::table('entities')->whereNotIn('owned_by', $userIdQuery)->update(['owned_by' => null]);
DB::table('entities')->whereNotIn('chapter_id', DB::table('chapters')->select('id'))->update(['chapter_id' => null]);
```

### 🔍 変換後の生SQL
```sql
-- ===== Step A: ID = 0 の無効値を NULL に変換 =====
-- 古いアプリケーションでは「未設定」を 0 で表現していたため、
-- 外部キー制約に適合するよう NULL に統一する
UPDATE entities SET created_by = NULL WHERE created_by = 0;
UPDATE entities SET updated_by = NULL WHERE updated_by = 0;
UPDATE entities SET owned_by   = NULL WHERE owned_by = 0;
UPDATE entities SET chapter_id = NULL WHERE chapter_id = 0;

-- ===== Step B: 存在しないIDを持つレコードを NULL に変換 =====
-- ユーザーが既に削除されていてもレコードだけ残っているケースを一斉クリーンアップ
UPDATE entities SET created_by = NULL
WHERE created_by NOT IN (SELECT id FROM users);

UPDATE entities SET updated_by = NULL
WHERE updated_by NOT IN (SELECT id FROM users);

UPDATE entities SET owned_by = NULL
WHERE owned_by NOT IN (SELECT id FROM users);

UPDATE entities SET chapter_id = NULL
WHERE chapter_id NOT IN (SELECT id FROM chapters);
```

### 📝 解説・対比のポイント
*   **2段階クリーンアップ**:
    まず Step A で「ID = 0」の無効値を NULL に変換し、次に Step B で「テーブルに存在しないID」を NULL に変換します。この順序で処理することで、Step B の `NOT IN` サブクエリで ID=0 のレコードが二重にヒットする問題を防いでいます。
*   **whereNotIn にクエリインスタンスを渡す**:
    Laravelの `whereNotIn('column', $subQuery)` は、別で組み立てたクエリビルダオブジェクトをそのまま引数に取ることで、SQLの `NOT IN (SELECT ...)` というサブクエリ構造を美しく再現します。
*   **外部キー制約を張る前のデータ整備**:
    外部キー制約（FOREIGN KEY）を追加するマイグレーションが後続で控えているため、この段階で不整合データをすべて NULL 化しておくことが必須です。
