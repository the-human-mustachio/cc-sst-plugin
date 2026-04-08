# Frontend Frameworks

SST supports deploying full-stack frontend frameworks to AWS with automatic CDN, SSL, and server-side rendering.

## Supported Frameworks

| Component | Framework | SSR | Container Deploy |
| --------- | --------- | --- | ---------------- |
| `sst.aws.Nextjs` | Next.js | Yes | Yes |
| `sst.aws.Remix` | Remix | Yes | Yes |
| `sst.aws.Astro` | Astro | Yes | Yes |
| `sst.aws.SvelteKit` | SvelteKit | Yes | Yes |
| `sst.aws.SolidStart` | SolidStart | Yes | Yes |
| `sst.aws.Nuxt` | Nuxt | Yes | Yes |
| `sst.aws.React` | React (TanStack) | Yes | Yes |
| `sst.aws.TanStackStart` | TanStack Start | Yes | Yes |
| `sst.aws.Analog` | Angular Analog | Yes | Yes |
| `sst.aws.StaticSite` | Any static site | No | No |

## Common Pattern

All framework components share the same pattern:

```typescript
const bucket = new sst.aws.Bucket("Uploads");
const table = new sst.aws.Dynamo("Data", {
  fields: { pk: "string" },
  primaryIndex: { hashKey: "pk" },
});

new sst.aws.Nextjs("MyApp", {
  link: [bucket, table],
  domain: "app.example.com",
  path: "packages/web",       // Path to the framework project (monorepo)
  environment: {
    NEXT_PUBLIC_APP_URL: "https://app.example.com",
  },
});
```

**Key props (shared across frameworks):**

| Prop | Description |
| ---- | ----------- |
| `link` | Resources to link (available server-side via `Resource`) |
| `domain` | Custom domain with automatic SSL |
| `path` | Path to the framework project (for monorepos) |
| `environment` | Environment variables |
| `server` | Server-side config: `memory`, `architecture`, `vpc` |

## Serverless vs Container Deployment

### Serverless (default)

By default, SST deploys frameworks using Lambda + CloudFront:

```typescript
new sst.aws.Nextjs("MyApp", {
  link: [bucket],
});
```

- Static assets served from S3 via CloudFront
- Server-side rendering via Lambda
- Auto-scales to zero, pay-per-request

### Container deployment

For frameworks that need long-running connections or more control:

```typescript
const vpc = new sst.aws.Vpc("MyVpc");
const cluster = new sst.aws.Cluster("MyCluster", { vpc });

new sst.aws.Service("MyApp", {
  cluster,
  link: [bucket],
  image: {
    dockerfile: "Dockerfile",
    context: ".",
  },
  loadBalancer: {
    ports: [{ listen: "443/https", forward: "3000/http" }],
    domain: "app.example.com",
  },
  dev: {
    command: "npm run dev",
  },
});
```

## Accessing Linked Resources

In server-side code (API routes, server components, middleware):

```typescript
import { Resource } from "sst";

// Next.js API Route
export async function GET() {
  const bucketName = Resource.Uploads.name;
  // Use AWS SDK with the bucket name
}
```

**Important:** `Resource` is only available server-side. For client-side values, use the `environment` prop with framework-specific prefixes:

- Next.js: `NEXT_PUBLIC_*`
- Remix: Use `loader` to pass to client
- Astro: `PUBLIC_*`
- SvelteKit: `PUBLIC_*`
- Nuxt: `NUXT_PUBLIC_*`

## Static Sites

For SPAs or static content without SSR:

```typescript
new sst.aws.StaticSite("Docs", {
  path: "packages/docs",
  build: {
    command: "npm run build",
    output: "dist",
  },
  domain: "docs.example.com",
  environment: {
    VITE_API_URL: api.url,
  },
});
```

## Multiple Frontends with Router

Serve multiple frontends under one domain using `sst.aws.Router`:

```typescript
const app = new sst.aws.Nextjs("App", { ... });
const docs = new sst.aws.StaticSite("Docs", { ... });

new sst.aws.Router("MyRouter", {
  domain: "example.com",
  routes: {
    "/docs/*": docs.url,
    "/*": app.url,
  },
});
```

## Dev Mode

During `sst dev`, framework components run their local dev server:

```bash
npx sst dev next dev          # Next.js
npx sst dev remix dev         # Remix
npx sst dev astro dev         # Astro
```

The `sst dev` multiplexer shows both your frontend dev server and SST infrastructure logs. All linked resources are injected as environment variables so `Resource` works locally.
