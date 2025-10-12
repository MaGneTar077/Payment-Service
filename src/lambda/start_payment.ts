import { DynamoDB, CloudWatch, SQS } from "aws-sdk";
import { v4 as uuidv4 } from "uuid";

const dynamo = new DynamoDB.DocumentClient();
const cloudwatch = new CloudWatch();
const sqs = new SQS();

const PAYMENT_TABLE = process.env.PAYMENT_TABLE!;
const CHECK_BALANCE_QUEUE_URL = process.env.CHECK_BALANCE_QUEUE_URL!;


/**
 * 📨 Handler principal - se ejecuta automáticamente cuando llega un mensaje a la SQS
 */
export const handler = async (event: any) => {
  console.log("📥 Evento recibido desde SQS:", JSON.stringify(event, null, 2));

  const startTime = Date.now();
  let traceId = uuidv4(); // por si el mensaje no tiene uno

  try {
    for (const record of event.Records) {
      try {
        const message = JSON.parse(record.body);

        // 🔹 Mantener el traceId original si viene en el mensaje
        traceId = message.traceId ?? traceId;

        console.log(
          JSON.stringify({
            traceId,
            step: "MESSAGE_RECEIVED",
            message,
            timestamp: new Date().toISOString(),
          })
        );

        const amount = Number(message.amount ?? message.service?.precio_mensual ?? 0);

        const paymentItem = {
          traceId,
          paymentId: message.paymentId || uuidv4(),
          userId: message.userId,
          cardId: message.cardId,
          service: message.service,
          amount,
          status: message.status || "INITIAL",
          createdAt: new Date().toISOString(),
        };

        await dynamo.put({
          TableName: PAYMENT_TABLE,
          Item: paymentItem,
        }).promise();

        console.log(JSON.stringify({
          traceId,
          step: "PAYMENT_INSERTED",
          table: PAYMENT_TABLE,
          paymentId: paymentItem.paymentId,
          timestamp: new Date().toISOString(),
        }));

        const checkBalancePayload = {
          traceId, // 👈 ahora conserva el mismo
          paymentId: paymentItem.paymentId,
          userId: paymentItem.userId,
          cardId: paymentItem.cardId,
          amount: paymentItem.amount,
          service: paymentItem.service,
        };

        await sqs.sendMessage({
          QueueUrl: CHECK_BALANCE_QUEUE_URL,
          MessageBody: JSON.stringify(checkBalancePayload),
        }).promise();

        console.log(JSON.stringify({
          traceId,
          step: "MESSAGE_SENT_TO_CHECK_BALANCE",
          queue: CHECK_BALANCE_QUEUE_URL,
          timestamp: new Date().toISOString(),
        }));

        await publishMetric("PaymentProcessed", 1, traceId);
      } catch (innerError: any) {
        console.error(`[${traceId}] ❌ Error procesando mensaje:`, innerError.message);
        await publishMetric("PaymentFailed", 1, traceId);
      }
    }

    const duration = Date.now() - startTime;
    console.log(JSON.stringify({
      traceId,
      step: "COMPLETE",
      processedCount: event.Records.length,
      duration_ms: duration,
    }));

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "Mensajes procesados correctamente",
        traceId,
        count: event.Records.length,
      }),
    };
  } catch (error: any) {
    console.error(`[${traceId}] Error general en Lambda:`, error);
    await publishMetric("PaymentHandlerError", 1, traceId);
    throw error;
  }
};


/**
 * 📈 Envía métricas personalizadas a CloudWatch
 */
async function publishMetric(metricName: string, value: number, traceId: string) {
  try {
    await cloudwatch
      .putMetricData({
        Namespace: "PaymentService",
        MetricData: [
          {
            MetricName: metricName,
            Timestamp: new Date(),
            Unit: "Count",
            Value: value,
            Dimensions: [
              { Name: "TraceId", Value: traceId },
            ],
          },
        ],
      })
      .promise();
  } catch (error: any) {
    console.warn(
      `⚠️ Falló la publicación de la métrica ${metricName}: ${error.message}`
    );
  }
}

