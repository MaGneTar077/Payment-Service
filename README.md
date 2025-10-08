# Payment-Service
This repository contains all lambdas and SQS queues related to the payment flow.

## 🚀 General Flow

1. **POST /payment** → Starts the payment and generates a "traceId".
2. **StartPaymentLambda** → Saves the initial state ("INITIAL") to DynamoDB and launches the "CheckBalanceQueue".
3. **CheckBalanceLambda** → Validates the available balance, updates the status, and launches the "TransactionQueue".
4. **TransactionLambda** → Calls the "/transactions/purchase" API and sets the status to "FINISH".
5. **GET /status/{traceId}** → Returns the payment status ("CheckStatusPaymentLambda")
