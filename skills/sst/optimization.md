# Optimization

## Lambda Memory and Timeout

### Right-sizing memory

Memory allocation directly affects CPU, network, and cost:

```typescript
new sst.aws.Function("ApiHandler", {
  handler: "src/api.handler",
  memory: "512 MB",     // Light API handler
  timeout: "10 seconds",
});

new sst.aws.Function("DataProcessor", {
  handler: "src/process.handler",
  memory: "3008 MB",    // CPU-intensive work (gets ~2 vCPU)
  timeout: "5 minutes",
});
```

**Key thresholds:**
- 1,769 MB = 1 full vCPU
- 3,538 MB = 2 vCPUs
- 5,307 MB = 3 vCPUs
- 10,240 MB = 6 vCPUs

**Tip:** Use AWS Lambda Power Tuning to find the optimal memory for your workload. More memory can actually reduce cost by finishing faster.

### Timeout strategy

- Set timeout per function based on its workload, not a global default
- API handlers: 10-30 seconds
- Event processors: 1-5 minutes
- Data pipelines: up to 15 minutes (900 seconds max)

## Architecture

Use ARM64 for ~20% cost savings with equivalent or better performance:

```typescript
new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  architecture: "arm64",  // Graviton2 — cheaper and often faster
});
```

ARM64 is compatible with most Node.js workloads. Check compatibility if using native binary dependencies.

## Cold Start Mitigation

### Provisioned concurrency

Keep instances warm for latency-sensitive functions:

```typescript
new sst.aws.Function("ApiHandler", {
  handler: "src/api.handler",
  concurrency: {
    provisioned: 5,  // Keep 5 instances warm
  },
});
```

**Cost:** You pay for provisioned instances even when idle. Use for critical API endpoints, not for background processors.

### Reserved concurrency

Limit the max concurrent executions (useful for protecting downstream resources):

```typescript
new sst.aws.Function("DbWriter", {
  handler: "src/db-writer.handler",
  concurrency: {
    reserved: 10,  // Max 10 concurrent executions
  },
});
```

### Reducing cold start time

1. **Minimize bundle size**: Use tree shaking and avoid large dependencies
2. **Use ESM format**: Faster module loading
3. **Lazy-load SDK clients**: Initialize outside the handler only what you always need
4. **Avoid VPC when possible**: VPC adds ~1-2s to cold starts (mitigated by Hyperplane ENIs)

```typescript
new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  nodejs: {
    minify: true,
    format: "esm",
    splitting: true,  // Code splitting for smaller chunks
  },
});
```

## Response Streaming

Stream responses for faster time-to-first-byte:

```typescript
new sst.aws.Function("StreamHandler", {
  handler: "src/stream.handler",
  streaming: true,
  url: true,
});
```

In the handler:
```typescript
export async function handler(event: any, responseStream: any) {
  responseStream.write("Starting...\n");
  // ... process ...
  responseStream.write("Done!\n");
  responseStream.end();
}
```

Streamed responses can be up to 200 MB (vs 6 MB synchronous limit).

## Bundling Optimization

### Minification and tree shaking

```typescript
new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  nodejs: {
    minify: true,           // Reduce bundle size
    format: "esm",          // ESM for better tree shaking
    splitting: true,         // Code splitting
    install: ["sharp"],      // Install native deps (not bundled by esbuild)
    esbuild: {
      external: ["@aws-sdk/*"],  // Exclude SDK (available in Lambda runtime)
    },
  },
});
```

### Copy extra files

```typescript
new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  copyFiles: [
    { from: "src/templates", to: "templates" },
  ],
});
```

## Container vs Serverless

| Factor | Function (Lambda) | Service (ECS Fargate) |
| ------ | ----------------- | -------------------- |
| Pricing | Pay per invocation | Pay per hour |
| Cold starts | Yes (mitigatable) | No |
| Max duration | 15 minutes | Unlimited |
| Connections | Short-lived | Long-lived (DB pools, WebSocket) |
| Scaling | Instant (per request) | Slower (per task) |
| Max memory | 10 GB | 120 GB |

**Use Functions when:** Short-lived, event-driven, bursty traffic, pay-per-use is important.

**Use Services when:** Long-running, persistent connections, steady traffic, need > 15 min execution.

### Fargate Spot for cost savings

```typescript
new sst.aws.Service("MyService", {
  cluster,
  capacity: "spot",  // Up to 70% cheaper, may be interrupted
});
```

Use Spot for non-critical workloads, development stages, or services that handle interruptions gracefully.

## Cost Optimization Patterns

### DynamoDB on-demand billing

SST's `Dynamo` component uses on-demand billing by default. Good for variable workloads. Switch to provisioned for predictable, steady traffic via transforms.

### CloudWatch log retention

```typescript
new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  logging: {
    retention: "1 week",  // Default is "forever" — costs add up
  },
});
```

### Ephemeral storage

```typescript
new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  // Default is 512 MB. Only increase if needed.
  transform: {
    function: {
      ephemeralStorage: { size: 1024 },  // MB
    },
  },
});
```

### Resource sizing by stage

```typescript
run() {
  const isProd = $app.stage === "production";

  new sst.aws.Postgres("MyDB", {
    vpc,
    instance: isProd ? "r6g.large" : "t4g.micro",
    storage: isProd ? "100 GB" : "20 GB",
  });
},
```

## Performance Checklist

- [ ] Use `arm64` architecture
- [ ] Set `memory` and `timeout` per function (not global defaults)
- [ ] Enable `minify` and `format: "esm"` in nodejs bundling
- [ ] Set `logging.retention` to avoid unbounded log costs
- [ ] Use `provisioned` concurrency only for latency-critical endpoints
- [ ] Consider Fargate Spot for non-critical services
- [ ] Use `streaming: true` for large responses
- [ ] Size database instances by stage (dev vs production)
