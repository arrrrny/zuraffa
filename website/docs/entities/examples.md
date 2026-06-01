# Real-World Entity Examples

These examples use the canonical Zuraffa v5 flow:

1. define entities with `zfa entity create`
2. generate architecture with `zfa make`
3. finish with `zfa build`

---

## 🛒 E-commerce Domain

### 1. Enums and supporting types

```bash
zfa entity enum -n OrderStatus --value pending,shipped,delivered,cancelled
zfa entity enum -n Currency --value usd,eur,gbp

zfa entity create -n Money --field amount:double --field currency:Currency
```

### 2. Product and reviews

```bash
zfa entity create -n Product \
  --field id:String \
  --field sku:String \
  --field name:String \
  --field price:Money \
  --field stock:int

zfa entity create -n Review \
  --field productId:String \
  --field rating:int \
  --field comment:String?
```

### 3. Generate the architecture

```bash
zfa make Product \
  --preset=crud \
  --methods=get,getList,create,update \
  --with=vpc \
  --di
```

---

## 📱 Social Media Domain

### 1. User profile and stats

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

### 2. Posts with media

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

### 3. Generate the architecture

```bash
zfa make Post \
  --preset=crud \
  --methods=getList,create,delete \
  --with=vpc \
  --mock
```

---

## ✅ Task Management

### 1. Supporting types

```bash
zfa entity enum -n Priority --value low,medium,high,urgent
zfa entity create -n Label --field name:String --field color:String
```

### 2. The task entity

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

### 3. Generate the architecture

```bash
zfa make Task \
  --preset=crud \
  --methods=get,getList,create,update \
  --with=vpc \
  --cache
```

---

## Pro tip for AI agents

If you describe the entity shape clearly, an AI agent should translate that into:

- one or more `zfa entity create` commands,
- a `zfa make` command that matches the desired layers, and
- a final `zfa build` step.

---

## Next steps

- [Entity Generation](./intro)
- [Advanced Patterns](./advanced-patterns)
- [CLI Commands Reference](../cli/commands)
