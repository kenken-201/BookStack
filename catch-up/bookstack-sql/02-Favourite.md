# 02-Favourite.md (ポリモーフィックリレーションシップの設計)

元のモデルファイル: [Favourite.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Activity/Models/Favourite.php)

## 2. 【中級】ポリモーフィックリレーションシップの設計
### 📂 ファイル: [Favourite.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Activity/Models/Favourite.php)
*   **主なテーマ**: 複数の異なるモデルを1つのテーブルに柔軟に紐付ける技術。
*   **ここから学べること**:
    *   `morphTo()` によるポリモーフィック関係のモデル定義。
    *   `favouritable_type` と `favouritable_id` の自動マッピングの仕組み。
    *   ポリモーフィックリレーションに、さらに `whereColumn()` を絡めた独自の `HasMany` リレーションを定義する高度なテクニック（`jointPermissions` メソッド）。
*   **キャッチアップのポイント**:
    BookStackの「ブック」「章」「ページ」というバラバラのエンティティに対して、共通で「お気に入り」機能を付与する美しいポリモーフィックの設計を学べます。

---

## 1. お気に入りレコードに対応する親エンティティを取得する

### 💡 ORMソースコード (PHP)
```php
public function favouritable(): MorphTo
{
    return $this->morphTo();
}

// 呼び出し側 (遅延ロード)
$parentEntity = $favourite->favouritable;
```

### 🔍 変換後の生SQL
#### Step 1-1: お気に入りレコードから、対象の型とIDを取得する
```sql
SELECT 
    id, 
    user_id, 
    favouritable_id, 
    favouritable_type 
FROM 
    favourites 
WHERE 
    id = :favourite_id;
```

#### Step 1-2: 取得した型（例: 'page', ID: 42）に基づいて親テーブルから取得する
```sql
SELECT 
    * 
FROM 
    entities 
WHERE 
    id = :favouritable_id 
    AND type = :favouritable_type
    AND deleted_at IS NULL;
```

### 📝 解説・対比のポイント
*   **ポリモーフィック関係の解決**: 単一の `morphTo` は、SQLレベルでは1回のクエリでは解決されません。まず結合親のタイプ（`favouritable_type`）とIDを取得したあと、そのタイプが指し示すテーブル（BookStackでは `entities` テーブル）に対して2回目の検索クエリを実行します（Lazy Loading時）。

---

## 2. お気に入りに紐づく権限 (Permissions) を同時取得する

### 💡 ORMソースコード (PHP)
```php
public function jointPermissions(): HasMany
{
    return $this->hasMany(JointPermission::class, 'entity_id', 'favouritable_id')
        ->whereColumn('favourites.favouritable_type', '=', 'joint_permissions.entity_type');
}
```

### 🔍 変換後の生SQL
```sql
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
```

### 📝 解説・対比のポイント
*   **whereColumnによるポリモーフィックHasMany**:
    通常、`hasMany` は単一の外部キー（`entity_id = favouritable_id`）のみで結合しますが、ポリモーフィックのままで結合するために、Laravelの `whereColumn()` を用いて `favourites.favouritable_type = joint_permissions.entity_type` の条件も追加します。
    生SQLでは、`ON` 句の中に `AND` 条件としてきれいに2カラムの結合式がマッピングされます。
