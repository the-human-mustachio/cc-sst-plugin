# Resource Linking

Resource linking is SST's core mechanism for connecting infrastructure to application code. It provides type-safe access to resource properties at runtime and automatically generates the necessary IAM permissions.

## The `link` Prop

Add resources to the `link` array on any compute component:

```typescript
const bucket = new sst.aws.Bucket("MyBucket");
const table = new sst.aws.Dynamo("MyTable", {
  fields: { pk: "string" },
  primaryIndex: { hashKey: "pk" },
});

new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  link: [bucket, table],
});
```

This does two things:
1. Injects resource properties (name, ARN, URL, etc.) into the function's environment
2. Generates least-privilege IAM permissions for the function to access those resources

## Accessing Linked Resources

In your application code, import the `Resource` object from `sst`:

```typescript
import { Resource } from "sst";

export async function handler() {
  // Type-safe access to linked resources
  console.log(Resource.MyBucket.name);    // S3 bucket name
  console.log(Resource.MyTable.name);     // DynamoDB table name

  // App metadata is always available
  console.log(Resource.App.name);         // App name
  console.log(Resource.App.stage);        // Current stage
}
```

## What Each Component Exposes

When a resource is linked, these properties are available via `Resource.<name>`:

| Component | Properties |
| --------- | ---------- |
| `Function` (with url) | `name`, `url` |
| `Bucket` | `name` |
| `Dynamo` | `name` |
| `Queue` | `url` |
| `Bus` | `name`, `arn` |
| `SnsTopic` | `arn` |
| `Postgres` | `host`, `port`, `username`, `password`, `database` |
| `ApiGatewayV2` | `url` |
| `Service` (with LB) | `url` |
| `KinesisStream` | `name` |
| `Redis` | `host`, `port` |

## Type Generation

SST generates `sst-env.d.ts` during `sst dev` and `sst deploy`. This file provides TypeScript types for all linked resources:

```typescript
// sst-env.d.ts (auto-generated, safe to commit)
declare module "sst" {
  export interface Resource {
    MyBucket: { name: string };
    MyTable: { name: string };
    App: { name: string; stage: string };
  }
}
```

This enables full autocomplete and type checking when using `Resource.*`.

## Custom Linkables

### Linking arbitrary values

Use `sst.Linkable` to expose custom values to your functions:

```typescript
const config = new sst.Linkable("MyConfig", {
  properties: {
    stripeKey: "sk_test_...",
    apiVersion: "2024-01",
  },
});

new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  link: [config],
});
```

Access in code:
```typescript
import { Resource } from "sst";
console.log(Resource.MyConfig.stripeKey);
```

### Wrapping Pulumi resources

Make raw Pulumi resources linkable:

```typescript
import * as aws from "@pulumi/aws";

sst.Linkable.wrap(aws.dynamodb.Table, (table) => ({
  properties: { tableName: table.name },
}));

// Now any raw DynamoDB table can be linked
const rawTable = new aws.dynamodb.Table("RawTable", { ... });

new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  link: [rawTable],  // Works because of the wrap
});
```

### Getting environment variables

For non-SST compute (e.g., Docker containers), convert links to env vars:

```typescript
const env = sst.Linkable.env([bucket, table]);
// Returns: { SST_RESOURCE_MyBucket: "...", SST_RESOURCE_MyTable: "..." }
```

## Linking in Frontends

For frontend frameworks (`Nextjs`, `Remix`, `Astro`, etc.), linked resources are injected as `SST_RESOURCE_` prefixed environment variables on the server side:

```typescript
const bucket = new sst.aws.Bucket("MyBucket");

new sst.aws.Nextjs("MyApp", {
  link: [bucket],
});
```

In your Next.js server code:
```typescript
import { Resource } from "sst";
// Works in server components, API routes, middleware
console.log(Resource.MyBucket.name);
```

**Important:** Linked resources are only available server-side. They are not exposed to the browser.

## Dev vs Production Linking

- **`sst dev`**: Resources are injected via `globalThis`, encrypted and decrypted synchronously on function cold start
- **`sst deploy`**: Resources are bundled into the function package, encrypted at rest

The `Resource` API is identical in both modes — no conditional code needed.
