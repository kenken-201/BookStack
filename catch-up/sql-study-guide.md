# Laravel SQL & Eloquent 実践学習ガイド（厳選7ファイル）

LaravelでのSQL操作（Eloquent ORM、クエリビルダ、マイグレーション、トランザクション）を、BookStackの洗練されたソースコードから最も効率よく（タイパ重視で）学ぶための「厳選7ファイル」です。

初級のCRUDから、中級のリレーション、そして生SQLやサブクエリJOINを駆使する超上級クエリまで、難易度・テーマ順に並べています。

---

## 🗺️ SQL学習ロードマップ（全体像）

```
[初級] ── ① Bookshelf.php (リレーション・多対多)
           │
           ▼
[中級] ── ② Favourite.php (ポリモーフィックリレーション)
           │
           ▼
[中級] ── ③ BaseRepo.php (一括代入・保存ライフサイクル)
           │
           ▼
[上級] ── ④ DatabaseTransaction.php (トランザクションと分離レベル)
           │
           ▼
[上級] ── ⑤ migrate_entity_data.php (高速バルクインサート移行)
           │
           ▼
[上級] ── ⑥ TagRepo.php (MySQL関数を用いた動的集計クエリ)
           │
           ▼
[超上級] ─ ⑦ SearchRunner.php (サブクエリJOIN・検索スコア動的算出)
```

---

## 1. 【初級】多対多リレーションと中間テーブル操作
### 📂 ファイル: [Bookshelf.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Entities/Models/Bookshelf.php)
*   **主なテーマ**: Eloquentにおける「多対多（N対N）」リレーションの定義とピボット操作。
*   **ここから学べること**:
    *   `belongsToMany()` による中間テーブルを介したリレーションシップの定義方法。
    *   `withPivot('order')` を用いて、中間テーブル（Pivot）に持たせた追加カラムを取得する仕組み。
    *   `attach($bookId, ['order' => $maxOrder + 1])` を使い、中間テーブルにアソシエーションデータを挿入する処理。
*   **キャッチアップのポイント**:
    「本棚とブック」というもっとも分かりやすい関係性を通じて、Laravelにおけるテーブル結合の基本と、リレーション先のデータを操作する作法が一発で理解できます。

---

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

## 4. 【上級】データベーストランザクションと分離レベル
### 📂 ファイル: [DatabaseTransaction.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Util/DatabaseTransaction.php)
*   **主なテーマ**: トランザクション処理による一貫性保持と競合回避。
*   **ここから学べること**:
    *   `DB::transaction(Closure)` を用いた、例外発生時に自動でロールバックするクロージャ型トランザクション。
    *   トランザクション開始前に `DB::statement('SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED')` を実行し、トランザクションの分離レベルをスマートに変更する実装。
*   **キャッチアップのポイント**:
    データ整合性が極めて重要な権限再生成処理などのデッドロックを防ぎ、安全に並行処理させるための堅牢なSQL設計の裏側が分かります。

---

## 5. 【上級】バルクインサートによる高速データ移行
### 📂 ファイル: [2025_09_15_134701_migrate_entity_data.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/database/migrations/2025_09_15_134701_migrate_entity_data.php)
*   **主なテーマ**: クエリビルダを使用した超高速なETL処理（データ移行）。
*   **ここから学べること**:
    *   `DB::beginTransaction()` と `DB::commit()` を明示的に使う手動トランザクション制御。
    *   `DB::table('...')->insertUsing(...)` を用いた、PHPのメモリを消費しない「他テーブルからのサブクエリ付き高速バルクインサート（SELECT INSERT）」。
    *   `whereNotIn` の条件に別のクエリビルダインスタンス（サブクエリ）を引き渡して、整合性の取れないデータを一瞬でUPDATEでクリーンアップする実戦テクニック。
*   **キャッチアップのポイント**:
    本番環境のデータベース構造を大規模アップデートする際に、数秒〜数ミリ秒で数万件のデータを一気に移行するためのクエリビルダの真の実力が学べます。

---

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
