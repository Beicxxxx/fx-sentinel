# 远程仓库

**以 GitHub 为主。** Origin 只是 Cursor 侧的一份拷贝，名称应对齐为 `fx-sentinel`。

| 角色 | 仓库 |
|---|---|
| 主仓（日常 clone / Release） | https://github.com/Beicxxxx/fx-sentinel |
| Origin（Cursor Codebase） | 应对齐为 `beichen-li/fx-sentinel`（不要再用 `forex-mind` 或临时 `tmp-*` 仓当主线） |

GitHub 用户名是 `Beicxxxx`，Origin 命名空间是 `beichen-li`，**所有者前缀可以不同**，仓库名必须都是 `fx-sentinel`。

## 在本机（WSL）把 Origin 对齐到 GitHub

Origin CLI 的云端 token 不能改仓。请在 WSL 登录后执行。

### 方案 A：从 GitHub 建 Origin 镜像（名字直接叫 fx-sentinel）

```bash
origin auth login
origin repo create-mirrored Beicxxxx/fx-sentinel --namespace beichen-li
origin repo clone beichen-li/fx-sentinel
```

若提示仓已存在，改用方案 B。

### 方案 B：已有 `beichen-li/forex-mind` 时，先灌入 GitHub 再改名

```bash
origin repo clone beichen-li/forex-mind
cd forex-mind
git remote add github https://github.com/Beicxxxx/fx-sentinel.git
git fetch github
git checkout -B main github/main
git push origin main --force
```

然后在 https://cursor.com/codebase/beichen-li/forex-mind 的设置里把仓库**重命名为 `fx-sentinel`**。设置页若不能改名，用方案 A 建新仓，旧的 `forex-mind` 不要再推。

之后日常：

```bash
git clone https://github.com/Beicxxxx/fx-sentinel.git
# 需要 Cursor Origin 时再 origin repo clone beichen-li/fx-sentinel
```

只向 GitHub `main` 发功能提交；Origin 用上面的 fetch + force-push 同步，或依赖 `create-mirrored` 的镜像关系。
