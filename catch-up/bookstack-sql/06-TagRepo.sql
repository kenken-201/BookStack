-- ====================================================================
-- 06-TagRepo.sql
-- --------------------------------------------------------------------
-- クエリビルダによる「MySQL集計関数を絡めた動的な集計クエリ」の生SQLです。
--
-- 元のPHPファイル: app/Activity/TagRepo.php
-- 目的: 全てのタグの使用状況（どの種類のエンティティで何回使われているか）を、
--       1回の大規模クエリで高速に集計する。
-- ====================================================================

-- --------------------------------------------------------------------
-- 集計クエリ: タグ別の使用頻度およびコンテンツ別カウント
-- --------------------------------------------------------------------
-- 元のLaravelコード:
--   Tag::query()->select([
--       'name',
--       ($searchTerm || $nameFilter) ? 'value' : DB::raw('COUNT(distinct value) as `values`'),
--       DB::raw('COUNT(id) as usages'),
--       DB::raw('CAST(SUM(IF(entity_type = \'page\', 1, 0)) as UNSIGNED) as page_count'),
--       ...
--   ])->whereHas('entity')->groupBy('name');
-- --------------------------------------------------------------------
-- 解説:
-- `SUM(IF(entity_type = 'page', 1, 0))` は「クロス集計」の超王道パターンです。
-- 行ベースで保存されているデータを、SQLの段階で列（カラム）ベースの集計データへ変換します。
-- `whereHas('entity')` は SQL では `EXISTS` サブクエリに変換され、親エンティティが削除された「浮いたタグ」を除外します。

SELECT 
    `name` AS tag_name, 
    
    -- タグ名の検索キーワードがない場合は、そのタグが持つ一意な「値」の種類数をカウント
    -- (検索ワードがある場合は直接 'value' カラムを選択するようにPHP側で動的に切り替えます)
    COUNT(DISTINCT `value`) AS `values_count`,
    
    -- このタグ全体の総使用回数
    COUNT(id) AS usages_count,
    
    -- 各レコードの対象エンティティの型 (entity_type) に応じて1か0を判定し、合計（SUM）する。
    -- CAST(... AS UNSIGNED) で明示的に符号なし整数に型変換を行う。
    CAST(SUM(IF(entity_type = 'page', 1, 0)) AS UNSIGNED) AS page_count,
    CAST(SUM(IF(entity_type = 'chapter', 1, 0)) AS UNSIGNED) AS chapter_count,
    CAST(SUM(IF(entity_type = 'book', 1, 0)) AS UNSIGNED) AS book_count,
    CAST(SUM(IF(entity_type = 'bookshelf', 1, 0)) AS UNSIGNED) AS shelf_count
FROM 
    tags
WHERE 
    -- 【whereHas('entity') の実現】
    -- ポリモーフィックな親エンティティが、親テーブル (entities) に実在するもののみに絞り込む (浮いたタグの除外)
    EXISTS (
        SELECT 1 
        FROM entities 
        WHERE 
            entities.id = tags.entity_id 
            AND entities.type = tags.entity_type
            AND entities.deleted_at IS NULL
    )
    
    -- タグ名やタグの値に対する部分一致検索（バインドパラメータ: :search_term）
    AND (
        `name` LIKE :search_term 
        OR `value` LIKE :search_term
    )
GROUP BY 
    -- タグ名ごとに集約して統計をとる
    `name`
ORDER BY 
    -- 使用頻度が多いもの順に並べ替える
    usages_count DESC;
