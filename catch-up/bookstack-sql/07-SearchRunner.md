# 07-SearchRunner.md (サブクエリJOINと動的SQLスコアリングの最高峰)

元の検索ランナーファイル: [SearchRunner.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Search/SearchRunner.php)

---

## 1. 検索スコアリングのサブクエリJOIN

### 💡 ORMソースコード (PHP)
```php
protected function applyTermSearch(EloquentBuilder $entityQuery, SearchOptions $options, array $entityTypes): void
{
    $terms = $options->searches->toValueArray();
    
    // スコア計算用のステートメントを動的に作成 (IFChain)
    $scoreSelect = $this->selectForScoredTerms($scoredTerms);

    $subQuery = DB::table('search_terms')->select([
        'entity_id',
        'entity_type',
        DB::raw($scoreSelect['statement']),
    ]);
    
    $subQuery->addBinding($scoreSelect['bindings'], 'select');
    
    // 検索語の結合
    $subQuery->where(function (Builder $query) use ($terms) {
        foreach ($terms as $inputTerm) {
            $query->orWhere('term', 'like', $inputTerm . '%');
        }
    });
    $subQuery->groupBy('entity_type', 'entity_id');

    // ★サブクエリとのINNER JOIN
    $entityQuery->joinSub($subQuery, 's', function (JoinClause $join) {
        $join->on('s.entity_id', '=', 'entities.id')
            ->on('s.entity_type', '=', 'entities.type');
    });
    
    $entityQuery->addSelect('s.score');
    $entityQuery->orderBy('score', 'desc');
}
```

### 🔍 変換後の生SQL
```sql
SELECT 
    entities.id,
    entities.type,
    entities.name,
    entities.slug,
    s.score AS match_score
FROM 
    entities
    
    -- =================================================================
    -- 【検索スコアリングのサブクエリとの INNER JOIN】
    -- =================================================================
    INNER JOIN (
        SELECT 
            entity_id, 
            entity_type,
            
            -- 動的な IF ネストによるスコア算出（IFChainの再現）
            -- 'laravel%' に一致したらスコアの1.2倍、'tutorial%' に一致したら0.8倍
            SUM(
                IF(term LIKE 'laravel%', score * 1.2, 
                    IF(term LIKE 'tutorial%', score * 0.8, 0)
                )
            ) AS score
        FROM 
            search_terms
        WHERE 
            term LIKE 'laravel%' 
            OR term LIKE 'tutorial%'
        GROUP BY 
            entity_type, 
            entity_id
    ) AS s 
        ON s.entity_id = entities.id 
        AND s.entity_type = entities.type
WHERE 
    entities.deleted_at IS NULL
ORDER BY 
    match_score DESC;
```

### 📝 解説・対比のポイント
*   **joinSub() によるサブクエリJOIN**:
    Laravelの `joinSub($query, 'alias', function)` は、クエリビルダを用いて組み立てた複雑な集計用サブクエリを、SQLの `INNER JOIN (SELECT ...) AS alias` として効率的にインナージョインします。
*   **動的なIFのネスト（IFChain）**:
    検索エンジン機能における「希少性の高い単語ほどヒットした時のスコア配点を高くする」ための複雑なアルゴリズムを、SQLの `IF(term like ?, score * multiplier, else_score)` の多重ネスト構造によってデータベースエンジン側で一括計算しています。

---

## 2. 自己JOINを駆使した最新コメント抽出

### 💡 ORMソースコード (PHP)
```php
protected function sortByLastCommented(EloquentBuilder $query, bool $negated)
{
    $commentsTable = DB::getTablePrefix() . 'comments';
    
    // c1 と c2 を自己結合し、c2.created_at が NULL になる行を抽出するサブクエリ
    $commentQuery = DB::raw('(SELECT c1.commentable_id, c1.commentable_type, c1.created_at as last_commented FROM ' . $commentsTable . ' c1 LEFT JOIN ' . $commentsTable . ' c2 ON (c1.commentable_id = c2.commentable_id AND c1.commentable_type = c2.commentable_type AND c1.created_at < c2.created_at) WHERE c2.created_at IS NULL) as comments');

    $query->join($commentQuery, function (JoinClause $join) {
        $join->on('entities.id', '=', 'comments.commentable_id')
            ->on('entities.type', '=', 'comments.commentable_type');
    })->orderBy('last_commented', $negated ? 'asc' : 'desc');
}
```

### 🔍 変換後の生SQL
```sql
SELECT 
    entities.*,
    comments.last_commented
FROM 
    entities
    
    -- =================================================================
    -- 【最新コメント日時を取得する自己JOINサブクエリ】
    -- =================================================================
    INNER JOIN (
        SELECT 
            c1.commentable_id, 
            c1.commentable_type, 
            c1.created_at AS last_commented 
        FROM 
            comments c1 
            
            -- c1 と同じエンティティへの別のコメントで、
            -- 「c1 より作成日時が新しいもの (c1.created_at < c2.created_at)」を LEFT JOIN する
            LEFT JOIN comments c2 
                ON c1.commentable_id = c2.commentable_id 
                AND c1.commentable_type = c2.commentable_type 
                AND c1.created_at < c2.created_at 
        WHERE 
            -- 「c1 より新しいコメントレコードが存在しない」 
            -- ＝ c2の全カラムが NULL になるため、c1 が最新コメントレコードとして確定する
            c2.created_at IS NULL
    ) AS comments 
        ON entities.id = comments.commentable_id 
        AND entities.type = comments.commentable_type
ORDER BY 
    last_commented DESC;
```

### 📝 解説・対比のポイント
*   **最新の1件を抽出する自己結合（Self JOIN）**:
    コメントテーブルには1つの記事に対して何十件ものレコードが入りますが、欲しいのは「最新の1件だけ」です。
    `GROUP BY` と `MAX(created_at)` を使う場合、その他のカラムを取得するために結局二重クエリになりますが、この **「LEFT JOIN して比較し、NULL判定する」** 手法を使うと、1回のジョインで最新のレコード行のすべてのデータをスマートに取得できるSQLの高度な常套句です。
