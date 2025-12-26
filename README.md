このリポジトリは `nix`, `direnv`, `dotenvx` を利用して **Next.js** の開発環境を、異なるOSや開発者の環境で再現するためのサンプルです

- `node`や`npm`がインストール済みの場合、既存のバージョンから隔離された開発環境にする
- 環境変数は`dotenvx`で暗号化された状態でgitで管理する
- `dotenvx`の復号化のキーは[pass](https://www.passwordstore.org)で管理を行い、さらに`gpg`で暗号化して復号鍵をプロジェクトの外に置いた状態にする
- `.envrc`からは`.gitignore`した`.envrc.local`の読み込みだけ行い、`.envrc.local`から`pass show`で復号鍵を展開させる
- 開発者間では`.envrc.local`のみを共有する
- 事前にロックファイルから `osv-scanner` を利用して、インストールするnpm packageの脆弱性を確認する

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
- 既存の`SOME_VAR`を確認する場合
```sh
DOTENV_PRIVATE_KEY=DOTENV_PRIVATE_KEY_DEVELOPMENT npx dotenvx get SOME_VAR -f .env.development
```

- 既存の`SOME_VAR`を更新あるいは新しく追加する場合
```sh
npx dotenvx set SOME_VAR "value" -f .env.development
```

## 2. バージョン管理
`node`を例として`nix`の`devShells`で管理してるパッケージのバージョン管理用法  

### メジャーバージョンを上げる場合  
1. `flake.nix`の`packages`内のリストの`nodejs_24`を`nodejs_26`などに変更
2. `nix flake update`で`flake.lock`を更新
3. `direnv reload`を行い反映
4. `node -v`でバージョン確認

### マイナーバージョンを上げる場合  
1. `flake.nix`は変更せず`nix flake update`を実行
2. `nixpkgs`の参照先が最新コミットになり、その中に含まれる「24系で最も新しいバージョン」が取得される
3. `node -v`でバージョン確認

### 特定のバージョンを指定する場合
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
    git
    biome
    osv-scanner
  ];
  shellHook = ''
    ${preCommit.shellHook}
    echo "node: $(node -v)"
    echo "npm: $(npm -v)"
  '';
};
```
3. `nix flake update`で`flake.lock`を更新
4. `direnv reload`を行い反映
5. `node -v`でバージョン確認
