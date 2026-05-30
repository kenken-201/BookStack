# 01-Bookshelf.md (多対多リレーションと中間テーブル操作)

元のモデルファイル: [Bookshelf.php](file:///Users/sasaki/Desktop/progDoc/バックエンド/BookStack/app/Entities/Models/Bookshelf.php)

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

## 🛠️ Eloquentモデルの基本構成とプロパティの解説

`Bookshelf` モデルのクラス宣言直後にある、メタデータ宣言や設定値の意味と役割を、Kotlinでの設計アプローチと対比しながら解説します。

```php
class Bookshelf extends Entity implements HasDescriptionInterface, HasCoverInterface
{
    use HasFactory;
    use ContainerTrait;

    public float $searchFactor = 1.2;

    protected $hidden = ['pivot', 'image_id', 'deleted_at', 'description_html', 'priority', 'default_template_id', 'sort_rule_id', 'entity_id', 'entity_type', 'chapter_id', 'book_id'];
    protected $fillable = ['name'];
}
```

### 1. `use HasFactory;` / `use ContainerTrait;` (トレイトの利用)
*   **PHPでの役割**: **「Trait（トレイト）」による多重継承のシミュレート（コードの再利用）**。
    PHPは単一継承の言語であるため、複数の独立したクラス間で共通のプロパティやメソッドを使い回す仕組みとして「Trait」があります。クラス内で `use Trait名;` を宣言すると、そのTraitの中身がそのままコンパイル時にクラス内へコピペされたかのように動作します。
    *   `HasFactory`: テストデータ生成用のFactoryクラス（`Bookshelf::factory()`）を有効化するLaravel標準のトレイト。
    *   `ContainerTrait`: BookStackが独自に実装した、「配下にコンテンツを持つことができるコンテナ（本棚、ブック、章）」に共通する独自メソッド群。
*   **Kotlinでの対比**: **「インターフェースのデフォルト実装」** や **「Delegation（`by` キーワードによるデリゲーション）」** に極めて近いです。
    Kotlinではインターフェース自体にメソッドの具象処理を書けるため、PHPのTraitと同じようなアプローチで共通機能の多重インポートが可能です。

### 2. `public float $searchFactor = 1.2;` (独自パラメータ)
*   **PHPでの役割**: **BookStackの検索ロジック用のエンティティ重み付け設定**。
    これはLaravelの機能ではなく、BookStack独自のプロパティです。検索エンジン（`SearchRunner`）がキーワード検索を行った際、ヒットしたエンティティの基本スコアにこの係数（本棚は1.2倍、本やページは異なる数値）を掛け合わせ、検索結果の優先順位をコントロールするために使われます。
*   **Kotlinでの対比**: 単なる「クラスのメンバープロパティ（初期値設定）」と同じです。

### 3. `protected $hidden = [...]` (JSON変換時のシリアライズ除外)
*   **PHPでの役割**: **APIやJSONレスポンスへのシリアライズ時に隠すカラムのブラックリスト**。
    `$bookshelf->toJson()` が呼び出された際や、APIコントローラーでモデルがそのまま返された際に、フロントエンドやセキュリティ上露出させたくないデータベース内の内部ID（`image_id`, `book_id` 等）やソフトデリートフラグ（`deleted_at`）などを自動でマスキングして取り除きます。
*   **Kotlinでの対比**: JacksonやMoshi等のシリアライザで使用する **`@JsonIgnore`** アノテーションを、クラス内に一括設定しているのと本質的に同一です。

### 4. `protected $fillable = ['name'];` (一括代入のホワイトリスト)
*   **PHPでの役割**: **一括代入（Mass Assignment）が可能なカラムの指定**。
    Laravelでは、クライアントから送られたリクエストパラメータ（Map形式）を `$bookshelf->fill($request->all())` や `Bookshelf::create(...)` で直接モデルに流し込んで保存することが多くあります。
    このとき、悪意のあるユーザーがHTTPリクエストを改ざんし、予期しないシステム管理フィールド（例: `is_admin = true` や `id = 999`）を強制上書きして保存するセキュリティ脆弱性（Mass Assignment 脆弱性）を防ぐため、**「一括で書き換えても安全なカラム（ホワイトリスト）」** として `name` のみを指定しています。これ以外のカラムは、`forceFill()` を使わない限り一括代入が弾かれます。
*   **Kotlinでの対比**: Kotlinでは「一度DTOに受け取り、そのDTOの安全なプロパティのみをドメインモデルのコンストラクタに引き渡す」ことで安全性を担保するのが主流です。Laravelでは、そのDTOによる型安全な保護レイヤーの代わりに、この `$fillable` というモデル側の設定で脆弱性を防止しています。

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
*   **多対多関係の結合**: Laravelの `belongsToMany` を使用すると、内部的にベーステーブルと中間テーブルが `INNER JOIN` されます。Kotlin/Roomでは、中間テーブル用の `@Entity` を別途定義して `@Relation` で紐付けるのが近いですが、Laravelでは `belongsToMany` 一行で完結します。
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
*   **attach() メソッド**: 多対多リレーションに新たな関係レコードを追加する際、Laravelは中間テーブルに対して直接 `INSERT` 文を実行します。なお、関係の削除には `detach()`、全件差し替えには `sync()` を使います。
*   **contains() による重複チェック**: `appendBook` はまず `$this->contains($book)` で既に本棚に含まれているかを確認します。これは内部的に `COUNT(*)` クエリを実行し、中間テーブルの一意性をアプリケーション側で担保しています。
*   **COALESCE**: `MAX(order)` が `NULL` （本がまだ１冊もない場合）の時にエラーを防ぐため、SQLでは `COALESCE` を用いてデフォルト値 `0` を返します。
