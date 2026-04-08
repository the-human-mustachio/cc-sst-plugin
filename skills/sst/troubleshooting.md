# Troubleshooting

## Diagnostic Tools

### Generate a debug report

```bash
npx sst diagnostic
```

Creates a zip file with environment info, config, and state metadata for sharing with support.

### Check deployed state

```bash
npx sst state list              # List all stages
npx sst state export            # Export current stage state
npx sst state export --decrypt  # Include secret values
```

### Preview changes

```bash
npx sst diff
```

Shows what SST would create, update, or delete without making changes.

## Common Errors

### "Resource already exists"

**Cause:** State drift — a resource was modified or created outside SST.

**Fix:**
```bash
npx sst refresh
```

This syncs SST's state with actual cloud resources.

### "Lock is held by another process"

**Cause:** A previous `sst dev` or `sst deploy` process crashed without releasing the lock.

**Fix:**
```bash
npx sst unlock
```

### "Cannot delete stack" / "Cannot remove stage"

**Cause:** Stage is protected or has retained resources.

**Check:**
1. Is `protect: true` set for this stage? Remove protection first.
2. Are there `removal: "retain"` resources? Delete them manually in AWS Console, then `sst refresh`.

### TypeScript errors in sst.config.ts

**Cause:** Missing types, wrong imports, or SST API changes.

**Fix:**
```bash
npm install                     # Ensure sst types are installed
npx sst install                 # Install provider types
npx tsc --noEmit --skipLibCheck # Check for errors
```

Common issues:
- Missing `/// <reference path="./.sst/platform/config.d.ts" />` at top of config
- Using imports instead of globals for provider resources (`aws.*` is a global, don't import it)
- Using plain values where `Output<T>` is returned (use `.apply()`)

### "No provider configured"

**Cause:** AWS provider not added.

**Fix:**
```bash
npx sst add aws
npx sst install
```

### Function timeout at runtime

**Causes:**
1. Insufficient `timeout` setting
2. VPC Lambda without internet access (missing NAT Gateway or VPC endpoints)
3. Downstream service is slow or unreachable

**Fix:**
```typescript
new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  timeout: "60 seconds",  // Increase timeout
  vpc,                     // If VPC is needed, ensure NAT/endpoints exist
});
```

### Permission denied at runtime

**Cause:** Resource not linked to the function.

**Fix:** Add the resource to the `link` array:

```typescript
new sst.aws.Function("MyFunction", {
  handler: "src/handler.handler",
  link: [bucket, table],  // Add missing resources here
});
```

SST generates IAM permissions automatically for linked resources.

### "Cannot find module 'sst'" in application code

**Cause:** `sst` package not installed in the application.

**Fix:**
```bash
npm install sst
```

### "sst-env.d.ts" missing or outdated types

**Cause:** Types are generated during `sst dev` and `sst deploy`.

**Fix:**
```bash
npx sst dev    # Generates sst-env.d.ts
# OR
npx sst deploy # Also generates sst-env.d.ts
```

### State corruption

**Cause:** Interrupted deployment, manual state edits, or bugs.

**Fix:**
```bash
npx sst state repair
```

If repair fails:
```bash
npx sst state export > backup.json    # Backup first
npx sst refresh                        # Resync with cloud
```

### VPC-related issues

**ENI cleanup timeout:** When removing VPC-attached Lambda functions, ENI cleanup can take 10-20 minutes. This is normal AWS behavior.

**Can't reach the internet from VPC Lambda:**
- Add a NAT Gateway to the VPC
- Or use VPC endpoints for the specific AWS services you need

**Can't connect to RDS locally:**
```bash
sudo npx sst tunnel install  # One-time setup
npx sst tunnel               # Connect to VPC
```

### sst dev not picking up changes

**Causes:**
1. `.env` file changed — restart `sst dev`
2. File outside watch directory — check `watch` config in `sst.config.ts`
3. `sst.config.ts` changed — restart `sst dev` (config changes require restart)

## Debugging Workflow

1. **Check logs**: Look at `sst dev` multiplexer output or CloudWatch
2. **Check config**: Run `sst diff` to verify resource state
3. **Check state**: Run `sst state export` to inspect deployment state
4. **Check permissions**: Verify `link` arrays include all needed resources
5. **Check connectivity**: For VPC issues, verify NAT/endpoints/security groups
6. **Generate diagnostic**: Run `sst diagnostic` for a full environment report

## Getting Help

- SST Documentation: https://sst.dev/docs/
- SST Discord: Community support
- SST GitHub: https://github.com/sst/sst/issues
- `sst diagnostic` output helps when filing issues
