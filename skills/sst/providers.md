# Providers

SST uses Pulumi and Terraform providers under the hood. You can use raw provider resources alongside SST's high-level components.

## Adding Providers

```bash
npx sst add aws
npx sst add cloudflare
npx sst add stripe
```

This adds the provider to `sst.config.ts` and installs it.

## Provider Configuration

Configure providers in the `app` function:

```typescript
app(input) {
  return {
    name: "my-app",
    home: "aws",
    providers: {
      aws: {
        region: "us-east-1",
        // version: "6.27.0",  // Pin version for reproducibility
      },
    },
  };
},
```

### Multiple AWS Regions

Create additional provider instances for multi-region:

```typescript
run() {
  // Default region from app config
  const bucket = new sst.aws.Bucket("PrimaryBucket");

  // Second region
  const usWest = new aws.Provider("UsWest", { region: "us-west-2" });
  const replicaBucket = new sst.aws.Bucket("ReplicaBucket", {}, {
    provider: usWest,
  });
},
```

## Raw Pulumi Resources

Use provider resources directly when SST doesn't have a high-level component:

```typescript
run() {
  // Raw AWS resource via Pulumi
  const topic = new aws.sns.Topic("MyTopic", {
    displayName: "My Notifications",
  });

  // Mix with SST components
  const fn = new sst.aws.Function("MyFunction", {
    handler: "src/handler.handler",
    link: [topic],  // Works if wrapped (see below)
  });
},
```

**Important:** Provider resources are available as globals (e.g., `aws.*`, `cloudflare.*`). Do not import them — SST injects them automatically.

## Making Raw Resources Linkable

Raw Pulumi resources aren't linkable by default. Wrap them:

```typescript
// One-time setup: teach SST how to link this resource type
sst.Linkable.wrap(aws.sns.Topic, (topic) => ({
  properties: { arn: topic.arn },
}));

// Now any raw SNS topic can be linked
const topic = new aws.sns.Topic("MyTopic");

new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  link: [topic],
});
```

## Importing Existing AWS Resources

Reference resources that already exist in your AWS account:

```typescript
run() {
  // Import an existing S3 bucket by name
  const existing = aws.s3.BucketV2.get("ExistingBucket", "my-existing-bucket-name");

  // Import an existing DynamoDB table
  const existingTable = sst.aws.Dynamo.get("ExistingTable", "my-table-name");
},
```

SST's `.get()` methods look up the resource by ID/name and return it as a managed reference.

## Transforms

Transforms let you customize the underlying AWS resources that SST components create. Use them when SST's high-level props don't expose what you need — they're the escape hatch to the raw Pulumi resource layer.

### When to use transforms vs props

- **Use SST props** when the component directly exposes the setting (e.g., `memory`, `timeout`, `link`)
- **Use transforms** when you need to set something on the underlying AWS resource that SST doesn't surface (e.g., `ephemeralStorage`, `tracingConfig`, `managedPolicyArns`)

### Object form (simple overrides)

Merge properties directly into the underlying resource:

```typescript
new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  transform: {
    function: {
      memorySize: 2048,
      ephemeralStorage: { size: 5120 },
    },
    role: {
      managedPolicyArns: ["arn:aws:iam::policy/ReadOnlyAccess"],
    },
  },
});
```

### Callback form (full control)

The callback receives `(args, opts, name)` — use it for conditional logic or to modify Pulumi resource options:

```typescript
new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  transform: {
    function: (args, opts, name) => {
      args.memorySize = 2048;
      args.tracingConfig = { mode: "Active" };
      // opts gives access to Pulumi ComponentResourceOptions
      opts.retainOnDelete = true;
    },
    role: (args) => {
      args.name = `custom-role-${args.name}`;
    },
  },
});
```

**Callback signature:** `(args: ResourceArgs, opts: pulumi.ComponentResourceOptions, name: string) => void`

### $transform global (apply to all instances)

Set defaults across every instance of a component type:

```typescript
run() {
  // All Functions created AFTER this line get these defaults
  $transform(sst.aws.Function, (args) => {
    args.architecture ??= "arm64";
    args.runtime ??= "nodejs22.x";
    args.logging ??= { format: "json", retention: "1 week" };
  });

  // These functions inherit the defaults above
  const api = new sst.aws.Function("Api", {
    handler: "src/api.handler",
    // architecture is "arm64" from $transform
  });

  const worker = new sst.aws.Function("Worker", {
    handler: "src/worker.handler",
    architecture: "x86_64",  // Overrides the $transform default
  });
},
```

**Important:**
- `$transform` only applies to components declared **after** the call — order matters
- Use nullish coalescing (`??=`) so component-level props can override the global default
- Callback signature: `(args: ComponentArgs, opts: pulumi.ComponentResourceOptions) => void`

### Transform targets by component

Each SST component exposes specific transform targets — these are the underlying Pulumi resources you can customize:

| Component | Transform targets |
| --------- | ----------------- |
| **Function** | `function`, `role`, `logGroup`, `eventInvokeConfig` |
| **Bucket** | `bucket`, `cors`, `lifecycle`, `policy`, `publicAccessBlock`, `versioning`, `notification` |
| **Dynamo** | `table`, `eventSourceMapping` |
| **Queue** | `queue`, `dlq` |
| **Bus** | `bus`, `rule`, `target` |
| **SnsTopic** | `topic` |
| **Postgres** | `instance`, `subnetGroup`, `parameterGroup`, `proxy` |
| **ApiGatewayV2** | `api`, `stage`, `accessLog`, `domainName` |
| **Cluster** | `cluster` |
| **Service** | `service`, `taskDefinition`, `taskRole`, `executionRole`, `loadBalancer`, `target`, `listener` |
| **Nextjs** | `assets`, `cdn`, `server`, `imageOptimizer`, `revalidationEventsSubscriber`, `revalidationSeeder` |
| **CronV2** | `rule`, `target` |

Consult each component's docs for the exact Pulumi resource type behind each target.

### Common transform patterns

**Enable X-Ray tracing on all functions:**
```typescript
$transform(sst.aws.Function, (args) => {
  args.transform ??= {};
  args.transform.function ??= {};
  // Note: for $transform on the component itself, set top-level args
});

// Or per-function:
new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  transform: {
    function: {
      tracingConfig: { mode: "Active" },
    },
  },
});
```

**Retain a bucket on delete:**
```typescript
new sst.aws.Bucket("ImportantData", {
  transform: {
    bucket: (args, opts) => {
      opts.retainOnDelete = true;
    },
  },
});
```

**Add a resource policy to an SNS topic:**
```typescript
new sst.aws.SnsTopic("Alerts", {
  transform: {
    topic: {
      policy: JSON.stringify({
        Version: "2012-10-17",
        Statement: [{
          Effect: "Allow",
          Principal: { Service: "events.amazonaws.com" },
          Action: "sns:Publish",
          Resource: "*",
        }],
      }),
    },
  },
});
```

**Skip creating a resource (return false):**
```typescript
new sst.aws.Bucket("MyBucket", {
  access: "public",
  transform: {
    publicAccessBlock: false,  // Don't create the public access block
  },
});
```

## Output<T> Types

Pulumi resources return `Output<T>` — values that aren't resolved until deployment. Handle them with:

### String interpolation

```typescript
const bucket = new sst.aws.Bucket("MyBucket");
const url = $interpolate`https://${bucket.name}.s3.amazonaws.com`;
```

### Transform values

```typescript
const upperName = bucket.name.apply((name) => name.toUpperCase());
```

### Wait on multiple outputs

```typescript
const result = $resolve([bucket.name, table.name]).apply(
  ([bucketName, tableName]) => {
    return `${bucketName}-${tableName}`;
  }
);
```

### Using outputs in conditionals

```typescript
// WRONG: Output<T> is not a plain value
// if (bucket.name === "foo") { ... }

// RIGHT: use .apply()
bucket.name.apply((name) => {
  if (name === "foo") { /* ... */ }
});
```

**Key rule:** You cannot use `Output<T>` values in plain JavaScript logic. Always use `.apply()` or `$interpolate` to work with them.

## Installing Providers

After modifying provider configuration in `sst.config.ts`:

```bash
npx sst install
```

This installs all configured providers.
