# src/MDPro3 —— 仅收录关键文件（非完整仓库）

## 为什么不是完整仓库

MDPro3 上游：<https://code.moenext.com/sherry_chaos/MDPro3>

它是一个 **Unity 工程**，包含大量美术资源、AssetBundle、纹理、模型，完整体积非常大。
而且该 GitLab 实例：

- 不支持部分克隆（`git clone --filter=blob:none` → `filtering not recognized by server`）
- 全量 `git clone --depth 1` 在本机网络下反复超时/失败

因此本目录只收录**本次调研真正用到的关键源码**，并附上完整文件树与按需拉取脚本。

## 本目录包含什么

### 1. 客户端关键源码（按仓库原始路径摆放）

```
Assets/Scripts/MDPro3/
├── Servant/
│   ├── SoloSelector.cs        本地人机入口（LaunchWithConfig / StartWindBot）
│   ├── OcgCore.cs             对局场景（含 RoomServant.Mode 分支）
│   └── RoomServant.cs         房间状态（Rule / Mode / MasterRule 读取）
├── Duel/
│   ├── CoreWrapper.cs         Percy 命名空间，P/Invoke 直连 ocgcore
│   ├── PercyOCG.cs            Percy AI 空壳（StartAI 被注释）
│   ├── TcpHelper.cs           协议收发
│   └── Message/
│       ├── DuelMessage.cs
│       └── MessageProcessor.cs
├── Game/
│   ├── Program.cs             路径常量（PATH_EXPANSIONS 等）
│   ├── Boot.cs
│   └── CardRenderer/
│       └── CardBuilderRushDuel.cs    ← RD 卡面渲染（证明客户端已支持 RD 显示）
├── Core/Data/
│   ├── FileGroup.cs
│   └── FileGroupConfig.cs     扩展文件（Expansions/*.zip|ypk）配置
└── UI/ServantUI/
    └── SoloSelectorUI.cs      人机设置界面（端口/LP/手牌/抽卡数）
```

### 2. 内置 WindBot（部分）

```
Assets/Scripts/Windbot/Game/
├── GameAI.cs                  决策调度
└── AI/
    ├── DefaultExecutor.cs     通用兜底
    └── DecksManager.cs        牌组注册与发现
```

完整清单见 `WINDBOT-FILE-TREE.txt`（共 100 个文件）。
**注意：MDPro3 内置的 WindBot 比上游 `src/windbot/` 旧**：

| 文件 | 上游 | MDPro3 内置 |
|---|---|---|
| `Game/AI/DefaultExecutor.cs` | 2227 行 | 1828 行 |
| `Game/GameAI.cs` | 1613 行 | 1232 行 |

### 3. 原生核心与服务器（C++，本次重点）

```
Tools/YGO Classes/
├── ocgcore/      C++ 核心源码（24 个文件）
│   ├── interpreter.cpp      脚本加载（constant/utility/procedure）
│   ├── ocgapi.cpp           preload_script 导出
│   ├── libduel.cpp          Lua 侧 Duel.* API 实现
│   ├── field.cpp            场地与流程
│   └── ...
└── ygoserver/    C++ 服务器源码（7 个文件）
    ├── single_duel.cpp      ← 加载 ./script/special.lua（RD 触发点）
    ├── data_manager.cpp     ← 脚本查找顺序 specials/ → expansions/ → script/
    ├── game.cpp             ← LoadExpansions() 卡库加载
    ├── gframe.cpp           ← 命令行参数解析
    └── ...
```

编译产物在仓库里是 `Assets/Plugins/Windows/{ocgcore.dll, ygoserver.dll, sqlite3.dll}`。

### 4. 清单文件

- `FILE-TREE.txt` —— MDPro3 完整文件树（约 4000 条路径，递归拉取所得）
- `WINDBOT-FILE-TREE.txt` —— 内置 WindBot 的全部文件路径

## 如何拉取更多文件

用仓库根目录的 `tools/fetch-mdpro3.sh`：

```bash
# 列某个目录下的文件
./tools/fetch-mdpro3.sh list "Assets/Scripts/Windbot/Game/AI/Decks"

# 下载单个文件
./tools/fetch-mdpro3.sh file "Assets/Scripts/MDPro3/Servant/SettingsServant.cs"

# 下载整个目录
./tools/fetch-mdpro3.sh dir  "Assets/Scripts/Windbot/Game/AI/Decks"

# 列整个仓库文件树
./tools/fetch-mdpro3.sh tree
```

默认输出到 `./mdpro3-download/`，可用 `OUT_DIR=xxx` 覆盖。

> 脚本已实测通过：`list` / `file` / `dir` 三种模式均正常。

## 如果要完整仓库

上游仓库本身是公开的，网络条件允许时可直接：

```bash
git clone --depth 1 https://code.moenext.com/sherry_chaos/MDPro3.git
```

（注意：本机网络下该命令多次失败，耗时可能很长。）
