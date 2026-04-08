# SST Plugin for Claude Code

Build and deploy full-stack applications with [SST](https://sst.dev) on AWS. This plugin provides Claude Code with comprehensive knowledge of SST's component-based infrastructure-as-code model, enabling AI-assisted development from project initialization through production deployment.

## Features

### Application Lifecycle
- Project initialization with `sst init`
- Live development with `sst dev` (Lambda proxy, multiplexer, VPC tunneling)
- Deployment with `sst deploy`, preview with `sst diff`
- Secrets management, state management, stage protection

### AWS Components
- **Compute:** Lambda Functions, ECS Fargate (Cluster/Service/Task), CronV2
- **APIs:** API Gateway V2 (HTTP), API Gateway V1 (REST), WebSocket, AppSync
- **Databases:** DynamoDB, PostgreSQL, Aurora, MySQL, Redis, OpenSearch
- **Storage:** S3 Buckets, EFS, Vector stores
- **Messaging:** EventBridge Bus, SQS Queue, SNS Topic, Kinesis Streams

### Frontend Frameworks
Next.js, Remix, Astro, SvelteKit, SolidStart, Nuxt, React (TanStack), TanStack Start, Analog, Static Sites

### Event-Driven Architecture
- EventBridge patterns, filtering, choreography vs orchestration
- DynamoDB Streams, SQS, SNS, S3 notifications, Kinesis subscribers
- Step Functions state machines, Lambda Durable Functions

### Observability & Optimization
- SST Console integration, CloudWatch logging, Powertools
- Memory tuning, ARM64, cold start mitigation, cost optimization

### Hooks
- Automatic TypeScript validation of `sst.config.ts` on edit

## Installation

### From Claude Code

```bash
claude plugin add sst
```

### Manual

Clone this repository and register it as a Claude Code plugin:

```bash
git clone https://github.com/mattpuccio/sst-plugin.git
claude plugin add ./sst-plugin
```

### Validation Hook Setup

The plugin includes a PostToolUse hook that validates `sst.config.ts` after edits. It requires:
- `npx` available in PATH
- `node_modules` with SST types installed (`npm install` in your project)
- `jq` for JSON parsing

The hook exits silently if prerequisites are missing.

## Configuration

On enable, the plugin prompts for optional settings:

| Setting | Description | Default |
| ------- | ----------- | ------- |
| `defaultStage` | Default SST stage name | None |
| `awsRegion` | Default AWS region | None |
| `devMode` | Prefer `sst dev` patterns | None |

All settings are optional.

## Usage

### Automatic activation

The skill activates when discussing SST-related topics (sst, lambda, serverless, resource linking, etc.).

### Manual activation

```
/sst [what are you building?]
```

### Example prompts

- "Create a new SST project with a REST API and DynamoDB table"
- "Add an S3 bucket with image upload notifications"
- "Set up EventBridge with order processing subscribers"
- "Deploy my app to a staging environment"
- "Configure local development with a Docker Postgres"

## What's Included

### Skill Guides (14 files)

| Guide | Description |
| ----- | ----------- |
| `SKILL.md` | Entry point, decision tree, best practices, limits reference |
| `getting-started.md` | Project initialization, `sst.config.ts` anatomy |
| `components.md` | AWS component reference (10 detailed + 25 reference) |
| `frontend-frameworks.md` | 10 framework deployments |
| `resource-linking.md` | Type-safe resource access, custom linkables |
| `dev-workflow.md` | `sst dev`, local databases, VPC tunneling |
| `deployment.md` | Stages, secrets, state, CI/CD |
| `providers.md` | Pulumi providers, raw resources, transforms |
| `event-driven-architecture.md` | EventBridge patterns and filtering |
| `event-sources.md` | All event source subscriber patterns |
| `orchestration-and-workflows.md` | Step Functions, Durable Functions |
| `optimization.md` | Performance and cost optimization |
| `observability.md` | Logging, tracing, monitoring |
| `troubleshooting.md` | Common errors and debugging |

### Validation Hook

PostToolUse hook runs `tsc --noEmit --skipLibCheck` on `sst.config.ts` edits.

## Plugin Structure

```
sst-plugin/
├── .claude-plugin/
│   └── plugin.json
├── hooks/
│   └── hooks.json
├── scripts/
│   └── validate-config.sh
├── skills/sst/
│   ├── SKILL.md
│   ├── getting-started.md
│   ├── components.md
│   ├── frontend-frameworks.md
│   ├── resource-linking.md
│   ├── dev-workflow.md
│   ├── deployment.md
│   ├── providers.md
│   ├── event-driven-architecture.md
│   ├── event-sources.md
│   ├── orchestration-and-workflows.md
│   ├── optimization.md
│   ├── observability.md
│   └── troubleshooting.md
├── README.md
└── LICENSE
```

## Using with Other Tools

The skill guides follow the [Agent Skills](https://github.com/anthropics/agent-skills) standard and work with compatible tools including Cursor, VS Code, and Gemini CLI.

## Prerequisites

- Node.js 18+
- AWS CLI with configured credentials
- SST CLI (`npx sst` or global install)
- Docker Desktop (optional, for local databases and container builds)

## Related Resources

- [SST Documentation](https://sst.dev/docs/)
- [SST Examples](https://sst.dev/docs/examples/)
- [SST GitHub](https://github.com/sst/sst)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Serverless Land](https://serverlessland.com/)

## License

MIT
