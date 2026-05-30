-- ====================================================================
-- 03-BaseRepo.sql
-- --------------------------------------------------------------------
-- Laravelの標準的な「CRUD処理（新規作成・更新）」に伴う生のSQLです。
--
-- 元のPHPファイル: app/Entities/Repos/BaseRepo.php
-- 目的: entitiesテーブルに対するデータの新規作成と更新を表現する。
-- ====================================================================

-- --------------------------------------------------------------------
-- クエリ1: 新規レコードの挿入 (create)
-- --------------------------------------------------------------------
-- Eloquentの処理:
--   $entity->fill($input);
--   $entity->forceFill([
--       'created_by' => user()->id,
--       'updated_by' => user()->id,
--       'owned_by'   => user()->id,
--   ]);
--   $entity->save();
-- --------------------------------------------------------------------
-- 解説:
-- 新規レコード作成時、Laravelはテーブル内のカラムリストを割り出し、
-- 設定された値とシステム管理用のメタデータ、タイムスタンプ（created_at, updated_at）を含めて
-- 1つの INSERT 文を実行します。

INSERT INTO entities (
    `type`, 
    `name`, 
    `slug`, 
    `created_by`, 
    `updated_by`, 
    `owned_by`, 
    `created_at`, 
    `updated_at`
) VALUES (
    :type,        -- 'book' や 'page' などのエンティティ種別
    :name,        -- 画面から入力された名前
    :slug,        -- システムによって自動生成されたURL用の一意なスラッグ
    :user_id,     -- 作成したユーザーのID (created_by)
    :user_id,     -- 最後に更新したユーザーのID (updated_by)
    :user_id,     -- 所有者ユーザーのID (owned_by)
    NOW(),        -- レコードの作成日時 (Laravelが自動設定する created_at)
    NOW()         -- レコードの更新日時 (Laravelが自動設定する updated_at)
);


-- --------------------------------------------------------------------
-- クエリ2: 既存レコードの更新 (update)
-- --------------------------------------------------------------------
-- Eloquentの処理:
--   $entity->fill($input);
--   $entity->updated_by = user()->id;
--   // スラッグに変更がある場合は refreshSlug() 経由で再生成
--   $entity->save();
-- --------------------------------------------------------------------
-- 解説:
-- Eloquentは、「どのフィールドが変更されたか（Dirty属性）」を自動的に追跡します。
-- データベースには、**変更されたカラムと、updated_at, updated_by のみ**を更新する
-- 効率的な UPDATE 文が発行されます。

UPDATE 
    entities 
SET 
    -- 変更されたカラムのみがセットされます
    `name` = :new_name,
    `slug` = :new_slug,
    
    -- 更新メタデータと、自動更新される updated_at タイムスタンプ
    `updated_by` = :updater_user_id,
    `updated_at` = NOW() 
WHERE 
    id = :entity_id;
