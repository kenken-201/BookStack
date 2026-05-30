# 01-Bookshelf.md (多対多リレーションと中間テーブル操作)

元のモデルファイル: [Bookshelf.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Entities/Models/Bookshelf.php)

---

## 1. 本棚に紐づくブック（Book）の一覧を取得する

### 💡 ORMソースコード (PHP)
```php
public function books(): BelongsToMany
{
    return $this->belongsToMany(Book::class, 'bookshelves_books', 'bookshelf_id', 'book_id')
        ->select(['entities.*', 'entity_container_data.*'])
        ->withPivot('order')
        ->orderBy('order', 'asc');
}

// 呼び出し側
$books = $bookshelf->books()->scopes('visible')->get();
```

### 🔍 変換後の生SQL
```sql
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
```

### 📝 解説・対比のポイント
*   **多対多関係の結合**: Laravelの `belongsToMany` を使用すると、内部的にベーステーブルと中間テーブルが `INNER JOIN` されます。
*   **withPivot**: 中間テーブル（`bookshelves_books`）のみが持つ `order` 属性を取得するため、SQL側で `bookshelves_books.order AS pivot_order` を明示的にセレクトに加えます。

---

## 2. 本棚に新しいブックを追加する (appendBook)

### 💡 ORMソースコード (PHP)
```php
public function appendBook(Book $book): void
{
    if ($this->contains($book)) {
        return;
    }

    $maxOrder = $this->books()->max('order');
    $this->books()->attach($book->id, ['order' => $maxOrder + 1]);
}
```

### 🔍 変換後の生SQL
#### Step 2-1: 現在の本棚に含まれるブックの 'order' の最大値を取得する
```sql
SELECT 
    COALESCE(MAX(`order`), 0) AS max_order
FROM 
    bookshelves_books
WHERE 
    bookshelf_id = :bookshelf_id;
```

#### Step 2-2: 中間テーブルに新しくレコードを挿入 (attach) する
*(※ `max_order + 1` の計算結果を `:new_order` としてバインドします)*
```sql
INSERT INTO bookshelves_books (
    bookshelf_id, 
    book_id, 
    `order`
) VALUES (
    :bookshelf_id, 
    :book_id, 
    :new_order
);
```

### 📝 解説・対比のポイント
*   **attach() メソッド**: 多対多リレーションに新たな関係レコードを追加する際、Laravelは中間テーブルに対して直接 `INSERT` 文を実行します。
*   **COALESCE**: `MAX(order)` が `NULL` （本がまだ1冊もない場合）の時にエラーを防ぐため、SQLでは `COALESCE` を用いてデフォルト値 `0` を返します。
