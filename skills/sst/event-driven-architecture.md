# Event-Driven Architecture

## Overview

Event-driven architecture decouples producers from consumers using events. SST provides first-class components for building event-driven systems on AWS.

## Choreography vs Orchestration

| Pattern | Implementation in SST | Best for |
| ------- | -------------------- | -------- |
| Choreography | `Bus` + `.subscribe()` | Loosely coupled services, fan-out |
| Orchestration | `StepFunctions` | Coordinated multi-step workflows |
| Hybrid | `Bus` triggers `StepFunctions` | Complex event-driven workflows |

**Choreography:** Each service reacts to events independently. No central coordinator. Use EventBridge Bus.

**Orchestration:** A central workflow controls the sequence. Use Step Functions. See [orchestration-and-workflows.md](orchestration-and-workflows.md).

## EventBridge Bus

### Create a bus

```typescript
const bus = new sst.aws.Bus("MyBus");
```

### Subscribe with Lambda

```typescript
bus.subscribe("OnOrderPlaced", "src/events/on-order-placed.handler", {
  pattern: {
    source: ["my.app.orders"],
    detailType: ["OrderPlaced"],
  },
});

bus.subscribe("OnOrderShipped", "src/events/on-order-shipped.handler", {
  pattern: {
    source: ["my.app.orders"],
    detailType: ["OrderShipped"],
  },
});
```

### Fan out to SQS

```typescript
const emailQueue = new sst.aws.Queue("EmailQueue");

bus.subscribeQueue("ToEmailQueue", emailQueue, {
  pattern: {
    source: ["my.app.orders"],
    detailType: ["OrderPlaced", "OrderShipped"],
  },
});
```

## Publishing Events

Use the AWS SDK with the linked bus name:

```typescript
import { Resource } from "sst";
import { EventBridgeClient, PutEventsCommand } from "@aws-sdk/client-eventbridge";

const client = new EventBridgeClient({});

export async function handler() {
  await client.send(
    new PutEventsCommand({
      Entries: [
        {
          EventBusName: Resource.MyBus.name,
          Source: "my.app.orders",
          DetailType: "OrderPlaced",
          Detail: JSON.stringify({
            orderId: "123",
            amount: 99.99,
            customerId: "cust-456",
          }),
        },
      ],
    })
  );
}
```

## Pattern Filtering

EventBridge supports rich content-based filtering:

### Exact match

```typescript
pattern: {
  source: ["my.app.orders"],
  detailType: ["OrderPlaced"],
}
```

### Prefix match

```typescript
pattern: {
  source: [{ prefix: "my.app" }],
}
```

### Numeric comparison

```typescript
pattern: {
  detail: {
    amount: [{ numeric: [">=", 100] }],
  },
}
```

### Anything-but

```typescript
pattern: {
  detail: {
    status: [{ "anything-but": ["cancelled", "refunded"] }],
  },
}
```

### Exists / Does not exist

```typescript
pattern: {
  detail: {
    discount: [{ exists: true }],
  },
}
```

### Combined filters

Filters within an array are OR'd. Filters across fields are AND'd.

```typescript
pattern: {
  source: ["my.app.orders"],                    // AND
  detail: {
    amount: [{ numeric: [">=", 100] }],         // AND
    region: ["us-east-1", "us-west-2"],          // OR (either region)
  },
}
```

## Event Envelope Design

### Recommended event structure

```typescript
{
  Source: "my.app.orders",
  DetailType: "OrderPlaced",
  Detail: JSON.stringify({
    // Metadata
    eventId: "evt-uuid",
    version: "1.0",
    timestamp: new Date().toISOString(),
    correlationId: "corr-uuid",

    // Data
    data: {
      orderId: "123",
      amount: 99.99,
      items: [...],
    },
  }),
}
```

### Light vs Rich Events

| Style | Event contains | Consumers do |
| ----- | -------------- | ------------ |
| Light | Entity ID only | Fetch full data from source |
| Rich | Full entity data | Process directly |

**Light events** reduce coupling but add latency. **Rich events** are faster but create tighter coupling. Prefer rich events when consumers need most of the data.

## Dead Letter Queues

Add DLQs to subscribers for failed event processing:

```typescript
const dlq = new sst.aws.Queue("DLQ");

bus.subscribe("OnOrder", "src/on-order.handler", {
  pattern: { source: ["my.app"] },
  transform: {
    target: {
      deadLetterConfig: {
        arn: dlq.arn,
      },
      retryPolicy: {
        maximumEventAgeInSeconds: 3600,
        maximumRetryAttempts: 3,
      },
    },
  },
});
```

## Common Patterns

### Event bridge between services

```typescript
// Service A publishes to the bus
const bus = new sst.aws.Bus("SharedBus");
const serviceA = new sst.aws.Function("ServiceA", {
  handler: "src/service-a.handler",
  link: [bus],
});

// Service B subscribes
bus.subscribe("ServiceBHandler", "src/service-b.handler", {
  pattern: { source: ["service-a"] },
});
```

### Fan-out pattern

```typescript
const bus = new sst.aws.Bus("OrderBus");

// Multiple subscribers for the same event
bus.subscribe("SendEmail", "src/send-email.handler", {
  pattern: { detailType: ["OrderPlaced"] },
});

bus.subscribe("UpdateInventory", "src/update-inventory.handler", {
  pattern: { detailType: ["OrderPlaced"] },
});

bus.subscribeQueue("AnalyticsQueue", analyticsQueue, {
  pattern: { detailType: ["OrderPlaced"] },
});
```
