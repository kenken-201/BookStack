-- ====================================================================
-- 04-DatabaseTransaction.sql
-- --------------------------------------------------------------------
-- Laravelの「データベーストランザクション」と「分離レベル」を表現する生のSQLです。
--
-- 元のPHPファイル: app/Util/DatabaseTransaction.php
-- 目的: 複数のクエリを実行する際、データの矛盾（不完全な保存や競合）を防ぐ。
-- ====================================================================

-- --------------------------------------------------------------------
-- トランザクション制御の生SQLフロー
-- --------------------------------------------------------------------
-- 元のコード:
--   DB::statement('SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED');
--   return DB::transaction($this->callback);
-- --------------------------------------------------------------------

-- Step 1: 現在のセッションのトランザクション分離レベルを "READ COMMITTED" に変更する
--
-- 【なぜ重要？】
-- デフォルトの分離レベル（MySQLでは REPEATABLE READ）では、トランザクション開始後に
-- 他のトランザクションが追加・コミットしたレコードが見えなくなります（幻読防止）。
-- しかし、BookStackの権限再作成（Permission Generation）などでは、
-- 「処理が実行されたまさにその時点での、他のトランザクションによる最新のコミットデータ」を
-- リアルタイムに考慮したいため、READ COMMITTED（コミットされた変更は即座に読み取る）に変更します。
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Step 2: トランザクションを開始する
START TRANSACTION;

-- Step 3: ビジネスロジックとしてのSQL群を実行 (例: 本棚の削除とブックの紐付け解除など)
-- (1) 削除対象の本棚を取得
SELECT * FROM entities WHERE id = 10 AND type = 'bookshelf' FOR UPDATE;

-- (2) 中間テーブルから対象本棚の紐づけデータを一括削除
DELETE FROM bookshelves_books WHERE bookshelf_id = 10;

-- (3) 本棚自体のデータを entities テーブルから物理削除（またはソフトデリート）
DELETE FROM entities WHERE id = 10 AND type = 'bookshelf';

-- Step 4: 全ての処理が正常に完了したら、変更をデータベースに確定・適用する
-- (もし Step 3 の途中でいずれかのクエリが失敗、またはPHP側で例外が発生した場合は ROLLBACK; が実行される)
COMMIT;

-- ※ 失敗時のロールバック例 (自動的に呼ばれます)
-- ROLLBACK;
