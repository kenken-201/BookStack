-- ====================================================================
-- 02-Favourite.sql
-- --------------------------------------------------------------------
-- Laravelの「ポリモーフィックリレーションシップ」を表現する生のSQLです。
--
-- 元のPHPファイル: app/Activity/Models/Favourite.php
-- 目的: どの種類のエンティティ (Book, Chapter, Pageなど) にも
--       単一のテーブルで対応可能なお気に入り機能を実現する。
-- ====================================================================

-- --------------------------------------------------------------------
-- クエリ1: お気に入りレコードに対応する親エンティティを取得する
-- --------------------------------------------------------------------
-- Eloquentの定義:
--   public function favouritable(): MorphTo { return $this->morphTo(); }
-- --------------------------------------------------------------------
-- 解説:
-- ポリモーフィックリレーションでは、`favouritable_type` にクラス名やMorph識別子 (例: 'page', 'book')
-- `favouritable_id` にその対象テーブルのIDが入ります。
-- よって、データベース上では「2ステップのSELECT文」が走ります。

-- Step 1-1: お気に入り(ID: 5) のレコードから、対象の型とIDを取得する
SELECT 
    id, 
    user_id, 
    favouritable_id, 
    favouritable_type 
FROM 
    favourites 
WHERE 
    id = :favourite_id;

-- Step 1-2: Step 1-1 で取得した型 (例: favouritable_type = 'page', favouritable_id = 42) 
-- に基づいて、対応する実体テーブルからデータを取得する
-- ※ 'page' の場合は entities テーブルの id = 42 かつ type = 'page'
SELECT 
    * 
FROM 
    entities 
WHERE 
    id = :favouritable_id 
    AND type = :favouritable_type
    AND deleted_at IS NULL;


-- --------------------------------------------------------------------
-- クエリ2: お気に入りに紐づく権限 (Permissions) を同時取得する
-- --------------------------------------------------------------------
-- Eloquentの定義:
--   public function jointPermissions(): HasMany
--   {
--       return $this->hasMany(JointPermission::class, 'entity_id', 'favouritable_id')
--           ->whereColumn('favourites.favouritable_type', '=', 'joint_permissions.entity_type');
--   }
-- --------------------------------------------------------------------
-- 解説:
-- ポリモーフィックのままでHasMany結合を行うという非常にトリッキーなリレーションです。
-- SQLレベルでは、「対象のID」と「対象の型（タイプ文字列）」の両方が一致する行を結合（JOIN）します。

SELECT 
    favourites.*,
    joint_permissions.role_id,
    joint_permissions.status,
    joint_permissions.owner_id
FROM 
    favourites
    
    -- favourites のポリモーフィック属性 (id & type) と 
    -- joint_permissions のエンティティ属性 (id & type) をダブル結合する
    INNER JOIN joint_permissions 
        ON favourites.favouritable_id = joint_permissions.entity_id
        AND favourites.favouritable_type = joint_permissions.entity_type
WHERE 
    favourites.user_id = :user_id;
