# Orchestration and Workflows

## Choosing an Approach

| Approach | Best for | SST Component |
| -------- | -------- | ------------- |
| Step Functions | Visual workflows, cross-service orchestration, retries | `sst.aws.StepFunctions` |
| Lambda Durable Functions | Code-first workflows, complex business logic | `sst.aws.Function` with `durable: true` |
| EventBridge choreography | Loosely coupled, fan-out, async notifications | `sst.aws.Bus` |

## Step Functions

SST provides the `sst.aws.StepFunctions` component for building AWS Step Functions state machines.

### Basic state machine

```typescript
const fn = new sst.aws.Function("ProcessOrder", {
  handler: "src/process-order.handler",
});

const sm = new sst.aws.StepFunctions("OrderWorkflow", {
  definition: {
    StartAt: "Process",
    States: {
      Process: {
        Type: "Task",
        Resource: fn.arn,
        Next: "Done",
      },
      Done: {
        Type: "Succeed",
      },
    },
  },
});
```

### State types

| Type | Purpose |
| ---- | ------- |
| `Task` | Execute work (Lambda, ECS, SDK calls) |
| `Choice` | Branch based on input |
| `Parallel` | Run branches concurrently |
| `Map` | Iterate over an array |
| `Wait` | Delay execution |
| `Pass` | Transform input/output |
| `Succeed` | Terminal success state |
| `Fail` | Terminal failure state |

### Task integrations

Step Functions can invoke many AWS services directly:

```typescript
// Lambda invoke
{
  Type: "Task",
  Resource: "arn:aws:states:::lambda:invoke",
  Parameters: {
    FunctionName: fn.arn,
    "Payload.$": "$",
  },
}

// DynamoDB PutItem
{
  Type: "Task",
  Resource: "arn:aws:states:::dynamodb:putItem",
  Parameters: {
    TableName: table.name,
    Item: {
      "pk": { "S.$": "$.orderId" },
      "status": { S: "processed" },
    },
  },
}

// SQS SendMessage
{
  Type: "Task",
  Resource: "arn:aws:states:::sqs:sendMessage",
  Parameters: {
    QueueUrl: queue.url,
    "MessageBody.$": "$",
  },
}

// SNS Publish
{
  Type: "Task",
  Resource: "arn:aws:states:::sns:publish",
  Parameters: {
    TopicArn: topic.arn,
    "Message.$": "$",
  },
}

// EventBridge PutEvents
{
  Type: "Task",
  Resource: "arn:aws:states:::events:putEvents",
  Parameters: {
    Entries: [{
      EventBusName: bus.name,
      Source: "my.app",
      DetailType: "OrderProcessed",
      "Detail.$": "$",
    }],
  },
}
```

### Error handling and retries

```typescript
{
  Type: "Task",
  Resource: fn.arn,
  Retry: [
    {
      ErrorEquals: ["Lambda.ServiceException", "Lambda.AWSLambdaException"],
      IntervalSeconds: 2,
      MaxAttempts: 3,
      BackoffRate: 2,
    },
  ],
  Catch: [
    {
      ErrorEquals: ["States.ALL"],
      Next: "HandleError",
    },
  ],
}
```

### Standard vs Express

| Feature | Standard | Express |
| ------- | -------- | ------- |
| Duration | Up to 1 year | Up to 5 minutes |
| Execution semantics | Exactly-once | At-least-once |
| Pricing | Per state transition | Per execution + duration |
| History | Full execution history | CloudWatch Logs only |
| Best for | Long-running, critical | High-volume, short |

## Lambda Durable Functions

Durable Functions let you write long-running workflows as regular TypeScript code. The runtime checkpoints automatically, and the function resumes where it left off after sleeping or waiting.

### Enable on a function

```typescript
new sst.aws.Function("Workflow", {
  handler: "src/workflow.handler",
  durable: true,
  // Or with options:
  durable: {
    timeout: "1 hour",
    retention: "3 days",
  },
});
```

### Writing durable functions

```typescript
import { step, sleep, map } from "@aws/durable-execution-sdk-js";

export async function handler(event: any) {
  // Each step is checkpointed — if the function is interrupted,
  // it resumes from the last completed step
  const order = await step("validate", async () => {
    return validateOrder(event.orderId);
  });

  const payment = await step("charge", async () => {
    return chargePayment(order.amount);
  });

  // Sleep for a duration (function hibernates, no cost)
  await sleep("wait-for-shipping", "2 hours");

  const shipping = await step("ship", async () => {
    return shipOrder(order.id);
  });

  // Process items in parallel
  const results = await map("process-items", order.items, async (item) => {
    return processItem(item);
  });

  return { order, payment, shipping, results };
}
```

### Key concepts

- **`step(name, fn)`** — Checkpoint a unit of work. If the function restarts, completed steps return their cached result.
- **`sleep(name, duration)`** — Hibernate the function. No cost during sleep. Resumes automatically.
- **`map(name, items, fn)`** — Process items in parallel with checkpointing.

### When to use Durable Functions

- Business logic that's easier to express as sequential code than a state machine
- Workflows with long waits (hours, days) between steps
- When you want TypeScript logic (conditions, loops) instead of JSON state definitions
- Simpler debugging — it's just code with a stack trace

### Limitations

- Requires Node.js 22+ runtime
- Each step must be idempotent (may re-execute on retry)
- Maximum execution depends on `durable.timeout`

## EventBridge Choreography

For loosely coupled workflows where services react independently to events:

```typescript
const bus = new sst.aws.Bus("OrderBus");

// Order service publishes OrderPlaced
const orderFn = new sst.aws.Function("OrderService", {
  handler: "src/order.handler",
  link: [bus],
});

// Payment service reacts
bus.subscribe("ChargePayment", "src/payment.handler", {
  pattern: { detailType: ["OrderPlaced"] },
});

// Inventory service reacts
bus.subscribe("UpdateInventory", "src/inventory.handler", {
  pattern: { detailType: ["OrderPlaced"] },
});

// Notification service reacts
bus.subscribe("SendConfirmation", "src/notification.handler", {
  pattern: { detailType: ["PaymentCompleted"] },
});
```

See [event-driven-architecture.md](event-driven-architecture.md) for detailed EventBridge patterns.

## Decision Guide

**Use Step Functions when:**
- You need visual workflow monitoring
- The workflow involves multiple AWS service integrations
- You need exactly-once execution semantics
- Error handling and retries per step are critical
- Non-technical stakeholders need to understand the flow

**Use Durable Functions when:**
- The workflow is primarily business logic
- You prefer code over JSON state definitions
- You need long sleeps between steps
- The team is more comfortable with TypeScript than ASL

**Use EventBridge choreography when:**
- Services should be loosely coupled
- Multiple consumers react to the same event
- There's no single "happy path" — each service decides independently
- You need fan-out patterns
