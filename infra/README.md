# Infrastructure

Bicep templates for HudlExtension. Everything reproducible from the templates,
no portal clicks.

## Order

The budget deploys **before any billable resource**, so the cost guardrail is
always in place first.

## budget.bicep

Subscription-scoped. Creates:

- the rung's resource group (`rg-hudlextension-m1`)
- a subscription-wide **guardrail** budget ($100/mo, alerts at 70% actual and 100% forecast)
- a resource-group **tripwire** budget ($50/mo, alerts at 50% actual and 100% forecast),
  deployed via `modules/rg-budget.bicep`

A budget **alerts, it does not cap** spend. The alert email is a required
parameter, passed at deploy time so a personal address is never committed to this
public repo.

### Deploy

```sh
# preview (validates server-side, creates nothing)
az deployment sub what-if \
  --location eastus \
  --template-file infra/budget.bicep \
  --parameters contactEmail=<your-email> \
  --name budget-m1

# deploy (swap what-if for create)
az deployment sub create \
  --location eastus \
  --template-file infra/budget.bicep \
  --parameters contactEmail=<your-email> \
  --name budget-m1
```

Note: managing Azure resources requires an MFA-authenticated session, so
`az login` must complete a second factor before these commands will run.
