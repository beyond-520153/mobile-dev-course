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
        │   ├── pages/        # 8 页：EntryPage 取餐方式入口页（启动页）/ Index 点餐页
        │   │                 #      CartPage / OrderListPage / OrderDetailPage
        │   │                 #      AddressPage / MinePage / LoginPage
        │   ├── components/   # 5 个：ProductThumb / ProductCard / CategorySideBar
        │   │                 #      BottomTabBar / VectorIcon（矢量图标，替代 emoji）
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
| `kfc:token:{token}` | String(JSON) | 1 小时 | 登录会话，值为 `LoginUser`（userId/username/nickname/role/godCard/loginAt） |
| `kfc:token:user:{userId}` | String | 1 小时 | 该用户当前 token，按用户维度踢下线 |

---

## 四、真实菜单数据（官方来源）

项目里的分类和餐品**不是编的**，是 2026-10-18 从肯德基官方预点餐 H5（`order.kfc.com.cn`）
按浙江农林大学（东湖校区）门店抓下来的**真实在售菜单**：

| 项 | 值 |
|---|---|
| 数据来源 | 官方接口 `POST /preorder-portal/api/v2/menu/list` |
| 抓取门店 | 农林大学餐厅（`HZ2226`）—— 临安区武肃街666号 浙江农林大学东湖食堂一楼外侧档口（东湖校区） |
| 分类 | 17 个（周末疯狂拼 / 人气热卖 / 夜宵炸串 / 夜宵鸡架 / 联名套餐 / 桶多人餐 / 汁汁牛堡 / 全鸡 / 吮指原味鸡 / 炸鸡小食 / 汉堡卷 / 饮品 / 金奖豆K咖啡 / 蛋挞甜品 / 冰淇淋 / 炸鸡伴侣 / 自选） |
| 餐品 | 96 条（81 个唯一单品·套餐，跨分类聚合的按官方菜单分别建行） |
| 图片 | 81 张官方原图，存 `backend/src/main/resources/static/images/products/`（约 16 MB） |

导入脚本：`backend/src/main/resources/db/migration/V6__zafu_campus_menu.sql`

```bash
psql -h 127.0.0.1 -p 5432 -U postgres -d kfc -f V6__zafu_campus_menu.sql
```

几个字段说明：

- `image` 存相对路径 `/images/products/xxx.gif|jpg|png`，由 Spring Boot 静态资源提供；
  ArkTS 侧的 `ProductThumb` 与预览页的 `thumbHtml()` 负责补上服务端地址。
  换 IP、换端口都不用动数据。
- `origin_price` 是官方划线原价，无折扣时等于 `price`；只有真有折扣时才在界面上画删除线。
- 官方菜单里分类名与餐品名带内部标记 `BBN`（如「人气BBN热卖」「S旅途随心桶2堡7件新」），
  导入时统一清掉，得到界面上看到的「人气热卖」「周末疯狂拼畅选8拼餐」。
- 同一餐品会出现在多个分类下（官方的「人气热卖」就是聚合位），所以 81 个唯一餐品
  在表里有 96 行，按 `(category_id, name)` 维度唯一。
- 换门店时旧菜单不硬删，只把 `status` 置 0 退役：`t_order_item` 引用着 `t_product`，
  硬删会毁掉历史订单快照；查询侧（分类、搜索）都只取 `status = 1`。
- 门店菜单里「多人团餐」是 0 元的团餐活动入口、不是菜品，未导入。

> 菜品图片版权归百胜中国所有，仅用于课程学习，不得用于任何商业用途。

---

## 五、启动步骤

### 1. 起数据库
```
双击 D:\devtools\scripts\start-all.bat
```
应看到 PostgreSQL `accepting connections` 和 Redis `PONG`（`status.bat` 可复查）。

### 2. 建表 + 灌数据（按 V1 → V2 → V3 → V4 → V5 → V6 顺序，各跑一次）

```bash
PSQL="D:\devtools\postgresql-17\bin\psql.exe"
$PSQL -U postgres -d kfc -f backend\src\main\resources\db\migration\V1__init_schema.sql
$PSQL -U postgres -d kfc -f backend\src\main\resources\db\migration\V2__kfc_real_menu.sql
$PSQL -U postgres -d kfc -f backend\src\main\resources\db\migration\V3__product_search.sql
$PSQL -U postgres -d kfc -f backend\src\main\resources\db\migration\V4__member.sql
$PSQL -U postgres -d kfc -f backend\src\main\resources\db\migration\V5__member_benefit.sql
$PSQL -U postgres -d kfc -f backend\src\main\resources\db\migration\V6__zafu_campus_menu.sql
```

（Windows 上直接写三行 `"D:\devtools\postgresql-17\bin\psql.exe" -U postgres -d kfc -f <脚本路径>` 即可。）

| 脚本 | 作用 | 可否重跑 |
|---|---|---|
| `V1__init_schema.sql` | 建 7 张表 + 最小种子数据（4 分类 / 15 餐品占位、演示账号、1 条默认地址） | ✅ 用了 `IF NOT EXISTS` |
| `V2__kfc_real_menu.sql` | **换成 KFC 官方真实菜单**：加 `origin_price` 列、清空餐品相关表、写入 13 分类 / 80 餐品 | ✅ 先 DELETE 再 INSERT |
| `V3__product_search.sql` | 加 `pinyin_initials` 列并写入 80 行拼音首字母（供搜索用） | ✅ `ADD COLUMN IF NOT EXISTS` |
| `V4__member.sql` | 建 3 张会员表（`t_member` / `t_member_plan` / `t_member_card`）+ 4 个档位种子 + 给已有用户补会员账户 | ✅ 用了 `IF NOT EXISTS` / `ON CONFLICT DO NOTHING` |
| `V5__member_benefit.sql` | 建 `t_benefit_rule`（权益规则）/ `t_benefit_usage`（每日次数流水）+ 给 `t_order` 加 `delivery_fee` / `discount_amount` / `benefit_codes` / `benefit_detail` 四列 + 6 条规则种子 | ✅ 用了 `IF NOT EXISTS` / `ON CONFLICT DO UPDATE` |
| `V6__zafu_campus_menu.sql` | **换成浙江农林大学店（`HZ2226`）菜单**：旧菜单置 `status=0` 退役、写入 17 分类 / 96 餐品并回填拼音首字母、同步大神卡套餐类权益的作用域 | ✅ 先退役再 `ON CONFLICT` 写入 |

⚠️ **四份都要跑**。后端的 `Product` 实体已经有 `originPrice` / `pinyinInitials` 两个字段，
而 `application.yml` 里 `ddl-auto: none`（表结构完全由脚本管，Hibernate 不会自己加列）——
只跑 V1 的话，表里缺这两列，**任何查询餐品的接口都会报 `column does not exist`，整个点餐页起不来**。
同理，漏跑 `V4` 的话 `/api/member/*` 全部报 `relation "t_member" does not exist`，
入口页会员卡与会员中心会显示「--」。漏跑 `V5` 的话下单接口会报
`column "delivery_fee" does not exist`，点餐页能看不能买。

跑完 `V3` 可以用这条确认数据齐了（**别名用英文**，Windows 下 psql 命令行传中文参数会报
`invalid byte sequence for encoding "UTF8"`）：

```bash
"$PSQL" -U postgres -d kfc -A -F' | ' -c \
  "SELECT (SELECT count(*) FROM t_category) AS cats,
          (SELECT count(*) FROM t_product)  AS products,
          (SELECT count(*) FROM t_product WHERE image LIKE '/images/%')      AS with_img,
          (SELECT count(*) FROM t_product WHERE pinyin_initials IS NOT NULL) AS with_py;"
```
期望输出：`13 | 80 | 80 | 80`。

菜单图片不必单独下载——69 张官方原图已随仓库提交，在
`backend/src/main/resources/static/images/products/`，打包后由后端直接提供。

### 3. 起后端
```bash
cd backend
mvn clean package -DskipTests
java -jar target/kfc-order-1.0.0-SNAPSHOT.jar --server.port=8090
```
**端口用 8090**，不是默认 8080 —— 本机 8080 被另一个常驻程序（GoAhead）占着，
8080 上会返回它的 404 页面，容易误判成后端没起来。

### 4. 起前端（DevEco Studio + 真机 / 模拟器）

#### 4.1 两个硬前提：设备系统版本 + 签名

**① 手机系统版本必须 ≥ 工程的最低兼容版本。**

`build-profile.json5` 里 `compatibleSdkVersion` 是 `6.1.1(24)`，也就是要求 **API 24**。
低于这个版本的设备会直接**安装失败**（`INSTALL_FAILED_DEVICE_NOT_SUPPORTED` 之类），
不是代码问题。先确认手机版本：设置 → 关于手机 → 系统版本。

如果手机版本偏低，把 `compatibleSdkVersion` 降到你手机支持的档位（例如 `5.0.0(12)`）再构建。
本项目用到的 API 都很基础（`TextInput` / `List` / `Shape` / `Path` / `Shape.viewPort` /
`AppStorage` / `getUIContext().getRouter()`，其中 `getUIContext()` 从 API 12 起可用），
降到 API 12 通常能编译通过。`targetSdkVersion` 不建议动。

**② 命令行产物未签名，装不上真机。**

命令行构建出来的是 `entry-default-unsigned.hap`（未签名），**直接装不到手机**。
真机/模拟器调试必须在 IDE 里签名：
DevEco Studio → `File` → `Project Structure` → `Signing Configs` → 勾选
**Automatically generate signature** → 用华为账号登录，等它自动生成证书。

（`build-profile.json5` 里 `signingConfigs` 目前是空数组 `[]`，就是这个原因。）

#### 4.2 选一种连法，改 `ets/common/Constants.ets` 的 `BASE_URL`

| 连法 | BASE_URL 填 | 前置条件 |
|---|---|---|
| ① 真机 + USB 数据线 | `http://127.0.0.1:8090` | 电脑先执行 `hdc rport tcp:8090 tcp:8090`；手机开「USB 调试」 |
| ② 真机 + 同一 WLAN | `http://10.205.201.67:8090` | 放行 Windows 防火墙的 8090（要管理员）；手机连同一个 WiFi |
| ③ DevEco 模拟器 | `http://10.0.2.2:8090` | 不通就退回 ② 的局域网 IP |

**推荐 ①**：流量走数据线，完全绕开防火墙和「换了网络 IP 就变」的问题。

```bash
HDC="D:/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe"

# 1) 手机开 USB 调试并插线，确认识别到设备
"$HDC" list targets

# 2) 建立反向端口转发：手机上的 8090 -> 电脑的 8090
"$HDC" rport tcp:8090 tcp:8090

# 3) 查看已建立的任务（换设备 / 重插线后，第 2 步要重新执行）
"$HDC" fport ls
```

#### 4.3 走局域网 IP（方案 ②）必须放行防火墙

Windows 防火墙默认拦截入站，本机三个配置文件（域 / 专用 / 公用）**全是启用状态**，
手机访问 `10.205.201.67:8090` 会被安静丢弃（表现为应用一直转圈、最后超时）。
放行需要**管理员权限**：

```
netsh advfirewall firewall add rule name="KFC dev 8090" dir=in action=allow protocol=TCP localport=8090
```

没有管理员权限就走方案 ①。

#### 4.4 跑起来

DevEco Studio 打开 `frontend` 目录 → 等 Sync 完成 → 选中设备 → `Run`。
启动后首页能加载出菜单（13 个分类）就说明网络通了。

#### 4.5 连不上时的排查顺序

1. `hdc list targets` 有没有设备？没有 → 换根数据线（有些线只供电不传数据）、
   确认手机上弹过「是否允许调试」
2. 电脑上 `curl http://127.0.0.1:8090/api/categories` 通不通？不通 → 后端没起，回到第 3 步
3. 用**手机浏览器**打开 `http://<电脑IP>:8090/preview.html`：
   - 能打开 → 网络没问题，是应用侧的事（`BASE_URL` 写错，或改完没重新安装）
   - 打不开 → 防火墙拦截或不在同一网段（方案 ②），改用方案 ①
4. **改完 `BASE_URL` 必须重新 `Run` 安装一次**，热重载不会改常量

> 关于明文 HTTP：不需要额外配置。HarmonyOS 的 `cleartextTrafficPermitted` **默认值就是 true**
> （API 18 起 Network Kit 默认允许明文），本项目 SDK 是 API 24。
> 工程里的 `resources/base/profile/network_config.json` 只是显式声明，留作保险。
> 另外 `module.json5` 已声明 `ohos.permission.INTERNET`，也不必再改。

#### 4.6 命令行构建（不开 IDE，仅用于自检 / CI）

```bash
cd frontend
DEVECO_SDK_HOME="D:/DevEco Studio/sdk" \
  "D:/DevEco Studio/tools/node/node.exe" \
  "D:/DevEco Studio/tools/hvigor/bin/hvigorw.js" assembleHap --no-daemon
```
产物在 `entry/build/default/outputs/default/entry-default-unsigned.hap`，**未签名，装不了真机**。

---

## 六、前后端联调怎么验（不需要模拟器）

后端启动后，浏览器直接打开：

```
http://localhost:8090/preview.html
```

这是放在后端 `static/` 下的同源联调预览页：复刻了 KFC 点餐界面（左侧分类 / 右侧餐品 /
底部购物车栏 / 底部导航），用 fetch 直接打 `/api/*`，自动用演示账号登录。
链路是：**点餐首页取分类餐品 → 加购 → 购物车改数量/删除 → 结算下单 → 支付出取餐码
→ 订单列表/详情 → 地址管理 → 我的**。

**演示账号：`demo` / `123456`**（种子数据里密码按「盐$SHA-256(盐+明文)」存储，不存明文）。

### 用 curl 调试时记得带 token

除了商品 / 分类 / 登录注册，其余接口都要求 `Authorization: Bearer <token>`，
否则直接 401：

```bash
TOKEN=$(curl -s -X POST http://localhost:8090/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"username":"demo","password":"123456"}' | python -c "import json,sys;print(json.load(sys.stdin)['data']['token'])")

# 带 token 才拿得到订单
curl -s "http://localhost:8090/api/orders?userId=1" -H "Authorization: Bearer $TOKEN"

# 商品接口匿名也能看，但只有带了有效 token 且持卡才会多出 memberPrice
curl -s http://localhost:8090/api/products/86
```

---

## 七、接口清单（统一前缀 `/api`，返回结构统一为 `Result`）

| 模块 | 接口 |
|---|---|
| 分类 | `GET /categories`（含餐品）、`GET/POST/PUT/DELETE /categories[/{id}]` |
| 餐品 | `GET /products?categoryId&keyword`、`GET /products/search?keyword`、`GET /products/{id}`、`POST/PUT/DELETE /products[/{id}]` |
| 购物车 | `GET /cart-items?userId`、`GET /cart-items/summary?userId`、`POST /cart-items`、`PUT /cart-items/{id}`、`DELETE /cart-items?userId` |
| 订单 | `GET /orders?userId`、`GET /orders/{id}`、`GET /orders/quote?userId&pickupType`（结算试算）、`POST /orders`、`POST /orders/{id}/pay`、`POST /orders/{id}/cancel`、`DELETE /orders/{id}` |
| 订单明细 | `GET /order-items?orderId` |
| 地址 | `GET /addresses?userId`、`POST/PUT/DELETE /addresses[/{id}]` |
| 用户 | `POST /users/login`、`POST /users/register`、`POST /users/logout`、`GET /users/{id}`、`PUT /users/{id}` |
| AI 点餐 | `POST /ai/recommend`（匿名可用，见第九节）、`GET /ai/health` |
| 会员 | `GET /member/summary?userId`、`GET /member/plans?cardType`、`GET /member/cards?userId`、`POST /member/cards`（开通/续费）、`GET /member/benefits?userId`（可享权益+今日剩余次数） |

`Result` 结构：`{ code, message, data }`，业务成功 `code=200`。
参数错 / 业务规则不通过 / 系统异常一律 HTTP 200 + 业务码（400 / 500 / 5000）。
**唯一例外是未登录：真正的 HTTP 401**（body 仍是 `Result`，`code=401`），
前端靠状态码直接触发「清 token → 重新登录」，不用去解析 message。

### 登录鉴权（JWT + Redis 会话）

**登录**：`POST /api/users/login`，密码用 `盐$SHA-256(盐 + 明文)` 与库里的 `t_user.password` 比对，
库里从不存明文。成功后返回 `token` 字段（JWT）。

**JWT**：HS 系列对称签名（密钥 ≥ 32 字节时 jjwt 自动选 HS384），
`sub` 放 userId，另外带 `username / nickname / role / god`；
`exp` 与 Redis 会话同为 **1 小时**，两者必须同寿，否则会出现「还验得过但已经登出」的半死状态。

**Redis**：

| key | value | TTL | 用途 |
|---|---|---|---|
| `kfc:token:{token}` | `LoginUser` 的 JSON（userId/username/nickname/role/godCard/loginAt） | 3600s | 拦截器直接 GET，判断会话是否还在 |
| `kfc:token:user:{userId}` | 该用户当前 token | 3600s | 登出清理、按用户维度踢下线 |

**拦截器**（`common/auth/AuthInterceptor`，挂在 `/api/**`）：

1. `OPTIONS` 预检直接放行（浏览器预检按规范不带 Authorization）；
2. 带 token：先验 JWT 签名与 exp，再查 Redis。失败时按接口性质分流——
   **受保护接口 401**；**公开只读接口降级为匿名**（菜单照常浏览，只是不带会员价，
   不会因为 token 过期把整个点餐页打成错误页）；
3. 不带 token：公开接口按匿名放行，其余 401。

公开接口（只对 GET 生效）：`/api/products`、`/api/products/**`、`/api/categories`、
`/api/categories/**`、`/api/member/plans`、`/api/member/benefits`；
另加 `POST /api/users/login`、`POST /api/users/register`。
写操作（`POST/PUT/DELETE /api/products` 等）即使路径在白名单里也必须带 token。

校验通过后把 `LoginUser` 放进 `UserContext`（ThreadLocal），Service 用 `UserContext.userId()`
取当前用户，请求结束在 `afterCompletion` 清理 —— 不清会在线程复用时串号。

**登出**：`POST /api/users/logout`，带同一个 token。JWT 本身无法撤销，
所以登出的本质是删 Redis 会话，之后同一 token 验签仍然通过、但查不到会话 → 401。

**商品会员价**（`GET /api/products*`、`GET /api/categories`）：

`ProductVO` 多了四个字段，未登录 / 未持卡时全部为 `null`，前端据此决定是否渲染标签：

| 字段 | 示例 |
|---|---|
| `memberPrice` | `10.00` |
| `memberCardName` | `大神卡` / `咖啡卡` |
| `memberBenefit` | `每日 1 杯指定咖啡 10 元` |
| `memberPriceText` | `大神卡 ¥10.00` |

叠加规则：按当前用户手上生效卡的规则逐条比价取最低，并且**必须同时满足**分类范围、
可用时段（现在就在时段内）、当日次数还有剩余 —— 列表上标了「大神卡 ¥10」而结算时
不打折，比不标更糟。有订单级门槛的立减（满 30 减 5）不参与单件价展示，因为单件价
表达不了「整单只减一次」。

> 会员价只在 Controller 出参前叠加，**不写进 Redis 餐品缓存** —— 缓存是所有人共用的，
> 写进去会把 A 的会员价发给 B。

### 搜索接口 `GET /products/search?keyword=`

四路匹配，命中任一即返回（都只搜上架餐品）：

| 匹配字段 | 例子 |
|---|---|
| 餐品名 | 搜「鸡腿堡」→ 新奥尔良烤鸡腿堡 |
| 餐品描述 | 搜「香辣」→ 描述里带香辣的餐品 |
| 所属分类名 | 搜「咖啡」→ 金奖豆K咖啡分类下全部 7 个产品 |
| 拼音首字母 | 搜「YWJ」→ 吮指原味鸡全系列（大小写不敏感） |

拼音首字母是**离线预计算**存在 `t_product.pinyin_initials` 列里的（由 `db/migration/V3__product_search.sql` 写入），
Java 端不需要引 pinyin4j 依赖，查询就是普通的 `LIKE '%KW%'`。
代价是以后换菜单要重跑一次导入脚本重新生成该列。

### 会员接口（大神卡 / WOW 会员中心）

三张表：`t_member`（一人一条账户：会员号 / V金 / 卡券 / 余额 / 成就）、
`t_member_plan`（可售档位）、`t_member_card`（已开通的卡）。

| 表 | 关键字段 | 说明 |
|---|---|---|
| `t_member` | `user_id` 唯一、`member_no` 唯一 | 与 `t_user` 一对一，`level` 由「是否持有生效卡」推出 |
| `t_member_plan` | `code` 唯一、`card_type` | 种子 4 档：季卡 30/38、年卡 100/108、月卡 19/25、咖啡卡 12/15 |
| `t_member_card` | `user_id` + `card_type` + `status` | 同一类型只保留一张 `ACTIVE` |

四条规则（实现都在 `MemberServiceImpl`）：

1. **续费不吞剩余天数**：在当前卡的 `expire_at` 上叠加 `months`，不是从今天重算。
2. **同类型只有一张生效卡**：重复开通走续费；过期卡自动标 `EXPIRED`。
3. **开卡赠 2 张卡券**，并把 `level` 升为 `WOW会员`；卡券目前是 `coupon_count` 计数，没有券实体。
4. **支付累计 V金**：`OrderServiceImpl.pay()` 成功后按实付金额 1:1 调 `accrueVgold()`，
   该方法内部吞异常——V金累计失败不能把已经成功的支付回滚掉。

缓存：`GET /member/summary` 走 Redis `kfc:member:summary:{userId}`，TTL 60 秒；
开卡、累计 V金 都会主动 `evict`，所以前端开完卡立刻刷新就能看到新数字。
`remainDays` 由后端算（`Duration.between`），前端不做日期减法——避免设备时区不同算出不同天数。

---

### 大神卡权益与订单优惠结算（V5）

规则不是写死在 Java 里，而是落在 `t_benefit_rule` 表里——官方一改价、一调时段，改数据即可，
不用重新发版。`BenefitServiceImpl` 只认四种 `benefit_type`：

| `benefit_type` | 含义 | 用到的参数 |
|---|---|---|
| `PERCENT_OFF` | 打折（两件套 6 折） | `discount_value=0.60`、`min_quantity=2`、`max_discount` 封顶 |
| `AMOUNT_OFF` | 立减 | `discount_value=5.00`、`threshold_amount` 门槛 |
| `FIXED_PRICE` | 特价（咖啡 10 元） | `discount_value=10.00`，只对原价高于特价的餐品生效 |
| `FREE_DELIVERY` | 免配送费 | 抵的是外送费，不动商品金额 |

六条种子规则（`V5` 脚本写入，与 2026 年官方权益对齐）：

| 规则 | 官方口径 | 本项目落地 |
|---|---|---|
| `GOD_BREAKFAST_40OFF` | 每日 1 次早餐两件套 6 折 | 07:00-10:30，「饮品 + 蛋挞甜品」两件 6 折，单笔最高减 20 |
| `GOD_COFFEE_10` | 每日 1 杯指定咖啡 10 元 | 「金奖豆K咖啡」7 款任选 1 杯 10 元（原价低于 10 元不参与） |
| `GOD_DESSERT_40OFF` | 每日 1 次下午茶两件套 6 折 | 14:00-17:00，「蛋挞甜品 + 冰淇淋」两件 6 折，最高减 20 |
| `GOD_COMBO_MINUS5` | 晚餐人气套餐立减 | 「人气热卖 / 桶多人餐 / 周末疯狂拼」满 30 元立减 5 元，每日 1 次 |
| `GOD_FREE_DELIVERY` | 每天最多 2 次外送免配送费 | 仅外送、商品满 29 元免 9 元配送费 |
| `COFFEE_DAILY_MINUS8` | 咖啡卡每日 1 杯 | 咖啡卡会员买「金奖豆K咖啡」立减 8 元 |

> 官方「早餐」在我们这套菜单里没有独立分类（菜单源自门店的 17 个正餐/夜宵分类），
> 所以映射到「饮品 + 蛋挞甜品」并加了 07:00-10:30 的时段限制；
> 「开卡赠 88 元券包」也简化成赠 2 张券（券还没有实体表）。

**结算链路（算价只有一条路）**

1. `GET /orders/quote?userId&pickupType` 试算：只读，不扣库存、不扣次数，结算页可反复调；
2. `POST /orders` 内部调**同一个** `BenefitService.quote()`，落库
   `total_amount`（商品金额）、`delivery_fee`、`discount_amount`、`pay_amount`
   以及 `benefit_codes`（用掉的规则编码）、`benefit_detail`（展示文案）；
3. 下单成功调 `consume()` 扣当日次数（`t_benefit_usage` 上 `用户 + 规则 + 日期` 唯一，当计数器用）；
4. 取消 / 店员作废订单调 `release()` 把次数按**订单创建那天**还回去（跨零点取消不会误加今天的额度）。

**为什么是按「件」算而不是按订单总额打折**：购物车会展开成一件件单价（`Unit`），
每条规则只认自己适用分类里、还没被别的规则用掉的件，命中后标记已用。
这样同时持大神卡 + 咖啡卡时，同一杯咖啡只会被抵扣一次（大神卡 10 元优先，咖啡卡的 8 元就没件可减了）。

**用户 DTO 新增的大神卡属性**（`UserVO`，登录 / 注册 / `GET /users/{id}` 都带）：

| 字段 | 说明 |
|---|---|
| `godCard` | 是否持有生效中的大神卡，下单时后端按它决定是否套用大神卡权益 |
| `godCardType` / `godCardName` | `GOD` / 季卡 |
| `godCardNo` / `godCardExpireAt` / `godCardRemainDays` | 卡号、到期时间、剩余天数（后端算） |
| `memberLevel` | 持有任意生效卡（大神卡或咖啡卡）即 `WOW会员` |
| `benefits` | 当前可享权益清单，带 `usedToday` / `remaining` / `usable` / `unavailableReason` |

> 没有在 `t_user` 上加一个 `is_god_card` 布尔列——那是会过期的冗余字段，迟早不一致。
> 全部按 `t_member_card` 当刻的 `expire_at` 现算。

---

## 八、取餐方式入口页与搜索框

### 页面流

```
启动 → pages/EntryPage（取餐方式入口页）
         ├─ 点「外送到家」→ pages/Index（点餐页，顶部标签显示「外送到家」）
         └─ 点「到店自取」→ pages/Index（同一个页面，顶部标签显示「到店自取」）
       └─ 点底栏中间的「AI点餐」→ pages/AIChatPage（小K 推荐页，无底栏，左上角返回）
```

两个入口进的是**同一个点餐页**，界面结构完全一致，唯一差别是顶部的取餐方式标签文案。
选择结果通过 `AppStorage` 的 `pickupType` 键在两端共享（`EntryPage` 写，`Index` 读）。

> 按需求，外送 / 自取**只做入口外观区分，不参与下单业务**——订单的 `pickupType` 仍写死 `PICKUP`，
> 后端 CRUD 逻辑一行没动。

### 点餐页顶部

原来那个「到店自取 / 外送到家」胶囊切换，已换成**白色圆角搜索框**：

- 左侧矢量放大镜图标，右侧输入后出现清空按钮
- 输入 300ms 防抖后请求后端；左栏分类栏收起，右侧整栏显示结果 + 「共 N 个结果」
- 清空关键词恢复原来的分类浏览态（左侧分类栏 + 右侧分组列表）
- 无结果时给空态提示，并建议换个词（如「堡」「咖啡」「YWJ」）

### 图标

两端已**彻底移除 emoji**，全部换成矢量图形：

- 鸿蒙端：新增 `components/VectorIcon.ets`，用 `Shape + Path` 描边图标（路径取自 Material Symbols，Apache-2.0）。
  底部 tab（汉堡/小票/人像）、购物车、放大镜、空态、头像、我的页入口、缩略图兜底全部换掉。
- 预览页：`preview.html` 里内置一套内联 SVG（`ICON` 常量），同上。

---

## 九、AI 点餐（通义千问 · 百炼兼容模式）

### 链路

```
底栏「AI点餐」→ pages/AIChatPage → POST /api/ai/recommend
   → AiServiceImpl 读真实菜单（status=1）→ 拼候选清单进 prompt
   → qwen3.8-flash（关思考 + 强制 json_object）
   → 模型只回 { reply, picks:[productId] }
   → 回到数据库补齐图 / 价 / 库存 / 会员价 → AiRecommendVO
```

**模型只负责「挑哪几样、说一句人话」**，价格与图片一律来自数据库，模型碰不到。
所以不会出现「AI 编了一个菜单里没有的餐品」或「推荐价和实际价对不上」。
模型给的 id 全部非法时，按分类热度本地补位（`degraded=true`），页面照常渲染。

### 配置（`application.yml` → `kfc.ai.*`）

| 键 | 值 | 说明 |
| --- | --- | --- |
| `enabled` | `true` | 总开关；关掉直接走本地兜底，可离线演示 |
| `base-url` | `https://dashscope.aliyuncs.com/compatible-mode/v1` | 百炼 OpenAI 兼容模式，不引官方 SDK |
| `api-key` | `${KFC_AI_API_KEY:...}` | **走环境变量覆盖**，换 key 不动代码 |
| `model` | `qwen3.8-flash` | 关思考后单次 2~4 秒 |
| `connect-timeout-ms` / `read-timeout-ms` | `5000` / `40000` | flash 偶发高峰，读超时留足 |
| `temperature` | `0.6` | 点餐要稳，别发散 |
| `max-tokens` | `900` | 6 条推荐 + 一句回复足够，超了就是跑偏 |
| `store-name` / `store-address` / `store-distance` | 农林大学餐厅 / 临安区武肃街666号… / `581m` | 与 V6 菜单同一门店，避免「推荐这家、地址那家」 |

> 请求体是标准 `/chat/completions`，`enable_thinking=false` + `response_format=json_object`。
> 不传 `enable_thinking` 时 qwen3 会先输出思考过程，延迟翻倍且 JSON 被污染。

### 接口

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| `POST` | `/api/ai/recommend` | body `{message, pickupType, count, userId}`，**匿名可用** |
| `GET` | `/api/ai/health` | 回模型名 / 是否配了 key / 一次探活耗时，排查用 |

`message` 一个字段承担三种语义，不做多轮会话表：

- 空 —— 首屏默认推荐（对应截图里刚进门那一屏）
- `换一换` —— 同一诉求换一批
- 自然语言 —— 「来点辣的」「两个人吃，60 以内」「选1和2」

`userId` 只在**没带 token** 时生效；带了有效 token 以拦截器解析的身份为准，
否则任何人都能拿别人的 userId 套会员价。

### 前端页面（`pages/AIChatPage.ets`）

版式照参考截图：深空联名 banner（返回键 + 默认语音胶囊 + `KFC｜三体`）
→ 两条白底气泡（第二条左下角一枚小喇叭）
→ 浅粉推荐卡：门店行 → **纯文字推荐清单**（编号 + 菜名 + 推荐理由 + 价格，末尾小计）
→ 下方 3×2 图片网格（卡角「选N」渐变贴纸、现价 + 划线原价，点卡片加购）
→ 底部「换一换 / 开启新对话」+ **文本输入框**（占位字居中，一打字左对齐）+ 发送键。

「先文字、后图片」是刻意的：文字负责回答「推荐了什么、为什么」，用户不点图也能判断
够不够吃、合不合口味；图片负责「长什么样 + 点一下加车」。所以首屏通常只露到第一排图卡，
往下滑才是完整网格 —— 这是内容量决定的，不是溢出 bug。

尺寸约定（两端同步，改一处必须改另一处）：banner `106`、气泡 `13.5/19` 行高、
清单菜名 `12.5/17`、理由 `11/13`、商品图 `68`、名称两行 `26`、网格间距 `6`、推荐卡内边距 `9`。
这组数值让首屏装下 6 条文字清单 + 第一排图片卡（能看见图），完整网格下滑可见。

---

## 十、已实测通过的用例

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
| **购物车件数口径统一**（4 份+2 份 → summary.count=6，订单 itemCount 也=6） | ✅ |
| 地址默认唯一：新增默认地址自动清掉旧的默认 | ✅ |
| 不存在路径返回 `code=404` 而不是 5000 | ✅ |
| Redis 缓存与 TTL 正确（cart hash TTL=604800 等） | ✅ |
| 前端 `hvigor assembleHap` 构建 | ✅ BUILD SUCCESSFUL（11 条警告，均为 "Function may throw exceptions" 提示，无 deprecated、无 ERROR） |
| **浏览器核验**：Edge headless 打开联调页，13 分类/80 餐品/80 图全加载、0 控制台错误 | ✅ |
| **浏览器内点完整链路**：加购 → 购物车改数量 → 去结算 → 取餐码 3744 | ✅ |
| **入口页**：两张卡（外送到家 / 到店自取）、hero 图加载、图标为矢量 | ✅ |
| **两个入口进同一页**：点外送 → 顶栏标签「外送到家」；点自取 → 「到店自取」，其余完全一致 | ✅ |
| **搜索三字段**：搜「咖啡」命中 7 条（分类名匹配）、搜「YWJ」命中 4 条（拼音首字母） | ✅ |
| **搜索态交互**：左栏收起 → 结果 + 「共 N 个结果」；无结果给空态；清空恢复分类浏览 | ✅ |
| **全端无 emoji**：鸿蒙 10 个 .ets + 预览页页面文本，emoji 检出 0 | ✅ |
| **会员开卡**：买季卡 → 等级 `WOW会员`、券 29→31、到期 2027-01-18、`remainDays=92` | ✅ |
| **会员续费叠加**：季卡后再买月卡，到期从 2027-01-18 叠到 2027-02-18（不吞剩余天数） | ✅ |
| **支付累计 V金**：实付 313.40 → V金 51000→51313 | ✅ |
| **会员概要不串数据**：开卡后 Redis `kfc:member:summary` 主动失效，前端立刻看到新值 | ✅ |
| **两端同源**：入口页会员卡 / WOW 中心 / 大神卡 在预览页与鸿蒙端读同一套接口，数字一致（券 29） | ✅ |
| **无卡原价**：拿铁 19 + 红豆派 ×2 16 → 商品 35、优惠 0、应付 35 | ✅ |
| **大神卡咖啡 10 元**：开季卡后同一单 → 优惠 9.00（拿铁 19→10）、应付 26 | ✅ |
| **外送免配送费**：同单改外送 → 商品 35 + 外送费 9 − 咖啡 9 − 配送 9 = 应付 26 | ✅ |
| **套餐立减**：牛牛双人餐 90.60 → 优惠 5、应付 85.60 | ✅ |
| **两件套 6 折**：红豆派 ×2（16）→ 优惠 6.40、应付 9.60（临时放开时段窗口验证，验完已还原 14:00-17:00） | ✅ |
| **每日限次**：当天第二杯咖啡不再打折，提示「今日权益次数已用完」 | ✅ |
| **取消归还次数**：取消订单后优惠重新可用（0 → 9.00） | ✅ |
| **下单落库**：订单 `total=35 / discount=9 / pay=26`，`benefit_detail=「每日 1 杯咖啡 10 元 -9.00（拿铁 ×1）」` | ✅ |
| **咖啡卡独立生效**：只持咖啡卡（无大神卡）买拿铁 19 → 优惠 8、应付 11，`godCard=false` 但 `memberLevel=WOW会员` | ✅ |
| **预览页显示**：点餐页餐车条 / 购物车「合计 ¥26 · 大神卡 季卡已省 ¥9.00」，订单详情「商品金额 35 / 大神卡优惠 −9 / 实付 26」 | ✅ |
| **鸿蒙端**：`hvigor assembleHap` BUILD SUCCESSFUL（购物车新增优惠行） | ✅ |
| **登录签发 JWT**：token 三段式（长度 241），`sub=1`，带 username/nickname/role/god | ✅ |
| **Redis 会话**：`kfc:token:{token}` 存在、value 为 LoginUser JSON（111 字节）、TTL=3599s | ✅ |
| **匿名访问商品列表**：17 分类 96 餐品全部正常，带 `memberPrice` 的商品数 = 0 | ✅ |
| **带 token 访问商品列表**：6 款咖啡出现 `memberPriceText="大神卡 ¥10.00"`，其余分类为空（早餐/下午茶不在时段，套餐类立减是订单级门槛不上单品标签） | ✅ |
| **商品详情**：匿名 `memberPrice=null`，带 token `memberPrice=10.0` | ✅ |
| **无 token 访问受保护接口**：`GET /api/orders` → **HTTP 401** `{"code":401,"message":"请先登录"}` | ✅ |
| **篡改 token 签名**：同一接口 → HTTP 401（验签直接失败，不查 Redis） | ✅ |
| **登出即失效**：`POST /api/users/logout` 后同一 token 访问订单 → 401「登录状态已失效」 | ✅ |
| **密码哈希校验**：错误密码 / 不存在用户名都返回「用户名或密码错误」（不区分，避免枚举账号） | ✅ |
| **只持咖啡卡的用户**：注册新号 → 开咖啡卡，商品详情 `memberPrice=11.0`（拿铁 19−8）、`memberPriceText="咖啡卡 ¥11.00"` | ✅ |
| **预览页**（CDP 实测）：登录后点餐页 6 个 `.mtag`「大神卡 ¥10.00」；清空 token 后 0 个；重新登录恢复 6 个 | ✅ |
| **过期 token 访问公开接口**：降级为匿名（HTTP 200、无会员价），不把整个点餐页打成 401 | ✅ |

### 前后端字段级一致性审计（脚本核对，全部通过）

只验编译不够——字段名或接口路径对不上，真机上会静默拿不到值。已用脚本逐项比对：

- **接口路径**：前端 5 个 Api 文件里的 35 处调用 ↔ 后端 7 个 Controller 的 38 个方法级 mapping，
  逐个有对应，无拼写漂移。
- **响应字段**：7 组 `VO ↔ model`（Product/Category/CartItem/OrderItem/Order/Address/User）
  字段集合**完全相同**，无「后端有前端没取」也无「前端有用后端没给」。
- **请求字段**：前端每个入参 interface（`CategoryBody` / `ProductBody` / `LoginBody` …）↔ 对应后端 DTO，
  字段集合**完全相同**。
- **枚举字面量**：`OrderStatus` 五个值、`pickupType` 的 `PICKUP`/`DELIVERY` 前后端一致。
- **页面路由**：`main_pages.json` 注册 8 页，代码里 8 个跳转目标全部命中；8 个页面都有 `@Entry`。
- **AppStorage 键名**：`userId`/`cartCount`/`cartAmount` 与 `CartViewModel` 常量逐字一致。

本轮（入口页 + 搜索）复跑了同一套审计，另加 4 项：

- **新增端点**：`GET /api/products/search` 前后端路径逐字一致。
- **`ProductVO` ↔ `model/Product.ets`**：10 个字段（含新加的 `originPrice`）**完全相同**，
  且 `ProductVO.from()` 对每个字段都调了 setter——漏赋值会让前端恒为默认值且不报错，所以这项单独查。
- **路由注册**：代码里 8 个跳转目标全部命中 `main_pages.json`；`EntryAbility` 已改为加载 `pages/EntryPage`。
- **AppStorage 键**：`pickupType` 只在 `EntryPage`（写）与 `Index`（读）出现，键名一致。

#### 会员模块这轮复跑的结果（脚本 `_kfc_audit_fields.py`，2026-10-18）

| 检查项 | 结果 |
|---|---|
| VO ↔ model 字段集合 | **10/10 通过**（含新增 MemberSummary / MemberCard / MemberPlan） |
| 请求 DTO ↔ 前端 body | **3/3 通过**（LoginBody / RegisterBody / MemberOpenBody） |
| 后端端点 ↔ 前端调用 | 42 个端点，前端 21 条路径**全部命中**；反查无「前端调了后端没有」 |
| 路由注册 ↔ 跳转目标 | `main_pages.json` 10 页，代码里所有 `'pages/Xxx'` 目标全部已注册，无孤儿页 |

唯一「后端有、前端没调」的是 `GET /api/order-items`（含 `/{id}`）——**这是设计如此**：
订单明细随 `OrderVO.items` 一起返回，单独那个端点留给后台/调试用。

---

## 十一、注意事项 / 踩过的坑

0. **加了拦截器之后，除了商品/分类/登录注册，所有 curl 都必须带 token**，
   否则拿到的不是业务错误而是 401（`{"code":401,...}`），很容易误以为接口坏了。
   生产部署记得把 `kfc.auth.secret` 换成环境变量 `KFC_AUTH_SECRET`，
   长度至少 32 字节；改了 secret 等于让所有已发出的 token 失效（这是预期行为）。
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

## 十二、已知问题（不阻塞 MVP，已记录待处理）

1. **没有登录态鉴权。** 所有接口的 `userId` 都靠前端在 URL 上带过来，服务端不做校验，
   所以现在还谈不上越权防护。等接入 token 拦截器时统一下掉。
2. **`HttpClient.remove()` 的返回类型是 `Promise<boolean>`，但服务端 DELETE 返回的
   `data` 是 `null`。** 现在两处调用点都只 `await` 不看返回值，所以没出问题；
   但类型是假的，将来谁写了 `if (!await api.remove(id))` 会恒判失败。
   建议把 `remove` 的返回类型改成 `Promise<void>`。
3. **购物车「改数量」接口 `PUT /cart-items/{id}` 没带 `userId`**，
   服务端用的是 `findById` 而不是 `findByIdAndUserId`。和「删除」接口的防护力度不一致，
   等第 1 条一起处理。
4. **演示账号里留了 16 单测试订单**（`demo`，含 制作中/已取消 两种状态），
   正好方便看订单列表的状态筛选。想清空的话删 `orders`/`order_items` 里 `user_id=1` 的行即可。
5. **权益「每日 N 次」是「下单即扣」**：下单锁库存的同时就把次数占了，未支付超时不会自动归还
   （目前只能靠取消订单归还）。接真实支付回调时需要补一个超时关单的定时任务。

---

## 十三、下一步

- [x] AI 点餐：通义千问推荐 + 六宫格页（`/api/ai/recommend`）
- [ ] 前端在真机/模拟器实跑（emoji 占位图已于 2026-10-16 全部替换为 KFC 官方真实图，界面已两端对齐）
- [ ] 取餐方式接入业务：外送时校验收货地址、把 `pickupType` 写进订单 —— 目前只做入口外观区分
- [ ] 搜索加历史记录 / 热门词（现在只有实时结果）
- [x] 登录鉴权：JWT + Redis 会话 + Interceptor 401（还剩登录页 UI，现为首页自动登录演示账号）
- [ ] 后台管理端（餐品/分类/订单的增删改页面）
- [ ] 支付流程接入（现为直接改状态的假支付）
- [x] 用户侧地址选择、外送配送费规则（V5：外送 9 元，大神卡满 29 元免）
- [ ] 卡券实体化：`t_member_coupon` + 券列表页，把「开卡赠 2 券」从计数改成真插两条券
- [ ] 权益次数超时归还（未支付关单时自动 `release`）
