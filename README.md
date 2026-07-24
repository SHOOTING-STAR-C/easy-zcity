# easy-zcity

Z-City 镜头/移动/持枪系统独立移植版。

## 已移植功能

### 镜头系统
- ✅ 第一人称（脖子骨骼追踪，不随视角俯身）
- ✅ 第三人称（`hg_thirdperson 1`）
- ✅ 第三人称公转（`hg_thirdperson_orbit 1`，静止时鼠标旋转，滚轮拉近拉远）
- ✅ FOV 调整（`hg_fov`，范围 75-100）
- ✅ 视角震动（4通道弹簧系统，走路/后座/受伤）
- ✅ 呼吸/走路晃动（HGAddView）
- ✅ 速度惯性滚转（MovementInertiaAddView）
- ✅ Alt-Look 自由视角（`+altlook`）
- ✅ CoolCamera 模式（`hg_coolcamera`）
- ✅ 适配所有武器（原版武器保留 viewmodel）

### 移动系统
- ✅ 速度状态：跑步/走路/慢走/下蹲/瞄准
- ✅ 移动惯性（`hg_inertiaenabled 1`）
- ✅ 侧向惩罚 1.2x / 后向惩罚 1.3x
- ✅ 反蹲伏垃圾操作
- ✅ 最低速度 40% 保护

### 歪头倾斜
- ✅ IN_ALT1（默认 E）右倾 / IN_ALT2（默认 Q）左倾
- ✅ 骨骼操作（spine/spine1/spine2/head/upperarm）
- ✅ 镜头滚转（`hg_leancam_mul`）
- ✅ 控制台命令（`+ezc_lean_left` / `+ezc_lean_right`）
- ✅ 第三人称偏移

### 持枪姿势
- ✅ 10 种姿势（`hg_change_posture <编号>`）
- ✅ 网络同步
- ✅ 适配所有武器

| 编号 | 姿势 |
|------|------|
| 0 | 常规持枪 |
| 1 | 腰射 |
| 2 | 左肩射击 |
| 3 | 高位戒备（跑步） |
| 4 | 低位戒备 |
| 5 | 指向射击 |
| 7 | 黑帮持枪（手枪） |
| 8 | 单手射击（手枪） |
| 9 | 索马里式射击 |

### 武器渲染（ezcity 武器专属）
- ✅ 世界模型渲染（武器绑在手上）
- ✅ TPIK 双手反向动力学
- ✅ 机瞄镜头（ZoomPos）
- ✅ `IsZoom` / `CanUse` / `IsSprinting`

## 控制台命令

| 命令 | 作用 |
|------|------|
| `hg_thirdperson 0/1` | 切换第三人称 |
| `hg_thirdperson_orbit 0/1` | 公转模式 |
| `hg_fov <75-100>` | 视野范围 |
| `hg_leancam_mul <值>` | 倾斜滚转倍数 |
| `hg_coolcamera <0-5>` | 冷却镜头 |
| `hg_inertiaenabled 0/1` | 移动惯性 |
| `hg_change_posture <编号>` | 切换持枪姿势 |
| `+hg_thirdperson` | 一键切换人称 |
| `hg_change_posture -1` | 循环姿势 |
| `hg_change_posture -2` | 重置姿势 |

## 文件结构

```
lua/
├── autorun/
│   └── ezcity_init.lua       # 加载器
└── ezcity/
    ├── sh_utility.lua         # 工具函数
    ├── sh_quaternions.lua     # 四元数库
    ├── sh_bonemethods.lua     # 骨骼方法
    ├── sh_movement.lua        # 移动系统
    ├── sh_posture.lua         # 持枪姿势
    ├── cl_viewpunch.lua       # 视角震动
    ├── cl_view.lua            # 镜头系统
    ├── cl_lean.lua            # 歪头倾斜
    ├── sh_worldmodel.lua      # 世界模型渲染
    ├── cl_tpik.lua            # TPIK
    ├── cl_wepcamera.lua       # 武器镜头
    └── sh_wepshared.lua       # SWEP 共享方法
```

## 待移植功能
- 1.站姿等姿势

## 来源

移植自 [Z-City](https://github.com/SHOOTING-STAR-C/Z-City)（`homigrad` 核心库 + `weapons/homigrad_base`）。
