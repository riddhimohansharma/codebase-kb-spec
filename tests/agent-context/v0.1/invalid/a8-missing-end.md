<!-- ckb-ac:begin acc=0.1 ckb=0.3 commit=89abcdef0123456789abcdef0123456789abcdef -->
# Agent context — orders-service

A typescript and sql repository (domain commerce, system orders, production).

## Non-negotiables
- Never edit src/generated/: regenerate it with npm run build. (`package.json:7`)
- Do not edit generated or vendored files: `src/generated/**`, `vendor/**`.

## Shape
- `packages/orders-client`: library
- `src`: module
- `src/lib`: library
- `src/orders`: service

## Commands
- `npm run build` (build)
- `npm test` (test)

## Changing X obligates Y
- `src/orders/routes.ts` → `docs/openapi.yaml`: A change to an HTTP route also updates docs/openapi.yaml.

## Traps
- Refund tests hit a stub, not Stripe: a green run proves nothing about the live refund path.

## Before you say you're done
- These pass: `npm test`.
- If you touched src/orders/routes.ts, regenerate the client with npm run build.


