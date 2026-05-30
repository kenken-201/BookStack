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

### 💡 ORMソースコード (PHP)
```php
// 存在しないユーザーIDが設定されているゴミデータを一斉に NULL に更新
$userIdQuery = DB::table('users')->select('id');
DB::table('entities')->whereNotIn('created_by', $userIdQuery)->update(['created_by' => null]);
```

### 🔍 変換後の生SQL
```sql
UPDATE 
    entities 
SET 
    created_by = NULL 
WHERE 
    created_by IS NOT NULL 
    -- ユーザーテーブルに存在しないIDを指定している行をサブクエリで抽出
    AND created_by NOT IN (
        SELECT id FROM users
    );
```

### 📝 解説・対比のポイント
*   **whereNotInにクエリインスタンスを渡す**:
    Laravelの `whereNotIn('column', $subQuery)` は、別で組み立てたクエリビルダオブジェクトをそのまま引数に取ることで、SQLの `NOT IN (SELECT ...)` というサブクエリ構造を美しく再現します。
    古いデータベースの整合性の取れていないゴミデータを、外部キー制約を張る前に一撃でクリーンアップする実戦テクニックです。
