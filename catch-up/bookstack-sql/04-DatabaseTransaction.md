# 04-DatabaseTransaction.md (データベーストランザクションと分離レベル)

元のユーティリティファイル: [DatabaseTransaction.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Util/DatabaseTransaction.php)

## 4. 【上級】データベーストランザクションと分離レベル
### 📂 ファイル: [DatabaseTransaction.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Util/DatabaseTransaction.php)
*   **主なテーマ**: トランザクション処理による一貫性保持と競合回避。
*   **ここから学べること**:
    *   `DB::transaction(Closure)` を用いた、例外発生時に自動でロールバックするクロージャ型トランザクション。
    *   トランザクション開始前に `DB::statement('SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED')` を実行し、トランザクションの分離レベルをスマートに変更する実装。
*   **キャッチアップのポイント**:
    データ整合性が極めて重要な権限再生成処理などのデッドロックを防ぎ、安全に並行処理させるための堅牢なSQL設計の裏側が分かります。

---

## 1. トランザクション制御と分離レベル設定

### 💡 ORMソースコード (PHP)
```php
class DatabaseTransaction
{
    public function __construct(protected Closure $callback) {}

    public function run(): mixed
    {
        // 1. 分離レベルを READ COMMITTED に設定する生ステートメント
        DB::statement('SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED');
        
        // 2. トランザクションの実行
        return DB::transaction($this->callback);
    }
}
```

### 🔍 変換後の生SQL
```sql
-- Step 1: トランザクション分離レベルを READ COMMITTED に変更
-- 
-- 【なぜ READ COMMITTED なのか？】
-- MySQLデフォルトの REPEATABLE READ では、トランザクション中に他者がコミットしたデータが見えません。
-- 権限再構築のような「今まさに確定している全データ」を参照してパーミッションを組む処理では、
-- 他の並行トランザクションがコミットした結果を即座に読み込む必要があるため、分離レベルを引き下げます。
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Step 2: トランザクションの開始
START TRANSACTION;

-- Step 3: ビジネスロジック内の複数クエリを実行（例: 本棚の削除と紐付け解除）
-- (a) データの取得と排他ロック (Pessimistic Lock)
SELECT * FROM entities WHERE id = :bookshelf_id AND type = 'bookshelf' FOR UPDATE;

-- (b) 中間テーブルの関連を削除
DELETE FROM bookshelves_books WHERE bookshelf_id = :bookshelf_id;

-- (c) 本体データを削除
DELETE FROM entities WHERE id = :bookshelf_id AND type = 'bookshelf';

-- Step 4: 例外が発生しなければ、すべての変更を完全に確定する
COMMIT;

-- ※ 途中のSQLでエラーが発生した場合、またはPHP側で例外がスローされた場合は即座に差し戻す
-- ROLLBACK;
```

### 📝 解説・対比のポイント
*   **DB::transaction(Closure)**:
    Laravelのクロージャを受け取る `DB::transaction()` メソッドは、内部で `try { ... DB::commit(); } catch { DB::rollBack(); throw $e; }` のような例外キャッチ処理を自動で行います。
*   **READ COMMITTED**:
    Laravel標準のトランザクションはDB側のデフォルト分離レベルに依存するため、`DB::statement('SET SESSION...')` を使って明示的にセッションスコープの分離レベルを書き換えています。これにより、デッドロックの回避や高並行性環境での一貫性担保を両立させています。
