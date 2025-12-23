このリポジトリは `nix`, `direnv`, `dotenvx` を利用して **Next.js** の開発環境を、異なるOSや開発者の環境で再現するためのサンプルです

- `node`や`npm`がインストール済みの場合、既存のバージョンから隔離された開発環境にする
- 環境変数は暗号化された状態でgitで管理して、復号化のためのキーのみを開発者間で共有する
- 事前にロックファイルから `osv-scanner` を利用して脆弱性を確認する

---

# パッケージのインストール  
すでに`nix`, `direnv`をインストール済みの場合はスキップしてください

## 1. `nix` のインストール  
```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

シェルの再起動後にバージョンを確認
```sh
exec $SHELL
nix --version
```

## 2. `direnv` のインストール  
```sh
brew install direnv
```

シェルへフックの組み込み
`~/.zshrc` 末尾に以下を追記
```sh
eval "$(direnv hook zsh)"
```

シェルの再起動後にバージョンを確認
```sh
exec $SHELL
direnv version
```

---

# 初回の設定と起動  

## 1. リポジトリのクローン
```sh
git clone <このリポジトリ>
cd next-with-nix
```

## 2. `dotenvx` を利用した環境変数の管理  
このサンプルでは `.env.development`, `.env.production` を **dotenvx** で暗号化した上でgitで管理します  
この2つを復号するための `DOTENV_PRIVATE_KEY_DEVELOPMENT`, `DOTENV_PRIVATE_KEY_PRODUCTION` を開発時にロードされるようにします  

1. **安全な経路**で `.env.keys` ファイルを受け取ります  
2. プロジェクトのルートに `.env.keys` を配置して確認  
```sh
cp /path/to/.env.keys ./env.keys
cat .env.keys
```

以下のように各環境のキーが指定されてるか確認してください
```sh
#/------------------!DOTENV_PRIVATE_KEYS!-------------------/
#/ private decryption keys. DO NOT commit to source control /
#/     [how it works](https://dotenvx.com/encryption)       /
#/----------------------------------------------------------/

# .env.development
DOTENV_PRIVATE_KEY_DEVELOPMENT=xxx

# .env.production
DOTENV_PRIVATE_KEY_PRODUCTION=zzz
```

## 3. `direnv` の有効化  
このリポジトリには `.envrc` が含まれています  
これによってディレクトリに入ると自動的に `devShell` 起動されるようになるので、以下のコマンドで許可します
```sh
direnv allow
```

初回の許可を行うと `use nix` が評価され、nix環境の `devShell` が起動します  
このタイミングで必要な依存がインストールされるので、下記でnodeのバージョンが表示されれば正常です  
```sh
which node # /nix/store/xxx-nodejs-24.11.1/bin/node
node -v    # v24.11.1
```
> [!NOTE]
> `node` の参照が `/nix/store/` で始まるパスになってることを確認してください

## 4. 依存関係のインストールと開発サーバの起動  
通常通り以下のコマンドで依存のインストールと起動を行います  
この際 `npm run scan` を実行して脆弱性を確認し、問題なければインストールを行います
```sh
npm run scan  # 脆弱性確認
npm ci
npm run dev
```
> [!NOTE]
> `npm run dev` は内部的に `dotenvx run -f .env.development -- next dev` として `dotenvx` を経由して実行され、`[dotenvx@1.51.2] injecting env` のように暗号化された `.env.development` が自動的に展開されます

---

# 開発と運用

## 1. 環境変数の確認と変更・追加
既存の`SOME_VAR`を確認する場合
```sh
DOTENV_PRIVATE_KEY=DOTENV_PRIVATE_KEY_DEVELOPMENT npx dotenvx get SOME_VAR -f .env.development
```

既存の`SOME_VAR`を更新あるいは新しく追加する場合
```sh
npx dotenvx set SOME_VAR "value" -f .env.development
```

---
