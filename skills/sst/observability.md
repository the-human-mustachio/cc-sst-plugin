# Observability

## SST Console

The SST Console is an optional web dashboard for managing SST apps. It provides:

- **Autodeploy**: Automatic deployment on Git push
- **Log viewer**: Real-time Lambda and container logs
- **Stage management**: View all deployed stages
- **Error tracking**: Automatic error detection for Lambda and containers
- **Deployment history**: Permalinks to every deployment

Free tier: projects with 350 or fewer active resources.

### Enable autodeploy

```typescript
export default $config({
  // ...
  console: {
    autodeploy: {
      target(event) {
        if (event.type === "branch" && event.branch === "main") {
          return { stage: "production" };
        }
        if (event.type === "pull_request") {
          return { stage: `pr-${event.number}` };
        }
      },
    },
  },
});
```

## CloudWatch Logging

### Configure log format and retention

```typescript
new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  logging: {
    format: "json",       // Structured JSON logs (recommended)
    retention: "1 week",  // Prevent unbounded log costs
  },
});
```

**Log formats:** `"text"` (default), `"json"` (structured — better for querying).

**Retention options:** `"1 day"`, `"3 days"`, `"5 days"`, `"1 week"`, `"2 weeks"`, `"1 month"`, `"2 months"`, `"3 months"`, `"6 months"`, `"1 year"`, `"forever"` (default).

### View logs during development

In `sst dev`, Lambda logs appear in the multiplexer TUI automatically.

From the CLI:

```bash
npx sst dev --print-logs
```

## AWS Lambda Powertools

Powertools for TypeScript provides structured logging, tracing, and metrics.

### Install

```bash
npm install @aws-lambda-powertools/logger @aws-lambda-powertools/tracer @aws-lambda-powertools/metrics
```

### Structured logging

```typescript
import { Logger } from "@aws-lambda-powertools/logger";

const logger = new Logger({
  serviceName: "my-service",
  logLevel: "INFO",
});

export async function handler(event: any) {
  logger.info("Processing order", { orderId: event.orderId });

  try {
    // ...
    logger.info("Order processed", { orderId: event.orderId, status: "success" });
  } catch (error) {
    logger.error("Failed to process order", error as Error);
    throw error;
  }
}
```

### Distributed tracing

```typescript
import { Tracer } from "@aws-lambda-powertools/tracer";

const tracer = new Tracer({ serviceName: "my-service" });

export async function handler(event: any) {
  const segment = tracer.getSegment();
  const subsegment = segment?.addNewSubsegment("processOrder");

  try {
    // ... do work
    subsegment?.close();
  } catch (error) {
    subsegment?.addError(error as Error);
    subsegment?.close();
    throw error;
  }
}
```

**Note:** X-Ray tracing is not auto-enabled by SST. Enable it via transform:

```typescript
new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  transform: {
    function: {
      tracingConfig: { mode: "Active" },
    },
  },
});
```

### Custom metrics (EMF)

```typescript
import { Metrics, MetricUnit } from "@aws-lambda-powertools/metrics";

const metrics = new Metrics({
  namespace: "MyApp",
  serviceName: "order-service",
});

export async function handler(event: any) {
  metrics.addMetric("OrdersProcessed", MetricUnit.Count, 1);
  metrics.addMetric("OrderAmount", MetricUnit.None, event.amount);

  // Publish metrics at the end
  metrics.publishStoredMetrics();
}
```

## Correlation ID Propagation

Pass a correlation ID through your event-driven pipeline for end-to-end tracing:

```typescript
import { Logger } from "@aws-lambda-powertools/logger";

const logger = new Logger({ serviceName: "my-service" });

export async function handler(event: any) {
  // Extract or generate correlation ID
  const correlationId = event.detail?.correlationId
    ?? event.headers?.["x-correlation-id"]
    ?? crypto.randomUUID();

  logger.appendKeys({ correlationId });
  logger.info("Processing event");

  // Pass it forward when publishing events
  await eventBridge.send(new PutEventsCommand({
    Entries: [{
      EventBusName: Resource.MyBus.name,
      Source: "my.service",
      DetailType: "OrderProcessed",
      Detail: JSON.stringify({
        correlationId,
        // ... other data
      }),
    }],
  }));
}
```

## CloudWatch Logs Insights

Query structured logs across functions:

```
# Find errors in the last hour
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50
```

```
# Aggregate by correlation ID
fields @timestamp, correlationId, @message
| filter correlationId = "abc-123"
| sort @timestamp asc
```

## Container Observability

For `sst.aws.Service` containers, logs go to CloudWatch automatically. Configure via:

```typescript
new sst.aws.Service("MyService", {
  cluster,
  // Logs are sent to CloudWatch Log Group automatically
  // Use structured logging in your application code
});
```

## Monitoring Best Practices

- Use `logging.format: "json"` for all functions — enables CloudWatch Logs Insights queries
- Set `logging.retention` to control costs — `"forever"` is rarely necessary
- Add Powertools Logger to every function for consistent structured logging
- Propagate correlation IDs across event-driven boundaries
- Use CloudWatch Alarms for critical metrics (error rate, latency, throttles)
- Monitor Lambda concurrent executions to avoid hitting account limits
