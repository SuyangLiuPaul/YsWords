# 版本号、发布与密钥 —— 四个 app 共用的一套做法

写于 2026-09-17，起因是「版本 naming convention 是什么我要一并给另一个
app 也这样」「包括 secret 这些存在哪里 Drive 怎么存之类的」。

这份文档写的是**已经在跑的做法**，不是提案。四个 app 都照这个走：

| app | 仓库 | 线上 |
|---|---|---|
| 雅伟之言 YsWords | `SuyangLiuPaul/Yahwehs-Words` | yahwehword.com |
| 雅伟之剑 SeekSparks | `SuyangLiuPaul/Yahwehs-Sword` | sword.yahwehword.com |
| 雅伟之界 Yahweh's World | `SuyangLiuPaul/yahwehs-globe` | world.yahwehword.com |
| 新闻洞见 News Insight | `SuyangLiuPaul/News-Insight` | newsinsight.yahwehword.com |

（最后一个的仓库名是旧的。没改：一改仓库地址、发布脚本和已经发出去的
链接都要跟着动，而仓库名不面向用户。）

---

## 一、版本号

### 形状

`pubspec.yaml` 里是 `x.y.z+n`。`x.y.z` 是对外的版本，`+n` 是 Android 的
`versionCode`，只能增不能减。

### 什么时候动

**只有在要 release 或者 push prod 的时候才动。** 2026-09-16 定的规矩：
「除非我叫你 release 和 prod push 否则版本号码不要变」。

理由不是洁癖。版本号是**发布标记**，不是进度计数器：应用内的更新检查
和 changelog 都读它，一个没有对应发布的版本号，等于告诉每一个用户
"有东西上线了"，而其实什么都没有。

### 那 dev 版怎么区分

dev 版显示 `1.6.11.7` —— 第四段是**从上一个 `v*` tag 到现在的 commit
数**。它是**算出来的**，不是存的：没有东西要 bump，没有东西会忘记改，
也不可能和它构建自的那棵树不一致。

```bash
git rev-list "$(git describe --tags --abbrev=0)..HEAD" --count
```

第四段只进**显示**的版本（`--dart-define=APP_VERSION=`），绝不进
pubspec。`version.json`、APK 的 `versionCode`、iOS 重装脚本读的版本
缓存、`verify_site`，读到的都还是干净的 `1.6.11`。
`UpdateService._parse` 只取**前三段**，所以 `1.6.11.7` 在任何比较里
都等于 1.6.11。

### tag

`vX.Y.Z`，和 pubspec 里的三段一字不差。

tag 是**不可撤销**的对外承诺（`releases/latest` 立刻指过去，about 页的
下载按钮立刻跟着变），所以两个仓库的打 tag 脚本都**拒绝在 CI 不是绿的
时候打 tag**，而且必须是**这一个 SHA** 的 CI 绿，不是"最近一次绿过"。

没有 CI 的仓库（yahwehs_world 一个 workflow 都没有）用另一种办法：
本地 `analyze` + `test` 顶替 CI，并且**每一个产物都打开来检查里面真的
带着这个版本号**才上传。证明不了自己版本的构建，不发布。

---

## 二、三层站点

| 层 | 权限 |
|---|---|
| **dev** | 随便推，任何改动的一部分 |
| **qat** | dev 验过就推 |
| **prod** | **必须在当前这一轮对话里明确说了 prod 才能推** |

"部署一下"、"发出去"、"release" 都**不算** prod 许可。上一轮说过的
prod 许可**不延续到下一轮**。细则在 `docs/release-policy.md`。

（`tools/release_web.sh` 现在默认**不** bump：`--bump` 是显式开关，
`--no-bump` 留着但已经是空操作。上面那份 2026-05 的 release-policy.md
里写的 `--no-bump` 是那之前的默认值，读到时不必困惑。）

---

## 三、发布产物

一次 release 四件，名字是 **app 的名字**，不是仓库的名字：

```
NewsInsight-Android.apk   NewsInsight-iOS.zip
NewsInsight-macOS.zip     NewsInsight-Web.zip
```

about 页（https://yahwehword.com/about）四个卡片的下载按钮都指
`releases/latest`，**不指具体版本**。这样每次发版不用回头改页面，
也不会出现页面说 1.2.4 而仓库已经 1.2.7 的情况。

---

## 四、Android 签名密钥

### 规矩

**正式包绝不能用 debug key 签。** Flutter 生成工程时留下的那句

```kotlin
signingConfig = signingConfigs.getByName("debug")   // TODO
```

必须换掉。那张证书写的是 `CN=Android Debug, O=Android, C=US`：
它谁也证明不了，而且全世界每一台装了 Flutter 的机器都握着同一把私钥,
任何人都能造一个 Android 愿意装上去的"更新"。

四个 app 换掉的日子：雅伟之剑 2026-08-25，雅伟之言 2026-09-09，
雅伟之界和新闻洞见 2026-09-17。

### 怎么建

```bash
keytool -genkeypair -v -keystore <app>-release.keystore -storetype PKCS12 \
  -alias <app> -keyalg RSA -keysize 4096 -sigalg SHA384withRSA \
  -validity 10000 \
  -dname "CN=Paul Liu, O=<App Name>, L=Melbourne, C=AU"
```

（这台机器上 `/usr/bin/keytool` 是个找不到 JRE 的壳，
用 `/opt/homebrew/opt/openjdk@17/bin/keytool`。）

### 构建时怎么找到它

`android/app/build.gradle.kts` 按顺序找两个地方，都没有就**退回 debug
签名并打一条响亮的警告**：

1. `android/key.properties` —— Flutter 的惯例，已经被 .gitignore 掉
2. `~/.config/yswords/secrets/<app>-key.properties`

退回是**故意的**：没有钥匙的机器（新 clone、CI runner）还要能打出可以
侧载的测试包。但那样打出来的包不能发布 —— 警告里就是这么写的。

### 换 key 的一次性代价

Android 拒绝安装签名不一致的更新。所以换 key 之后，**所有已装的用户
都必须先卸载再装一次**。这就是为什么要趁装的人少的时候换。

同理，**密钥丢了不能补办**，没有任何办法。所以有三份：本机、
`~/Documents/secure-keys-backup/`、Google Drive。

### 怎么验

这些 APK **没有 v1 签名**，所以 `keytool -printcert -jarfile` 什么都
不打印 —— 不要把它的沉默当成"没签名"。用 apksigner：

```bash
$(ls -d /opt/homebrew/share/android-commandlinetools/build-tools/*/apksigner | tail -1) \
  verify --print-certs -v app-release.apk
```

要看到 `Signer #1 certificate DN:` 是自己那一行，
`SHA-256 digest` 和 keystore 里的一致。

---

## 五、密钥放哪里

### 三个地方，各有各的角色

| 位置 | 放什么 | 角色 |
|---|---|---|
| `~/.config/yswords/secrets/` | keystore、`*-key.properties`、`*.env` | **构建时真正读的那一份** |
| `~/Documents/secure-keys-backup/` | 同上的镜像 | 本机第二份，防误删 |
| Drive `我的云端硬盘/PasswordManager/<项目>/` | 同上 + `说明.txt` | 防这台机器没了 |

GitHub 的 `gh` token 在**钥匙串**里，不在文件里。
Netlify / Resend / Gemini 这些走 **Netlify 环境变量**，不落盘。

### Drive 那一份长什么样

```
PasswordManager/
  SeekSparks-YsWords/   seeksparks-release.keystore  seeksparks-key.properties
                        yswords-release.jks  yswords-android-key.properties  说明.txt
  yahwehs-globe/        …
  NewsInsight/          newsinsight-release.keystore
                        newsinsight-key.properties  说明.txt
```

`说明.txt` 每一把钥匙至少写清楚：

- **本机路径**（以及镜像在哪）
- **用途**（给什么签名 / 哪个服务用）
- **alias**
- **证书主体** DN
- **有效期**
- **SHA-256 指纹**（这个是公开信息，它本来就在每个 APK 里）
- **丢了会怎样**

口令不另写一份，就在同目录的 `key.properties` 里 —— 那个文件同时也是
gradle 直接读的格式，拷回 `~/.config/yswords/secrets/` 就能用，
不用手抄，也就不会抄错。

### 记忆文件里不放钥匙

`~/.claude/.../memory/` 里的文件**只放指路，不放 token**。
指纹可以写（公开），口令和 token 不写。

---

## 六、给一个新 app 照着做的清单

1. `pubspec.yaml` 用 `x.y.z+n`；显示版本走 `--dart-define`，dev 加第四段。
2. 建一把 4096-bit 的发布密钥，DN 用 app 的名字，写进
   `~/.config/yswords/secrets/`，镜像到 `~/Documents/secure-keys-backup/`，
   再进 Drive 的 `PasswordManager/<项目>/` 并写 `说明.txt`。
3. `build.gradle.kts` 按上面那两个候选路径找 keystore，找不到就退回
   debug 并警告。
4. 发布脚本：先 analyze + test，再构建，**每个产物打开验版本号**，
   最后才 `gh release create`，产物名用 app 的名字。
5. 三层站点，prod 那一层写进 `docs/release-policy.md`。
6. 在 https://yahwehword.com/about 加一张卡片：一个 Open（yahwehword.com
   下的地址）+ 一个 Download（`releases/latest`）。
