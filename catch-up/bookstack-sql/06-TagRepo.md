# 06-TagRepo.md (MySQL関数を絡めた動的な集計クエリ)

元のリポジトリファイル: [TagRepo.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Activity/TagRepo.php)

---

## 1. クロス集計と動的GROUP BYクエリ

### 💡 ORMソースコード (PHP)
```php
protected function baseQueryWithTotals(string $nameFilter, string $searchTerm): Builder
{
    $query = Tag::query()
        ->select([
            'name',
            ($searchTerm || $nameFilter) ? 'value' : DB::raw('COUNT(distinct value) as `values`'),
            DB::raw('COUNT(id) as usages'),
            DB::raw('CAST(SUM(IF(entity_type = \'page\', 1, 0)) as UNSIGNED) as page_count'),
            DB::raw('CAST(SUM(IF(entity_type = \'chapter\', 1, 0)) as UNSIGNED) as chapter_count'),
            DB::raw('CAST(SUM(IF(entity_type = \'book\', 1, 0)) as UNSIGNED) as book_count'),
            DB::raw('CAST(SUM(IF(entity_type = \'bookshelf\', 1, 0)) as UNSIGNED) as shelf_count'),
        ])
        ->whereHas('entity');

    if ($nameFilter) {
        $query->where('name', '=', $nameFilter)->groupBy('value');
    } else {
        $query->groupBy('name');
    }

    return $query;
}
```

### 🔍 変換後の生SQL
```sql
SELECT 
    `name` AS tag_name, 
    
    -- 検索キーワードが渡されていない場合は、そのタグが持つ一意な「値」の種類数をカウント
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
GROUP BY 
    -- タグ名ごとに集約して統計をとる
    `name`
ORDER BY 
    usages_count DESC;
```

### 📝 解説・対比のポイント
*   **DB::raw()**:
    Laravelの標準ORMでは書けない複雑なSQL関数（`COUNT(DISTINCT column)` や `CAST(SUM(IF(...)))`）を実行するため、`DB::raw()` を用いて生のSQLスニペットを直接 `select` 配列内に記述します。
*   **クロス集計の定番パターン**:
    `SUM(IF(entity_type = 'page', 1, 0))` は、レコードの種別をカラムへと展開し、1回のSQLで各ドメイン（ページ、章、ブック、本棚）ごとの合計カウントを一括で計算する、パフォーマンス上非常に有効な定番のテクニックです。
*   **whereHas() と EXISTS 句**:
    Laravelの `whereHas('relation')` は、SQL化される際に `EXISTS (SELECT 1 FROM ...)` 句に自動変換され、インデックスが効いた状態の高速な関連チェックが行われます。
