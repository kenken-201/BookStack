# Colima & Docker コマンド チートシート

このプロジェクト（BookStack）の開発環境を構築・操作するための、よく使うColimaおよびDockerコマンドをまとめました。

## 1. Colima の基本操作

Colimaは、Mac上で軽量にDocker環境を動かすためのツール（Docker Desktopの代替）です。

| 目的               | コマンド                          | 解説                                                               |
| :----------------- | :-------------------------------- | :----------------------------------------------------------------- |
| **Colimaの起動**   | `colima start`                    | 開発を始めるときに最初に実行します。（初回は少し時間がかかります） |
| **Colimaの停止**   | `colima stop`                     | 開発が終わってPCのメモリを解放したい時に実行します。               |
| **ステータス確認** | `colima status`                   | Colimaが現在起動しているか（Running）を確認します。                |
| **詳細設定で起動** | `colima start --cpu 4 --memory 8` | CPUやメモリのリソースを指定して起動したい場合に使います。          |

---

## 2. BookStack環境のDocker操作

このプロジェクトのルートディレクトリで実行するコマンドです。

| 目的                   | コマンド                       | 解説                                                                               |
| :--------------------- | :----------------------------- | :--------------------------------------------------------------------------------- |
| **コンテナ群の起動**   | `docker-compose up -d`         | バックグラウンドで全コンテナ（app, db, node, mailhog等）を起動します。             |
| **コンテナ群の停止**   | `docker-compose down`          | コンテナを停止・削除します。（DBのデータは保持されます）                           |
| **コンテナ群の再構築** | `docker-compose up -d --build` | Dockerfileなどを書き換えた場合や、初回構築時にイメージをビルドし直して起動します。 |
| **ログの確認**         | `docker-compose logs -f`       | 全コンテナのログをリアルタイムで表示します。（終了は `Ctrl+C`）                    |
| **特定のログ確認**     | `docker-compose logs -f app`   | `app` (PHP) コンテナなど、特定のコンテナのみのログを追います。                     |
| **稼働状況の確認**     | `docker-compose ps`            | 現在動いているコンテナの一覧とポート番号などを確認します。                         |

---

## 3. コンテナ内での作業（キャッチアップによく使うコマンド）

Docker環境内で artisan コマンドや npm コマンドを実行する方法です。

### 💻 App (PHP / Laravel) コンテナ

BookStackの本体（PHP）が動いているコンテナです。Laravelのコマンドはここに対して打ち込みます。

- **コンテナ内に入る（シェルに入る）**

  ```bash
  docker-compose exec app bash
  ```

  ※中に入ってから `php artisan migrate` などが実行できます。

- **外から artisan コマンドを実行する**（中に入らなくて済むので便利です）

  ```bash
  docker-compose exec app php artisan migrate
  docker-compose exec app php artisan tinker
  docker-compose exec app php artisan ide-helper:generate
  ```

- **Composer コマンド**
  ```bash
  docker-compose exec app composer install
  ```

### 📦 Node コンテナ

フロントエンドのアセット（JS/CSS）をビルドするためのコンテナです。

- **依存パッケージのインストール**

  ```bash
  docker-compose exec node npm install
  ```

- **アセットのビルド（開発用）**
  ```bash
  docker-compose exec node npm run build
  ```
  ※package.jsonのscriptsにあるコマンドを実行します。

### 🗄 DB (MySQL) コンテナ

- **DBコンテナに入る**
  ```bash
  docker-compose exec db bash
  ```
- **MySQLに直接接続する**
  ```bash
  docker-compose exec db mysql -u bookstack-test -pbookstack-test bookstack-dev
  ```

---

## 💡 開発の流れ（一日の始まりと終わり）

**🌅 開発を始めるとき**

```bash
colima start
docker-compose up -d
```

⇒ ブラウザで `http://localhost:8080` (デフォルト設定の場合) にアクセス。
メール（Mailhog）の確認は `http://localhost:8025` 。

**🌃 開発を終えるとき**

```bash
docker-compose down
colima stop
```
