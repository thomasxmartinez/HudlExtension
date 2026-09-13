// infra/modules/rg-budget.bicep
//
// A cost budget scoped to the resource group it is deployed into. Because the
// deployment scope IS the resource group, the budget automatically measures only
// that group's spend, no explicit filter needed.

targetScope = 'resourceGroup'

@description('Budget name, unique within the resource group.')
param budgetName string

@description('Monthly budget amount.')
param amount int

@description('Actual-spend alert threshold, percent.')
param actualThresholdPercent int

@description('Forecasted-spend backstop threshold, percent.')
param forecastThresholdPercent int

@description('Email that receives alerts.')
param contactEmail string

param startDate string
param endDate string

resource budget 'Microsoft.Consumption/budgets@2023-05-01' = {
  name: budgetName
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
      endDate: endDate
    }
    notifications: {
      actual_over_threshold: {
        enabled: true
        operator: 'GreaterThan'
        threshold: actualThresholdPercent
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
