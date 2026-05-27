# Kotlin開発者のためのPHP & Laravel文法対比ガイド

Kotlinでの開発経験があるあなたが、PHPおよびLaravelのソースコード（BookStackなど）を最短で理解し、タイパよくキャッチアップするための文法・記法対比ガイドです。

Kotlinの強力でクリーンな文法と対比させながら、PHP特有の記号やLaravelの「魔法」のような記法を1つずつ紐解きます。

---

## 1. 最も重要な演算子の対比表

まずは一番戸惑いやすい記号（演算子）の対比です。

| PHPの記法 | Kotlinの記法 | 役割 | 具体例（PHP vs Kotlin） |
| :--- | :--- | :--- | :--- |
| **`->`** | **`.`** | **インスタンスメンバーへのアクセス** (プロパティ/メソッド) | `$user->save()` <br> `user.save()` |
| **`::`** | **`.`** (または静的アクセス) | **静的メンバー/クラス定数へのアクセス**、クラス名取得 | `User::class` <br> `User::class.java` |
| **`=>`** | **`to`** | **連想配列（Map）のキーと値の定義** | `['name' => 'John']` <br> `mapOf("name" to "John")` |
| **`.`** (ドット) | **`+`** | **文字列の結合** (★最も間違いやすいポイント) | `'Hello ' . $name` <br> `"Hello " + name` |
| **`??`** | **`?:`** | **Null合体演算子（エルビス演算子）** (Nullなら右辺を返す) | `$name = $input ?? 'Guest'` <br> `val name = input ?: "Guest"` |
| **`?->`** | **`?.`** | **Null安全なプロパティ/メソッドアクセス** (Null安全コール) | `$user?->profile?->image` <br> `user?.profile?.image` |

---

## 2. 徹底解説：`auth()->check()` のアロー演算子（`->`）とは？

ご質問いただいた `auth()->check()` の処理について、Kotlinと対比して構造を分解します。

```php
protected function isSignedIn(): bool
{
    return auth()->check();
}
```

### ① `auth()` （ヘルパー関数）
*   **PHP/Laravel**: `auth()` はLaravelがグローバルに提供している**ヘルパー関数**です。
*   **Kotlinでのイメージ**: プロジェクトのどこからでも呼べるトップレベル関数 `auth()` に相当します。この関数は、認証処理を担当するオブジェクト（インスタンス）を返します。
    ```kotlin
    // Kotlinイメージ
    val authInstance = getAuthService() 
    ```

### ② `->` （アロー演算子）
*   **PHP**: `->` は、オブジェクトのメソッドやプロパティを呼び出す演算子です。**Kotlinの「 `.` （ドット）」と全く同じ**です。
*   **なぜ `.` じゃないの？**: PHPでは `.` は「文字列を結合する演算子」として予約されているため、オブジェクトへのアクセスには `->` という記号が使われます。

### ③ `check()` （メソッド）
*   **PHP**: 認証オブジェクトが持つ「現在ユーザーがログインしているか？」を調べるメソッド（真偽値を返す）です。

### 🔄 Kotlinと並べて比較すると：
```php
// PHP
auth()->check()
```
```kotlin
// Kotlin (イメージ)
auth().check()
```
こう見ると、全く同じ構造であることが分かりますね！

---

## 3. Kotlinと比較で覚えるPHP/Laravelの重要文法

Kotlin開発者がPHPコードを読む際に「おや？」となりやすい文法をピックアップして解説します。

### A. 変数宣言の `$`
PHPのローカル変数は、常に先頭に `$` がつきます。Kotlinの `val` / `var` のような明示的な区別はありません（すべて再代入可能です）。
*   **PHP**: `$age = 30;`
*   **Kotlin**: `var age = 30` (再代入可能) または `val age = 30` (再代入不可)

---

### B. 連想配列（PHP） vs Map（Kotlin）
PHPでは、Kotlinの `List` も `Map` も、すべて `array`（配列）という単一のデータ構造で表現されます。キーと値を紐付けるのが **`=>`**（ダブルアロー）です。

*   **PHP (連想配列)**:
    ```php
    $user = [
        'name' => 'Sasaki',
        'role' => 'Developer'
    ];
    ```
*   **Kotlin (Map)**:
    ```kotlin
    val user = mapOf(
        "name" to "Sasaki",
        "role" to "Developer"
    )
    ```

---

### C. 静的アクセス `::`（ダブルコロン）
クラスの静的メソッドの呼び出しや、クラスの完全修飾名（クラス名文字列）を取得する際に使われます。

*   **PHP (静的メソッド呼び出し)**:
    ```php
    // クラスの静的メソッド
    Book::where('id', 1)->first();
    
    // クラス名（型）自体の取得
    $className = Book::class; // "BookStack\Entities\Models\Book" が返る
    ```
*   **Kotlin**:
    ```kotlin
    // 静的メソッド (companion object等)
    Book.where("id", 1).first()
    
    // クラス名（型）自体の取得
    val classObj = Book::class
    ```

---

### D. Null安全と「エルビス演算子」
PHP 8.0以降、Kotlinとほぼ同等のNull安全機構がサポートされています。

*   **Null安全コール (`?->` vs `?.`)**:
    *   **PHP**: `$user?->profile?->address`
    *   **Kotlin**: `user?.profile?.address`
*   **Null合体演算子 / エルビス演算子 (`??` vs `?:`)**:
    *   **PHP**: `$theme = $config ?? 'default';`
    *   **Kotlin**: `val theme = config ?: "default"`

---

### E. 文字列補間（テンプレート）
ダブルクォーテーション `"` で囲んだ文字列の中では、変数をそのまま展開できます。シングルクォーテーション `'` では展開されません（ただの文字列になります）。

*   **PHP**:
    ```php
    $name = 'Sasaki';
    echo "Hello, {$name}!"; // 出力: Hello, Sasaki!
    echo 'Hello, {$name}!'; // 出力: Hello, {$name}! (展開されない)
    ```
*   **Kotlin**:
    ```kotlin
    val name = "Sasaki"
    println("Hello, $name!")   // 出力: Hello, Sasaki!
    println("Hello, ${name}!") // 同上
    ```

---

## 4. Laravel特有の「ファサード（Facade）」と「魔法」

Laravelには、KotlinやJavaの静的型付けの世界にはない **「ファサード（Facade）」** という非常に強力で独特な仕組みがあります。BookStackのコードにも頻繁に登場します。

### ファサードとは？
例えば、先ほどの `auth()->check()` は、以下のように書くこともできます。

```php
use Illuminate\Support\Facades\Auth;

// ファサードを使った記述
Auth::check();
```

一見すると `Auth` クラスの静的（`static`）メソッド `check()` を呼び出しているように見えます。
しかし、実際には `Auth` クラスに `check` という静的メソッドは存在しません。

#### 🪄 Laravelの裏で起きていること：
1.  Laravelが `Auth::check()` の呼び出しを検知する。
2.  裏側で「サービスコンテナ（DIコンテナ）」から実際の認証インスタンス（実体）を取り出す。
3.  そのインスタンスの非静的メソッド `check()` に処理を自動転送する。

### Kotlin開発者へのアドバイス
これはKotlinでいう **「シングルトンオブジェクト（`object`）のメソッド呼び出し」** に非常に近い感覚で使えます。
「静的メソッドっぽく見えて、裏ではDIされたインスタンスのメソッドが動いているんだな」と理解しておけば、テスト時やコードリーディング時に混乱せずに済みます。

---

## 5. LaravelのDI（依存注入）とPHP 8のコンストラクタ

BookStackのコントローラー等で頻繁に目にする、依存関係の自動注入の仕組みと文法について、Kotlinと対比します。

### A. コンストラクタのプロパティ昇格 (Constructor Property Promotion)
`BookController` などのコンストラクタ定義には、一見不思議な記法があります。

```php
public function __construct(
    protected ShelfContext $shelfContext,
    protected BookRepo $bookRepo,
) {
}
```

これはPHP 8.0で導入された「**コンストラクタのプロパティ昇格**」という文法です。
コンストラクタの引数に `protected` や `private` を書くことで、**「メンバ変数の宣言」「引数の受け取り」「メンバ変数への代入」をすべて1箇所で自動的に行う**仕様です。

*   **Kotlinでの完全な等価表現**:
    Kotlinのプライマリコンストラクタと**全く同じ概念・動作**です！
    ```kotlin
    class BookController(
        protected val shelfContext: ShelfContext,
        protected val bookRepo: BookRepo
    ) : Controller()
    ```
    Kotlinを知っているあなたからすれば、むしろ一番自然に頭に入ってくる文法のはずです。

### B. 自動依存注入（DIコンテナの魔法）
上記のコンストラクタに対し、あなた自身が `new BookController(...)` と手動でインスタンス化コードを書くことはありません。
Laravelの「DIコンテナ（サービスコンテナ）」が、型宣言（Type Hinting）を頼りに、必要なクラスのインスタンスを自動的に作成・解決してコンストラクタに流し込んでくれます。

*   **Kotlin (Spring Bootなど) でのイメージ**:
    Spring Frameworkの `@Autowired` やコンストラクタインジェクションと同様です。型を定義しておくだけで自動的に適切なBean（インスタンス）が差し込まれます。

### C. アクションメソッドへの自動注入 (Method Injection)
Laravelでは、コンストラクタだけでなく、コントローラーの個別のメソッド（アクション）に対してもDIが機能します。
`BookController@show` の引数リストを見てみましょう。

```php
public function show(Request $request, ActivityQueries $activities, string $slug)
```

この時、Laravelは以下のハイブリッドな解決を行います：
1.  **型宣言がある引数 (`Request $request`, `ActivityQueries $activities`)**:
    DIコンテナからインスタンスを自動的に解決して注入します。
2.  **型宣言がない、またはルーティングパラメータに一致する変数 (`string $slug`)**: 
    `routes/web.php` で定義されたプレースホルダー（`/books/{slug}`）に入力された実際の値（例: `my-book`）を、引数の名前（`$slug`）にマッピングして自動で引き渡します。

これにより、コントローラーのメソッド内は余計なインスタンス化やURLパラメータの解析処理を挟むことなく、ビジネスロジックに集中できるスマートな作りになっています。

<details><summary>BookController@showについての詳細解説</summary>

### 1. DIコンテナは「どのように」用いられているか？

LaravelのDIコンテナ（サービスコンテナ）は、コントローラーが動作する際に **「引数の型（型宣言/Type Hinting）」をリフレクションで自動解析し、必要なインスタンスを裏側で作成・注入** しています。

`BookController` では、これが **「コンストラクタ」** と **「メソッド（アクション）」** の2箇所で機能しています。

#### ① コンストラクタでの自動注入 (Constructor Injection)
`BookController` のコンストラクタは以下のようになっています。

```php
public function __construct(
    protected ShelfContext $shelfContext,
    protected BookRepo $bookRepo,
    protected BookQueries $queries,
    // ...
) {}
```
これはPHP 8の「**コンストラクタのプロパティ昇格**」という文法で、Kotlinのプライマリコンストラクタと全く同じです。

```kotlin
// Kotlinでの等価表現 (プライマリコンストラクタ)
class BookController(
    protected val shelfContext: ShelfContext,
    protected val bookRepo: BookRepo,
    protected val queries: BookQueries,
    // ...
) : Controller()
```

Laravelがこのコントローラーを動かす際、引数の型（`ShelfContext`, `BookRepo` など）を見て、コンテナからそれぞれの実体（インスタンス）を自動で解決し、コンストラクタに流し込みます。
そのため、開発者は手動で `new` する必要がなく、コントローラー内ではいつでも `$this->bookRepo` や `$this->queries` を使ってこれらにアクセスできます。

#### ② アクションメソッドでの自動注入 (Method Injection)
`show` メソッドの引数リストは以下の通りです。

```php
public function show(Request $request, ActivityQueries $activities, string $slug)
```

ここでは、Laravelが非常にスマートな「**ハイブリッド解決**」を行っています。

1.  **型宣言がある引数 (`Request $request`, `ActivityQueries $activities`)**
    DIコンテナが自動的にインスタンスを作成・解決して注入します。
2.  **型宣言がない、またはルーティングパラメータに一致する引数 (`string $slug`)**
    `routes/web.php` の `/books/{slug}` という定義に基づき、URLから抽出された実際の文字列（例: `my-book`）を名前ベースで自動マッピングして渡します。

---

### 2. どういうルールで「Repos（リポジトリ）」が呼び出されているか？

実は、`show` メソッドの中身を注意深く見ると、**`BookRepo`（リポジトリ）のメソッドは一度も呼び出されていません**。
その代わり、`$this->queries`（`BookQueries`）というクラスが使われています。

```php
// showメソッド内でのデータ取得処理
$book = $this->queries->findVisibleBySlugOrFail($slug);
```

ここに、BookStackの極めて綺麗で一貫した **「CQRS（コマンド・クエリ責務分離）」** ライクな設計ルールが存在します。

#### 💡 BookStackのデータアクセス・ルール
BookStackでは、データベースとやり取りするロジックを「読み取り」と「書き込み」で明確に分離しています。

| レイヤー | 担当する役割 | 主に使われるコントローラーのメソッド |
| :--- | :--- | :--- |
| **`Queries` (参照系)** | データの**取得・検索・絞り込み**。DBからの読み出し専用。 | `index` (一覧), `show` (詳細), `edit` (編集画面の表示) |
| **`Repos` (更新系)** | データの**作成・更新・削除**。ビジネスロジックを伴う状態変更。 | `store` (新規作成), `update` (更新処理), `destroy` (削除) |

#### 実際のコントローラーコードでの使い分け：
*   **詳細表示 (`show` メソッド) — [参照系]**
    データをDBから読み出すだけなので、`BookQueries` を使います。
    `$this->queries->findVisibleBySlugOrFail($slug)`
*   **新規登録 (`store` メソッド) — [更新系]**
    データの新規作成（状態の変更）を行うため、`BookRepo` を使います。
    `$this->bookRepo->create($validated)`
*   **更新処理 (`update` メソッド) — [更新系]**
    データの書き換えを行うため、`BookRepo` を使います。
    `$book = $this->bookRepo->update($book, $validated)`

### 🌟 Kotlin開発者としての視点でのまとめ
Kotlin (あるいはJavaのSpring Frameworkなど) に慣れているsasakisさんから見れば、この構造は **「Spring Bootのコンストラクタインジェクション」や「読み取り専用サービス（Read-only Service）と更新用サービス（Write Service）の分割」と本質的に全く同じ** です。

PHP特有の記号（`->` や `$`）さえクリアできれば、背後で動いているオブジェクト指向やDIの設計思想はすでに馴染みのあるものばかりですので、恐れる必要は全くありません！

この流れを意識した上で、改めて `BookController@show` のコードを眺めてみてください。非常に見通しが良く感じられるはずです！
</details>

---

## 6. キャッチアップのためのまとめ
*   PHPの **`->`** は、Kotlinの **`.`** と全く同じ！
*   PHPの **`::`** は、Kotlinの **`.` (静的アクセス / companion object)** や **`::class`** に相当！
*   PHPの **`=>`** は、Kotlinの **`to` (Mapの定義)** と同じ！
*   PHPの **`.`** は文字列結合！Kotlinの **`+`** に相当するので注意！
*   PHP 8の **`__construct(protected ...)`** は、Kotlinの **プライマリコンストラクタ `(protected val ...)`** と全く同じ！
*   **型宣言（Type Hinting）** を引数に書いておくだけで、LaravelのDIコンテナが自動的にインスタンスを解決・注入してくれる！

これさえ頭に入れておけば、BookStackのコントローラーやモデルのコードが、驚くほどスラスラ読めるようになります！
さらに深く知りたい文法や、BookStack固有の実装があれば、いつでも気軽に聞いてくださいね。
