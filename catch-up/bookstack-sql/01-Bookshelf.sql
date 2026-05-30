-- ====================================================================
-- 01-Bookshelf.sql
-- --------------------------------------------------------------------
-- Laravelの「多対多 (N対N) リレーション」を表現する生のSQLです。
--
-- 元のPHPファイル: app/Entities/Models/Bookshelf.php
-- 目的: 本棚 (Bookshelf) に紐づくブック (Book) の一覧を取得・追加する。
-- ====================================================================

-- --------------------------------------------------------------------
-- クエリ1: 本棚に紐づくブック（Book）の一覧を取得する
-- --------------------------------------------------------------------
-- Eloquentの定義:
--   $this->belongsToMany(Book::class, 'bookshelves_books', 'bookshelf_id', 'book_id')
--       ->select(['entities.*', 'entity_container_data.*'])
--       ->withPivot('order')
--       ->orderBy('order', 'asc');
-- --------------------------------------------------------------------

SELECT 
    -- entities テーブル（ブックのIDやスラッグなどの基本情報）と
    -- entity_container_data テーブル（ブックの説明文やカバー画像IDなどの共通詳細）を全セレクト
    entities.*, 
    entity_container_data.*,
    
    -- 中間テーブル (bookshelves_books) の並び順カラム 'order' をピボット値として取得
    bookshelves_books.order AS pivot_order
FROM 
    entities
    
    -- 1. 中間テーブル (bookshelves_books) を結合し、本と本棚をマッピング
    INNER JOIN bookshelves_books 
        ON entities.id = bookshelves_books.book_id
        
    -- 2. ブック固有のコンテナデータ (entity_container_data) を結合
    INNER JOIN entity_container_data 
        ON entities.id = entity_container_data.entity_id 
        AND entity_container_data.entity_type = 'book'
WHERE 
    -- 指定された本棚のIDで絞り込む（バインドパラメータ: :bookshelf_id）
    bookshelves_books.bookshelf_id = :bookshelf_id
    
    -- entities テーブル内のブック（type = 'book'）かつ、ソフトデリートされていないレコード
    AND entities.type = 'book'
    AND entities.deleted_at IS NULL
ORDER BY 
    -- 中間テーブルで設定された並び順でソート
    bookshelves_books.order ASC;


-- --------------------------------------------------------------------
-- クエリ2: 本棚に新しいブックを追加する (appendBook)
-- --------------------------------------------------------------------
-- Eloquentの処理:
--   $maxOrder = $this->books()->max('order');
--   $this->books()->attach($book->id, ['order' => $maxOrder + 1]);
-- --------------------------------------------------------------------

-- Step 2-1: 現在の本棚に含まれるブックの 'order' の最大値を取得する
SELECT 
    COALESCE(MAX(`order`), 0) AS max_order
FROM 
    bookshelves_books
WHERE 
    bookshelf_id = :bookshelf_id;

-- Step 2-2: 中間テーブルに新しくレコードを挿入 (attach) する
-- (PHP側で計算した max_order + 1 を :new_order としてバインドする)
INSERT INTO bookshelves_books (
    bookshelf_id, 
    book_id, 
    `order`
) VALUES (
    :bookshelf_id, 
    :book_id, 
    :new_order
);
