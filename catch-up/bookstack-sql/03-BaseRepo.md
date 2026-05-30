# 03-BaseRepo.md (標準的なデータ保存フロー (CRUD))

元のリポジトリファイル: [BaseRepo.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Entities/Repos/BaseRepo.php)

---

## 1. 新規レコードの挿入 (create)

### 💡 ORMソースコード (PHP)
```php
public function create(Entity $entity, array $input): Entity
{
    $entity = (clone $entity)->refresh();
    $entity->fill($input);
    $entity->forceFill([
        'created_by' => user()->id,
        'updated_by' => user()->id,
        'owned_by'   => user()->id,
    ]);
    
    // スラッグ自動生成
    $this->refreshSlug($entity);

    $entity->save();
    return $entity;
}
```

### 🔍 変換後の生SQL
```sql
INSERT INTO entities (
    `type`, 
    `name`, 
    `slug`, 
    `created_by`, 
    `updated_by`, 
    `owned_by`, 
    `created_at`, 
    `updated_at`
) VALUES (
    :type,        -- 'book' や 'page' などのエンティティ種別
    :name,        -- 画面から入力された名前
    :slug,        -- システムによって自動生成された一意なスラッグ
    :user_id,     -- 作成したユーザーのID (created_by)
    :user_id,     -- 最後に更新したユーザーのID (updated_by)
    :user_id,     -- 所有者ユーザーのID (owned_by)
    NOW(),        -- レコード作成日時 (created_at)
    NOW()         -- レコード更新日時 (updated_at)
);
```

### 📝 解説・対比のポイント
*   **一括代入 (fill / forceFill)**:
    Laravelの `fill()` や `forceFill()` はメモリ上での属性セットです。データベースに値が書き込まれるのは、最終的に `save()` メソッドが呼び出された瞬間であり、この時初めて `INSERT` クエリが走ります。
*   **タイムスタンプの自動設定**:
    Eloquentモデルに `public $timestamps = true;` (デフォルト) が設定されている場合、Laravelは自動的に `created_at` と `updated_at` の現在時刻（`NOW()` に相当）をプレースホルダー値に埋め込みます。

---

## 2. 既存レコードの更新 (update)

### 💡 ORMソースコード (PHP)
```php
public function update(Entity $entity, array $input): Entity
{
    $entity->fill($input);
    $entity->updated_by = user()->id;

    if ($entity->isDirty('name') || empty($entity->slug)) {
        $this->refreshSlug($entity);
    }

    $entity->save();
    return $entity;
}
```

### 🔍 変換後の生SQL
```sql
UPDATE 
    entities 
SET 
    -- 変更があったカラム（Dirty属性）のみが動的に列挙されます
    `name` = :new_name,
    `slug` = :new_slug,
    
    -- 更新メタデータと、自動更新される updated_at
    `updated_by` = :updater_user_id,
    `updated_at` = NOW() 
WHERE 
    id = :entity_id;
```

### 📝 解説・対比のポイント
*   **isDirty() による最適化**:
    Eloquentはインスタンスの「元の値」と「現在の値」を比較し、変更があったカラム（Dirtyなカラム）のみを `UPDATE` 文の `SET` 句に含めます。これにより、データベース側の無駄なデータ書き換えとログ生成を最小限に抑えています。
