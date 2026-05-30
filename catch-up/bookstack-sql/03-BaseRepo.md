# 03-BaseRepo.md (標準的なデータ保存フロー (CRUD))

元のリポジトリファイル: [BaseRepo.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Entities/Repos/BaseRepo.php)

## 3. 【中級】標準的なデータ保存フロー（CRUD）
### 📂 ファイル: [BaseRepo.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Entities/Repos/BaseRepo.php)
*   **主なテーマ**: リポジトリ層でのモデルの新規作成・更新ライフサイクル。
*   **ここから学べること**:
    *   `$entity->fill($input)` による複数カラムの安全な一括代入（Mass Assignment）。
    *   `forceFill()` による、モデルの保護ガードを一時的にバイパスしたデータ書き込み。
    *   `save()`, `touch()`, `refresh()` の実戦的な使い分け。
*   **キャッチアップのポイント**:
    実務で最も頻繁に実装する「フォームからの入力を受け取って安全にレコードを保存する」という処理の、お手本のようなベストプラクティスが学べます。


---

## 1. 新規レコードの挿入 (create)

### 💡 ORMソースコード (PHP)
```php
public function create(Entity $entity, array $input): Entity
{
    // 引数で渡されたインスタンスを汚染しないよう clone し、
    // refresh() でDBから最新の空状態に初期化する
    $entity = (clone $entity)->refresh();
    $entity->fill($input);            // $fillable で許可されたカラムのみ代入
    $entity->forceFill([              // $fillable ガードをバイパスして代入
        'created_by' => user()->id,
        'updated_by' => user()->id,
        'owned_by'   => user()->id,
    ]);
    $this->refreshSlug($entity);      // スラッグ自動生成

    if ($entity instanceof HasDescriptionInterface) {
        $this->updateDescription($entity, $input);  // 説明文の処理
    }

    $entity->save();                  // ★ ここで初めて INSERT が実行される

    // --- save() 後の後続処理 ---
    if (isset($input['tags'])) {
        $this->tagRepo->saveTagsToEntity($entity, $input['tags']); // タグの保存
    }
    $entity->refresh();               // DB側で自動生成された値（ID等）を再取得
    $entity->rebuildPermissions();     // 権限テーブルの再構築
    $entity->indexForSearch();         // 全文検索インデックスの更新
    $this->referenceStore->updateForEntity($entity);

    return $entity;
}
```

### 🔍 変換後の生SQL
```sql
-- ===== Step 1: エンティティ本体の INSERT =====
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
    :name,        -- 画面から入力された名前（$fillable で保護された安全な値）
    :slug,        -- システムによって自動生成された一意なスラッグ
    :user_id,     -- 作成したユーザーのID (created_by) ※forceFill経由
    :user_id,     -- 最後に更新したユーザーのID (updated_by) ※forceFill経由
    :user_id,     -- 所有者ユーザーのID (owned_by) ※forceFill経由
    NOW(),        -- レコード作成日時 (Eloquentが自動設定)
    NOW()         -- レコード更新日時 (Eloquentが自動設定)
);

-- ===== Step 2: タグの保存（入力にタグがある場合） =====
-- 既存タグを全削除してから新規タグを一括INSERT
DELETE FROM tags WHERE entity_id = :entity_id AND entity_type = :entity_type;
INSERT INTO tags (entity_id, entity_type, name, value) VALUES
    (:entity_id, :entity_type, 'Status', 'Draft'),
    (:entity_id, :entity_type, 'Priority', 'High');

-- ===== Step 3: 権限テーブルの再構築 =====
-- joint_permissions テーブルに対して、新エンティティのアクセス権を計算・挿入

-- ===== Step 4: 全文検索インデックスの更新 =====
-- search_terms テーブルにエンティティの名前・説明文を分解して格納
```

### 📝 解説・対比のポイント
*   **`(clone $entity)->refresh()` の意味**:
    PHPの `clone` はオブジェクトのシャローコピーを作成します。引数で渡されたインスタンスの状態を汚染しないようにクローンを作り、`refresh()` でDBから最新の空状態に再読込します。Kotlinでは `data class` の `.copy()` に近い操作ですが、PHPには `copy()` が無いため `clone` を使います。
*   **fill() vs forceFill()**:
    `fill()` は `$fillable` で許可されたカラムのみセットし、`forceFill()` はガードを無視して全カラムをセットします。いずれもメモリ上の操作で、DBに反映されるのは `save()` 呼び出し時です。
*   **save() 後の連鎖処理**:
    Laravel/BookStackでは `save()` の後に権限再構築や検索インデックス更新など、複数の後続処理が走ります。これらはSQLレベルではそれぞれ独立したクエリとして実行されます。
*   **タイムスタンプの自動設定**:
    Eloquentはデフォルトで `created_at` と `updated_at` を自動設定します（`$timestamps = true`）。

---

## 2. 既存レコードの更新 (update)

### 💡 ORMソースコード (PHP)
```php
public function update(Entity $entity, array $input): Entity
{
    $oldUrl = $entity->getUrl();       // 変更前のURLを保持（参照更新に使用）

    $entity->fill($input);             // 許可されたカラムのみ一括代入
    $entity->updated_by = user()->id;  // 直接代入（$fillable 不要）

    if ($entity->isDirty('name') || empty($entity->slug)) {
        $this->refreshSlug($entity);   // 名前変更時のみスラッグ再生成
    }

    if ($entity instanceof HasDescriptionInterface) {
        $this->updateDescription($entity, $input);
    }

    $entity->save();                   // ★ ここで UPDATE が実行される

    // --- save() 後の後続処理 ---
    if (isset($input['tags'])) {
        $this->tagRepo->saveTagsToEntity($entity, $input['tags']);
        $entity->touch();              // タグ更新時は updated_at も更新
    }
    $entity->indexForSearch();         // 検索インデックスの再構築

    if ($oldUrl !== $entity->getUrl()) {
        $this->referenceUpdater->updateEntityReferences($entity, $oldUrl);
    }

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
*   **touch() の役割**:
    `touch()` は `updated_at` を現在時刻に更新するだけの軽量なメソッドです。タグの変更はエンティティ本体のカラムには影響しないため、「このエンティティが最近更新された」ことを明示するために `touch()` を呼んでいます。
*   **直接代入 vs fill()**:
    `$entity->updated_by = user()->id;` のように個別に直接代入する場合は `$fillable` のガードが適用されません。`fill()` のガードはあくまで「配列による一括代入」に対する保護です。
