# 風力人員統計系統｜GitHub Pages 版

這個版本專門改成 **GitHub Pages + Supabase** 架構：

- GitHub Pages：放前端網頁（HTML / CSS / JavaScript）
- Supabase：登入、資料庫、管理員/檢視者權限
- Excel：管理員可以在「管理後台」直接匯入舊資料
- 同事：登入後只能檢視
- 管理員：可新增、編輯、登記離職、Excel 匯入
- 海外事業部：獨立頁面，不計入主頁統計

> 重要：不要把舊版「內嵌 125 位人員資料」的 HTML 上傳到公開 GitHub。這個 GitHub 版 `index.html` **完全不內嵌人員名單**，資料都存 Supabase，登入後才讀取。

## 1. 建立 Supabase

1. 建立 Supabase project。
2. 打開 **SQL Editor**。
3. 貼上並執行 `supabase.sql`。
4. 到 **Authentication > Users** 建立你自己的帳號與同事帳號。
5. 執行：

```sql
update public.profiles
set role='admin'
where email='你的Email';
```

同事保持 `viewer` 即可。

## 2. 填入 config.js

在 Supabase 專案的 API 設定取得：

- Project URL
- Publishable key / anon key

修改 `config.js`：

```js
window.APP_CONFIG = {
  SUPABASE_URL: "https://xxxx.supabase.co",
  SUPABASE_ANON_KEY: "你的 publishable / anon key"
};
```

不要把 `service_role` key 放到網站。網站只能使用 publishable/anon key，寫入安全由 RLS 控制。

## 3. 上傳到 GitHub

建立一個 repository，例如：

`wind-personnel-system`

把這個資料夾內檔案全部放到 repository 根目錄：

- `index.html`
- `config.js`
- `supabase.sql`
- `.nojekyll`
- `README.md`

然後到 GitHub：

**Settings → Pages → Build and deployment → Deploy from a branch → main / root → Save**

幾分鐘後會取得網址：

`https://你的GitHub帳號.github.io/wind-personnel-system/`

## 4. Excel 舊資料匯入

以管理員登入 → 左側 **管理後台** → 拖入 Excel。

系統會自動辨識常見欄位：

| Excel 欄位 | 網站欄位 |
|---|---|
| 工號 / 員工編號 | 工號 |
| 姓名 / 員工姓名 | 姓名 |
| 班別 / 班次 | 班別 |
| 職別 / 職稱 | 職別 |
| 組別 | 組別 |
| 職級 / 分類 | 職級 |
| 籍別 / 國籍 | 籍別 |
| 區域 | 本部 / 海外事業部 |
| 到職日 / 報到日 | 到職日 |
| 備註 | 備註 |

### 自動規則

- W 開頭 → 外籍 / W
- Z 開頭 → 外籍 / Z
- X 開頭 → 建教生，籍別顯示 `—`
- 其他工號 → 台籍
- 主管職級會依「組長 / 課長 / 廠長 / 副廠長 / 工程師」自動判定
- 同工號再次匯入會更新資料，不會重複新增

## 5. 權限設計

### 管理員 admin

可：
- 新增人員
- 編輯人員
- 登記離職
- Excel 匯入
- 管理海外事業部

### 同事 viewer

只可：
- 看總覽
- 看人員名單
- 使用搜尋 / 篩選
- 看人員變動
- 看海外事業部

即使同事在瀏覽器修改前端程式，Supabase RLS 仍會阻擋新增/修改/刪除。

## 6. Excel 建議格式

第一列建議使用：

`工號 | 姓名 | 班別 | 職別 | 組別 | 職級 | 籍別 | 區域 | 到職日 | 備註`

其中至少要有：**工號、姓名**。

## 7. 上線前建議

- Repository 如果放公司內部程式碼，建議用 Private repo（是否可直接用 Pages 取決於你的 GitHub 方案）。
- 不要把 `service_role` key、資料庫密碼或任何管理密鑰放入 GitHub。
- 正式使用前先用測試帳號確認 viewer 無法修改資料。


## V2：班別與外籍合約到期名單
- 班別只保留：**日 / 中 / 夜**。
- 新增左側 **「外籍合約到期名單」**，只對 `admin` 顯示。
- 合約到期日放在獨立 `foreign_contracts` 資料表，RLS 設定為只有 admin 能讀寫，所以 viewer 不能從 API 取得。
- Excel 可新增欄位：`合約到期日`、`外籍合約到期日` 或 `合約期限`。
- 舊班別匯入時會自動整理：早→日、晚→夜、中→中。
- 已經執行過舊版 SQL 的話，請再執行新版 `supabase.sql`。


# V3 權限模式

網站入口改為兩種：

1. **同事檢視**
   - 只輸入「公司共用檢視密碼」。
   - 前端使用 `config.js` 的 `VIEWER_EMAIL` 搭配該密碼登入。
   - 同事只能查看。
   - 共用密碼不會寫進 GitHub。

2. **管理員登入**
   - 使用管理員自己的 Email + Password。
   - 可以新增、修改、Excel 匯入、登記離職。
   - 可以查看「外籍合約到期名單」。

## 建立 Supabase 帳號

Supabase → Authentication → Users → Add user

建立：
- `viewer@your-company.local`：公司共用檢視帳號
- 你的 Email：管理員帳號

再到 SQL Editor 執行：

```sql
update public.profiles set role='viewer'
where email='viewer@your-company.local';

update public.profiles set role='admin'
where email='你的管理員Email';
```

## config.js

```js
window.APP_CONFIG = {
  SUPABASE_URL: "你的 Project URL",
  SUPABASE_ANON_KEY: "你的 Publishable / anon key",
  VIEWER_EMAIL: "viewer@your-company.local"
};
```

**不要**把 viewer 密碼、admin 密碼、service_role / secret key 放進 GitHub。
