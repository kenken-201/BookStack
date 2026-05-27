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

## 5. キャッチアップのためのまとめ
*   PHPの **`->`** は、Kotlinの **`.`** と全く同じ！
*   PHPの **`::`** は、Kotlinの **`.` (静的アクセス / companion object)** や **`::class`** に相当！
*   PHPの **`=>`** は、Kotlinの **`to` (Mapの定義)** と同じ！
*   PHPの **`.`** は文字列結合！Kotlinの **`+`** に相当するので注意！

これさえ頭に入れておけば、BookStackのコントローラーやモデルのコードが、驚くほどスラスラ読めるようになります！
さらに深く知りたい文法や、BookStack固有の実装があれば、いつでも気軽に聞いてくださいね。
