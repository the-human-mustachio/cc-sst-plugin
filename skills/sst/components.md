# SST AWS Components

## Common Components

### sst.aws.Function

Lambda function with automatic bundling, linking, and IAM.

```typescript
const fn = new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  runtime: "nodejs22.x",
  memory: "512 MB",
  timeout: "30 seconds",
  architecture: "arm64",
  url: true,
  link: [bucket, table],
  environment: {
    MY_VAR: "value",
  },
});
```

**Key props:**

| Prop | Default | Description |
| ---- | ------- | ----------- |
| `handler` | — | Required. Path to handler: `"src/handler.handler"` |
| `runtime` | `"nodejs22.x"` | Node.js runtime version |
| `memory` | `"1024 MB"` | Memory allocation |
| `timeout` | `"20 seconds"` | Max execution time (up to 900s) |
| `architecture` | `"x86_64"` | `"arm64"` for ~20% cost savings |
| `url` | `false` | Enable Lambda Function URL |
| `link` | `[]` | Resources to link (auto-generates IAM) |
| `permissions` | `[]` | Additional IAM permissions |
| `environment` | `{}` | Environment variables |
| `streaming` | `false` | Enable response streaming |
| `durable` | `false` | Enable Durable Functions (see [orchestration](orchestration-and-workflows.md)) |
| `concurrency` | — | `{ provisioned: N, reserved: N }` |
| `vpc` | — | VPC configuration |
| `layers` | `[]` | Lambda layers |
| `nodejs` | — | esbuild options: `{ minify, install, format, splitting }` |
| `logging` | — | `{ format: "json", retention: "1 week" }` |
| `copyFiles` | `[]` | Extra files to include in bundle |
| `volume` | — | EFS volume mount |

**When linked, exposes:** `name`, `url`

**Methods:** `.addEnvironment(key, value)`

---

### sst.aws.Bucket

S3 bucket with optional public access, notifications, and lifecycle rules.

```typescript
const bucket = new sst.aws.Bucket("MyBucket", {
  access: "public",
  cors: true,
  versioning: true,
});

// Subscribe to events — uses .notify(), NOT .subscribe()
bucket.notify({
  notifications: [
    {
      name: "OnUpload",
      function: "src/on-upload.handler",
      events: ["s3:ObjectCreated:*"],
      filterPrefix: "uploads/",
      filterSuffix: ".jpg",
    },
  ],
});
```

**Key props:** `access` (`"public"` | `"cloudfront"`), `cors`, `versioning`, `lifecycle`, `enforceHttps`

**When linked, exposes:** `name`

**Important:** Uses `.notify()` method, not `.subscribe()`.

---

### sst.aws.Dynamo

DynamoDB table with streams and subscriber support.

```typescript
const table = new sst.aws.Dynamo("MyTable", {
  fields: {
    pk: "string",
    sk: "string",
    gsi1pk: "string",
    gsi1sk: "string",
  },
  primaryIndex: { hashKey: "pk", rangeKey: "sk" },
  globalIndexes: {
    gsi1: { hashKey: "gsi1pk", rangeKey: "gsi1sk" },
  },
  stream: "new-and-old-images",
});

// Subscribe to DynamoDB Streams
table.subscribe("OnChange", "src/on-change.handler", {
  filters: [
    {
      dynamodb: {
        Keys: { pk: { S: ["USER#"] } },
      },
    },
  ],
});
```

**Key props:** `fields`, `primaryIndex`, `globalIndexes`, `localIndexes`, `stream`, `ttl`, `deletionProtection`

**Stream modes:** `"new-image"`, `"old-image"`, `"new-and-old-images"`, `"keys-only"`

**When linked, exposes:** `name`

**Method:** `.subscribe(name, subscriber, args?)` — requires `stream` to be enabled

---

### sst.aws.Queue

SQS queue with Lambda subscriber support.

```typescript
const queue = new sst.aws.Queue("MyQueue", {
  fifo: true,
  dlq: {
    queue: dlq.arn,
    retry: 5,
  },
  visibilityTimeout: "30 seconds",
});

// NOTE: Queue.subscribe() has NO name parameter — unlike Bus/SnsTopic
queue.subscribe("src/process.handler", {
  batch: {
    size: 10,
    window: "20 seconds",
    partialResponses: true,
  },
  filters: [
    {
      body: { type: ["order"] },
    },
  ],
});
```

**Key props:** `fifo`, `dlq`, `delay`, `visibilityTimeout`

**When linked, exposes:** `url`

**Important:** `.subscribe(subscriber, args?)` — no `name` parameter, unlike Bus and SnsTopic.

---

### sst.aws.Bus

EventBridge event bus with subscriber and queue fan-out support.

```typescript
const bus = new sst.aws.Bus("MyBus");

// Lambda subscriber with pattern filtering
bus.subscribe("OnOrder", "src/on-order.handler", {
  pattern: {
    source: ["my.app"],
    detailType: ["OrderPlaced"],
    detail: {
      amount: [{ numeric: [">=", 100] }],
    },
  },
});

// Fan out to SQS queue
bus.subscribeQueue("ToQueue", queue, {
  pattern: {
    source: ["my.app"],
  },
});
```

**Key props:** `logging` (`{ level, detail }`)

**When linked, exposes:** `name`, `arn`

**Methods:** `.subscribe(name, subscriber, args?)`, `.subscribeQueue(name, queue, args?)`

---

### sst.aws.SnsTopic

SNS topic with Lambda and SQS subscribers.

```typescript
const topic = new sst.aws.SnsTopic("MyTopic", {
  fifo: true,
});

topic.subscribe("OnMessage", "src/on-message.handler", {
  filter: {
    type: ["order", "payment"],
  },
});

topic.subscribeQueue("ToQueue", queue, {
  filter: {
    type: ["order"],
  },
});
```

**Key props:** `fifo`

**When linked, exposes:** `arn`

**Methods:** `.subscribe(name, subscriber, args?)`, `.subscribeQueue(name, queue, args?)`

---

### sst.aws.CronV2

Scheduled tasks using EventBridge rules. Replaces the deprecated `sst.aws.Cron`.

```typescript
new sst.aws.CronV2("DailyReport", {
  schedule: "rate(1 day)",
  function: "src/daily-report.handler",
});

// Cron expression
new sst.aws.CronV2("Midnight", {
  schedule: "cron(0 0 * * ? *)",
  function: "src/midnight.handler",
});

// ECS Task target
new sst.aws.CronV2("HeavyJob", {
  schedule: "rate(1 hour)",
  task: {
    cluster: cluster.arn,
    task: taskDef.arn,
  },
});
```

**Key props:** `schedule`, `function` or `task`, `enabled`, `event`

**Schedule formats:** `rate(1 minute)`, `rate(5 hours)`, `cron(0 12 * * ? *)`, `at(2024-01-01T00:00:00)`

**Note:** Cron jobs continue running after `sst dev` exits.

---

### sst.aws.Postgres

RDS PostgreSQL with optional local Docker dev mode.

```typescript
const vpc = new sst.aws.Vpc("MyVpc");

const db = new sst.aws.Postgres("MyDB", {
  vpc,
  instance: "t4g.micro",
  storage: "20 GB",
  version: "17",
  dev: {
    host: "localhost",
    port: 5432,
    username: "postgres",
    password: "postgres",
    database: "mydb",
  },
});
```

**Key props:**

| Prop | Default | Description |
| ---- | ------- | ----------- |
| `vpc` | — | Required. VPC for the database |
| `instance` | `"t4g.micro"` | RDS instance type |
| `storage` | `"20 GB"` | Storage size |
| `version` | `"17"` | PostgreSQL version |
| `database` | App name | Database name |
| `proxy` | `false` | Enable RDS Proxy |
| `dev` | — | Local dev config (Docker Postgres) |

**When linked, exposes:** `host`, `port`, `username`, `password`, `database`

**Important:** The `dev` config makes `sst dev` use a local database instead of provisioning RDS. In production (`sst deploy`), the real RDS instance is used.

---

### sst.aws.ApiGatewayV2

HTTP API Gateway with Lambda route handlers.

```typescript
const api = new sst.aws.ApiGatewayV2("MyApi", {
  cors: true,
  domain: "api.example.com",
});

api.route("GET /", "src/routes/home.handler");
api.route("POST /users", "src/routes/create-user.handler");
api.route("GET /users/{id}", "src/routes/get-user.handler");
api.route("$default", "src/routes/default.handler");

// With authorizer
api.route("GET /admin", "src/routes/admin.handler", {
  auth: {
    jwt: {
      audiences: ["my-audience"],
      issuer: "https://example.auth0.com/",
    },
  },
});
```

**Key props:** `cors`, `domain`, `accessLog`

**Methods:** `.route(path, handler, args?)`, `.routePrivate(path, handler, args?)`

**When linked, exposes:** `url`

---

### sst.aws.Cluster + sst.aws.Service

ECS Fargate containers with auto-scaling and load balancing.

```typescript
const vpc = new sst.aws.Vpc("MyVpc");
const cluster = new sst.aws.Cluster("MyCluster", { vpc });

const service = new sst.aws.Service("MyService", {
  cluster,
  cpu: "0.25 vCPU",
  memory: "0.5 GB",
  architecture: "arm64",
  link: [db, bucket],
  image: {
    dockerfile: "Dockerfile",
    context: ".",
  },
  scaling: {
    min: 1,
    max: 10,
    cpuUtilization: 70,
    memoryUtilization: 70,
  },
  loadBalancer: {
    ports: [{ listen: "443/https", forward: "3000/http" }],
    domain: "app.example.com",
  },
  dev: {
    command: "npm run dev",
  },
});
```

**Key props (Service):** `cluster`, `cpu`, `memory`, `architecture`, `link`, `image`, `scaling`, `loadBalancer`, `dev`, `capacity` (Spot)

**When linked, exposes:** `url` (if load balancer configured)

**Note:** Use `dev.command` to run your local dev server during `sst dev` instead of deploying to ECS.

---

## Reference Components

For full documentation, see https://sst.dev/docs/components/

### Compute & Tasks
- **[sst.aws.Task](https://sst.dev/docs/component/aws/task)** — ECS Fargate tasks for async background jobs

### APIs
- **[sst.aws.ApiGatewayV1](https://sst.dev/docs/component/aws/api-gateway-v1)** — REST API Gateway
- **[sst.aws.ApiGatewayWebSocket](https://sst.dev/docs/component/aws/api-gateway-websocket)** — WebSocket API Gateway
- **[sst.aws.AppSync](https://sst.dev/docs/component/aws/app-sync)** — GraphQL with AppSync
- **[sst.aws.Router](https://sst.dev/docs/component/aws/router)** — CloudFront-based routing

### Streaming & Realtime
- **[sst.aws.KinesisStream](https://sst.dev/docs/component/aws/kinesis-stream)** — Kinesis data streams with `.subscribe()`
- **[sst.aws.Realtime](https://sst.dev/docs/component/aws/realtime)** — IoT WebSocket pub/sub

### Workflows
- **[sst.aws.StepFunctions](https://sst.dev/docs/component/aws/step-functions)** — Step Functions state machines (see [orchestration](orchestration-and-workflows.md))

### Databases
- **[sst.aws.Aurora](https://sst.dev/docs/component/aws/aurora)** — Aurora clusters (MySQL/PostgreSQL)
- **[sst.aws.Mysql](https://sst.dev/docs/component/aws/mysql)** — RDS MySQL
- **[sst.aws.Dsql](https://sst.dev/docs/component/aws/dsql)** — Aurora DSQL
- **[sst.aws.Redis](https://sst.dev/docs/component/aws/redis)** — ElastiCache Redis
- **[sst.aws.OpenSearch](https://sst.dev/docs/component/aws/open-search)** — OpenSearch domains

### Storage
- **[sst.aws.Efs](https://sst.dev/docs/component/aws/efs)** — Elastic File System
- **[sst.aws.Vector](https://sst.dev/docs/component/aws/vector)** — Vector store for embeddings

### Networking & CDN
- **[sst.aws.Vpc](https://sst.dev/docs/component/aws/vpc)** — VPC with subnets
- **[sst.aws.Cdn](https://sst.dev/docs/component/aws/cdn)** — CloudFront CDN
- **[sst.aws.Dns](https://sst.dev/docs/component/aws/dns)** — Route53 DNS
- **[sst.aws.Alb](https://sst.dev/docs/component/aws/alb)** — Application Load Balancer
- **[sst.aws.Email](https://sst.dev/docs/component/aws/email)** — SES Email

### Auth
- **[sst.aws.Auth](https://sst.dev/docs/component/aws/auth)** — Authentication
- **[sst.aws.CognitoUserPool](https://sst.dev/docs/component/aws/cognito-user-pool)** — Cognito User Pool
- **[sst.aws.CognitoIdentityPool](https://sst.dev/docs/component/aws/cognito-identity-pool)** — Cognito Identity Pool

### IAM
- **[sst.aws.Permission](https://sst.dev/docs/component/aws/permission)** — IAM permission helper

## Subscriber Method Reference

Different components use different method names — be precise:

| Component | Method | Signature |
| --------- | ------ | --------- |
| `Bus` | `.subscribe()` | `(name, subscriber, args?)` |
| `Bus` | `.subscribeQueue()` | `(name, queue, args?)` |
| `Dynamo` | `.subscribe()` | `(name, subscriber, args?)` |
| `SnsTopic` | `.subscribe()` | `(name, subscriber, args?)` |
| `SnsTopic` | `.subscribeQueue()` | `(name, queue, args?)` |
| `KinesisStream` | `.subscribe()` | `(name, subscriber, args?)` |
| **Queue** | **`.subscribe()`** | **`(subscriber, args?)` — no name param** |
| **Bucket** | **`.notify()`** | **`(args)` — different method name** |
| `Realtime` | `.subscribe()` | `(subscriber, args?)` |
