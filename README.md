## 構成  
このリポジトリは `nix`, `direnv`, `dotenvx`, `pnpm` を利用して、セキュアな **Next.js** の開発環境を、異なるOSや開発者間の環境で再現するためのサンプルです  

[`direnv`を利用したローカルホスト環境](#ローカルホスト環境で開発する場合)と、[`devcontainer`を利用したコンテナ環境](#コンテナ環境で開発する場合)いずれも、環境の定義は`nix`で行われるため差分が発生しません  

### 開発環境の趣旨と概要  
- 各ユーザー環境の`node`や`pnpm`のインストール有無に関わらず、既存のバージョンから隔離された共通の開発環境にする
- `osv-scanner` を利用して、依存関係をインストールする前にロックファイルからパッケージの脆弱性を確認する
- サプライチェーン攻撃・パッケージ汚染の対策として、信用するパッケージを除いてレジストリ公開後24時間未満のパッケージをインストールしない  
> [!NOTE]
> 悪意のあるパッケージは多くの場合レジストリ公開後数時間程度で削除されるため、インストール自体を未然に防ぐための対策です  
- インストール時の`preinstall`や`postinstall`などのビルドスクリプトは、明示的に許可したパッケージ以外は実行させない  
> [!NOTE]
> インストール時のスクリプトをトリガとする感染を防ぐための対策です  

### 機密情報の取り扱い  
このリポジトリでは`dotenvx`で`.env*`の内容を暗号化して、復号鍵を[infisical](https://infisical.com/)で管理する事で、プロジェクト内に平文のシークレット関連が存在しない状態にしています  
[infisical](https://infisical.com/)を利用していれば、環境変数はランタイムでインジェクト出来るので`dotenvx`を利用するのは冗長ですが、[infisical](https://infisical.com/)を無償で利用可能な範囲を超えた場合の対策として用意しています  

もし`dotenvx`のみで運用する場合、復号鍵の取り扱いは`.envrc`で読み込まれる`.envrc.local`で下記のように読み込ませることで展開することが可能です  
`.envrc.local`は`.gitignore`の対象ですが「プロジェクト内に平文の復号鍵が存在する」状態になってしまうことに留意してください
``` sh
export DOTENV_PRIVATE_KEY_DEVELOPMENT="開発環境の復号鍵"
export DOTENV_PRIVATE_KEY_PRODUCTION="本番環境の復号鍵"
```

<!--[infisical](https://infisical.com/)以外にも[doppler](https://www.doppler.com/)など類似サービスはありますが、どれも有償か無償であっても何かしら制限があります  

チーム開発を前提とした場合にチーム内の足並みを揃えることが可能であれば[pass](https://www.passwordstore.org/)を利用することで、開発者のローカル環境のプロジェクト外（ホームディレクトリ）に暗号化したパスワードストアを作成して、以下のように復号鍵を展開することが可能です
``` sh
export DOTENV_PRIVATE_KEY_DEVELOPMENT="$(
  pass show path/to/repository/password-store/DEVELOPMENT | head -n 1
)"
export DOTENV_PRIVATE_KEY_PRODUCTION="$(
  pass show path/to/repository/password-store/PRODUCTION | head -n 1
)"
```

この方法は外部サービスのストアに頼らず無償で管理することが可能な反面、運用や導入コストは高くなりますが、セキュリティリスクとのトレードオフになります-->

---

## ローカルホスト環境で開発する場合  
すでに`nix`, `direnv`をインストール済みの場合はスキップしてください

### 1. 必要なパッケージのインストール  
```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
brew install direnv
```

シェルの再起動後にバージョンを確認
```sh
exec $SHELL
nix --version
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

### 2. リポジトリのクローン
```sh
git clone <このリポジトリ>
cd next-with-nix
```

### 3. 環境変数の管理  
前述のようにこのサンプルでは `.env.development`, `.env.production` を **dotenvx** で暗号化した上でgitで管理します  

これらの復号鍵 `DOTENV_PRIVATE_KEY_DEVELOPMENT`, `DOTENV_PRIVATE_KEY_PRODUCTION` を開発時にロードされるようにしますが、以下の2つのパターンがあります  

#### (1) `infisical`から復号鍵を利用する場合  
以下のコマンドで`infisical`をインストールしてログイン
``` sh
brew install infisical/get-cli/infisical
```
`infisical`にログイン
``` sh
infisical login
```

#### (2) `dotenvx`のみを利用する場合  
**安全な経路**で `.envrc.local` ファイルを受け取って、プロジェクトのルートに `.envrc.local` を配置  
```sh
cp /path/from/.envrc.local ./envrc.local
```
`package.json` の `scripts` から`infisical`を取り除いて以下のように変更
```json
"scripts": {
  "dev": "dotenvx run -f .env.development -- next dev",
  "start": "dotenvx run -f .env.production -- next start",
  "build": "dotenvx run -f .env.production -- next build",
  "lint": "biome check .",
  "format": "biome format --write .",
  "scan": "osv-scanner scan source -r ."
},
```

### 4. `direnv` の有効化  
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
> [!IMPORTANT]
> `node` の参照が `/nix/store/` で始まるパスになってることを確認してください

### 5. 依存関係のインストールと開発サーバの起動  
通常通り以下のコマンドで依存のインストールと起動を行います  
この際 `nr scan` を実行して脆弱性を確認し、問題なければインストールを行います
```sh
nr scan # 脆弱性確認
nci     # インストール
nr dev  # 起動
```
> [!NOTE]
> このリポジトリではパッケージマネージャーのコマンドを統一するために[ni](https://github.com/antfu-collective/ni)を利用しています  
> `nr dev` は内部的に `dotenvx run -f .env.development -- next dev` として `dotenvx` を経由して実行され、`[dotenvx@1.51.2] injecting env` のように暗号化された `.env.development` が自動的に展開されます  

---

## コンテナ環境で開発する場合
すでに`docker`, `devcontainers/cli`をインストール済みの場合はスキップしてください

### 1. 必要なパッケージのインストール  
```sh
brew install docker colima
npm install -g @devcontainers/cli
```
> [!NOTE]
> ランタイムに`colima`を利用する場合  

### 2. リポジトリのクローン
```sh
git clone <このリポジトリ>
cd next-with-nix
```

### 3. `docker` ランタイムとコンテナを起動
```sh
colima start
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash
```

### 4. コンテナ内から開発サーバの起動  
```sh
nix develop
pnpm install --frozen-lockfile
pnpm dev
```

---

## 開発と運用

### 1. 環境変数の確認と変更・追加
既存の`SOME_VAR`を確認する場合
```sh
DOTENV_PRIVATE_KEY=DOTENV_PRIVATE_KEY_DEVELOPMENT nlx dotenvx get SOME_VAR -f .env.development
```

既存の`SOME_VAR`を更新あるいは新しく追加する場合
```sh
nlx dotenvx set SOME_VAR "value" -f .env.development
```

### 2. バージョン管理
`node`を例として`nix`の`devShells`で管理してるパッケージのバージョン管理用法  

#### メジャーバージョンを上げる場合  
1. `flake.nix`の`packages`内のリストの`nodejs_24`を`nodejs_26`などに変更
2. `nix flake update`で`flake.lock`を更新
3. `direnv reload`を行い反映
4. `node -v`でバージョン確認

#### マイナーバージョンを上げる場合  
1. `flake.nix`は変更せず`nix flake update`を実行
2. `nixpkgs`の参照先が最新コミットになり、その中に含まれる「24系で最も新しいバージョン」が取得される
3. `node -v`でバージョン確認

#### 特定のバージョンを指定する場合
`nix`では`nodejs_24`を指定することで、常にその時の最新バージョンを取得します  
特定バージョンで固定するには、以下の手順で直接参照する必要があります  
1. [nixhub](https://www.nixhub.io/) などで、目的のバージョンが含まれるリファレンスのコミットハッシュをコピー
2. `flake.nix`の`inputs`に以下のように追記
```nix
inputs = {
  # 特定のバージョンが含まれるコミットハッシュを指定して input を追加（24.11.0の場合）
  nixpkgs-node-fixed.url = "github:NixOS/nixpkgs/1d4c88323ac36805d09657d13a5273aea1b34f0c";
};
```
3. `flake.nix`の`outputs`で以下のように引数を追加して、パッケージの更新
```nix
outputs = { self, nixpkgs, flake-utils, git-hooks, nixpkgs-node-fixed, ... }:

# 中略

let
  pkgs = import nixpkgs { inherit system; };
  # 追加した input をそのシステム用に import する
  pkgs-fixed = import nixpkgs-node-fixed { inherit system; };
in

# 中略

devShells.default = pkgs.mkShell {
  packages = with pkgs; [
    # pkgs-fixed から nodejs を取り出す
    pkgs-fixed.nodejs_24
    pnpm
    ni
    git
    biome
    osv-scanner
  ];
  shellHook = ''
    ${preCommit.shellHook}
    echo "node: $(node -v)"
    echo "pnpm: $(pnpm -v)"
  '';
};
```
3. `nix flake update`で`flake.lock`を更新
4. `direnv reload`を行い反映
5. `node -v`でバージョン確認
