# Event Sources

SST components provide subscriber patterns for connecting Lambda functions to AWS event sources.

## Push Sources

### S3 Bucket Notifications

Bucket uses `.notify()` — not `.subscribe()`.

```typescript
const bucket = new sst.aws.Bucket("Uploads");

bucket.notify({
  notifications: [
    {
      name: "OnImageUpload",
      function: "src/on-image-upload.handler",
      events: ["s3:ObjectCreated:*"],
      filterPrefix: "images/",
      filterSuffix: ".jpg",
    },
    {
      name: "OnDelete",
      function: "src/on-delete.handler",
      events: ["s3:ObjectRemoved:*"],
    },
  ],
});
```

**Available event types:**
- `s3:ObjectCreated:*` — any creation method
- `s3:ObjectCreated:Put`, `s3:ObjectCreated:Post`, `s3:ObjectCreated:Copy`
- `s3:ObjectRemoved:*` — any deletion
- `s3:ObjectRemoved:Delete`, `s3:ObjectRemoved:DeleteMarkerCreated`
- `s3:ObjectRestore:*` — Glacier restore events

**Filtering:** `filterPrefix` and `filterSuffix` on the key name.

**Targets:** Lambda function, SQS queue, or SNS topic.

### SNS Topic

```typescript
const topic = new sst.aws.SnsTopic("Notifications");

topic.subscribe("OnMessage", "src/on-message.handler", {
  filter: {
    type: ["order", "payment"],
  },
});

// Fan out to SQS
topic.subscribeQueue("ToProcessingQueue", queue, {
  filter: {
    type: ["order"],
  },
});
```

**Filter:** Attribute-based filtering on message attributes.

## Poll Sources

### DynamoDB Streams

Requires `stream` to be enabled on the table.

```typescript
const table = new sst.aws.Dynamo("Orders", {
  fields: {
    pk: "string",
    sk: "string",
  },
  primaryIndex: { hashKey: "pk", rangeKey: "sk" },
  stream: "new-and-old-images",
});

table.subscribe("OnOrderChange", "src/on-order-change.handler", {
  filters: [
    {
      dynamodb: {
        Keys: {
          pk: { S: [{ prefix: "ORDER#" }] },
        },
      },
    },
  ],
});
```

**Stream modes:** `"new-image"`, `"old-image"`, `"new-and-old-images"`, `"keys-only"`

**Filters:** Up to 5 filter policies (OR'd together). Filter on `dynamodb.Keys`, `dynamodb.NewImage`, `dynamodb.OldImage`.

**Static method for existing tables:**
```typescript
sst.aws.Dynamo.subscribe("ExternalSub", "arn:aws:dynamodb:...:table/MyTable/stream/...", "src/handler.handler");
```

### SQS Queue

```typescript
const queue = new sst.aws.Queue("ProcessingQueue", {
  visibilityTimeout: "60 seconds",
  dlq: {
    queue: dlq.arn,
    retry: 3,
  },
});

// NOTE: Queue.subscribe() has NO name parameter
queue.subscribe("src/process.handler", {
  batch: {
    size: 10,
    window: "20 seconds",
    partialResponses: true,
  },
  filters: [
    {
      body: {
        type: ["order"],
      },
    },
  ],
});
```

**Batch options:**
- `size` — max messages per batch (1-10, or up to 10,000 for FIFO)
- `window` — max time to wait for a full batch
- `partialResponses` — report individual message failures instead of failing the entire batch

**Filters:** Up to 5 filter policies. Filter on `body` content.

**Important:** Queue `.subscribe()` has no `name` parameter — this differs from Bus, SnsTopic, and Dynamo.

### Kinesis Streams

```typescript
const stream = new sst.aws.KinesisStream("MyStream");

stream.subscribe("OnRecord", "src/on-record.handler", {
  filters: [
    {
      data: {
        type: ["transaction"],
      },
    },
  ],
});
```

**When linked, exposes:** `name`

## Scheduled Sources

### CronV2

Triggers a function or ECS task on a schedule.

```typescript
// Rate expression
new sst.aws.CronV2("EveryMinute", {
  schedule: "rate(1 minute)",
  function: "src/tick.handler",
});

// Cron expression
new sst.aws.CronV2("DailyReport", {
  schedule: "cron(0 9 * * ? *)",
  function: "src/daily-report.handler",
});

// At a specific time
new sst.aws.CronV2("OneTime", {
  schedule: "at(2024-12-31T23:59:00)",
  function: "src/new-year.handler",
});
```

**Schedule formats:**
- `rate(N unit)` — `rate(1 minute)`, `rate(5 hours)`, `rate(1 day)`
- `cron(min hour day month dow year)` — standard cron with `?` for unused day fields
- `at(ISO-8601)` — one-time execution

**Note:** `sst.aws.Cron` is deprecated. Use `sst.aws.CronV2`.

**Warning:** Cron jobs continue running after `sst dev` exits. Remove them with `sst remove` or disable with `enabled: false`.

## Realtime (IoT WebSocket)

For real-time pub/sub messaging:

```typescript
const server = new sst.aws.Realtime("Chat", {
  authorizer: "src/authorizer.handler",
});

server.subscribe("src/on-message.handler", {
  filter: `${$app.name}/${$app.stage}/chat/*`,
});
```

See [sst.aws.Realtime docs](https://sst.dev/docs/component/aws/realtime) for full details.

## Filter Pattern Summary

| Source | Filter location | Max filters |
| ------ | --------------- | ----------- |
| DynamoDB Streams | `dynamodb.Keys`, `dynamodb.NewImage`, `dynamodb.OldImage` | 5 |
| SQS Queue | `body` | 5 |
| Kinesis | `data` | 5 |
| SNS Topic | Message attributes | — |
| S3 Bucket | `filterPrefix`, `filterSuffix` on key | Per notification |
| EventBridge Bus | `source`, `detailType`, `detail` | Per rule |

All filter arrays are OR'd (match any). Multiple filter fields are AND'd (match all).
