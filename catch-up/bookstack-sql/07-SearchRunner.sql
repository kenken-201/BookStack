-- ====================================================================
-- 07-SearchRunner.sql
-- --------------------------------------------------------------------
-- Laravelのクエリビルダを駆使した「サブクエリJOIN・検索スコア動的算出」の生SQLです。
--
-- 元のPHPファイル: app/Search/SearchRunner.php
-- 目的: 全エンティティから、キーワードに合致するものを検索し、
--       キーワードとの合致度（検索スコア）を算出して降順ソートする。
--       さらに、最新のコメント情報も自己結合サブクエリでJOINして取得する。
-- ====================================================================

-- --------------------------------------------------------------------
-- 検索＆最新コメント取得の大規模SQLクエリ
-- --------------------------------------------------------------------

SELECT 
    -- 1. 基本エンティティ情報
    entities.id,
    entities.type,
    entities.name,
    entities.slug,
    
    -- 2. サブクエリJOIN (s) から算出された、検索キーワードとのマッチングスコア
    s.score AS match_score,
    
    -- 3. コメントJOIN (comments) から取得した、最新コメント日時
    comments.last_commented
FROM 
    entities
    
    -- =================================================================
    -- 【検索スコアリングのサブクエリJOIN】
    -- =================================================================
    -- Laravelコード:
    --   $entityQuery->joinSub($subQuery, 's', function ($join) { ... })
    --
    -- 各キーワード（例: 'laravel', 'tutorial'）について、MySQLの `IF(term LIKE ...)` をネストさせ、
    -- キーワードのヒット回数と重み（スコア）の合計を算出します。
    -- (検索ワードが珍しいものほどスコアが上がります)
    INNER JOIN (
        SELECT 
            entity_id, 
            entity_type,
            
            -- 動的な IF ネストによるスコア算出（IFChainの再現）
            -- 'laravel%' に一致したら元のスコアの 1.2倍、'tutorial%' に一致したら 0.8倍、それ以外は0
            SUM(
                IF(term LIKE 'laravel%', score * 1.2, 
                    IF(term LIKE 'tutorial%', score * 0.8, 0)
                )
            ) AS score
        FROM 
            search_terms
        WHERE 
            -- 入力された検索ワードのいずれか前方一致する行だけを対象にする
            term LIKE 'laravel%' 
            OR term LIKE 'tutorial%'
        GROUP BY 
            entity_type, 
            entity_id
    ) AS s 
        ON s.entity_id = entities.id 
        AND s.entity_type = entities.type
        
    -- =================================================================
    -- 【最新コメント日時を取得する自己JOINサブクエリ】
    -- =================================================================
    -- Laravelコード:
    --   $query->join($commentQuery, function ($join) { ... })
    --
    -- コメントテーブル（comments）に対し、同じエンティティへの別のコメントで、
    -- 「作成日時がより新しいもの (c1.created_at < c2.created_at)」を LEFT JOIN します。
    -- `c2.created_at IS NULL`（より新しいコメントが存在しない）という条件を満たす c1 が、
    -- 「そのエンティティにおける最新のコメントレコード」になります（自己結合の極意）。
    LEFT JOIN (
        SELECT 
            c1.commentable_id, 
            c1.commentable_type, 
            c1.created_at AS last_commented 
        FROM 
            comments c1 
            LEFT JOIN comments c2 
                ON c1.commentable_id = c2.commentable_id 
                AND c1.commentable_type = c2.commentable_type 
                -- より新しいコメントレコードがあるかを結合
                AND c1.created_at < c2.created_at 
        WHERE 
            -- 「より新しいコメントがない」 ＝ c1が最新コメントレコードとなる
            c2.created_at IS NULL
    ) AS comments 
        ON entities.id = comments.commentable_id 
        AND entities.type = comments.commentable_type
        
WHERE 
    -- ソフトデリートされていないもの
    entities.deleted_at IS NULL
ORDER BY 
    -- 算出された検索スコアの降順でソート（適合度が高いもの順）
    match_score DESC,
    
    -- コメント日時順
    last_commented DESC;
