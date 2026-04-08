# Development Workflow

## sst dev

`sst dev` is the primary development command. It deploys your infrastructure to AWS and proxies Lambda invocations to your local machine for instant feedback.

```bash
npx sst dev
```

### Modes

| Mode | Flag | Description |
| ---- | ---- | ----------- |
| Multi (default) | `--mode multi` | TUI multiplexer showing all panes |
| Mono | `--mode mono` | Single pane, no TUI |
| Basic | `--mode basic` | No TUI, plain output |

### With a frontend

```bash
npx sst dev next dev          # Next.js
npx sst dev remix dev         # Remix
npx sst dev -- npm run dev    # Generic
```

The multiplexer shows separate panes for:
- SST infrastructure deployment
- Your frontend dev server
- Lambda function logs

### How Live Lambda Works

1. SST deploys a stub Lambda function to AWS
2. When the stub is invoked, it forwards the event to your local machine via IoT WebSocket
3. Your local code executes with the event
4. The response is sent back to AWS
5. Code changes are picked up instantly — no redeploy needed

## Personal Stages

Each developer should use their own stage to avoid conflicts:

```bash
npx sst dev --stage matt
npx sst dev --stage jane
```

Resources are prefixed with the stage name, so stages are fully isolated.

## Local Database Development

### Postgres with Docker

Use the `dev` prop on `sst.aws.Postgres` to point to a local database during development:

```typescript
const db = new sst.aws.Postgres("MyDB", {
  vpc,
  dev: {
    host: "localhost",
    port: 5432,
    username: "postgres",
    password: "postgres",
    database: "mydb",
  },
});
```

Run a local Postgres with Docker:

```bash
docker run -d \
  --name sst-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  postgres:17
```

When `sst dev` runs, `Resource.MyDB.*` points to the local database. When `sst deploy` runs, it provisions a real RDS instance.

### Redis with Docker

Similarly for Redis:

```bash
docker run -d --name sst-redis -p 6379:6379 redis:7
```

## VPC Tunneling

Access VPC resources (RDS, ElastiCache, etc.) from your local machine:

```bash
# One-time setup (requires sudo)
sudo npx sst tunnel install

# Connect to VPC
npx sst tunnel
```

This creates a network tunnel so your local code can reach private VPC resources.

## Environment Variables

SST loads `.env` files automatically:

| File | Loaded when |
| ---- | ----------- |
| `.env` | Always |
| `.env.dev` | `--stage dev` |
| `.env.production` | `--stage production` |

Access via `process.env` in both `sst.config.ts` and application code.

**Note:** Changes to `.env` files require restarting `sst dev`.

## Dev vs Production Differences

| Behavior | `sst dev` | `sst deploy` |
| -------- | --------- | ------------ |
| Lambda execution | Local machine via proxy | AWS Lambda |
| Resource linking | `globalThis` injection | Bundled + encrypted |
| Frontend | Local dev server | S3 + CloudFront |
| Postgres (with `dev`) | Local Docker | RDS instance |
| Service (with `dev.command`) | Local process | ECS Fargate |
| Cost | Minimal (stub functions only) | Full AWS pricing |

## Watching Files

By default, `sst dev` watches your project for changes. Customize with:

```typescript
app(input) {
  return {
    name: "my-app",
    home: "aws",
    watch: ["packages/functions/**/*.ts", "packages/core/**/*.ts"],
  };
},
```

## Useful Commands During Development

```bash
npx sst diff                    # Preview changes before deploying
npx sst shell                   # Open shell with all resources linked
npx sst shell -- node script.js # Run a script with linked resources
npx sst secret set API_KEY xxx  # Set a secret for the current stage
```
