# MDPro3 本地 Rush Duel 人机 —— 调研交接包

> 这个仓库是为了**跨设备继续开发**而建的。
> 换到新电脑后，先读本文件，再读 `docs/01-可行性分析.md` 和 `docs/02-技术链路与代码证据.md`。

---

## 仓库地址与恢复方式

- **仓库**：<https://github.com/pandipper/ygopro-rd-handoff>（**私有**）
- **SSH**：`git@github.com:pandipper/ygopro-rd-handoff.git`

在另一台电脑上：

```bash
git clone https://github.com/pandipper/ygopro-rd-handoff.git
cd ygopro-rd-handoff
# 然后按顺序读：README.md → docs/01 → docs/02 → docs/03
```

> 若是首次在该机器上克隆私有库，需要先登录 GitHub 账号
> （Windows 会弹出 git-credential-manager 浏览器授权；或配置 Personal Access Token）。

---

## 目标

在 **MDPro3** 的"本地 AI 对战"模式里，切换到 **Rush Duel（超速决斗）** 规则，
与 **Rush Duel 牌组机器人**对战。

现状：目前只能连指定服务器 → "添加 AI"，跟少数几个固定牌组机器人打。
诉求：把这个能力搬到 MDPro3 的**本地人机**里，并且能自己写新的 RD 牌组机器人。

---

## 一句话结论

**方向可行，架构上没有硬阻塞。** 但有三点必须先对齐（详见 `docs/01`）：

1. **MDPro3 的本地 AI 是 WindBot（C#）**，牌组 AI 不是 Lua。
2. 生态里**确实另有一套 Lua AI**（YGOPro Percy 的 `ai/ai.lua` + `ai/decks/*.lua`），
   但 MDPro3 里只留了个空壳（`PercyOCG.StartAI()` 被注释）。
3. **Rush Duel 是"数据扩展 + 一条全局规则脚本"，没有模式开关**——
   装了 RD 扩展，本地人机就会全部变成 RD。

---

## 目录导航

```
docs/
├── 01-可行性分析.md          总体结论、四个仓库定位、可行性逐项判断、分阶段方案
├── 02-技术链路与代码证据.md   ★ 事实底稿：每条结论都带源码位置
└── 03-待办与待确认.md         ★ 下一步做什么、要问用户什么、阶段 0 操作清单

src/
├── windbot/                  完整（C# 决斗机器人，上游 IceYGO/windbot）
├── ygopro-rush-duel/         完整（RD 数据扩展：3 cdb + 3086 lua + conf）
├── YGOMobile-cn-ko-en/       已裁剪（去掉 irrlicht 与第三方 C 库，保留客户端代码）
└── MDPro3/                   仅关键文件 + 完整文件树 + 按需拉取脚本（见其 README）

tools/
└── fetch-mdpro3.sh           通过 GitLab API 按需拉取 MDPro3 文件（list/file/dir/tree）

notes/
└── 调研笔记-2026-09-30.md    当时的调研过程记录
```

---

## 核心结论速查

### MDPro3 本地人机的实现

```
SoloSelector.LaunchWithConfig
  ├─ YgoServer.StartServer(args)      进程内启动 YGOPro 服务器（ygoserver.dll）
  ├─ TcpHelper.LinkStart(127.0.0.1)   玩家连本地
  └─ WindBot.Program.Main(args)       后台线程起内置 WindBot，连同一端口
```

三者走 **本地 TCP（127.0.0.1）**。与"连远程服务器加 AI"是同一套协议模型。

启动参数：`port -1 5 0 F F F <lp> <hand> <draw> 0 0`
（`rule=5` 是**大师规则 2020**，**不是** RD 开关；本地服务器没有任何 RD 参数。）

### RD 是怎么生效的

```
ygoserver/single_duel.cpp:578
    preload_script(pduel, "./script/special.lua");     ← 服务器模式下无条件执行
        ↓ 脚本查找顺序（data_manager.cpp: ScriptReaderEx）
    specials/  →  expansions/script/  →  script/
        ↓
    special.lua → Duel.LoadScript("RDRule.lua") ...
                 → Auxiliary.PreloadUds() → RushDuel.Init()
        ↓
    RDRule.lua 用 EFFECT_* 全局效果改写规则
    （召唤次数 100 / 抽到 5 张 / 无 SP·MP2 / 手牌无上限 / 极大召唤 ...）
```

卡库加载（`game.cpp: LoadExpansions()`）：
`./cdb/*.cdb` → `./Data/locales/zh-CN/*.cdb` → `./expansions/*.cdb`

### 为什么机器人能打 RD

RD 的所有"选择"都落到标准协议消息：

```lua
-- RDFunction.lua
function RushDuel.Select(...)
    return group:SelectSubGroup(player, check, cancelable, min, max, ...)
end
```

→ `MSG_SELECT_CARD` / `MSG_SELECT_UNSELECT_CARD` / `MSG_SELECT_SUM`

WindBot 已有 `OnSelectCard` / `OnSelectSum` / `OnSelectUnselectCard` / `OnSelectIdleCmd`
等通用回调 → **协议层天然兼容，机器人不需要理解 RD 规则**。

### 真正的活在哪

不是"改规则"，而是 **写 RD 牌组 AI**。而 WindBot 的牌组 AI **是 C#**：

```
Assets/Scripts/Windbot/Game/AI/Decks/XxxExecutor.cs
    [Deck("RD-XXX", "AI_RdXxx")]
    class RdXxxExecutor : DefaultExecutor { ... }
```

---

## 下一步（当前卡在哪）

**卡在第一步：判定用户手上的"RD 卡组机器人 lua"属于哪套 AI。**

拿到文件后，按 `docs/03-待办与待确认.md` 第二节的判据表判定：

- 含 `require("ai.mod.` 或 `AI.SelectCard` → **Percy Lua AI**（需先给 MDPro3 接线）
- 含 `class XxxExecutor : DefaultExecutor` 或 `AddExecutor(ExecutorType.` → **WindBot（C#）**
- 只有 `initial_effect` / `c<id>.lua` 结构 → 只是卡片脚本，不是 AI

判定结果决定后续路线，见 `docs/03`。

---

## 环境备忘

- 上游仓库地址
  - MDPro3：<https://code.moenext.com/sherry_chaos/MDPro3>
  - YGOMobile-cn-ko-en：<https://github.com/fallenstardust/YGOMobile-cn-ko-en>
  - ygopro-rush-duel：<https://code.moenext.com/mycard/ygopro-rush-duel>
  - windbot：<https://github.com/IceYGO/windbot>
- MDPro3 使用 **Unity 6000.0.10f1**；改 C# 需要重新编译
- `code.moenext.com` 的 GitLab API 无需鉴权即可读公开仓库；
  但 `search` 接口需要 token（返回 401）
- YGOMobile 的本地 AI 同样是 WindBot（`libWindbot.aar` + `runWindbot()`），
  与 MDPro3 一致

---

## 收录范围说明（哪些被裁掉了）

| 项目 | 处理 | 说明 |
|---|---|---|
| `src/windbot` | 完整 | 仅去掉 `.git` |
| `src/ygopro-rush-duel` | 完整 | 仅去掉 `.git` |
| `src/YGOMobile-cn-ko-en` | **已裁剪** | 去掉 `.git`、`irrlicht/`、`Classes/{openssl,sqlite3,libsndfile,freetype,openal,libevent,mpg123}`、`mobile/assets/data/{textures,sound}`。保留 `Classes/{gframe,ocgcore,lua}`、`mobile/src`、`mobile/assets/data/windbot` 等 |
| `src/MDPro3` | **仅关键文件** | Unity 工程太大且 clone 不稳定；附完整文件树 + `tools/fetch-mdpro3.sh` 按需拉取 |

被裁掉的部分都是**第三方库或游戏美术资源**，需要时可从上游重新获取。
