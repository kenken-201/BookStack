# 07-SearchRunner.md (サブクエリJOINと動的SQLスコアリングの最高峰)

元の検索ランナーファイル: [SearchRunner.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Search/SearchRunner.php)

## 7. 【超上級】サブクエリJOINと動的SQLスコアリングの最高峰
### 📂 ファイル: [SearchRunner.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Search/SearchRunner.php)
*   **主なテーマ**: 複雑な検索条件に応じた動的クエリの生成とスコア判定。
*   **ここから学べること**:
    *   `joinSub($subQuery, 's', ...)` による、クエリビルダで作成した集計用サブクエリとベーステーブルのインナージョイン。
    *   `CASE WHEN` や `IF(term like ?, score * ...)` のSQL文と bindings（プリペアドステートメント用のパラメータ）を動的に配列で組み立てる `selectRaw` テクニック。
    *   `whereHas` / `whereDoesntHave` にクロージャを渡して、関連テーブルの有無（Not In等）をフィルタする高度な絞り込み。
    *   最新のコメント行のみを抽出するための「LEFT JOINとNULL判定」を駆使した高度なソート用サブクエリJOIN（`sortByLastCommented` メソッド）。
*   **キャッチアップのポイント**:
    Laravelのクエリビルダが持つ表現力の限界に近い、極めて複雑かつ高度な動的SQLです。これが理解できれば、実務のあらゆるデータ抽出要件に対応できます。

---

## 1. 検索スコアリングのサブクエリJOIN

### 💡 ORMソースコード (PHP)
```php
protected function applyTermSearch(EloquentBuilder $entityQuery, SearchOptions $options, array $entityTypes): void
{
    $terms = $options->searches->toValueArray();
    if (count($terms) === 0) {
        return;  // 検索語が空なら何もしない
    }

    // 1. 各検索語の希少度スコア係数を取得（後述）
    $scoredTerms = $this->getTermAdjustments($options);
    
    // 2. スコア計算用のSQLスニペットを動的生成
    $scoreSelect = $this->selectForScoredTerms($scoredTerms);

    // 3. search_terms テーブルからスコアを集計するサブクエリを組み立て
    $subQuery = DB::table('search_terms')->select([
        'entity_id',
        'entity_type',
        DB::raw($scoreSelect['statement']),  // SUM(IF(term like ?, score * 1.2, ...)) as score
    ]);
    $subQuery->addBinding($scoreSelect['bindings'], 'select');
    
    // 4. OR 条件で検索語にマッチするレコードを絞り込み
    $subQuery->where(function (Builder $query) use ($terms) {
        foreach ($terms as $inputTerm) {
            $escapedTerm = str_replace('\\', '\\\\', $inputTerm);  // バックスラッシュのエスケープ
            $query->orWhere('term', 'like', $escapedTerm . '%');    // 前方一致検索
        }
    });
    $subQuery->groupBy('entity_type', 'entity_id');

    // 5. ★サブクエリとのINNER JOIN（マッチしたエンティティのみ残る）
    $entityQuery->joinSub($subQuery, 's', function (JoinClause $join) {
        $join->on('s.entity_id', '=', 'entities.id')
            ->on('s.entity_type', '=', 'entities.type');
    });
    
    $entityQuery->addSelect('s.score');
    $entityQuery->orderBy('score', 'desc');
}

// --- スコア計算用SQLの生成ロジック ---
protected function selectForScoredTerms(array $scoredTerms): array
{
    // IF文を「後ろから前に」組み立てる（ネスト構造のため）
    // 初期値 '0' = どの語にもマッチしなかった場合のスコア
    $ifChain = '0';
    $bindings = [];
    foreach ($scoredTerms as $term => $score) {
        $ifChain = 'IF(term like ?, score * ' . (float) $score . ', ' . $ifChain . ')';
        $bindings[] = $term . '%';
    }
    return [
        'statement' => 'SUM(' . $ifChain . ') as score',
        'bindings'  => array_reverse($bindings),  // IFは逆順に組み立てたので bindings も反転
    ];
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
*   **動的なIFのネスト（IFChain）の構築順序**:
    `selectForScoredTerms` では IF 文を「後ろから前に」組み立てます。これはIFのネスト構造上、「else側に前回の結果を埋め込む」必要があるためです。その結果、bindings の順序も逆転するため `array_reverse()` で正しい順序に戻しています。
*   **希少度スコアの仕組み**:
    `getTermAdjustments()` メソッドが各検索語の出現回数をカウントし、よく使われる語ほどスコア係数が低く（`1.3 - 1.0 = 0.3`）、希少な語ほど係数が高く（`1.3 - 0.1 = 1.2`）なるよう調整されます。これにより、希少なキーワードでヒットしたエンティティが検索結果の上位に来るようになります（TF-IDFに似た考え方）。
*   **エスケープ処理**:
    `str_replace('\\', '\\\\', $inputTerm)` は、ユーザー入力中のバックスラッシュをエスケープし、MySQLの `LIKE` 句でワイルドカードとして誤解釈されるのを防いでいます。

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
