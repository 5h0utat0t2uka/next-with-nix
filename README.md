このリポジトリは `nix`, `direnv`, `dotenvx` を利用して **Next.js** の開発環境を、異なるOSや開発者の環境で再現するためのサンプルです

- `node`や`npm`がインストール済みの場合、既存のバージョンから隔離された開発環境にする
- 環境変数は暗号化された状態でgitで管理して、復号化のためのキーのみを開発者間で共有する
- 事前にロックファイルから `osv-scanner` を利用して脆弱性を確認する

---

## 1. `nix` のインストール  
すでにインストール済みの場合はスキップしてください
```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

シェルの再起動後にバージョンを確認
```sh
exec $SHELL
nix --version
```

## 2. `direnv` のインストール  
すでにインストール済みの場合はスキップしてください
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

## 1. リポジトリのクローン
```sh
git clone <repo-url>
cd next-with-nix
```

## 2. `dotenvx` を利用した環境変数管理  
このサンプルでは `.env.development`, `.env.production` を **dotenvx** で暗号化した上でgit管理する前提です  
そのためこの2つを復号するための `DOTENV_PRIVATE_KEY_DEVELOPMENT`, `DOTENV_PRIVATE_KEY_PRODUCTION` の値をコピーして、以下のコマンドで`.secrets/`の中に用意して、開発時にロードされるようにします
```sh
mkdir -p .secrets
printf '%s' '<development 用の復号鍵>' > .secrets/dotenv_private_key_development
printf '%s' '<production 用の復号鍵>' > .secrets/dotenv_private_key_production
chmod 600 .secrets/dotenv_private_key_development
chmod 600 .secrets/dotenv_private_key_production
```

## 3. `direnv` の有効化  
このリポジトリには `.envrc` が含まれています  
これによってディレクトリに入ると自動的に環境変数が読み込まれるので、以下のコマンドで許可します
```sh
direnv allow
```

初回の許可を行うと `.envrc` の `use flake` で `flake.nix` が評価されるので、下記でnodeのバージョンが表示されれば正常です  
```sh
which node # /nix/store/xxx-nodejs-24.11.1/bin/node
node -v    # v24.x
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
> `npm run dev` は内部的に `dotenvx run -f .env.development -- next dev` として `dotenvx` を経由して実行され、暗号化された `.env.development` が自動的に復号・展開されます
