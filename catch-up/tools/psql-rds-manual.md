# PostgreSQL (psql) × AWS RDS 操作マニュアル

AWS EC2 から RDS (PostgreSQL) を操作する際に抑えておくべきコマンドや操作方法を、優先度（High / Middle / Low）に分類して網羅的にまとめました。

---

## 🔴 Priority: High (接続・基本操作・日常的なCRUD)

RDSに繋いでデータを確認・操作するために、まず最初に必ず覚えるべきコマンド群です。

### EC2 から RDS への接続
- **`psql -h <RDSエンドポイント> -U <ユーザー名> -d <DB名>`**
  RDSへの基本的な接続コマンドです。エンドポイントはAWSコンソールのRDS画面から確認できます。
  ```
  psql -h mydb.xxxxxxxxxxxx.ap-northeast-1.rds.amazonaws.com -U postgres -d myapp
  ```
- **`psql "host=<エンドポイント> dbname=<DB名> user=<ユーザー名> sslmode=require"`**
  接続文字列形式。本番環境ではSSL接続を強制するのが推奨です。
- **`export PGPASSWORD='<パスワード>'`**
  パスワード入力を省略したい場合に環境変数にセット（スクリプトでの自動化時に利用。履歴に残る点に注意）。

### psql メタコマンド（バックスラッシュコマンド）
psql 内で使用する、データベースの構造を素早く確認するための特殊コマンドです。
- **`\l`** : データベースの一覧を表示
- **`\c <DB名>`** : 別のデータベースに切り替え
- **`\dt`** : 現在のデータベース内のテーブル一覧を表示
- **`\dt+`** : テーブル一覧をサイズ情報付きで表示
- **`\d <テーブル名>`** : テーブルの構造（カラム名、データ型、制約など）を表示
- **`\d+ <テーブル名>`** : テーブルの詳細情報（ストレージ設定、説明など）も含めて表示
- **`\di`** : インデックスの一覧を表示
- **`\du`** : ユーザー（ロール）の一覧を表示
- **`\q`** : psql を終了

### 基本的な SQL 操作
- **SELECT（データ取得）**
  ```sql
  SELECT * FROM users LIMIT 10;
  SELECT id, name, email FROM users WHERE status = 'active' ORDER BY created_at DESC;
  SELECT COUNT(*) FROM orders WHERE created_at >= '2026-01-01';
  ```
- **INSERT（データ挿入）**
  ```sql
  INSERT INTO users (name, email) VALUES ('田中太郎', 'tanaka@example.com');
  ```
- **UPDATE（データ更新）**
  ```sql
  UPDATE users SET status = 'inactive' WHERE last_login_at < '2025-01-01';
  ```
  ※ 本番環境では **必ず先に SELECT + WHERE で対象行を確認** してから実行すること。
- **DELETE（データ削除）**
  ```sql
  DELETE FROM users WHERE id = 123;
  ```
  ※ UPDATE と同様、事前確認を徹底すること。

### トランザクション（本番作業の安全策）
本番RDSでの更新系操作は、**必ずトランザクション内で実行** するのが鉄則です。
```sql
BEGIN;
  UPDATE users SET status = 'suspended' WHERE id = 456;
  -- 結果を確認
  SELECT * FROM users WHERE id = 456;
  -- 問題なければ確定、問題があれば取り消し
COMMIT;   -- 確定
ROLLBACK; -- 取り消し（COMMITの代わりに実行）
```

---

## 🟡 Priority: Middle (調査・分析・パフォーマンス確認)

障害対応やパフォーマンスチューニング、データ分析で頻繁に使うコマンド群です。

### psql の便利メタコマンド
- **`\x`** : 拡張表示モードのON/OFF切り替え。カラム数が多いテーブルを縦に見やすく表示する。
- **`\timing`** : クエリの実行時間を表示するようにトグル。パフォーマンス確認に必須。
- **`\i <ファイルパス>`** : SQLファイルを読み込んで実行。
- **`\o <ファイルパス>`** : クエリ結果をファイルに出力（`\o` のみで出力先をターミナルに戻す）。
- **`\e`** : 外部エディタ（`$EDITOR`、デフォルトは vi）でクエリを編集して実行。長いSQLを書く際に便利。
- **`\pset format csv`** : 出力をCSV形式に変更。データのエクスポートに活用。
- **`\watch <秒数>`** : 直前のクエリを指定した秒数間隔で繰り返し実行（監視用途）。

### クエリのパフォーマンス分析
- **`EXPLAIN <SQL>`** : クエリの実行計画を表示する（実際には実行しない）。
- **`EXPLAIN ANALYZE <SQL>`** : **【超重要】** クエリを実際に実行し、実行計画と実測の実行時間を比較して表示する。スロークエリの原因調査に必須。
  ```sql
  EXPLAIN ANALYZE SELECT * FROM orders WHERE user_id = 100;
  ```
  実行計画で `Seq Scan`（フルスキャン）が出ていたらインデックス追加を検討する。

### 接続・セッション管理
実行中のクエリの確認やスタックしたセッションの強制終了に使います。
```sql
-- 現在の接続セッション一覧と実行中のクエリを確認
SELECT pid, usename, client_addr, state, query, query_start
FROM pg_stat_activity
WHERE datname = current_database()
ORDER BY query_start;

-- 特定のクエリ/セッションをキャンセル（安全な方法）
SELECT pg_cancel_backend(<PID>);

-- セッションを強制終了（キャンセルが効かない場合の最終手段）
SELECT pg_terminate_backend(<PID>);
```

### テーブルの統計情報
```sql
-- テーブルごとの行数・ディスクサイズ概算
SELECT relname AS table_name,
       n_live_tup AS estimated_rows,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC;

-- インデックスの使用状況（使われていないインデックスの特定）
SELECT indexrelname, idx_scan, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;
```

### データのエクスポート / インポート
- **psql からCSVエクスポート**
  ```sql
  \COPY (SELECT * FROM users WHERE status = 'active') TO '/tmp/active_users.csv' WITH CSV HEADER;
  ```
- **CSVからインポート**
  ```sql
  \COPY users (name, email) FROM '/tmp/import_users.csv' WITH CSV HEADER;
  ```
- **EC2 コマンドラインからの一括実行**
  ```bash
  psql -h <エンドポイント> -U postgres -d myapp -c "SELECT COUNT(*) FROM users;"
  psql -h <エンドポイント> -U postgres -d myapp -f /path/to/migration.sql
  ```

---

## 🔵 Priority: Low (バックアップ・復元・高度な管理)

DBのバックアップ/リストアや、スキーマ変更、高度な運用管理で使うコマンド群です。

### pg_dump / pg_restore（論理バックアップ）
RDSの自動スナップショットとは別に、論理的なバックアップ/リストアを行う場合に使います。
- **データベース全体のダンプ**
  ```bash
  pg_dump -h <エンドポイント> -U postgres -d myapp -Fc -f myapp_backup.dump
  ```
  `-Fc` はカスタム形式（圧縮あり・pg_restoreで復元可能）。
- **特定テーブルのみダンプ**
  ```bash
  pg_dump -h <エンドポイント> -U postgres -d myapp -t users -Fc -f users_backup.dump
  ```
- **スキーマのみダンプ（データなし）**
  ```bash
  pg_dump -h <エンドポイント> -U postgres -d myapp --schema-only -f schema.sql
  ```
- **リストア**
  ```bash
  pg_restore -h <エンドポイント> -U postgres -d myapp_restore -Fc myapp_backup.dump
  ```

### スキーマ変更（DDL）
```sql
-- カラム追加
ALTER TABLE users ADD COLUMN phone VARCHAR(20);

-- カラムのデータ型変更
ALTER TABLE users ALTER COLUMN phone TYPE TEXT;

-- インデックス作成（本番では CONCURRENTLY を推奨）
CREATE INDEX CONCURRENTLY idx_users_email ON users (email);

-- インデックス削除
DROP INDEX idx_users_email;
```
※ `CONCURRENTLY` を付けると、テーブルロックを最小限にしてインデックスを作成できる（本番環境での定番テクニック）。

### ロック・デッドロックの調査
```sql
-- ロック待ちになっているクエリを特定
SELECT blocked.pid AS blocked_pid,
       blocked.query AS blocked_query,
       blocking.pid AS blocking_pid,
       blocking.query AS blocking_query
FROM pg_stat_activity AS blocked
JOIN pg_locks AS bl ON bl.pid = blocked.pid
JOIN pg_locks AS kl ON kl.locktype = bl.locktype
  AND kl.relation = bl.relation
  AND kl.pid != bl.pid
  AND NOT kl.granted
JOIN pg_stat_activity AS blocking ON blocking.pid = kl.pid
WHERE NOT bl.granted;
```

### RDS 固有の注意点
- **スーパーユーザー権限がない**: RDS では `rds_superuser` ロールが最上位。`pg_hba.conf` の直接編集はできない。
- **パラメータグループ**: `postgresql.conf` に相当する設定はAWSコンソールの「パラメータグループ」から変更する。
- **拡張機能の有効化**:
  ```sql
  CREATE EXTENSION IF NOT EXISTS pg_stat_statements;  -- クエリ統計
  CREATE EXTENSION IF NOT EXISTS pgcrypto;             -- 暗号化関数
  ```
- **`pg_stat_statements` で遅いクエリTOP10を確認**:
  ```sql
  SELECT query, calls, mean_exec_time, total_exec_time
  FROM pg_stat_statements
  ORDER BY mean_exec_time DESC
  LIMIT 10;
  ```

### 接続のベストプラクティス
- **`~/.pgpass` ファイル**: パスワードを安全に保存してログインを自動化する。
  ```
  # ホスト:ポート:DB名:ユーザー名:パスワード
  mydb.xxxx.ap-northeast-1.rds.amazonaws.com:5432:myapp:postgres:MySecretPass
  ```
  ファイル作成後 `chmod 600 ~/.pgpass` で権限を設定すること。
- **`~/.psqlrc` ファイル**: psql 起動時のデフォルト設定をカスタマイズ。
  ```
  \timing on
  \x auto
  \pset null '(NULL)'
  \set PROMPT1 '%n@%M:%>/%/ %# '
  ```
