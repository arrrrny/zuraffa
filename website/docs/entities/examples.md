# Real-World Examples

Complete, production-ready entity structures for common use cases.

## E-commerce Platform

### Product Management

```bash
# Enums
zfa entity enum -n ProductStatus --value available,out_of_stock,discontinued
zfa entity enum -n ProductCategory --value electronics,clothing,books,home
zfa entity enum -n Currency --value usd,eur,gbp,jpy

# Entities
zfa entity create -n Money \
  --field amount:double \
  --field currency:Currency

zfa entity create -n ProductImage \
  --field url:String \
  --field altText:String? \
  --field isPrimary:bool \
  --field order:int

zfa entity create -n ProductReview \
  --field userId:String \
  --field rating:int \
  --field comment:String? \
  --field createdAt:DateTime

zfa entity create -n Product \
  --field id:String \
  --field sku:String \
  --field name:String \
  --field description:String? \
  --field price:Money \
  --field compareAtPrice:Money? \
  --field status:ProductStatus \
  --field category:ProductCategory \
  --field images:List<$ProductImage> \
  --field tags:List<String> \
  --field stock:int \
  --field lowStockThreshold:int \
  --field reviews:List<$ProductReview> \
  --field averageRating:double \
  --field createdAt:DateTime \
  --field updatedAt:DateTime?
```

**Usage:**
```dart
final product = Product(
  id: 'prod-123',
  sku: 'WIDGET-001',
  name: 'Premium Widget',
  description: 'High-quality widget',
  price: Money(amount: 29.99, currency: Currency.usd),
  status: ProductStatus.available,
  category: ProductCategory.electronics,
  images: [
    ProductImage(
      url: 'https://example.com/image1.jpg',
      altText: 'Front view',
      isPrimary: true,
      order: 0,
    ),
  ],
  tags: ['premium', 'bestseller'],
  stock: 100,
  lowStockThreshold: 10,
  reviews: [],
  averageRating: 4.5,
  createdAt: DateTime.now(),
);
```

### Order Management

```bash
# Enums
zfa entity enum -n OrderStatus --value pending,processing,shipped,delivered,cancelled,refunded
zfa entity enum -n PaymentStatus --value pending,completed,failed,refunded
zfa entity enum -n ShippingMethod --value standard,express,overnight

# Entities
zfa entity create -n Address \
  --field street:String \
  --field street2:String? \
  --field city:String \
  --field state:String \
  --field zipCode:String \
  --field country:String \
  --field isDefault:bool

zfa entity create -n Customer \
  --field id:String \
  --field email:String \
  --field firstName:String \
  --field lastName:String \
  --field phone:String? \
  --field addresses:List<$Address> \
  --field createdAt:DateTime

zfa entity create -n OrderItem \
  --field productId:String \
  --field productName:String \
  --field quantity:int \
  --field unitPrice:Money \
  --field totalPrice:Money

zfa entity create -n ShippingInfo \
  --field method:ShippingMethod \
  --field trackingNumber:String? \
  --field estimatedDelivery:DateTime? \
  --field actualDelivery:DateTime?

zfa entity create -n Order \
  --field id:String \
  --field orderNumber:String \
  --field customer:Customer \
  --field items:List<$OrderItem> \
  --field subtotal:Money \
  --field tax:Money \
  --field shipping:Money \
  --field total:Money \
  --field status:OrderStatus \
  --field paymentStatus:PaymentStatus \
  --field shippingAddress:Address \
  --field billingAddress:Address \
  --field shippingInfo:ShippingInfo? \
  --field notes:String? \
  --field createdAt:DateTime \
  --field updatedAt:DateTime?
```

### Shopping Cart

```bash
zfa entity create -n CartItem \
  --field productId:String \
  --field quantity:int \
  --field price:Money

zfa entity create -n Cart \
  --field id:String \
  --field customerId:String? \
  --field items:List<$CartItem> \
  --field subtotal:Money \
  --field tax:Money \
  --field total:Money \
  --field expiresAt:DateTime
```

## Social Media Platform

### User System

```bash
# Enums
zfa entity enum -n UserStatus --value active,inactive,suspended,banned
zfa entity enum -n PrivacyLevel --value public,friends,private
zfa entity enum -N AccountType --value user,moderator,admin

zfa entity create -n UserProfile \
  --field displayName:String \
  --field bio:String? \
  --field avatarUrl:String? \
  --field coverUrl:String? \
  --field website:String? \
  --field location:String? \
  --field birthDate:DateTime?

zfa entity create -n UserStats \
  --field followersCount:int \
  --field followingCount:int \
  --field postsCount:int \
  --field likesCount:int

zfa entity create -n User \
  --field id:String \
  --field username:String \
  --field email:String \
  --field hashedPassword:String \
  --field profile:UserProfile \
  --field stats:UserStats \
  --field status:UserStatus \
  --field accountType:AccountType \
  --field isVerified:bool \
  --field createdAt:DateTime \
  --field lastLoginAt:DateTime?
```

### Content System

```bash
# Enums
zfa entity enum -n PostVisibility --value public,followers,private
zfa entity enum -N ContentType --value text,image,video,audio,link,poll

zfa entity create -n MediaAttachment \
  --field type:String \
  --field url:String \
  --field thumbnailUrl:String? \
  --field width:int? \
  --field height:int? \
  --field duration:int? \
  --field size:int

zfa entity create -n PostStats \
  --field likesCount:int \
  --field commentsCount:int \
  --field sharesCount:int \
  --field viewsCount:int

zfa entity create -n Post \
  --field id:String \
  --field authorId:String \
  --field content:String \
  --field type:ContentType \
  --field attachments:List<$MediaAttachment> \
  --field tags:List<String> \
  --field mentions:List<String> \
  --field visibility:PostVisibility \
  --field stats:PostStats \
  --field publishedAt:DateTime? \
  --field createdAt:DateTime \
  --field updatedAt:DateTime?

zfa entity create -n Comment \
  --field id:String \
  --field postId:String \
  --field authorId:String \
  --field content:String \
  --field parentId:String? \
  --field likesCount:int \
  --field createdAt:DateTime

zfa entity create -n Like \
  --field userId:String \
  --field targetId:String \
  --field targetType:String \
  --field createdAt:DateTime
```

### Follow System

```bash
zfa entity create -n Follow \
  --field followerId:String \
  --field followingId:String \
  --field createdAt:DateTime

zfa entity create -n FollowRequest \
  --field fromUserId:String \
  --field toUserId:String \
  --field status:String \
  --field createdAt:DateTime
```

## Task Management

### Task System

```bash
# Enums
zfa entity enum -n TaskPriority --value low,medium,high,critical
zfa entity enum -n TaskStatus --value todo,in_progress,in_review,done,cancelled
zfa entity enum -n RecurrenceType --value none,daily,weekly,monthly,yearly

zfa entity create -n TaskLabel \
  --field id:String \
  --field name:String \
  --field color:String

zfa entity create -n TaskComment \
  --field id:String \
  --field authorId:String \
  --field content:String \
  --field createdAt:DateTime

zfa entity create -n TaskAttachment \
  --field id:String \
  --field name:String \
  --field url:String \
  --field size:int \
  --field mimeType:String \
  --field uploadedAt:DateTime

zfa entity create -n Task \
  --field id:String \
  --field title:String \
  --field description:String? \
  --field assigneeId:String? \
  --field creatorId:String \
  --field projectId:String? \
  --field priority:TaskPriority \
  --field status:TaskStatus \
  --field labels:List<$TaskLabel> \
  --field dueDate:DateTime? \
  --field startDate:DateTime? \
  --field estimatedHours:double? \
  --field actualHours:double? \
  --field comments:List<$TaskComment> \
  --field attachments:List<$TaskAttachment> \
  --field dependsOn:List<String> \
  --field recurrence:RecurrenceType \
  --field completedAt:DateTime? \
  --field createdAt:DateTime \
  --field updatedAt:DateTime?

zfa entity create -n Project \
  --field id:String \
  --field name:String \
  --field description:String? \
  --field ownerId:String \
  --field memberIds:List<String> \
  --field color:String \
  --field isArchived:bool \
  --field startDate:DateTime? \
  --field endDate:DateTime? \
  --field createdAt:DateTime
```

### Team Management

```bash
# Enums
zfa entity enum -n TeamRole --value owner,admin,member,guest

zfa entity create -n Team \
  --field id:String \
  --field name:String \
  --field description:String? \
  --field avatarUrl:String? \
  --field createdAt:DateTime

zfa entity create -n TeamMember \
  --field teamId:String \
  --field userId:String \
  --field role:TeamRole \
  --field joinedAt:DateTime
```

## Blog/CMS Platform

### Content Management

```bash
# Enums
zfa entity enum -n PostStatus --value draft,published,archived,scheduled
zfa entity enum -N PostFormat --value standard,video,audio,gallery,quote

zfa entity create -n Category \
  --field id:String \
  --field slug:String \
  --field name:String \
  --field description:String? \
  --field parentId:String? \
  --field icon:String? \
  --field color:String?

zfa entity create -n Tag \
  --field id:String \
  --field slug:String \
  --field name:String \
  --field count:int

zfa entity create -n Author \
  --field id:String \
  --field name:String \
  --field slug:String \
  --field bio:String? \
  --field photoUrl:String? \
  --field website:String? \
  --field twitterHandle:String?

zfa entity create -n SeoData \
  --field title:String? \
  --field description:String? \
  --field keywords:List<String> \
  --field ogImageUrl:String?

zfa entity create -n BlogPost \
  --field id:String \
  --field title:String \
  --field slug:String \
  --field content:String \
  --field excerpt:String? \
  --field featuredImageUrl:String? \
  --field status:PostStatus \
  --field format:PostFormat \
  --field author:Author \
  --field category:Category \
  --field tags:List<$Tag> \
  --field seo:SeoData \
  --field allowComments:bool \
  --field publishedAt:DateTime? \
  --field scheduledFor:DateTime? \
  --field viewCount:int \
  --field createdAt:DateTime \
  --field updatedAt:DateTime?

zfa entity create -n Comment \
  --field id:String \
  --field postId:String \
  --field authorName:String \
  --field authorEmail:String? \
  --field authorUrl:String? \
  --field content:String \
  --field parentId:String? \
  --field status:String \
  --field createdAt:DateTime
```

## Messaging/Chat Application

### Chat System

```bash
# Enums
zfa entity enum -n MessageStatus --value sending,sent,delivered,read,failed
zfa entity enum -n MessageType --value text,image,audio,video,file,system
zfa entity enum -n ChatType --value direct,group,channel

zfa entity create -n User \
  --field id:String \
  --field username:String \
  --field displayName:String \
  --field avatarUrl:String? \
  --field isOnline:bool \
  --field lastSeenAt:DateTime?

zfa entity create -n Message \
  --field id:String \
  --field chatId:String \
  --field senderId:String \
  --field type:MessageType \
  --field content:String? \
  --field mediaUrl:String? \
  --field replyToId:String? \
  --field status:MessageStatus \
  --field createdAt:DateTime \
  --field editedAt:DateTime?

zfa entity create -n Chat \
  --field id:String \
  --field type:ChatType \
  --field name:String? \
  --field avatarUrl:String? \
  --field participantIds:List<String> \
  --field adminIds:List<String> \
  --field lastMessage:Message? \
  --field unreadCount:int \
  --field muted:bool \
  --field createdAt:DateTime

zfa entity create -n ReadReceipt \
  --field messageId:String \
  --field userId:String \
  --field readAt:DateTime
```

## Analytics/Events

### Event Tracking

```bash
# Enums
zfa entity enum -n EventType --value page_view,click,submit,error,purchase,signup
zfa entity enum -n EventSource --value web,mobile,api,server

zfa entity create -n Event \
  --field id:String \
  --field type:EventType \
  --field source:EventSource \
  --field userId:String? \
  --field sessionId:String \
  --field name:String \
  --field properties:Map<String,dynamic> \
  --field timestamp:DateTime \
  --field platform:String \
  --field appVersion:String

zfa entity create -n PageView \
  --field sessionId:String \
  --field page:String \
  --field referrer:String? \
  --field duration:int? \
  --field timestamp:DateTime

zfa entity create -n ClickEvent \
  --field elementId:String \
  --field elementType:String \
  --field page:String \
  --field coordinates:Map<String,double> \
  --field timestamp:DateTime
```

## Configuration System

### App Configuration

```bash
zfa entity create -n FeatureFlag \
  --field key:String \
  --field isEnabled:bool \
  --field description:String? \
  --field conditions:Map<String,dynamic>

zfa entity create -n AppConfig \
  --field environment:String \
  --field apiBaseUrl:String \
  --field cdnBaseUrl:String \
  --field features:List<$FeatureFlag> \
  --field maxFileSize:int \
  --field supportedLanguages:List<String> \
  --field maintenanceMode:bool \
  --field version:String

zfa entity create -n RemoteConfig \
  --field key:String \
  --field value:String \
  --field updatedAt:DateTime \
  --field hash:String
```

## Generate Clean Architecture

Once you have your entities, generate the complete Clean Architecture:

```bash
# E-commerce
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state
zfa generate Order --methods=get,getList,create --data --vpc --state
zfa generate Customer --methods=get,getList,create --data --vpc --state

# Social Media
zfa generate User --methods=get,getList,create --data --vpc --state
zfa generate Post --methods=get,getList,create,delete --data --vpc --state
zfa generate Comment --methods=get,getList,create --data --vpc --state

# Task Management
zfa generate Task --methods=get,getList,create,update,delete --data --vpc --state
zfa generate Project --methods=get,getList,create,update --data --vpc --state

# Blog
zfa generate BlogPost --methods=get,getList,create --data --vpc --state
zfa generate Category --methods=get,getList --data --vpc --state

# Build everything
zfa build --watch
```

## Tips for Real-World Projects

### 1. Use Consistent Naming

```bash
# ✅ Good - Consistent
zfa entity create -n User --field createdAt:DateTime
zfa entity create -n Product --field createdAt:DateTime
zfa entity create -n Order --field createdAt:DateTime

# ❌ Avoid - Inconsistent
zfa entity create -n User --field createdAt:DateTime
zfa entity create -n Product --field created:DateTime
zfa entity create -n Order --field timestamp:DateTime
```

### 2. Use Enums for Fixed Values

```bash
# ✅ Good - Type-safe
zfa entity enum -n Status --value active,inactive
zfa entity create -n Account --field status:Status

# ❌ Avoid - Stringly typed
zfa entity create -n Account --field status:String
```

### 3. Separate Metadata from Data

```bash
# ✅ Good - Separate concerns
zfa entity create -n Product --field name:String --field price:double
zfa entity create -n ProductMetadata \
  --field viewCount:int \
  --field averageRating:double \
  --field stockLevel:int

# ❌ Avoid - Mixing concerns
zfa entity create -n Product \
  --field name:String \
  --field price:double \
  --field viewCount:int \
  --field averageRating:double \
  --field stockLevel:int
```

### 4. Use Nullable for Optional Data

```bash
# ✅ Good - Clear optionality
zfa entity create -n User \
  --field email:String \
  --field phone:String? \
  --field secondaryEmail:String?

# ❌ Avoid - Unclear optionality
zfa entity create -n User \
  --field email:String \
  --field phone:String \
  --field secondaryEmail:String
```

## What's Next?

- [Field Types Reference](./field-types) - All supported field types
- [Advanced Patterns](./advanced-patterns) - Polymorphism, inheritance, generics
- [CLI Commands](../cli/entity-commands) - Complete command reference
