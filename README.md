# 移动互联开发课设 —— KFC 风格点餐系统（MVP）

前端用鸿蒙 ArkTS 编写，界面参照肯德基小程序；后端用 Java Spring Boot 分层架构；
数据存储采用 PostgreSQL（唯一事实来源）+ Redis（缓存）双层。

**当前状态：MVP 已完成并实测通过。**
后端 7 个模块 CRUD 全部打通（63 个 Java 文件，打包出 63 MB 可执行 jar）；
前端 7 个页面 + 4 个组件 + 网络层 + 状态管理写完，`hvigor assembleHap` **BUILD SUCCESSFUL**，
产出 `entry-default-unsigned.hap`；前后端已按下单主链路联调通过。

---

## 一、目录结构

```
mobile-dev-course/
├── backend/                          # 后端：Spring Boot 3.5.16（JDK 25 实测编译通过）
│   ├── pom.xml
│   └── src/main/
│       ├── java/com/example/kfc/               # 共 63 个 .java
│       │   ├── KfcApplication.java             # 启动类
│       │   ├── controller/                     # 控制层 7 个
│       │   ├── service/ + service/impl/        # 业务层 7 接口 + 7 实现
│       │   ├── repository/                     # 持久层 7 个
│       │   ├── domain/
│       │   │   ├── entity/    # 实体 7 个（对应数据库表）
│       │   │   ├── dto/       # 入参 10 个（带 @Valid 校验注解）
│       │   │   ├── vo/        # 出参 7 个（与前端 model 一一对应）
│       │   │   └── enums/     # OrderStatus / UserRole
│       │   ├── common/
│       │   │   ├── result/     # Result / ResultCode
│       │   │   ├── exception/  # BusinessException / GlobalExceptionHandler
│       │   │   ├── cache/      # RedisJsonCache（Redis 读写降级封装）
│       │   │   └── constant/   # RedisKeyConstants
│       │   └── config/         # RedisConfig / WebConfig(CORS)
│       └── resources/
│           ├── application.yml
│           ├── db/migration/V1__init_schema.sql   # 建表 + 种子数据
│           └── static/preview.html                # 浏览器联调预览页（同源调 /api）
│
└── frontend/                         # 前端：HarmonyOS ArkTS，SDK 6.1.1(24)，共 31 个 .ets
    ├── AppScope/
    ├── build-profile.json5 / oh-package.json5 / hvigorfile.ts / local.properties
    └── entry/src/main/
        ├── module.json5
        ├── ets/
        │   ├── entryability/EntryAbility.ets
        │   ├── pages/        # 7 页：Index 点餐首页 / CartPage / OrderListPage
        │   │                 #      OrderDetailPage / AddressPage / MinePage / LoginPage
        │   ├── components/   # 4 个：ProductThumb / ProductCard / CategorySideBar / BottomTabBar
        │   ├── model/        # 9 个数据模型（与后端 VO 字段对齐）
        │   ├── api/          # HttpClient + 5 个模块 Api
        │   ├── common/       # Constants（BASE_URL / Theme）/ DateUtil
        │   └── viewmodel/    # CartViewModel（AppStorage 跨页共享）
        └── resources/
            └── base/profile/network_config.json     # 允许明文 HTTP（联调期必需）
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

七个领域对象：`User`、`Category`、`Product`、`CartItem`、`Order`、`OrderItem`、`Address`。

---

## 三、Redis + PostgreSQL 双层怎么分工

- **PostgreSQL 是唯一事实来源。** 所有写操作先落库，Redis 只是缓存副本，
  任何 Redis 异常都不影响主流程（`RedisJsonCache` 内部吞异常返回 null）。
- **Redis key 与 TTL**（见 `RedisKeyConstants`）：

| Key | 类型 | TTL | 用途 |
|---|---|---|---|
| `kfc:category:list` | String(JSON) | 5 分钟 | 点餐首页「分类 + 餐品」整体结构，一次请求返回 |
| `kfc:product:{id}` | String(JSON) | 10 分钟 | 餐品详情；任何写操作后立即失效 |
| `kfc:cart:{userId}` | Hash | 7 天 | 购物车缓存副本，写库后整份刷新 |
| `kfc:token:{userId}` | String | 2 小时 | 登录 token |

---

## 四、启动步骤

### 1. 起数据库
```
双击 D:\devtools\scripts\start-all.bat
```
应看到 PostgreSQL `accepting connections` 和 Redis `PONG`（`status.bat` 可复查）。

### 2. 建表（只需一次）
```bash
"D:\devtools\postgresql-17\bin\psql.exe" -U postgres -d kfc -f \
  backend\src\main\resources\db\migration\V1__init_schema.sql
```
脚本会建 7 张表，并写入种子数据：4 个分类 / 15 款餐品（image 暂用 emoji 占位）、
演示账号、1 条默认地址。`application.yml` 里 `ddl-auto: none`，表结构完全由脚本管，
不会被 Hibernate 改。

### 3. 起后端
```bash
cd backend
mvn clean package -DskipTests
java -jar target/kfc-order-1.0.0-SNAPSHOT.jar --server.port=8090
```
**端口用 8090**，不是默认 8080 —— 本机 8080 被另一个常驻程序（GoAhead）占着，
8080 上会返回它的 404 页面，容易误判成后端没起来。

### 4. 起前端
用 DevEco Studio 打开 `frontend` 目录 → Sync → 连真机或模拟器运行。
真机调试时把 `ets/common/Constants.ets` 的 `BASE_URL` 改成电脑局域网 IP
（现在写的是 `http://10.205.201.67:8090`），**不能写 127.0.0.1**。

HAP 命令行构建（不用开 IDE）：
```bash
cd frontend
DEVECO_SDK_HOME="D:/DevEco Studio/sdk" \
  "D:/DevEco Studio/tools/node/node.exe" \
  "D:/DevEco Studio/tools/hvigor/bin/hvigorw.js" assembleHap --no-daemon
```

---

## 五、前后端联调怎么验（不需要模拟器）

后端启动后，浏览器直接打开：

```
http://localhost:8090/preview.html
```

这是放在后端 `static/` 下的同源联调预览页：复刻了 KFC 点餐界面（左侧分类 / 右侧餐品 /
底部购物车栏 / 底部导航），用 fetch 直接打 `/api/*`，自动用演示账号登录。
链路是：**点餐首页取分类餐品 → 加购 → 购物车改数量/删除 → 结算下单 → 支付出取餐码
→ 订单列表/详情 → 地址管理 → 我的**。

**演示账号：`demo` / `123456`**（种子数据里密码按「盐$SHA-256(盐+明文)」存储，不存明文）。

---

## 六、接口清单（统一前缀 `/api`，返回结构统一为 `Result`）

| 模块 | 接口 |
|---|---|
| 分类 | `GET /categories`（含餐品）、`GET/POST/PUT/DELETE /categories[/{id}]` |
| 餐品 | `GET /products?categoryId&keyword`、`GET /products/{id}`、`POST/PUT/DELETE /products[/{id}]` |
| 购物车 | `GET /cart-items?userId`、`GET /cart-items/summary?userId`、`POST /cart-items`、`PUT /cart-items/{id}`、`DELETE /cart-items?userId` |
| 订单 | `GET /orders?userId`、`GET /orders/{id}`、`POST /orders`、`POST /orders/{id}/pay`、`POST /orders/{id}/cancel`、`DELETE /orders/{id}` |
| 订单明细 | `GET /order-items?orderId` |
| 地址 | `GET /addresses?userId`、`POST/PUT/DELETE /addresses[/{id}]` |
| 用户 | `POST /users/login`、`POST /users/register`、`GET /users/{id}`、`PUT /users/{id}` |

`Result` 结构：`{ code, message, data }`，业务成功 `code=200`。
HTTP 状态码始终 200，业务错误靠 `code` 区分（400 参数错 / 404 接口或资源不存在 / 500 业务规则不通过 / 5000 系统异常）。

---

## 七、已实测通过的用例

| 用例 | 结果 |
|---|---|
| 点餐首页一次取回分类+餐品 | ✅ |
| 登录 demo/123456 返回 token（不含密码字段） | ✅ |
| 加购同商品累加数量 | ✅ |
| 加购数量 0 被 `@Valid` 拦下（"数量至少为 1"） | ✅ |
| 加购超库存被拒（"库存不足，最多还能加 N 份"） | ✅ |
| 下单：算价 → 扣库存 → 写明细 → 清空购物车 | ✅ |
| 支付生成 4 位取餐码，状态 待支付→制作中 | ✅ |
| 状态机拦截非法流转（已完成/已取消不可再变） | ✅ |
| **取消订单回补库存**（198→196→取消→198） | ✅ |
| 地址默认唯一：新增默认地址自动清掉旧的默认 | ✅ |
| 不存在路径返回 `code=404` 而不是 5000 | ✅ |
| Redis 缓存与 TTL 正确（cart hash TTL=604800 等） | ✅ |
| 前端 `hvigor assembleHap` 构建 | ✅ BUILD SUCCESSFUL |

---

## 八、注意事项 / 踩过的坑

1. **工程路径必须纯英文。** hvigor 拒绝构建含中文路径的工程，
   实测报 `Invalid project path`。目录已从「移动互联开发课设」改名为 `mobile-dev-course`，
   请勿改回中文名。
2. **JDK 23+ 必须显式声明 Lombok 注解处理器。** JDK 23 起 `javac` 不再从 classpath
   自动发现注解处理器，`@Getter/@Setter` 会静默失效，编译出几百个
   `cannot find symbol`。已在 `pom.xml` 的 `maven-compiler-plugin` 里加
   `annotationProcessorPaths` 指向 Lombok，`<proc>full</proc>`，别删。
3. **ArkTS 里自定义组件的属性不能叫 `size`。** 会和 `CustomComponent` 基类的
   `size()` 属性方法冲突报 `10505001`。本项目用的是 `thumbSize`。
4. **ArkTS 不允许无类型的对象字面量**（`arkts-no-untyped-obj-literals`）。
   空 body 的 POST 不要把 `{}` 传进去，直接把参数设为可选省略即可。
5. **前端真机要改 `BASE_URL` 为局域网 IP**，且 `network_config.json` 里
   `cleartextTrafficPermitted: true` 不能删，否则明文 HTTP 被拦。
6. `application.yml` 里的数据库密码是本地开发的 `postgres`，交作业前如需脱敏可走环境变量。

---

## 九、下一步

- [ ] 前端在真机/模拟器实跑，替换 emoji 占位图为真实餐品图
- [ ] 登录态改为 token 拦截器统一注入（现为首页自动登录演示账号）
- [ ] 后台管理端（餐品/分类/订单的增删改页面）
- [ ] 支付流程接入（现为直接改状态的假支付）
- [ ] 用户侧地址选择、外送配送费规则
