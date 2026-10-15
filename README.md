# 移动互联开发课设 —— KFC 风格点餐系统

前端用鸿蒙 ArkTS 编写，界面参照肯德基小程序；后端用 Java Spring Boot 分层架构；
数据存储采用 PostgreSQL（持久化）+ Redis（缓存）双层。

**当前状态：工程骨架已完成，四层结构齐备，业务逻辑（CRUD）尚未实现。**
后端已通过 `mvn compile` 编译，前端已通过 `hvigor assembleHap` 构建。

---

## 一、目录结构

```
mobile-dev-course/
├── backend/                          # 后端：Spring Boot 3.5.16 + JDK 21
│   ├── pom.xml
│   └── src/
│       ├── main/java/com/example/kfc/
│       │   ├── KfcApplication.java            # 启动类
│       │   ├── controller/                    # 控制层   7 个
│       │   ├── service/                       # 业务层   7 个接口
│       │   │   └── impl/                      # 业务层   7 个实现
│       │   ├── repository/                    # 持久层   7 个
│       │   ├── domain/                        # 领域层
│       │   │   ├── entity/                    # 实体 7 个（对应数据库表）
│       │   │   ├── dto/                       # 入参 4 个
│       │   │   ├── vo/                        # 出参 2 个
│       │   │   └── enums/                     # 枚举 2 个
│       │   ├── common/                        # 统一返回、异常、常量
│       │   │   ├── result/                    # Result / ResultCode
│       │   │   ├── exception/                 # BusinessException / 全局异常处理
│       │   │   └── constant/                  # RedisKeyConstants
│       │   └── config/                        # RedisConfig / WebConfig
│       ├── main/resources/
│       │   ├── application.yml
│       │   ├── application-dev.yml
│       │   └── db/migration/V1__init_schema.sql   # 建表脚本（草案）
│       └── test/java/com/example/kfc/KfcApplicationTests.java
│
└── frontend/                         # 前端：HarmonyOS ArkTS，SDK 6.1.1(24)
    ├── AppScope/                     # 应用级配置与图标
    ├── build-profile.json5           # 工程构建配置
    ├── oh-package.json5
    ├── hvigorfile.ts
    └── entry/                        # 主 HAP 模块
        └── src/main/
            ├── module.json5
            ├── ets/
            │   ├── entryability/EntryAbility.ets
            │   ├── entrybackupability/EntryBackupAbility.ets
            │   ├── pages/            # 7 个页面
            │   ├── components/       # 3 个自定义组件
            │   ├── model/            # 7 个数据模型
            │   ├── api/              # 5 个接口类 + HttpClient
            │   ├── common/           # 常量、工具
            │   └── viewmodel/        # 状态管理
            └── resources/            # 字符串/颜色/图标/路由表（含中英文国际化）
```

---

## 二、后端四层职责（强约束）

依赖方向**单向**：`Controller → Service → Repository → Domain`

| 层 | 包 | 该做什么 | 不许做什么 |
|---|---|---|---|
| 控制层 | `controller` | 接收请求、参数校验、调用 Service、封装 `Result` 返回 | 写业务判断、直接访问数据库或 Redis |
| 业务层 | `service` / `service.impl` | 业务规则、事务边界、缓存与数据库编排 | 直接操作 HttpServletRequest |
| 持久层 | `repository` | 数据存取（`JpaRepository`）、复杂查询 | 写业务判断 |
| 领域层 | `domain` | 实体、DTO、VO、枚举的定义 | 依赖以上任何一层 |

已覆盖的七个领域对象：
`User`（用户）、`Category`（餐品分类）、`Product`（餐品）、`CartItem`（购物车项）、
`Order`（订单）、`OrderItem`（订单明细）、`Address`（收货地址）。

---

## 三、开发环境

| 组件 | 版本 | 位置 / 说明 |
|---|---|---|
| JDK | 21（待安装） | 本机现只有 JDK 25，Spring Boot 3.5.16 两者都支持 |
| Maven | 3.9.16 | `D:\devtools\apache-maven-3.9.16`，已加入用户 PATH |
| PostgreSQL | 17.6 | `D:\devtools\postgresql-17`，端口 5432，账号 `postgres` / `postgres` |
| Redis | 5.0.14.1 | `D:\devtools\redis-5.0.14`，端口 6379，无密码 |
| DevEco Studio | 6.1.1.300 | `D:\DevEco Studio`，SDK 6.1.1(24) |
| IntelliJ IDEA | 2026.2.1 | `D:\IntelliJ IDEA 2026.2.1` |

数据库启停：双击 `D:\devtools\scripts\start-all.bat`，用 `status.bat` 查状态，`stop-all.bat` 关闭。

---

## 四、启动步骤

### 1. 起数据库
```
双击 D:\devtools\scripts\start-all.bat
```
应看到 PostgreSQL `accepting connections` 和 Redis `PONG`。

### 2. 建表（二选一，详见建表脚本头部说明）
- 方案 A：用 `backend/src/main/resources/db/migration/V1__init_schema.sql` 建表，
  之后把实体字段补齐并把 `application.yml` 的 `ddl-auto` 改成 `validate`
- 方案 B：不跑脚本，靠 Hibernate 按实体自动建表（当前 `ddl-auto: update`）

### 3. 起后端
```
cd backend
mvn spring-boot:run
```
或在 IntelliJ 里直接运行 `KfcApplication`。默认端口 **8080**。

### 4. 起前端
用 DevEco Studio 打开 `frontend` 目录 → Sync → 连真机或模拟器运行。

---

## 五、注意事项

1. **工程路径必须纯英文。** hvigor 会拒绝构建路径中含中文的工程，
   实测报 `Invalid project path` 且 BUILD FAILED。所以本目录已从
   「移动互联开发课设」改名为 `mobile-dev-course`，请勿改回中文名。
2. **后端接口前缀统一 `/api`**，返回结构统一用 `common.result.Result`。
3. **购物车会同时写 PostgreSQL 和 Redis**，Redis key 见 `RedisKeyConstants`。
4. `application.yml` 中的数据库密码是本地开发用的 `postgres`，
   提交作业前如需脱敏，可改用环境变量注入。
5. 前端真机调试时，`ets/common/Constants.ets` 里的 `BASE_URL` 要改成电脑的局域网 IP，
   不能写 `127.0.0.1`（手机上的 127.0.0.1 指向手机自己）。

---

## 六、下一步

- [ ] 定稿数据库字段，确定建表方案 A 还是 B
- [ ] 补齐 `domain/entity` 字段与实体关系
- [ ] 实现七个模块的 CRUD（Controller → Service → Repository）
- [ ] Redis 缓存与登录 token 落地
- [ ] 前端页面按肯德基小程序 1:1 还原
- [ ] 前后端联调
