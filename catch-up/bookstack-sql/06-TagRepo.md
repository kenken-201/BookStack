# 06-TagRepo.md (MySQL関数を絡めた動的な集計クエリ)

元のリポジトリファイル: [TagRepo.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Activity/TagRepo.php)

## 6. 【上級】MySQL関数を絡めた動的な集計クエリ
### 📂 ファイル: [TagRepo.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Activity/TagRepo.php)
*   **主なテーマ**: 単純なCRUDに留まらない、集計（Analytics）系SQL。
*   **ここから学べること**:
    *   `DB::raw()` を用いた、生SQL関数（`COUNT(distinct value)`, `SUM(IF(entity_type = 'page', 1, 0))` 等）のセレクト。
    *   リクエストパラメータの内容に応じて、`groupBy()` のグループ化単位を動的に切り替えるロジック。
    *   `$query->pluck('name')` による、余計なモデル化を挟まないダイレクトな一次元配列抽出。
*   **キャッチアップのポイント**:
    「各タグがどのエンティティで何回使われているか」を1回のSQLクエリで効率よく集計し、フロントエンドに渡すための高速化テクニックが詰まっています。

---

## 1. クロス集計と動的GROUP BYクエリ

### 💡 ORMソースコード (PHP)
```php
protected function baseQueryWithTotals(string $nameFilter, string $searchTerm): Builder
{
    $query = Tag::query()
        ->select([
            'name',
            // ▼ 三項演算子による動的なセレクト切り替え
            // 検索条件がある場合 → value カラムをそのまま取得
            // 検索条件がない場合 → value のユニーク数を集計
            ($searchTerm || $nameFilter) ? 'value' : DB::raw('COUNT(distinct value) as `values`'),
            DB::raw('COUNT(id) as usages'),
            DB::raw('CAST(SUM(IF(entity_type = \'page\', 1, 0)) as UNSIGNED) as page_count'),
            DB::raw('CAST(SUM(IF(entity_type = \'chapter\', 1, 0)) as UNSIGNED) as chapter_count'),
            DB::raw('CAST(SUM(IF(entity_type = \'book\', 1, 0)) as UNSIGNED) as book_count'),
            DB::raw('CAST(SUM(IF(entity_type = \'bookshelf\', 1, 0)) as UNSIGNED) as shelf_count'),
        ])
        ->whereHas('entity');

    // ▼ GROUP BY の動的切り替え（3パターン）
    if ($nameFilter) {
        $query->where('name', '=', $nameFilter);
        $query->groupBy('value');           // 特定タグ名の値ごとに集約
    } elseif ($searchTerm) {
        $query->groupBy('name', 'value');   // name+value の組み合わせごとに集約
    } else {
        $query->groupBy('name');            // タグ名ごとに集約
    }

    // ▼ 検索キーワードがある場合のフィルタリング
    if ($searchTerm) {
        $query->where(function (Builder $query) use ($searchTerm) {
            $query->where('name', 'like', '%' . $searchTerm . '%')
                ->orWhere('value', 'like', '%' . $searchTerm . '%');
        });
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
*   **三項演算子による動的セレクト**:
    `($searchTerm || $nameFilter) ? 'value' : DB::raw('COUNT(...)')` は、PHP側の条件分岐でSQLのSELECT句の中身を切り替えています。検索結果を「タグ値ごとに表示」するか「タグ名ごとに集計」するかの出し分けに使われます。
*   **クロス集計の定番パターン**:
    `SUM(IF(entity_type = 'page', 1, 0))` は、レコードの種別をカラムへと展開し、1回のSQLで各ドメイン（ページ、章、ブック、本棚）ごとの合計カウントを一括で計算する、パフォーマンス上非常に有効な定番のテクニックです。
*   **whereHas() と EXISTS 句**:
    Laravelの `whereHas('relation')` は、SQL化される際に `EXISTS (SELECT 1 FROM ...)` 句に自動変換され、インデックスが効いた状態の高速な関連チェックが行われます。
*   **動的 GROUP BY**:
    `$nameFilter` の有無と `$searchTerm` の有無に応じて、GROUP BYの単位が3パターンに分岐されます。同じクエリビルダーインスタンスを動的に組み替える、Laravelのクエリビルダーの柔軟性を活かした実装です。
