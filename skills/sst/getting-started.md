# Getting Started with SST

## Decision Tree

Use this to route to the right approach:

| What are you building? | Primary components | Guide |
| ---------------------- | ------------------ | ----- |
| REST/HTTP API | `ApiGatewayV2` + `Function` | [components.md](components.md) |
| Full-stack web app | `Nextjs`/`Remix`/`Astro` + backend resources | [frontend-frameworks.md](frontend-frameworks.md) |
| Event processor | `Bus`/`Queue`/`SnsTopic` + `.subscribe()` | [event-sources.md](event-sources.md) |
| Scheduled job | `CronV2` + `Function` or `Task` | [components.md](components.md) |
| Container service | `Cluster` + `Service` | [components.md](components.md) |
| Multi-step workflow | `StepFunctions` or `Function` with `durable: true` | [orchestration-and-workflows.md](orchestration-and-workflows.md) |
| Database-backed app | `Dynamo` or `Postgres` + compute | [components.md](components.md) |
| Static website | `StaticSite` | [frontend-frameworks.md](frontend-frameworks.md) |

## Prerequisites

Before starting, verify:

```bash
node --version          # Node.js 18+
aws sts get-caller-identity  # AWS credentials configured
npx sst version         # SST CLI available
docker --version        # Optional: for local DBs and container builds
```

## Initialize a New Project

### New project from scratch

```bash
npx sst@latest init
```

This detects your framework (if any) and generates `sst.config.ts`.

### Add SST to an existing project

```bash
cd my-existing-app
npx sst@latest init
```

SST detects the framework and creates a `sst.config.ts` at the project root.

## Project Structure

After `sst init`, your project has:

```
my-app/
├── sst.config.ts       # Infrastructure definition
├── sst-env.d.ts        # Auto-generated types for linked resources
├── .sst/               # SST state and build artifacts (gitignored)
├── package.json
└── src/                # Your application code
```

## sst.config.ts Anatomy

Every SST project has a single `sst.config.ts` using the `$config` function:

```typescript
/// <reference path="./.sst/platform/config.d.ts" />

export default $config({
  app(input) {
    return {
      name: "my-app",
      removal: input.stage === "production" ? "retain" : "remove",
      protect: ["production"].includes(input.stage),
      home: "aws",
      providers: {
        aws: {
          region: "us-east-1",
        },
      },
    };
  },
  run() {
    // Define all resources here
    const bucket = new sst.aws.Bucket("MyBucket");

    const api = new sst.aws.Function("MyApi", {
      handler: "src/handler.handler",
      url: true,
      link: [bucket],
    });

    // Return outputs to display in CLI
    return {
      url: api.url,
    };
  },
});
```

### The `app` function

Evaluated first. Configures the app-level settings. **Cannot contain components or resources.**

| Property | Description | Default |
| -------- | ----------- | ------- |
| `name` | App identifier, used as resource prefix | Required |
| `home` | State provider: `"aws"`, `"cloudflare"`, or `"local"` | Required |
| `removal` | What happens on `sst remove`: `"remove"`, `"retain"`, `"retain-all"` | `"retain"` |
| `protect` | Prevent accidental removal: `true` or array of stage names | `false` |
| `providers` | Provider configuration (region, version, etc.) | `{}` |
| `version` | Pin SST version for consistency | Latest |

### The `run` function

Where all resources are defined. This is an async function — you can `await` if needed. Return an object of outputs to display after deploy.

### Global variables in `run()`

SST injects these globals (no import needed):

- `$app.name` — app name
- `$app.stage` — current stage
- `$app.removal` — removal policy
- `$app.providers` — configured providers
- `$interpolate` — template literal for `Output<string>` interpolation
- `$resolve` — wait on multiple outputs
- `$asset` — reference local files as assets

## Drop-in Mode vs Monorepo

### Drop-in mode (single app)

Place `sst.config.ts` at the project root. SST manages infrastructure alongside your app code.

```
my-app/
├── sst.config.ts
├── src/
├── package.json
└── ...
```

### Monorepo

For multiple services, use a monorepo structure:

```
my-monorepo/
├── sst.config.ts           # Single config for all infrastructure
├── packages/
│   ├── web/                # Frontend (Next.js, Remix, etc.)
│   ├── api/                # API handlers
│   ├── core/               # Shared business logic
│   └── functions/          # Lambda function handlers
└── package.json
```

The `sst.config.ts` at the root references handlers in subdirectories:

```typescript
new sst.aws.Function("MyApi", {
  handler: "packages/api/src/handler.handler",
  link: [bucket],
});
```

## Working with Existing SST Projects

When joining an existing project:

1. Look for `sst.config.ts` at the project root
2. Run `npm install` to get SST types
3. Check `.sst/` directory exists (created on first `sst dev` or `sst deploy`)
4. Run `sst diff` to see what's currently deployed
5. Run `sst dev` to start local development

## Environment Variables

SST loads `.env` and `.env.<stage>` files automatically:

- `.env` — loaded for all stages
- `.env.dev` — loaded only when `--stage dev`

Variables are available via `process.env` in both `app()` and `run()` functions. Changing `.env` files requires restarting `sst dev`.

## Next Steps

- [components.md](components.md) — Learn about SST's AWS components
- [resource-linking.md](resource-linking.md) — Connect resources to your application code
- [dev-workflow.md](dev-workflow.md) — Set up your local development environment
