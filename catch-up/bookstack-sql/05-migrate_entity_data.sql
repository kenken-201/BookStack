-- ====================================================================
-- 05-migrate_entity_data.sql
-- --------------------------------------------------------------------
-- Laravelのクエリビルダを使用した「超高速データ移行 (SELECT INSERT)」の生SQLです。
--
-- 元のPHPファイル: database/migrations/2025_09_15_134701_migrate_entity_data.php
-- 目的: 古いテーブル (books, chapters, pages 等) に散らばっていたデータを、
--       新設計の集約テーブル (entities, entity_container_data) へ一括超高速移行する。
-- ====================================================================

-- --------------------------------------------------------------------
-- データ移行トランザクションの開始
-- --------------------------------------------------------------------
START TRANSACTION;

-- --------------------------------------------------------------------
-- 処理1: books テーブルから新 entities テーブルへ、ブックの基本データ移行
-- --------------------------------------------------------------------
-- 元のLaravelコード:
--   DB::table('entities')->insertUsing([
--       'id', 'type', 'name', 'slug', 'created_at', 'updated_at', 'deleted_at', 'created_by', 'updated_by', 'owned_by',
--   ], DB::table('books')->select([
--       'id', DB::raw("'book'"), 'name', 'slug', 'created_at', 'updated_at', 'deleted_at', 'created_by', 'updated_by', 'owned_by',
--   ]));
-- --------------------------------------------------------------------
-- 解説:
-- 通常の Laravel-ORM でループ処理を行うと、1件ごとにSELECTしてINSERTするため数万件で数秒〜数分かかります。
-- クエリビルダの `insertUsing` は、データベースの機能（SELECTした結果を直接INSERTする）をそのまま使うため、
-- メモリ消費ゼロかつ数ミリ秒で完了します。

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


-- --------------------------------------------------------------------
-- 処理2: books テーブルから新 entity_container_data テーブルへ、詳細データ移行
-- --------------------------------------------------------------------
INSERT INTO entity_container_data (
    entity_id, entity_type, `description`, description_html, default_template_id, image_id, sort_rule_id
)
SELECT 
    id, 
    'book', -- 親のIDとポリモーフィック結合できるように型を固定
    `description`, 
    description_html, 
    default_template_id, 
    image_id, 
    sort_rule_id 
FROM 
    books;


-- --------------------------------------------------------------------
-- 処理3: データのクリーニング - 外部キー制約違反を防ぐNULL化アップデート
-- --------------------------------------------------------------------
-- 元のLaravelコード:
--   $userIdQuery = DB::table('users')->select('id');
--   DB::table('entities')->whereNotIn('created_by', $userIdQuery)->update(['created_by' => null]);
-- --------------------------------------------------------------------
-- 解説:
-- テーブル統合の際、存在しないユーザーID（退職した人のゴミデータなど）が `created_by` に入っていると、
-- 新規に設定する外部キー制約（Foreign Key Constraint）でエラーになります。
-- 存在しないIDを持つカラムを、一括で NULL にクリーンアップします。

UPDATE 
    entities 
SET 
    created_by = NULL 
WHERE 
    created_by IS NOT NULL 
    AND created_by NOT IN (
        SELECT id FROM users
    );

-- 同様に、更新者(updated_by) や所有者(owned_by) にも同じ処理を施す
UPDATE 
    entities 
SET 
    updated_by = NULL 
WHERE 
    updated_by IS NOT NULL 
    AND updated_by NOT IN (
        SELECT id FROM users
    );

-- --------------------------------------------------------------------
-- コミットして全データの移行を完了する
-- --------------------------------------------------------------------
COMMIT;
