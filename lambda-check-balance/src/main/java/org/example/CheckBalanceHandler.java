package org.example;

import com.amazonaws.services.dynamodbv2.AmazonDynamoDBClientBuilder;
import com.amazonaws.services.dynamodbv2.document.*;
import com.amazonaws.services.dynamodbv2.document.spec.QuerySpec;
import com.amazonaws.services.dynamodbv2.document.spec.UpdateItemSpec;
import com.amazonaws.services.dynamodbv2.document.utils.NameMap;
import com.amazonaws.services.dynamodbv2.document.utils.ValueMap;
import com.amazonaws.services.dynamodbv2.model.ReturnValue;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import com.amazonaws.services.sqs.AmazonSQS;
import com.amazonaws.services.sqs.AmazonSQSClientBuilder;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.*;
import java.util.concurrent.*;

public class CheckBalanceHandler implements RequestHandler<SQSEvent, Void> {

    private final ObjectMapper mapper = new ObjectMapper();
    private final DynamoDB dynamoDB = new DynamoDB(AmazonDynamoDBClientBuilder.defaultClient());
    private final AmazonSQS sqs = AmazonSQSClientBuilder.defaultClient();

    private final String cardTable = System.getenv("CARD_TABLE_NAME");
    private final String paymentTable = System.getenv("PAYMENT_TABLE_NAME");
    private final String transactionQueueUrl = System.getenv("TRANSACTION_QUEUE_URL");

    @Override
    public Void handleRequest(SQSEvent event, Context context) {

        int threads = Math.min(event.getRecords().size(), 5);
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        List<Future<?>> futures = new ArrayList<>();

        context.getLogger().log("📨 Mensajes recibidos: " + event.getRecords().size() + "\n");

        for (SQSEvent.SQSMessage message : event.getRecords()) {
            futures.add(executor.submit(() -> processMessage(message, context)));
        }

        for (Future<?> future : futures) {
            try {
                future.get(30, TimeUnit.SECONDS);
            } catch (Exception e) {
                context.getLogger().log("⚠️ Error en una tarea: " + e.getMessage() + "\n");
            }
        }

        executor.shutdown();
        return null;
    }

    private void processMessage(SQSEvent.SQSMessage message, Context context) {
        try {
            Map<String, Object> payload = mapper.readValue(message.getBody(), Map.class);
            String cardId = (String) payload.get("cardId");
            String traceId = (String) payload.get("traceId");
            Map<String, Object> service = (Map<String, Object>) payload.get("service");

            context.getLogger().log("🧾 Procesando mensaje con traceId=" + traceId + " y cardId=" + cardId + "\n");

            if (traceId == null || traceId.isEmpty()) {
                context.getLogger().log("⚠️ traceId nulo o vacío, no se puede actualizar el pago\n");
                return;
            }

            // Simulación de latencia
            Thread.sleep(2000);

            Table cardTbl = dynamoDB.getTable(cardTable);

            QuerySpec query = new QuerySpec()
                    .withKeyConditionExpression("#u = :uuid")
                    .withNameMap(new NameMap().with("#u", "uuid"))
                    .withValueMap(new ValueMap().withString(":uuid", cardId))
                    .withScanIndexForward(false)
                    .withMaxResultSize(1);

            ItemCollection<QueryOutcome> items = cardTbl.query(query);
            Iterator<Item> iterator = items.iterator();
            Item cardItem = iterator.hasNext() ? iterator.next() : null;

            if (cardItem == null) {
                updatePayment(traceId, "FAILED", "Tarjeta no encontrada", context);
                context.getLogger().log("❌ No se encontró la tarjeta con uuid=" + cardId + "\n");
                return;
            }

            double balance = cardItem.getDouble("balance");
            context.getLogger().log("💰 Saldo actual: " + balance + "\n");

            double price = 0;
            if (service != null && service.get("precio_mensual") != null) {
                try {
                    price = Double.parseDouble(service.get("precio_mensual").toString());
                } catch (NumberFormatException e) {
                    context.getLogger().log("⚠️ precio_mensual inválido: " + service.get("precio_mensual") + "\n");
                    updatePayment(traceId, "FAILED", "Precio inválido en el mensaje", context);
                    return;
                }
            } else {
                context.getLogger().log("⚠️ El servicio no contiene precio_mensual.\n");
                updatePayment(traceId, "FAILED", "Falta precio_mensual en el mensaje", context);
                return;
            }

            context.getLogger().log("💸 Precio mensual: " + price + "\n");

            if (balance < price) {
                updatePayment(traceId, "FAILED", "Saldo insuficiente", context);
                context.getLogger().log("❌ Saldo insuficiente (balance=" + balance + ", precio=" + price + ")\n");
            } else {
                updatePayment(traceId, "IN_PROGRESS", null, context);
                context.getLogger().log("✅ Saldo suficiente. Enviando a cola de transacción...\n");

                String nextMessage = mapper.writeValueAsString(payload);
                sqs.sendMessage(transactionQueueUrl, nextMessage);
            }

        } catch (Exception e) {
            context.getLogger().log("❌ Error procesando mensaje: " + e.getMessage() + "\n");
            e.printStackTrace();
        }
    }

    private void updatePayment(String traceId, String status, String error, Context context) {
        try {
            Table paymentTbl = dynamoDB.getTable(paymentTable);

            UpdateItemSpec updateSpec = new UpdateItemSpec()
                    .withPrimaryKey("traceId", traceId)
                    .withUpdateExpression("set #s = :s, #e = :e")
                    .withNameMap(new NameMap()
                            .with("#s", "status")
                            .with("#e", "error"))
                    .withValueMap(new ValueMap()
                            .withString(":s", status)
                            .withString(":e", error != null ? error : ""))
                    .withReturnValues(ReturnValue.UPDATED_NEW);

            paymentTbl.updateItem(updateSpec);
            context.getLogger().log("💾 Estado del pago actualizado: " + status + "\n");

        } catch (Exception e) {
            context.getLogger().log("⚠️ Error actualizando pago con traceId=" + traceId + ": " + e.getMessage() + "\n");
        }
    }
}
