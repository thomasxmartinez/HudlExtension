// infra/budget.bicep
//
// Deployed FIRST, before any billable resource, per the "budget before anything
// else" rule. It creates the resource group for this rung and two cost budgets:
//   - a subscription-wide guardrail (watches all spend, survives RG teardown)
//   - a resource-group tripwire (watches only this rung, torn down with the RG)
//
// A budget ALERTS, it does not cap spend. Each budget has two notifications:
// an ACTUAL threshold (already-spent tripwire) and a FORECASTED threshold
// (projected end-of-month overrun, the early smoke detector).

targetScope = 'subscription'

@description('Azure region for the resource group.')
param location string = 'eastus'

@description('Resource group for this rung. One RG per rung, torn down when the rung passes.')
param resourceGroupName string = 'rg-hudlextension-m1'

@description('Email that receives budget alerts. Required and passed at deploy time so a personal address is never committed to this public repo.')
param contactEmail string

@description('Monthly amount for the subscription-wide guardrail budget, in your billing currency.')
param subscriptionBudgetAmount int = 100

@description('Actual-spend alert threshold for the subscription budget, percent.')
param subscriptionThresholdPercent int = 70

@description('Monthly amount for the resource-group tripwire budget.')
param resourceGroupBudgetAmount int = 50

@description('Actual-spend alert threshold for the resource-group budget, percent.')
param resourceGroupThresholdPercent int = 50

@description('Forecasted-spend backstop threshold for both budgets, percent.')
param forecastThresholdPercent int = 100

@description('First day of the budget period. Defaults to the first of the current month.')
param budgetStartDate string = utcNow('yyyy-MM-01')

// Budgets recur monthly; a far-future end keeps them running without yearly edits.
var budgetEndDate = dateTimeAdd(budgetStartDate, 'P10Y', 'yyyy-MM-dd')

// The resource group is free and not a billable resource, so creating it before
// the budgets does not violate "budget before anything billable."
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

// Subscription-wide guardrail. Deployed at subscription scope because that is
// exactly what it measures: every dollar in the subscription.
resource subscriptionBudget 'Microsoft.Consumption/budgets@2023-05-01' = {
  name: 'sub-monthly-guardrail'
  properties: {
    category: 'Cost'
    amount: subscriptionBudgetAmount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: budgetStartDate
      endDate: budgetEndDate
    }
    notifications: {
      actual_over_threshold: {
        enabled: true
        operator: 'GreaterThan'
        threshold: subscriptionThresholdPercent
        thresholdType: 'Actual'
        contactEmails: [ contactEmail ]
      }
      forecast_over_threshold: {
        enabled: true
        operator: 'GreaterThan'
        threshold: forecastThresholdPercent
        thresholdType: 'Forecasted'
        contactEmails: [ contactEmail ]
      }
    }
  }
}

// Resource-group tripwire. Deployed via a module scoped to the RG so it measures
// only this rung's spend and is removed when the RG is torn down.
module resourceGroupBudget 'modules/rg-budget.bicep' = {
  name: 'rg-budget'
  scope: rg
  params: {
    budgetName: 'rg-monthly-tripwire'
    amount: resourceGroupBudgetAmount
    actualThresholdPercent: resourceGroupThresholdPercent
    forecastThresholdPercent: forecastThresholdPercent
    contactEmail: contactEmail
    startDate: budgetStartDate
    endDate: budgetEndDate
  }
}
