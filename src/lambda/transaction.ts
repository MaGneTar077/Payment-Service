import {
  SQSClient,
  SendMessageCommand,
} from "@aws-sdk/client-sqs";
import {
  CloudWatchClient,
  PutMetricDataCommand,
} from "@aws-sdk/client-cloudwatch";
import {
  DynamoDBClient,
  UpdateItemCommand,
} from "@aws-sdk/client-dynamodb";
import type { SQSEvent, SQSRecord } from "aws-lambda";
import fetch, { Response } from "node-fetch";


const sqs = new SQSClient({});
const cloudwatch = new CloudWatchClient({});
const dynamo = new DynamoDBClient({});

const PAYMENT_API_URL =
  process.env.PAYMENT_API_URL ??
  "https://x8ewzbrr6k.execute-api.us-east-1.amazonaws.com/dev/transactions/purchase";

const DEAD_LETTER_QUEUE_URL = process.env.DEAD_LETTER_QUEUE_URL!;
const PAYMENT_TABLE = process.env.PAYMENT_TABLE!;

export const handler = async (event: SQSEvent) => {
  console.log("📥 Evento recibido desde SQS:", JSON.stringify(event, null, 2));

  //const fetch = (await import("node-fetch")).default;

  for (const record of event.Records) {
    const body = JSON.parse(record.body) as {
      traceId: string;
      userId?: string;
      cardId: string;
      amount: number;
      service?: { proveedor?: string };
    };

    const traceId = body.traceId;
    console.log(`🚀 Procesando transacción con traceId: ${traceId}`);

    try {
      // 🕒 Simular retardo bancario
      await new Promise((res) => setTimeout(res, 5000));

      // 🧾 Construir payload correcto para el core bancario
      const purchasePayload = {
        merchant: body.service?.proveedor ?? "Comercio no identificado",
        cardId: body.cardId,
        amount: body.amount,
      };

      console.log("📦 Payload enviado al core bancario:", purchasePayload);

      // 🔄 Reintentos en caso de error 502 o fallas
      let response: Response;
      let attempts = 3;
      while (attempts > 0) {
        response = await fetch(PAYMENT_API_URL, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(purchasePayload),
        });

        const text = await response.text();
        console.log("🔁 Intento:", 4 - attempts, "→ Status:", response.status, "Body:", text);

        if (response.ok) {
          console.log("✅ Transacción registrada exitosamente en el core bancario");
          break;
        }

        attempts--;
        if (attempts === 0) {
          throw new Error(`API Gateway failed with ${response.status}: ${text}`);
        }

        console.warn("⚠️ Reintentando llamada al core bancario...");
        await new Promise((r) => setTimeout(r, 1000));
      }

      // ✅ Marcar transacción como finalizada en DynamoDB
      await dynamo.send(
        new UpdateItemCommand({
          TableName: PAYMENT_TABLE,
          Key: { traceId: { S: traceId } },
          UpdateExpression: "SET #status = :status",
          ExpressionAttributeNames: { "#status": "status" },
          ExpressionAttributeValues: { ":status": { S: "FINISH" } },
        })
      );
      console.log("✅ Transacción marcada como finish en DynamoDB");

      // 📊 Registrar métrica exitosa en CloudWatch
      await cloudwatch.send(
        new PutMetricDataCommand({
          Namespace: "TransactionProcessor",
          MetricData: [
            {
              MetricName: "TransactionsProcessed",
              Dimensions: [
                { Name: "Status", Value: "Success" },
                { Name: "Lambda", Value: "TransactionHandler" },
              ],
              Unit: "Count",
              Value: 1,
            },
          ],
        })
      );

    } catch (error: unknown) {
      console.error("💥 Error procesando mensaje:", error);

      // Manejo seguro del tipo `unknown`
      let errorMessage = "Unknown error";
      if (error instanceof Error) {
        errorMessage = error.message;
      } else if (typeof error === "string") {
        errorMessage = error;
      } else {
        try {
          errorMessage = JSON.stringify(error);
        } catch {
          errorMessage = "Unserializable error";
        }
      }

      // 📝 Actualizar estado en DynamoDB a 'failed'
      await dynamo.send(
        new UpdateItemCommand({
          TableName: PAYMENT_TABLE,
          Key: { traceId: { S: traceId } },
          UpdateExpression: "SET #status = :status, #error = :error",
          ExpressionAttributeNames: {
            "#status": "status",
            "#error": "error",
          },
          ExpressionAttributeValues: {
            ":status": { S: "failed" },
            ":error": { S: errorMessage },
          },
        })
      );

      // 📊 Registrar métrica de error en CloudWatch
      await cloudwatch.send(
        new PutMetricDataCommand({
          Namespace: "TransactionProcessor",
          MetricData: [
            {
              MetricName: "TransactionsProcessed",
              Dimensions: [
                { Name: "Status", Value: "Error" },
                { Name: "Lambda", Value: "TransactionHandler" },
              ],
              Unit: "Count",
              Value: 1,
            },
          ],
        })
      );

      // 🔄 Enviar mensaje fallido a Dead Letter Queue
      if (DEAD_LETTER_QUEUE_URL) {
        await sqs.send(
          new SendMessageCommand({
            QueueUrl: DEAD_LETTER_QUEUE_URL,
            MessageBody: JSON.stringify({
              error: errorMessage,
              originalMessage: record.body,
            }),
          })
        );
        console.log("📤 Mensaje fallido reenviado a Dead Letter Queue");
      }
    }
  }

  return {
    statusCode: 200,
    body: JSON.stringify({ message: "Mensajes procesados correctamente" }),
  };
};
