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

## Transform Callbacks

Customize the underlying AWS resources that SST components create:

```typescript
new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  transform: {
    function: {
      // Override the underlying Lambda function props
      memorySize: 2048,
      ephemeralStorage: { size: 5120 },
    },
    role: {
      // Override the IAM role props
      managedPolicyArns: ["arn:aws:iam::policy/ReadOnlyAccess"],
    },
  },
});
```

Transforms give you access to the raw Pulumi resource properties when SST's high-level props don't expose what you need.

### Function transforms

```typescript
transform: {
  function: (args) => {
    args.memorySize = 2048;
    return args;
  },
}
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
