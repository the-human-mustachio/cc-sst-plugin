# Deployment

## Deploying

### Deploy to a stage

```bash
npx sst deploy --stage production
npx sst deploy --stage staging
npx sst deploy --stage dev
```

### Preview changes first

```bash
npx sst diff --stage production
```

Shows what resources will be created, updated, or deleted without making changes.

### Deploy specific resources

```bash
npx sst deploy --stage production --target MyFunction
npx sst deploy --stage production --exclude MyBucket
```

## Stages

Stages are isolated environments. Each stage gets its own set of AWS resources prefixed with the stage name.

Common stage patterns:
- `production` — live traffic
- `staging` — pre-production testing
- `dev` — shared development
- `matt`, `jane` — personal developer stages

The current stage is available in config via `input.stage` and in code via `Resource.App.stage`.

### Conditional configuration by stage

```typescript
app(input) {
  return {
    name: "my-app",
    home: "aws",
    removal: input.stage === "production" ? "retain" : "remove",
    protect: ["production"].includes(input.stage),
  };
},
run() {
  const isProd = $app.stage === "production";

  const db = new sst.aws.Postgres("MyDB", {
    vpc,
    instance: isProd ? "r6g.large" : "t4g.micro",
    storage: isProd ? "100 GB" : "20 GB",
  });
},
```

## Removal

```bash
npx sst remove --stage dev
```

### Removal policies

Set in the `app` function:

| Policy | Behavior |
| ------ | -------- |
| `"remove"` | Delete all resources on `sst remove` |
| `"retain"` | Keep S3 buckets and DynamoDB tables, delete everything else (default) |
| `"retain-all"` | Keep all resources |

### Stage protection

```typescript
app(input) {
  return {
    name: "my-app",
    home: "aws",
    protect: true,                         // Protect all stages
    // OR
    protect: ["production", "staging"],    // Protect specific stages
  };
},
```

Protected stages cannot be removed with `sst remove`.

## Secrets

SST encrypts secrets and stores them in your state backend (S3 for AWS).

### Set a secret

```bash
npx sst secret set STRIPE_KEY sk_live_xxx --stage production
npx sst secret set STRIPE_KEY sk_test_xxx --stage dev
```

### Set a fallback (default across stages)

```bash
npx sst secret set DATABASE_URL postgres://... --fallback
```

### Bulk load from file

```bash
npx sst secret load .env.secrets --stage production
```

### List secrets

```bash
npx sst secret list --stage production
```

### Remove a secret

```bash
npx sst secret remove OLD_SECRET --stage production
```

### Use secrets in config

```typescript
run() {
  const secret = new sst.Secret("StripeKey");

  new sst.aws.Function("Checkout", {
    handler: "src/checkout.handler",
    link: [secret],
  });
},
```

In application code:
```typescript
import { Resource } from "sst";
const key = Resource.StripeKey.value;
```

## State Management

SST stores deployment state in your `home` provider (S3 for AWS).

### List all deployed stages

```bash
npx sst state list
```

### Export state

```bash
npx sst state export
npx sst state export --decrypt    # Include secret values
```

### Fix corrupted state

```bash
npx sst state repair
```

### Remove a resource from state

```bash
npx sst state remove <resource-urn>
```

This removes the resource from SST's state without deleting it from AWS. Useful when manually cleaning up.

### Unlock stuck deployments

```bash
npx sst unlock
```

Releases a deployment lock held by a previous process that crashed.

### Sync state with cloud

```bash
npx sst refresh --stage production
```

Syncs SST's state with the actual cloud resources. Use when resources were modified outside of SST.

## CI/CD

### Manual CI

```bash
# In your CI pipeline
npm install
npx sst deploy --stage production
```

### SST Console Autodeploy

Configure in `sst.config.ts`:

```typescript
export default $config({
  // ...
  console: {
    autodeploy: {
      target(event) {
        if (event.type === "branch" && event.branch === "main" && event.action === "pushed") {
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

This deploys automatically when code is pushed to GitHub.

## Useful Flags

| Flag | Description |
| ---- | ----------- |
| `--stage <name>` | Target stage |
| `--verbose` | Detailed output |
| `--print-logs` | Print Lambda logs during deploy |
| `--target <name>` | Deploy only specific resources |
| `--exclude <name>` | Skip specific resources |
| `--continue` | Continue on error |
