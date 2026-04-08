---
name: sst
description: "Build and deploy full-stack applications with SST (Ion) on AWS — Lambda, containers, databases, frontends, and event-driven architectures"
argument-hint: "[what are you building?]"
allowed-tools: Bash(sst *), Bash(npx sst *), Bash(aws *), Bash(docker *), Read, Glob, Grep, Edit, Write
---

# SST Plugin

## Overview

Build and deploy full-stack applications with SST on AWS. SST uses Pulumi under the hood to provision infrastructure through TypeScript, providing high-level components for Lambda functions, containers, databases, frontends, and event-driven architectures — all defined in a single `sst.config.ts` file.

This skill covers the AWS provider with TypeScript/Node.js. SST supports 150+ providers, but this plugin focuses on the most common AWS patterns.

**Key capabilities:**

- **Infrastructure as Code**: Define all resources in `sst.config.ts` using TypeScript
- **Resource Linking**: Type-safe access to infrastructure from application code via `import { Resource } from "sst"`
- **Live Development**: `sst dev` provides live Lambda reloading, local frontend dev servers, and VPC tunneling
- **Full-Stack Frontends**: First-class support for Next.js, Remix, Astro, SvelteKit, and 6 more frameworks
- **Event-Driven**: EventBridge Bus, SQS Queue, SNS Topic, DynamoDB Streams with subscriber patterns
- **Containers**: ECS Fargate clusters and services with auto-scaling and load balancing
- **Workflows**: Step Functions state machines and Lambda Durable Functions

## Workflow Guidance

Refer to these supporting files for detailed guidance on specific workflows:

| File | When to Use |
| ---- | ----------- |
| [getting-started.md](getting-started.md) | Decision tree: what are you building? Routes to the right component and guide |
| [components.md](components.md) | SST component reference: Function, Bucket, Dynamo, Queue, Bus, Postgres, API Gateway, Cluster, and more |
| [frontend-frameworks.md](frontend-frameworks.md) | Next.js, Remix, Astro, SvelteKit, SolidStart, Nuxt, and other frontend deployments |
| [resource-linking.md](resource-linking.md) | The `link` prop, `Resource` SDK, type generation, custom linkables |
| [dev-workflow.md](dev-workflow.md) | `sst dev` modes, live Lambda, local databases, VPC tunneling |
| [deployment.md](deployment.md) | Stages, secrets, `sst deploy`, `sst diff`, removal policies, CI/CD |
| [providers.md](providers.md) | Adding providers, raw Pulumi resources, transforms (`transform` prop, `$transform` global), `Output<T>` |
| [event-driven-architecture.md](event-driven-architecture.md) | EventBridge patterns, publishing, filtering, choreography vs orchestration |
| [event-sources.md](event-sources.md) | S3 notifications, DynamoDB Streams, SQS, SNS, Kinesis, Cron, Realtime |
| [orchestration-and-workflows.md](orchestration-and-workflows.md) | Step Functions state machines, Lambda Durable Functions |
| [optimization.md](optimization.md) | Memory tuning, cold starts, arm64, concurrency, cost optimization |
| [observability.md](observability.md) | SST Console, CloudWatch logging, Powertools, tracing |
| [troubleshooting.md](troubleshooting.md) | `sst diagnostic`, state repair, common errors and solutions |

## Best Practices

### Resource Linking

- Do: Use the `link` prop to grant access between resources — it handles IAM permissions automatically
- Do: Access linked resources via `import { Resource } from "sst"` for type-safe access
- Don't: Hardcode ARNs, URLs, or resource names — always use Resource linking
- Don't: Manually craft IAM policies when `link` can handle it

### Project Configuration

- Do: Set `removal: "retain"` for production stages to protect S3 buckets and DynamoDB tables
- Do: Use `protect: true` for production stages to prevent accidental deletion
- Do: Use personal stages for development (e.g., `--stage matt`)
- Don't: Deploy to production without running `sst diff` first

### Functions

- Do: Use `arm64` architecture for ~20% cost savings: `architecture: "arm64"`
- Do: Set appropriate `memory` and `timeout` per function workload, not global defaults
- Do: Use `link` instead of `permissions` when connecting to SST-managed resources
- Don't: Use the default `nodejs18.x` runtime — prefer `nodejs22.x` or later

### Security

- Do: Store secrets with `sst secret set` — never in environment variables or code
- Do: Use VPC endpoints instead of NAT Gateways for AWS service access when possible
- Don't: Use wildcard (`*`) IAM policies — SST's `link` prop generates least-privilege permissions automatically

### Containers vs Functions

- Do: Use `sst.aws.Function` for event-driven, short-lived workloads (< 15 min)
- Do: Use `sst.aws.Cluster` + `sst.aws.Service` for long-running services, connection pools, or WebSocket servers
- Do: Use `sst.aws.Task` for async background jobs (ECS Fargate tasks)

## Lambda Limits Quick Reference

| Resource | Limit |
| -------- | ----- |
| Function timeout | 900 seconds (15 minutes) |
| Memory | 128 MB – 10,240 MB |
| 1 vCPU equivalent | 1,769 MB memory |
| Synchronous payload (request + response) | 6 MB each |
| Async invocation payload | 1 MB |
| Streamed response | 200 MB |
| Deployment package (.zip, uncompressed) | 250 MB |
| Deployment package (.zip upload, compressed) | 50 MB |
| Container image | 10 GB |
| Layers per function | 5 |
| Environment variables (aggregate) | 4 KB |
| `/tmp` ephemeral storage | 512 MB – 10,240 MB |
| Account concurrent executions (default) | 1,000 (requestable increase) |

Check Service Quotas: `aws lambda get-account-settings`

## Troubleshooting Quick Reference

| Error | Cause | Solution |
| ----- | ----- | ------- |
| "Resource already exists" | State drift from manual changes | Run `sst refresh` to sync state |
| "Lock is held" | Previous process died mid-deploy | Run `sst unlock` |
| "Cannot delete stack" | Protected stage or retained resources | Check `protect` and `removal` settings |
| Function timeout | Insufficient timeout or VPC issues | Increase `timeout` prop, check VPC connectivity |
| Permission denied at runtime | Missing resource link | Add resource to `link` array |
| "No provider configured" | Provider not installed | Run `sst add aws` |
| TypeScript errors in config | Invalid `sst.config.ts` | Check imports, ensure `npm install` has been run |

For detailed troubleshooting, see [troubleshooting.md](troubleshooting.md).

## Configuration

### Prerequisites

1. **Node.js 18+**: `node --version`
2. **AWS CLI with credentials**: `aws sts get-caller-identity`
3. **SST CLI**: `npx sst version` (or install globally)
4. **Docker Desktop** (optional): For local database development and container builds

### Plugin Configuration

This plugin supports optional user configuration:

- **defaultStage**: Default stage name for `sst dev` and `sst deploy` (e.g., `dev`, your username)
- **awsRegion**: Default AWS region (e.g., `us-east-1`)
- **devMode**: When `true`, prefer `sst dev` patterns over `sst deploy` in suggestions

### TypeScript Validation Hook

This plugin includes a `PostToolUse` hook that runs `tsc --noEmit --skipLibCheck` after edits to `sst.config.ts`. If validation fails, the error is returned as a system message. The hook requires `node_modules` with SST types installed and silently skips if unavailable. Disable via `/hooks`.
