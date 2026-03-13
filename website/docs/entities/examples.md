# Real-World Entity Examples

The best way to learn Zuraffa's entity system is to see it in action. Below are production-ready entity setups for common app domains. Use these as blueprints for your own projects.

---

## 🛒 E-commerce Domain

A complete setup for products, orders, and money management.

### 1. Enums & Base Types
```bash
zfa entity enum -n OrderStatus --value pending,shipped,delivered,cancelled
zfa entity enum -n Currency --value usd,eur,gbp

zfa entity create -n Money --field amount:double --field currency:Currency
```

### 2. Product & Reviews
```bash
zfa entity create -n Product \
  --field id:String \
  --field sku:String \
  --field name:String \
  --field price:Money \
  --field stock:int \
  --field description:String?

zfa entity create -n Review \
  --field productId:String \
  --field rating:int \
  --field comment:String?
```

### 3. Generate the Feature
```bash
zfa feature Product --methods=get,getList,create,update --data --vpcs --di
```

---

## 📱 Social Media Domain

Modeling users, posts, and complex interactions.

### 1. User Profile & Stats
```bash
zfa entity create -n UserProfile \
  --field username:String \
  --field bio:String? \
  --field avatarUrl:String?

zfa entity create -n User \
  --field id:String \
  --field profile:$UserProfile \
  --field followerCount:int
```

### 2. Posts with Media
```bash
zfa entity enum -n MediaType --value image,video,text

zfa entity create -n Post \
  --field id:String \
  --field authorId:String \
  --field content:String \
  --field type:MediaType \
  --field likes:int \
  --field createdAt:DateTime
```

### 3. Generate the Feature
```bash
zfa feature Post --methods=getList,create,delete --data --vpcs --mock
```

---

## ✅ Task Management

Modeling projects, tasks, and team assignments.

### 1. Task Priorities & Labels
```bash
zfa entity enum -n Priority --value low,medium,high,urgent

zfa entity create -n Label --field name:String --field color:String
```

### 2. The Task Entity
```bash
zfa entity create -n Task \
  --field id:String \
  --field title:String \
  --field description:String? \
  --field priority:Priority \
  --field labels:List<$Label> \
  --field assigneeId:String? \
  --field isDone:bool
```

### 3. Generate the Feature
```bash
zfa feature Task --methods=get,getList,create,update --data --cache --vpcs
```

---

## 🧠 Pro Tip: AI Generation

If you're using an AI agent like **Trae** or **Cursor**, you don't need to type all these commands manually. You can simply provide a JSON or a text description:

> "Create a **Chat** domain with **Message** and **Conversation** entities. Messages should support text and images. Generate the full feature stack with real-time **watch** methods."

Zuraffa's **MCP Server** will handle the execution of all necessary `zfa entity` and `zfa feature` commands for you.

---

## 📂 Next Steps

*   [**Field Types Reference**](./field-types) - Master the building blocks.
*   [**Advanced Patterns**](./advanced-patterns) - Use sealed classes for state machines.
*   [**CLI Reference**](../cli/commands) - See all available flags for feature generation.
